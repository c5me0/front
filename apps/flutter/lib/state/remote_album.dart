import 'dart:async';

import 'package:flutter/foundation.dart';

import '../api/cameo_api.dart';
import '../api/media_models.dart';
import 'captured_photo.dart';
import 'photo_upload.dart';

/// Server-owned gallery state. Epochs prevent one account's pending requests from
/// publishing into another account; revisions prevent refresh/mutation races.
class RemoteAlbum extends ChangeNotifier {
  CameoApi? _api;
  String? ownerId, _partnerId;
  void Function(ApiException)? onError;
  final Map<String, ApiPhoto> photos = {};
  final Map<String, ApiCall> calls = {};
  final Map<String, ApiPhoto> favoritePhotos = {};
  final Map<String, ApiCall> favoriteCalls = {};
  String? _favoritePhotoCursor, _favoriteCallCursor;
  bool _loadingFavorites = false;
  bool get favoritesHaveMore =>
      _favoritePhotoCursor != null || _favoriteCallCursor != null;
  bool get loadingFavorites => _loadingFavorites;
  String? _photoCursor, _callCursor;
  int _photoPages = 1, _callPages = 1, _epoch = 0, _revision = 0;
  bool loading = false, uploading = false, _disposed = false;
  String? error;
  Future<void>? _fetch;
  final Set<String> _mutating = {};
  bool get enabled => _api != null;
  bool get connected => enabled && ownerId != null && _partnerId != null;
  bool get hasMore => _photoCursor != null || _callCursor != null;
  bool get busy => loading || uploading || _mutating.isNotEmpty;
  bool _current(int epoch) => !_disposed && epoch == _epoch;

  void configure(
    CameoApi? api,
    String? owner,
    String? partner, {
    void Function(ApiException)? onError,
  }) {
    this.onError = onError;
    if (identical(api, _api) && owner == ownerId && partner == _partnerId) {
      return;
    }
    _epoch++;
    _fetch = null;
    _api = api;
    ownerId = owner;
    _partnerId = partner;
    photos.clear();
    calls.clear();
    favoritePhotos.clear();
    favoriteCalls.clear();
    _favoritePhotoCursor = null;
    _favoriteCallCursor = null;
    _loadingFavorites = false;
    _mutating.clear();
    _photoCursor = null;
    _callCursor = null;
    _photoPages = 1;
    _callPages = 1;
    loading = false;
    uploading = false;
    error = null;
    notifyListeners();
    if (connected) unawaited(refresh());
  }

  void _failure(Object problem, int epoch) {
    if (!_current(epoch)) return;
    final value = problem is ApiException
        ? problem
        : const ApiException('internal_error');
    error = value.code;
    onError?.call(value);
  }

  Future<void> _coalesce(Future<void> Function() run) {
    final pending = _fetch;
    if (pending != null) return pending;
    final work = run();
    _fetch = work;
    unawaited(
      work.whenComplete(() {
        if (identical(_fetch, work)) _fetch = null;
      }),
    );
    return work;
  }

  Future<void> refresh({bool renewUrls = false}) =>
      _coalesce(() => _refresh(renewUrls: renewUrls));

  ApiPhoto _photoFromServer(ApiPhoto photo, {bool renewUrls = false}) {
    final previous = photos[photo.id] ?? favoritePhotos[photo.id];
    if (renewUrls ||
        previous == null ||
        previous.urlExpiresAt.isBefore(
          DateTime.now().add(const Duration(minutes: 5)),
        ) ||
        Uri.parse(previous.url).origin != Uri.parse(photo.url).origin) {
      return photo;
    }
    return photo.retainingUrlsFrom(previous);
  }

