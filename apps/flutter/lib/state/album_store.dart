// Shared album state with stable photo IDs, two-by-two favorites, soft deletion, and
// capture insertion. Account snapshots preserve ordering, flags, and capture metadata
// across logout and recovery.

//

import 'dart:async';
import 'package:flutter/widgets.dart';

import '../content/lab.g.dart';
import 'captured_photo.dart';
import '../api/media_models.dart';
import 'remote_album.dart';
import '../content/app.g.dart';
import 'package:intl/intl.dart';

@immutable
class AlbumPhoto {
  const AlbumPhoto({
    required this.id,
    required this.image,
    this.liked = false,
    this.deleted = false,
    this.shared = false,
    this.capture,
    this.remote,
  });

  final String id;

  final String image;

  final bool liked;

  final bool deleted;

  final bool shared;

  final CapturedPhoto? capture;
  final ApiPhoto? remote;

  bool get isVideo => remote?.isVideo ?? capture?.isVideo ?? false;
  double get aspectRatio {
    final width = remote?.width?.toDouble() ?? capture?.width ?? 0;
    final height = remote?.height?.toDouble() ?? capture?.height ?? 0;
    return width > 0 && height > 0 ? width / height : 3 / 4;
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'image': image,
    'liked': liked,
    'deleted': deleted,
    'shared': shared,
    'capture': capture?.toJson(),
  };

  factory AlbumPhoto.fromJson(Map<String, dynamic> json) => AlbumPhoto(
    id: json['id'] as String,
    image: json['image'] as String,
    liked: json['liked'] == true,
    deleted: json['deleted'] == true,
    shared: json['shared'] == true,
    capture: json['capture'] == null
        ? null
        : CapturedPhoto.fromJson(json['capture'] as Map<String, dynamic>),
  );

  ImageProvider get provider => remote != null
      ? NetworkImage(remote!.isVideo ? remote!.thumbnailUrl : remote!.url)
      : capture?.image ?? AssetImage(image);
  ImageProvider get thumbnailProvider =>
      remote != null ? NetworkImage(remote!.thumbnailUrl) : provider;

  AlbumPhoto copyWith({bool? liked, bool? deleted, bool? shared}) => AlbumPhoto(
    id: id,
    image: image,
    liked: liked ?? this.liked,
    deleted: deleted ?? this.deleted,
    shared: shared ?? this.shared,
    capture: capture,
    remote: remote,
  );

  @override
  bool operator ==(Object other) =>
      other is AlbumPhoto &&
      other.id == id &&
      other.image == image &&
      other.liked == liked &&
      other.deleted == deleted &&
      other.shared == shared &&
      other.capture == capture;

  @override
  int get hashCode => Object.hash(id, image, liked, deleted, shared, capture);

  @override
  String toString() =>
      'AlbumPhoto($id${liked ? ' ♥' : ''}${deleted ? ' ⌫' : ''}${shared ? ' ✓' : ''})';
}

@immutable
class AlbumSection {
  const AlbumSection({
    required this.content,
    required this.photos,
    this.includeCalls = true,
    ImageProvider? hero,
    this.date,
  }) : _hero = hero;

  final AlbumV5SectionContent content;

  final List<AlbumPhoto> photos;

  final bool includeCalls;

  final ImageProvider? _hero;
  final DateTime? date;

  String get id => content.id;

  List<CallCardV5Content> get calls =>
      includeCalls ? content.callCards : const [];

  bool get isToday => id == todaySectionId;

  ImageProvider? get heroImage {
    final cover = content.cover;
    if (cover != null) return AssetImage(cover);
    if (_hero != null) return _hero;
    if (isToday) return photos.isEmpty ? null : photos.first.provider;
    return null;
  }

  AlbumSectionKind get kind {
    if (photos.isEmpty && calls.isNotEmpty) return AlbumSectionKind.callsOnly;
    return calls.isEmpty
        ? AlbumSectionKind.photosOnly
        : AlbumSectionKind.photosCalls;
  }

