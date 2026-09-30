// Regression coverage for album store. Preserve behavior, layout, and interaction
// expectations.

import 'package:cameo/content/lab.g.dart';
import 'package:cameo/state/album_store.dart';
import 'package:cameo/state/captured_photo.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AlbumStore store;
  late int notified;
  setUp(() {
    store = AlbumStore();
    notified = 0;
    store.addListener(() => notified++);
  });
  tearDown(() => store.dispose());

  test(
    '섹션 = content labAlbumV5 (최신 → 과거) · 사진 = grid.photos 순서 · id = 섹션:순번 · 종류',
    () {
      final content = labAlbumV5.sections;
      expect(
        [for (final s in store.sections) s.id],
        [for (final s in content) s.id],
      );
      final first = store.sections.first;
      expect(first.photos.length, content.first.grid!.photos.length);
      expect(
        first.photos.first.id,
        '${content.first.id}/${content.first.grid!.photos.first.image.split('/').last}',
      );
      expect(first.photos.first.image, content.first.grid!.photos.first.image);
      expect(first.photos.first.liked, isTrue);
      expect(first.likedIds, [first.photos.first.id]);
      expect(
        [for (final s in store.sections) s.kind],
        [
          AlbumSectionKind.photosCalls,
          AlbumSectionKind.callsOnly,
          AlbumSectionKind.photosOnly,
        ],
      );
      expect(store.isEmpty, isFalse);
      expect(store.photoAt(first.id, 3)!.id, first.photos[3].id);
      expect(store.photoAt(first.id, 999), isNull);
      expect(store.photoAt('nope', 0), isNull);
      expect(store.locate(first.photos[3].id)!.index, 3);
      expect(
        store.photoByImage(content.first.grid!.photos[2].image)!.id,
        first.photos[2].id,
      );
    },
  );

  test('toggleLike · setLiked — 알림 · 새 값 · 없는 사진은 false', () {
    final id = store.sections.first.photos[1].id;
    expect(store.toggleLike(id), isTrue);
    expect(store.photoById(id)!.liked, isTrue);
    expect(notified, 1);
    expect(store.toggleLike(id), isFalse);
    expect(store.photoById(id)!.liked, isFalse);
    store.setLiked(id, false);
    expect(notified, 2);
    expect(store.toggleLike('nope'), isFalse);
  });

  test(
    'markShared (사진 시트 A 체크 · 선택 공유) · deletePhotos (리플로우 — 순번이 당겨진다, id 는 그대로)',
    () {
      final photos = store.sections.first.photos;
      final a = photos[1].id;
      final b = photos[2].id;
      final c = photos[3].id;
      store.markShared([a, b]);
      expect(store.photoById(a)!.shared, isTrue);
      expect(store.photoById(c)!.shared, isFalse);
      expect(store.deletePhotos([a, b]), 2);
      expect(store.photoById(a), isNull);
      expect(store.sections.first.photos[1].id, c);
      expect(store.locate(c)!.index, 1);
      expect(store.deletePhotos(['nope']), 0);
    },
  );

  test(
    'coveredContentPhotos = 2×2 타일에 덮인 content 칸 (시트 전용 — 앨범 스토어 밖, id 규칙 같음). RN 과 같은 값',
    () {
      final covered = [
        for (final s in labAlbumV5.sections) coveredContentPhotos(s),
      ];
      expect(
        [
          for (final list in covered) [for (final p in list) p.image],
        ],
        [
          [
            LabImages.albumSungsuGridR1c2,
            LabImages.albumSungsuGridR2c1,
            LabImages.albumSungsuGridR2c2,
          ],
          <String>[],
          <String>[],
        ],
      );
      for (final p in covered.expand((l) => l)) {
        expect(store.photoById(p.id), isNull);
        expect(p.id, startsWith('${labAlbumV5.sections.first.id}/'));
        expect(p.liked || p.shared, isFalse);
      }
    },
  );

  test('사진을 다 지우면 섹션 종류가 바뀐다 (사진+통화 → 통화만) · 사진만 섹션은 사라진다', () {
    final first = store.sections.first;
    store.deletePhotos(first.photos.map((p) => p.id));
    expect(store.sectionOf(first.id)!.kind, AlbumSectionKind.callsOnly);
    final last = store.sections.last;
    expect(last.kind, AlbumSectionKind.photosOnly);
    store.deletePhotos(last.photos.map((p) => p.id));
    expect(store.sectionOf(last.id), isNull);
    expect(store.sections.length, labAlbumV5.sections.length - 1);
  });

  test(
    'addCapture (탭 카메라) → 첫 촬영이 맨 앞에 오늘 섹션을 만든다 (사진만 섹션 틀 · 제목 = 날짜 · 히어로 = 최근 촬영) · id capture-n',
    () {
      final template = labAlbumV5.sections.firstWhere(
        (s) => s.kind == AlbumSectionKind.photosOnly,
      );
      final photo = CapturedPhoto.placeholder(LabImages.cameraViewfinderV5);
      final a = store.addCapture(photo, now: DateTime(2026, 9, 29));
      final b = store.addCapture(photo, now: DateTime(2026, 9, 30));
      expect(a.id, 'capture-1');
      expect(b.id, 'capture-2');
      final today = store.sections.first;
      expect(today.id, todaySectionId);
      expect(today.isToday, isTrue);
      expect(today.content.title, '2026년 9월 29일');
      expect(today.content.tint, template.tint);
      expect(today.content.heroGradient, template.heroGradient);
      expect(today.content.subtitle, template.subtitle);
      expect(today.content.stats.photos, '2');
      expect(today.content.stats.calls, template.stats.calls);
      expect(today.kind, AlbumSectionKind.photosOnly);
      expect(today.photos, [b, a]);
      expect(today.heroImage, b.provider);
      expect(store.sections.length, labAlbumV5.sections.length + 1);
      expect(store.latestCapture, b);
      expect(b.provider, photo.image);
      expect(notified, 2);
      store.toggleLike(b.id);
      expect(store.latestCapture!.liked, isTrue);
      store.deletePhotos([a.id, b.id]);
      expect(store.latestCapture, isNull);
      expect(store.sectionOf(todaySectionId), isNull);
      expect(formatAlbumDate(DateTime(2026, 8, 20)), '2026년 8월 20일');
    },
  );

  test('isEmptyFor: 상대 없음 · 빈 모드 · 섹션 없음 (RN albumView().empty)', () {
    expect(store.isEmptyFor(hasPartner: true), isFalse);
    expect(store.isEmptyFor(hasPartner: false), isTrue);
    store.setEmptyMode(true);
    expect(store.isEmptyFor(hasPartner: true), isTrue);
  });

  test('히어로는 사진을 다 지워도 남는다 (통화만 섹션 — E12 ②)', () {
    final first = store.sections.first;
    store.deletePhotos(first.photos.map((p) => p.id));
    final after = store.sectionOf(first.id)!;
    expect(after.kind, AlbumSectionKind.callsOnly);
    expect(after.heroImage, AssetImage(first.content.cover!));
  });

  test(
    'v6 소프트 삭제: 타임라인에서 빠지고 삭제 보기에 남는다 (같은 섹션 · 통화 없음 · content 순서) · 되살림 = 원래 자리',
    () {
      final first = store.sections.first;
      final ids = [first.photos[3].id, first.photos[1].id];
      expect(store.deletePhotos(ids), 2);
      expect(store.deletePhotos(ids), 0);
      expect(store.sectionOf(first.id)!.photos.length, first.photos.length - 2);
      expect(store.photoById(ids.first), isNull);
      expect(store.anyPhotoById(ids.first)!.deleted, isTrue);
      final deleted = store.deletedSections;
      expect([for (final s in deleted) s.id], [first.id]);
      expect(
        [for (final p in deleted.single.photos) p.id],
        [first.photos[1].id, first.photos[3].id],
      );
      expect(deleted.single.calls, isEmpty);
      expect(deleted.single.includeCalls, isFalse);
      expect(deleted.single.kind, AlbumSectionKind.photosOnly);
      expect(deleted.single.heroImage, first.heroImage);
      expect(store.restorePhotos([ids.first]), 1);

      expect(store.sectionOf(first.id)!.photos[2].id, ids.first);
      expect(
        [for (final p in store.deletedSections.single.photos) p.id],
        [first.photos[1].id],
      );
      store.restorePhotos([first.photos[1].id]);
      expect(store.deletedSections, isEmpty);
      expect(store.sectionOf(first.id)!.photos, first.photos);
    },
  );

  test('v6 좋아요 보기: 좋아요한 (지우지 않은) 사진이 있는 섹션만 · setLikes 여러 장 · 지운 사진은 빠진다', () {
    final first = store.sections.first;
    expect([for (final s in store.likedSections) s.id], [first.id]);
    expect(store.likedSections.single.photos.single.id, first.photos.first.id);
    final more = [for (final p in first.photos.skip(1).take(4)) p.id];
    store.setLikes(more, true);
    expect(store.likedSections.single.photos.length, 5);
    store.deletePhotos([more.first]);
    expect(store.likedSections.single.photos.length, 4);
    store.setLikes([first.photos.first.id, ...more], false);
    expect(store.likedSections, isEmpty);
  });

  test(
    'v6 addPhotos (사진 불러오기): 오늘 섹션 맨 앞에 고른 순서대로 (photos[0] 이 맨 앞 · 히어로) · 빈 목록 = 아무 일 없음',
    () {
      expect(store.addPhotos(const []), isEmpty);
      expect(notified, 0);
      final a = CapturedPhoto.placeholder(LabImages.cameraViewfinderV5);
      final b = CapturedPhoto.placeholder(LabImages.cameraPlaceholder);
      final added = store.addPhotos([a, b], now: DateTime(2026, 9, 29));
      expect(notified, 1);
      expect([for (final p in added) p.capture], [a, b]);
      final today = store.sections.first;
      expect(today.id, todaySectionId);
      expect(
        [for (final p in today.photos) p.id],
        [for (final p in added) p.id],
      );
      expect(today.heroImage, a.image);
      expect(today.content.stats.photos, '2');
      expect(store.latestCapture, added.first);

      store.deletePhotos([added.first.id]);
      expect(store.sections.first.heroImage, a.image);
      expect(store.sections.first.content.stats.photos, '1');
    },
  );

  test('v6 빈 모드는 content 섹션만 숨긴다 — 촬영 · 불러오기로 만든 오늘 섹션은 보인다', () {
    store.setEmptyMode(true);
    expect(store.isEmpty, isTrue);
    store.addPhotos([CapturedPhoto.placeholder(LabImages.cameraPlaceholder)]);
    expect([for (final s in store.sections) s.id], [todaySectionId]);
    expect(store.isEmptyFor(hasPartner: true), isFalse);
    expect(store.isEmptyFor(hasPartner: false), isTrue);
  });

  test('빈 모드 (album=empty) — 섹션 없음 · isEmpty · reset 으로 content 전체', () {
    store.deletePhotos([store.sections.first.photos.first.id]);
    store.setEmptyMode(true);
    expect(store.sections, isEmpty);
    expect(store.isEmpty, isTrue);
    expect(store.photoAt(labAlbumV5.sections.first.id, 0), isNull);
    store.setEmptyMode(true);
    final before = notified;
    store.reset();
    expect(notified, before + 1);
    expect(store.emptyMode, isFalse);
    expect(
      store.sections.first.photos.length,
      labAlbumV5.sections.first.grid!.photos.length,
    );
    expect(store.latestCapture, isNull);
    store.reset(empty: true);
    expect(store.isEmpty, isTrue);
    expect(AlbumStore(empty: true).isEmpty, isTrue);
  });

  testWidgets('AlbumScope.of 는 구독한다 (변화 → 다시 그림) · read 는 구독하지 않는다', (
    tester,
  ) async {
    var builds = 0;
    await tester.pumpWidget(
      AlbumScope(
        store: store,
        child: Builder(
          builder: (context) {
            builds++;
            AlbumScope.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(builds, 1);
    store.toggleLike(store.sections.first.photos[2].id);
    await tester.pump();
    expect(builds, 2);
    expect(AlbumScope.maybeRead(tester.element(find.byType(SizedBox))), store);
  });
}