  Future<void> _refresh({required bool renewUrls}) async {
    if (!connected || loading) return;
    final epoch = _epoch, revision = _revision, api = _api!;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final photoRows = <String, ApiPhoto>{}, callRows = <String, ApiCall>{};
      String? photoCursor, callCursor;
      for (var page = 0; page < _photoPages; page++) {
        final result = await api.photos(cursor: photoCursor);
        if (!_current(epoch)) return;
        photoRows.addEntries(
          result.items.map(
            (p) => MapEntry(p.id, _photoFromServer(p, renewUrls: renewUrls)),
          ),
        );
        if (result.nextCursor == photoCursor && result.nextCursor != null) {
          throw const ApiException('invalid_response');
        }
        photoCursor = result.nextCursor;
        if (photoCursor == null) break;
      }
      for (var page = 0; page < _callPages; page++) {
        final result = await api.calls(cursor: callCursor);
        if (!_current(epoch)) return;
        callRows.addEntries(result.items.map((c) => MapEntry(c.id, c)));
        if (result.nextCursor == callCursor && result.nextCursor != null) {
          throw const ApiException('invalid_response');
        }
        callCursor = result.nextCursor;
        if (callCursor == null) break;
      }
      if (!_current(epoch) || revision != _revision) return;
      photos
        ..clear()
        ..addAll(photoRows);
      calls
        ..clear()
        ..addAll(callRows);
      _photoCursor = photoCursor;
      _callCursor = callCursor;
    } catch (problem) {
      _failure(problem, epoch);
    } finally {
      if (_current(epoch)) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMore() => _coalesce(_loadMore);

  Future<void> _loadMore() async {
    if (!connected || loading || !hasMore) return;
    final epoch = _epoch, revision = _revision, api = _api!;
    loading = true;
    error = null;
    notifyListeners();
    try {
      if (_photoCursor case final cursor?) {
        final page = await api.photos(cursor: cursor);
        if (!_current(epoch) || revision != _revision) return;
        if (page.nextCursor == cursor) {
          throw const ApiException('invalid_response');
        }
        photos.addEntries(
          page.items.map((p) => MapEntry(p.id, _photoFromServer(p))),
        );
        _photoCursor = page.nextCursor;
        _photoPages++;
      }
      if (_callCursor case final cursor?) {
        final page = await api.calls(cursor: cursor);
        if (!_current(epoch) || revision != _revision) return;
        if (page.nextCursor == cursor) {
          throw const ApiException('invalid_response');
        }
        calls.addEntries(page.items.map((c) => MapEntry(c.id, c)));
        _callCursor = page.nextCursor;
        _callPages++;
      }
    } catch (problem) {
      _failure(problem, epoch);
    } finally {
      if (_current(epoch)) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> refreshFavorites({bool more = false}) async {
    if (!connected || _loadingFavorites) return;
    final epoch = _epoch, revision = _revision, api = _api!;
    _loadingFavorites = true;
    error = null;
    notifyListeners();
    try {
      final photoPage = !more || _favoritePhotoCursor != null
          ? await api.photos(
              favorite: true,
              cursor: more ? _favoritePhotoCursor : null,
            )
          : null;
      if (!_current(epoch)) return;
      final callPage = !more || _favoriteCallCursor != null
          ? await api.calls(
              favorite: true,
              cursor: more ? _favoriteCallCursor : null,
            )
          : null;
      if (!_current(epoch) || revision != _revision) return;
      if (!more) {
        favoritePhotos.clear();
        favoriteCalls.clear();
      }
      if (photoPage != null) {
        if (more &&
            photoPage.nextCursor != null &&
            photoPage.nextCursor == _favoritePhotoCursor) {
          throw const ApiException('invalid_response');
        }
        favoritePhotos.addEntries(
          photoPage.items.map((p) => MapEntry(p.id, _photoFromServer(p))),
        );
        _favoritePhotoCursor = photoPage.nextCursor;
      }
      if (callPage != null) {
        if (more &&
            callPage.nextCursor != null &&
            callPage.nextCursor == _favoriteCallCursor) {
          throw const ApiException('invalid_response');
        }
        favoriteCalls.addEntries(callPage.items.map((c) => MapEntry(c.id, c)));
        _favoriteCallCursor = callPage.nextCursor;
      }
    } catch (problem) {
      _failure(problem, epoch);
    } finally {
      if (_current(epoch)) {
        _loadingFavorites = false;
        notifyListeners();
      }
    }
  }

  Future<bool> _mutate(
    String key,
    Future<void> Function(CameoApi) request,
    void Function() apply,
  ) async {
    if (!connected || !_mutating.add(key)) return false;
    final epoch = _epoch;
    _revision++;
    error = null;
    notifyListeners();
    try {
      await request(_api!);
      if (!_current(epoch)) return false;
      apply();
      _revision++;
      return true;
    } catch (problem) {
      _failure(problem, epoch);
      return false;
    } finally {
      if (_current(epoch)) {
        _mutating.remove(key);
        notifyListeners();
      }
    }
  }

  Future<bool> favoritePhoto(String id, bool value) =>
      _mutate('photo:$id', (api) => api.favoritePhoto(id, value), () {
        final photo = photos[id] ?? favoritePhotos[id];
        if (photo != null) {
          if (photos.containsKey(id)) photos[id] = photo.withFavorite(value);
          if (value) {
            favoritePhotos[id] = photo.withFavorite(true);
          } else {
            favoritePhotos.remove(id);
          }
        }
      });
  Future<bool> deletePhoto(String id) =>
      _mutate('photo:$id', (api) => api.deletePhoto(id), () {
        photos.remove(id);
        favoritePhotos.remove(id);
      });
  Future<bool> favoriteCall(String id, bool value) =>
      _mutate('call:$id', (api) => api.favoriteCall(id, value), () {
        final call = calls[id] ?? favoriteCalls[id];
        if (call != null) {
          if (calls.containsKey(id)) calls[id] = call.withFavorite(value);
          if (value) {
            favoriteCalls[id] = call.withFavorite(true);
          } else {
            favoriteCalls.remove(id);
          }
        }
      });
  Future<bool> deleteCall(String id) =>
      _mutate('call:$id', (api) => api.deleteCall(id), () {
        calls.remove(id);
        favoriteCalls.remove(id);
      });

  Future<List<ApiPhoto>> upload(List<CapturedPhoto> captures) async {
    if (!connected || uploading) return const [];
    final epoch = _epoch, api = _api!;
    uploading = true;
    _revision++;
    error = null;
    notifyListeners();
    final added = <ApiPhoto>[];
    try {
      for (final capture in captures) {
        final data = await preparePhoto(capture);
        if (!_current(epoch)) return const [];
        final upload = await api.reservePhoto(
          contentType: data.contentType,
          sizeBytes: data.bytes.length,
          thumbnailSizeBytes: data.thumbnail.length,
          width: data.width,
          height: data.height,
          takenAt: DateTime.now(),
        );
        if (!_current(epoch)) return const [];
        await api.uploadObject(upload.url, data.bytes, data.contentType);
        if (!_current(epoch)) return const [];
        await api.uploadObject(
          upload.thumbnailUrl,
          data.thumbnail,
          'image/png',
        );
        if (!_current(epoch)) return const [];
        final photo = await api.completePhoto(upload.photoId);
        if (!_current(epoch)) return const [];
        photos[photo.id] = photo;
        added.add(photo);
        _revision++;
        notifyListeners();
      }
    } catch (problem) {
      _failure(problem, epoch);
    } finally {
      if (_current(epoch)) {
        uploading = false;
        notifyListeners();
      }
    }
    return _current(epoch) ? added : const [];
  }

  void receivedPhoto(ApiPhoto photo) {
    if (!connected) return;
    _revision++;
    photos[photo.id] = _photoFromServer(photo);
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    super.dispose();
  }
}