  bool get isEmpty => photos.isEmpty && calls.isEmpty;

  Iterable<String> get likedIds => [
    for (final p in photos)
      if (p.liked) p.id,
  ];

  AlbumSection withPhotos(List<AlbumPhoto> next) => AlbumSection(
    content: content,
    photos: List.unmodifiable(next),
    includeCalls: false,
    hero: _hero,
    date: date,
  );

  @override
  String toString() => 'AlbumSection($id, ${kind.name}, ${photos.length})';
}

const String todaySectionId = 'today';

String formatAlbumDate(DateTime date, {String languageCode = 'ko'}) =>
    languageCode == 'ko'
    ? '${date.year}년 ${date.month}월 ${date.day}일'
    : DateFormat.yMMMMd('en').format(date);

String _fileOf(String asset) => asset.split('/').last;

List<AlbumPhoto> coveredContentPhotos(AlbumV5SectionContent content) {
  final grid = content.grid;
  if (grid == null) return const [];
  final visible = {for (final p in grid.photos) p.image};
  return [
    for (final row in grid.rows)
      for (final image in row)
        if (!visible.contains(image))
          AlbumPhoto(id: '${content.id}/${_fileOf(image)}', image: image),
  ];
}

DateTime? _storedDate(String? value) {
  if (value == null) return null;
  final iso = DateTime.tryParse(value);
  if (iso != null) return iso;
  final legacy = RegExp(r'^(\d{4})년 (\d{1,2})월 (\d{1,2})일$').firstMatch(value);
  return legacy == null
      ? null
      : DateTime(
          int.parse(legacy[1]!),
          int.parse(legacy[2]!),
          int.parse(legacy[3]!),
        );
}

class AlbumSnapshot {
  AlbumSnapshot({
    required Map<String, List<AlbumPhoto>> photos,
    required this.empty,
    required this.captureCount,
    required this.photoCount,
    required this.callCount,
    this.todayTitle,
    this.todayHero,
    this.latestCapture,
  }) : photos = Map.unmodifiable({
         for (final entry in photos.entries)
           entry.key: List<AlbumPhoto>.unmodifiable(entry.value),
       });

  final Map<String, List<AlbumPhoto>> photos;
  final bool empty;
  final int captureCount;
  final int photoCount;
  final int callCount;
  final String? todayTitle;
  final AlbumPhoto? todayHero;
  final AlbumPhoto? latestCapture;

  Map<String, Object?> toJson() => {
    'photos': {
      for (final entry in photos.entries)
        entry.key: [for (final photo in entry.value) photo.toJson()],
    },
    'empty': empty,
    'captureCount': captureCount,
    'photoCount': photoCount,
    'callCount': callCount,
    'todayTitle': todayTitle,
    'todayHero': todayHero?.toJson(),
    'latestCapture': latestCapture?.toJson(),
  };

  factory AlbumSnapshot.fromJson(Map<String, dynamic> json) {
    AlbumPhoto? photo(Object? value) => value == null
        ? null
        : AlbumPhoto.fromJson(value as Map<String, dynamic>);
    final rows = json['photos'] as Map<String, dynamic>;
    return AlbumSnapshot(
      photos: {
        for (final entry in rows.entries)
          entry.key: [
            for (final value in entry.value as List)
              AlbumPhoto.fromJson(value as Map<String, dynamic>),
          ],
      },
      empty: json['empty'] == true,
      captureCount: json['captureCount'] as int,
      photoCount: json['photoCount'] as int,
      callCount: json['callCount'] as int,
      todayTitle: json['todayTitle'] as String?,
      todayHero: photo(json['todayHero']),
      latestCapture: photo(json['latestCapture']),
    );
  }
}

class AlbumStore extends ChangeNotifier {
  AlbumStore({List<AlbumV5SectionContent>? content, bool empty = false})
    : _customContent = content,
      _empty = empty {
    _load();
    remote.addListener(notifyListeners);
  }

