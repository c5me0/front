// Shared album state with stable photo IDs, two-by-two favorites, soft deletion, and
// capture insertion. Account snapshots preserve ordering, flags, and capture metadata
// across logout and recovery.

//

import 'package:flutter/widgets.dart';

import '../content/lab.g.dart';
import 'captured_photo.dart';

@immutable
class AlbumPhoto {
  const AlbumPhoto({
    required this.id,
    required this.image,
    this.liked = false,
    this.deleted = false,
    this.shared = false,
    this.capture,
  });

  final String id;

  final String image;

  final bool liked;

  final bool deleted;

  final bool shared;

  final CapturedPhoto? capture;

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

  ImageProvider get provider => capture?.image ?? AssetImage(image);

  AlbumPhoto copyWith({bool? liked, bool? deleted, bool? shared}) => AlbumPhoto(
    id: id,
    image: image,
    liked: liked ?? this.liked,
    deleted: deleted ?? this.deleted,
    shared: shared ?? this.shared,
    capture: capture,
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
  }) : _hero = hero;

  final AlbumV5SectionContent content;

  final List<AlbumPhoto> photos;

  final bool includeCalls;

  final ImageProvider? _hero;

  String get id => content.id;

  List<CallCardV5Content> get calls =>
      includeCalls ? content.callCards : const [];

  bool get isToday => id == todaySectionId;

  ImageProvider? get heroImage {
    final cover = content.cover;
    if (cover != null) return AssetImage(cover);
    if (isToday) {
      return _hero ?? (photos.isEmpty ? null : photos.first.provider);
    }
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
  );

  @override
  String toString() => 'AlbumSection($id, ${kind.name}, ${photos.length})';
}

const String todaySectionId = 'today';

String formatAlbumDate(DateTime date) =>
    '${date.year}년 ${date.month}월 ${date.day}일';

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
    : _content = content ?? labAlbumV5.sections,
      _empty = empty {
    _load();
  }

  final List<AlbumV5SectionContent> _content;

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
      title: title,
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
  );

  List<AlbumSection> get sections => [
    for (final r in _raw)
      if (_sectionOf(r.content, [
            for (final p in r.all)
              if (!p.deleted) p,
          ])
          case final section when !section.isEmpty)
        section,
  ];

  List<AlbumSection> get likedSections => [
    for (final r in _raw)
      if ([
            for (final p in r.all)
              if (p.liked && !p.deleted) p,
          ]
          case final liked when liked.isNotEmpty)
        _sectionOf(r.content, liked, includeCalls: false),
  ];

  List<AlbumSection> get deletedSections => [
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

  AlbumPhoto? get latestCapture => _latestCapture;

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
    _update({photoId}, (p) => p.copyWith(liked: next));
    return next;
  }

  void setLiked(String photoId, bool liked) =>
      _update({photoId}, (p) => p.copyWith(liked: liked));

  void setLikes(Iterable<String> photoIds, bool liked) =>
      _update(photoIds.toSet(), (p) => p.copyWith(liked: liked));

  void markShared(Iterable<String> photoIds) =>
      _update(photoIds.toSet(), (p) => p.copyWith(shared: true));

  int deletePhotos(Iterable<String> photoIds) {
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
    _todayTitle ??= formatAlbumDate(now);
    (_photos[todaySectionId] ??= []).insert(0, photo);
    _todayHero = photo;
    _latestCapture = photo;
    return photo;
  }

  /// RN `album.addCapture(photo, now?) → photoId`.
  AlbumPhoto addCapture(CapturedPhoto capture, {DateTime? now}) {
    final photo = _insertToday(capture, now ?? DateTime.now());
    notifyListeners();
    return photo;
  }

  /// RN `album.addPhotos(photos, now?) → photoIds`.
  List<AlbumPhoto> addPhotos(List<CapturedPhoto> photos, {DateTime? now}) {
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