  String _languageCode = 'ko';
  AppContent get _copy => _languageCode == 'en' ? appContentEn : appContent;
  void setLanguage(String code) {
    if (_languageCode == code) return;
    _languageCode = code;
    notifyListeners();
  }

  final RemoteAlbum remote = RemoteAlbum();
  bool get usesBackend => remote.enabled;
  AlbumPhoto _remotePhoto(ApiPhoto p) =>
      AlbumPhoto(id: p.id, image: p.url, liked: p.favorite, remote: p);

  List<AlbumSection> _serverSections({bool favorites = false}) {
    final days = <String, DateTime>{};
    String day(DateTime at) {
      final d = at.toLocal();
      final key =
          'remote-${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      days[key] = DateTime(d.year, d.month, d.day);
      return key;
    }

    final photos = <String, List<ApiPhoto>>{},
        calls = <String, List<ApiCall>>{};
    for (final p
        in (favorites ? remote.favoritePhotos : remote.photos).values) {
      if (!favorites || p.favorite) {
        (photos[day(p.takenAt ?? p.createdAt)] ??= []).add(p);
      }
    }
    for (final c in (favorites ? remote.favoriteCalls : remote.calls).values) {
      if (!favorites || c.favorite) (calls[day(c.createdAt)] ??= []).add(c);
    }
    final keys = days.keys.toList()
      ..sort((a, b) => days[b]!.compareTo(days[a]!));
    return [
      for (final key in keys)
        _serverSection(key, days[key]!, photos[key] ?? [], calls[key] ?? []),
    ];
  }

  AlbumSection _serverSection(
    String key,
    DateTime date,
    List<ApiPhoto> photos,
    List<ApiCall> calls,
  ) {
    photos.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    calls.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final copy = _copy.v6.backend;
    final cards = [
      for (final call in calls)
        CallCardV5Content(
          nodeId: call.id,
          variant: call.status == 'missed'
              ? 'failed'
              : photos.isEmpty
              ? 'default'
              : 'list',
          direction: call.callerId == remote.ownerId
              ? CallDirection.outgoing
              : CallDirection.incoming,
          icon: call.callerId == remote.ownerId
              ? 'arrow-up-right'
              : 'arrow-down-left',
          title: call.status == 'missed'
              ? copy.callMissed
              : call.title ?? copy.callRecord,
          subtitle: [
            LabTextSpan(
              '${_callLabel(call.status)} · ${_duration(call.duration)}',
              LabTextWeight.regular,
            ),
          ],
        ),
    ];
    return AlbumSection(
      date: date,
      content: AlbumV5SectionContent(
        id: key,
        figmaName: '',
        nodeId: '',
        kind: photos.isEmpty
            ? AlbumSectionKind.callsOnly
            : calls.isEmpty
            ? AlbumSectionKind.photosOnly
            : AlbumSectionKind.photosCalls,
        tint: photos.isEmpty
            ? 'background/canvas/neutral/base'
            : 'section/tint',
        heroGradient: null,
        cover: null,
        title: formatAlbumDate(date, languageCode: _languageCode),
        subtitle: '',
        stats: AlbumStatsContent(
          photos: '${photos.length}',
          calls: '${calls.length}',
        ),
        callCards: cards,
        grid: null,
        featured: const [],
      ),
      photos: photos.map(_remotePhoto).toList(),
      hero: photos.isEmpty
          ? null
          : NetworkImage(
              photos.first.isVideo
                  ? photos.first.thumbnailUrl
                  : photos.first.url,
            ),
    );
  }

  String _duration(double seconds) =>
      '${seconds ~/ 60}:${(seconds.toInt() % 60).toString().padLeft(2, '0')}';
  String _callLabel(String status) {
    final copy = _copy.v6.backend;
    return switch (status) {
      'ringing' => copy.callRinging,
      'active' => copy.callActive,
      'missed' => copy.callMissed,
      'declined' => copy.callDeclined,
      'failed' => copy.callFailed,
      _ => copy.callEnded,
    };
  }

  Future<List<AlbumPhoto>> savePhotos(List<CapturedPhoto> captures) async {
    if (!usesBackend) return addPhotos(captures);
    final added = await remote.upload(captures);
    final result = added.map(_remotePhoto).toList();
    if (result.isNotEmpty) _latestCapture = result.last;
    return result;
  }

  Future<bool> removePhotos(Iterable<String> ids) async {
    if (!usesBackend) {
      deletePhotos(ids);
      return true;
    }
    var ok = true;
    for (final id in ids.toList()) {
      if (!await remote.deletePhoto(id)) ok = false;
    }
    return ok;
  }

  final List<AlbumV5SectionContent>? _customContent;
  List<AlbumV5SectionContent> get _content =>
      _customContent ??
      (_languageCode == 'en' ? labAlbumV5En.sections : labAlbumV5.sections);

  final Map<String, List<AlbumPhoto>> _photos = {};
  bool _empty;
  int _captureCount = 0;
  AlbumPhoto? _latestCapture;

  String? _todayTitle;

  AlbumPhoto? _todayHero;

  AlbumSnapshot snapshot() => AlbumSnapshot(
    photos: _photos,
    empty: _empty,
    captureCount: _captureCount,
    todayTitle: _todayTitle,
    todayHero: _todayHero,
    latestCapture: _latestCapture,
    photoCount: sections.fold(
      0,
      (count, section) => count + section.photos.length,
    ),
    callCount: sections.fold(
      0,
      (count, section) => count + section.calls.length,
    ),
  );

  void restoreSnapshot(AlbumSnapshot snapshot) {
    _photos
      ..clear()
      ..addAll({
        for (final entry in snapshot.photos.entries)
          entry.key: List.of(entry.value),
      });
    _empty = snapshot.empty;
    _captureCount = snapshot.captureCount;
    _todayTitle = snapshot.todayTitle;
    _todayHero = snapshot.todayHero;
    _latestCapture = snapshot.latestCapture;
    notifyListeners();
  }

  void _load() {
    _photos.clear();
    _todayTitle = null;
    _todayHero = null;
    for (final section in _content) {
      final grid = section.grid;
      _photos[section.id] = [
        if (grid != null)
          for (final photo in grid.photos)
            AlbumPhoto(
              id: '${section.id}/${_fileOf(photo.image)}',
              image: photo.image,
              liked: photo.liked,
            ),
      ];
    }
  }

  AlbumV5SectionContent _todayContent(String title, int photoCount) {
    final template = _content.firstWhere(
      (c) => c.kind == AlbumSectionKind.photosOnly,
      orElse: () => _content.last,
    );
    return AlbumV5SectionContent(
      id: todaySectionId,
      figmaName: 'today',
      nodeId: template.nodeId,
      kind: AlbumSectionKind.photosOnly,
      tint: template.tint,
      heroGradient: template.heroGradient,
      cover: null,
      title: _storedDate(title) == null
          ? title
          : formatAlbumDate(_storedDate(title)!, languageCode: _languageCode),
      subtitle: template.subtitle,
      stats: AlbumStatsContent(
        photos: '$photoCount',
        calls: template.stats.calls,
      ),
      callCards: const [],
      grid: null,
      featured: const [],
    );
  }

  bool get emptyMode => _empty;

  Iterable<({AlbumV5SectionContent content, List<AlbumPhoto> all})>
  get _raw sync* {
    final title = _todayTitle;
    final today = _photos[todaySectionId];
    if (title != null && today != null && today.isNotEmpty) {
      final visible = today.where((p) => !p.deleted).length;
      yield (content: _todayContent(title, visible), all: today);
    }
    if (_empty) return;
    for (final c in _content) {
      yield (content: c, all: _photos[c.id] ?? const <AlbumPhoto>[]);
    }
  }

  AlbumSection _sectionOf(
    AlbumV5SectionContent content,
    List<AlbumPhoto> photos, {
    bool includeCalls = true,
  }) => AlbumSection(
    content: content,

    photos: List.unmodifiable(photos),
    includeCalls: includeCalls,
    hero: content.id == todaySectionId ? _todayHero?.provider : null,
    date: content.id == todaySectionId ? _storedDate(_todayTitle) : null,
  );

  List<AlbumSection> get sections => usesBackend
      ? _serverSections()
      : [
          for (final r in _raw)
            if (_sectionOf(r.content, [
                  for (final p in r.all)
                    if (!p.deleted) p,
                ])
                case final section when !section.isEmpty)
              section,
        ];

  List<AlbumSection> get likedSections => usesBackend
      ? _serverSections(favorites: true)
      : [
          for (final r in _raw)
            if ([
                  for (final p in r.all)
                    if (p.liked && !p.deleted) p,
                ]
                case final liked when liked.isNotEmpty)
              _sectionOf(r.content, liked, includeCalls: false),
        ];

  List<AlbumSection> get deletedSections => usesBackend
      ? const []
      : [
          for (final r in _raw)
            if ([
                  for (final p in r.all)
                    if (p.deleted) p,
                ]
                case final gone when gone.isNotEmpty)
              _sectionOf(r.content, gone, includeCalls: false),
        ];

  bool get isEmpty => sections.isEmpty;

  bool isEmptyFor({required bool hasPartner}) => !hasPartner || isEmpty;

  AlbumPhoto? get latestCapture {
    if (!usesBackend) return _latestCapture;
    final own =
        remote.photos.values
            .where((p) => p.uploaderId == remote.ownerId)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return own.isEmpty ? null : _remotePhoto(own.first);
  }

  AlbumSection? sectionOf(String sectionId) {
    for (final s in sections) {
      if (s.id == sectionId) return s;
    }
    return null;
  }

  AlbumPhoto? photoAt(String sectionId, int index) {
    final photos = sectionOf(sectionId)?.photos;
    if (photos == null || index < 0 || index >= photos.length) return null;
    return photos[index];
  }

  AlbumPhoto? photoById(String id) => locate(id)?.photo;

  AlbumPhoto? anyPhotoById(String id) {
    if (usesBackend) {
      final photo = remote.photos[id] ?? remote.favoritePhotos[id];
      return photo == null ? null : _remotePhoto(photo);
    }
    for (final list in _photos.values) {
      for (final p in list) {
        if (p.id == id) return p;
      }
    }
    return null;
  }

  AlbumPhoto? photoByImage(String image) {
    for (final s in sections) {
      for (final p in s.photos) {
        if (p.image == image) return p;
      }
    }
    return null;
  }

  ({String sectionId, int index, AlbumPhoto photo})? locate(String id) {
    for (final s in sections) {
      for (var i = 0; i < s.photos.length; i++) {
        if (s.photos[i].id == id) {
          return (sectionId: s.id, index: i, photo: s.photos[i]);
        }
      }
    }
    return null;
  }

  bool _update(Set<String> ids, AlbumPhoto Function(AlbumPhoto) update) {
    var changed = false;
    for (final entry in _photos.entries) {
      final list = entry.value;
      for (var i = 0; i < list.length; i++) {
        if (!ids.contains(list[i].id)) continue;
        final next = update(list[i]);
        if (next != list[i]) {
          list[i] = next;
          changed = true;
        }
      }
    }
    if (_latestCapture case final latest? when ids.contains(latest.id)) {
      final next = update(latest);
      _latestCapture = next.deleted ? null : next;
    }
    if (_todayHero case final hero? when ids.contains(hero.id)) {
      _todayHero = update(hero);
    }
    if (changed) notifyListeners();
    return changed;
  }

  bool toggleLike(String photoId) {
    final photo = photoById(photoId);
    if (photo == null) return false;
    final next = !photo.liked;
    if (usesBackend) {
      unawaited(remote.favoritePhoto(photoId, next));
      return next;
    }
    _update({photoId}, (p) => p.copyWith(liked: next));
    return next;
  }

  void setLiked(String photoId, bool liked) => setLikes([photoId], liked);

  void setLikes(Iterable<String> photoIds, bool liked) {
    if (usesBackend) {
      for (final id in photoIds.toSet()) {
        unawaited(remote.favoritePhoto(id, liked));
      }
    } else {
      _update(photoIds.toSet(), (p) => p.copyWith(liked: liked));
    }
  }

  void markShared(Iterable<String> photoIds) =>
      _update(photoIds.toSet(), (p) => p.copyWith(shared: true));

  int deletePhotos(Iterable<String> photoIds) {
    if (usesBackend) {
      unawaited(removePhotos(photoIds));
      return 0;
    }
    final ids = photoIds.toSet();
    var count = 0;
    for (final list in _photos.values) {
      for (final p in list) {
        if (ids.contains(p.id) && !p.deleted) count++;
      }
    }
    _update(ids, (p) => p.deleted ? p : p.copyWith(deleted: true));
    return count;
  }

  int restorePhotos(Iterable<String> photoIds) {
    if (usesBackend) return 0;
    final ids = photoIds.toSet();
    var count = 0;
    for (final list in _photos.values) {
      for (final p in list) {
        if (ids.contains(p.id) && p.deleted) count++;
      }
    }
    _update(ids, (p) => p.deleted ? p.copyWith(deleted: false) : p);
    return count;
  }

  AlbumPhoto _insertToday(CapturedPhoto capture, DateTime now) {
    _captureCount++;
    final photo = AlbumPhoto(
      id: 'capture-$_captureCount',
      image: capture.uri,
      capture: capture,
    );
    _todayTitle ??= now.toIso8601String();
    (_photos[todaySectionId] ??= []).insert(0, photo);
    _todayHero = photo;
    _latestCapture = photo;
    return photo;
  }

  /// RN `album.addCapture(photo, now?) → photoId`.
  AlbumPhoto addCapture(CapturedPhoto capture, {DateTime? now}) {
    if (usesBackend) throw StateError('Use savePhotos for server uploads');
    final photo = _insertToday(capture, now ?? DateTime.now());
    notifyListeners();
    return photo;
  }

  /// RN `album.addPhotos(photos, now?) → photoIds`.
  List<AlbumPhoto> addPhotos(List<CapturedPhoto> photos, {DateTime? now}) {
    if (usesBackend) throw StateError('Use savePhotos for server uploads');
    if (photos.isEmpty) return const [];
    final at = now ?? DateTime.now();
    final added = <AlbumPhoto>[];
    for (var i = photos.length - 1; i >= 0; i--) {
      added.insert(0, _insertToday(photos[i], at));
    }
    notifyListeners();
    return added;
  }

  void setEmptyMode(bool empty) {
    if (_empty == empty) return;
    _empty = empty;
    notifyListeners();
  }

  void reset({bool empty = false}) {
    _load();
    _empty = empty;
    _captureCount = 0;
    _latestCapture = null;
    notifyListeners();
  }

  @override
  void dispose() {
    remote.removeListener(notifyListeners);
    remote.dispose();
    super.dispose();
  }
}

class AlbumScope extends InheritedNotifier<AlbumStore> {
  const AlbumScope({super.key, required AlbumStore store, required super.child})
    : super(notifier: store);

  static AlbumStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AlbumScope>();
    assert(scope != null, 'AlbumScope 가 없다 — CameoApp 아래에서 쓴다');
    return scope!.notifier!;
  }

  static AlbumStore read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AlbumScope>();
    assert(scope != null, 'AlbumScope 가 없다 — CameoApp 아래에서 쓴다');
    return scope!.notifier!;
  }

  static AlbumStore? maybeRead(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AlbumScope>()?.notifier;
}
