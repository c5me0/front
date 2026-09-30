// Regression coverage for viewer v6. Preserve behavior, layout, and interaction
// expectations.

import 'package:cameo/components/confirm_sheet.dart';
import 'package:cameo/components/scrim_pill.dart';
import 'package:cameo/components/thumb_strip.dart';
import 'package:cameo/navigation/navigation.dart';
import 'package:cameo/screens/home_timeline/album_timeline_model.dart';
import 'package:cameo/screens/home_timeline/home_timeline_screen.dart';
import 'package:cameo/screens/instant_viewer/instant_subject.dart';
import 'package:cameo/screens/instant_viewer/instant_viewer_screen.dart';
import 'package:cameo/screens/photo_viewer/photo_viewer_screen.dart';
import 'package:cameo/screens/photo_viewer/viewer_presence.dart';
import 'package:cameo/state/captured_photo.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../navigation/app_harness.dart';
import 'album_v6_harness.dart';

PhotoViewerScreenState _viewer(WidgetTester tester) =>
    tester.state<PhotoViewerScreenState>(find.byType(PhotoViewerScreen));

Finder _pillItem(int i) => find.descendant(
  of: find.byKey(PhotoViewerScreen.pillKey),
  matching: find.byKey(ScrimPill.itemKey(i)),
);

Future<String> _openFromCell(WidgetTester tester, int index) async {
  await pumpCameoAppV6(tester, '/?session=member');
  final id = lastAlbum.sections.first.photos[index].id;
  await tester.tap(find.byKey(HomeTimelineScreen.cellKey(id)));
  await tester.pump(const Duration(milliseconds: 400));
  await settleApp(tester);
  expect(find.byType(PhotoViewerScreen), findsOneWidget);
  return id;
}

void main() {
  setUp(() {
    resetAlbumTestState();
    ViewerPresence.resetForTesting();
    resetInstantSubject();
    HomeTimelineScreenState.resetLaunchParamsForTesting();
  });
  tearDown(FlowDemo.resetForTesting);

  testWidgets(
    '기하 @402: 카드 394 × 525.33 @ (4, 122) · 닫기 (16, 62) 46 · pill (240, 62) 146 · 스트립 663.33 (현재 칸 가운데 172) · 날짜 pill 가운데 790 · 탭바 mini',
    (tester) async {
      final id = await _openFromCell(tester, 3);
      final viewer = _viewer(tester);
      expect(viewer.photoId, id);
      expect(viewer.albumMode, isTrue);
      expectRect(
        tester.getRect(
          find.descendant(
            of: find.byKey(PhotoViewerScreen.cardKey),
            matching: find.byKey(ViewerZoomCard.clipKey),
          ),
        ),
        viewerCardRectV6(402),
      );
      expectRect(
        tester.getRect(find.byKey(PhotoViewerScreen.closeKey)),
        const Rect.fromLTWH(16, 62, 46, 46),
      );
      expectRect(
        tester.getRect(find.byKey(PhotoViewerScreen.pillKey)),
        const Rect.fromLTWH(240, 62, 146, 46),
      );
      expectRect(
        tester.getRect(find.byKey(ThumbStrip.rowKey)),
        Rect.fromLTWH(0, viewerStripTop(402), 402, 58),
      );
      expectRect(
        tester.getRect(find.byKey(ThumbStrip.cellKey(3))),
        Rect.fromLTWH(172, viewerStripTop(402), 58, 58),
        reason: '현재 사진 썸네일이 가운데',
      );
      final date = tester.getRect(find.byKey(PhotoViewerScreen.datePillKey));
      expect(date.top, 790);
      expect(date.height, 38);

      final pill = tester.getRect(
        find
            .ancestor(
              of: find.byKey(PhotoViewerScreen.dateKey),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect(
        pill.width,
        closeTo(
          tester.getSize(find.byKey(PhotoViewerScreen.dateKey)).width + 28,
          1e-3,
        ),
      );
      expect(pill.center.dx, closeTo(201, 1e-3));
      expect(pill.height, 38);
      expect(
        tester.getCenter(find.byKey(PhotoViewerScreen.dateKey)).dx,
        closeTo(201, 1e-3),
      );
      expect(find.text('오늘, 12시 00분'), findsOneWidget);
      expect(appTabs(tester)!.tabBarModeShown, TabBarV6Mode.mini);
      await disposeApp(tester);
    },
  );

  testWidgets(
    '썸네일 탭 = 그 사진으로 (두 칸 이상 → 옆에서 한 장 넘김) · 스트립이 가운데로 (centerSpring) · 흐름 데모 viewer.strip → 다음 칸 · settle',
    (tester) async {
      await _openFromCell(tester, 1);
      final viewer = _viewer(tester);
      final photos = lastAlbum.sections.first.photos;
      await tester.tap(find.byKey(ThumbStrip.cellKey(3)));
      await tester.pump(kFrame);
      expect(viewer.photoId, photos[3].id);
      expect(viewer.pagePosition, lessThan(3.0), reason: '출발 = 2 (목표 옆)');
      expect(viewer.pagePosition, greaterThanOrEqualTo(2.0));
      await settleApp(tester);
      expect(viewer.pagePosition, closeTo(3, 1e-3));
      expect(viewer.stripPosition, closeTo(3, 1e-3));
      expect(
        tester.getTopLeft(find.byKey(ThumbStrip.cellKey(3))).dx,
        closeTo(172, 1e-3),
      );
      final before = FlowDemo.settleCount(FlowDemoAction.viewerStrip);
      expect(FlowDemo.run(FlowDemoAction.viewerStrip), isTrue);
      await settleApp(tester);
      await tester.pump(const Duration(seconds: 1));
      expect(viewer.photoId, photos[4].id);
      expect(FlowDemo.settleCount(FlowDemoAction.viewerStrip), before + 1);
      await disposeApp(tester);
    },
  );

  testWidgets(
    'heart = 앨범 좋아요 (filled) · trash → 확인 → 소프트 삭제 + 닫힘 (삭제 보기에 남는다)',
    (tester) async {
      final id = await _openFromCell(tester, 2);
      await tester.tap(_pillItem(1));
      await settleApp(tester);
      expect(lastAlbum.anyPhotoById(id)!.liked, isTrue);
      await tester.tap(_pillItem(2));
      await settleApp(tester);
      expect(find.text('지운 사진은 최근 삭제에서\n다시 되돌릴 수 있어요'), findsOneWidget);
      await tester.tap(find.byKey(ConfirmSheet.confirmKey));
      await settleApp(tester);
      expect(find.byType(PhotoViewerScreen), findsNothing);
      expect(lastAlbum.photoById(id), isNull);
      expect(lastAlbum.deletedSections.single.photos.single.id, id);
      await disposeApp(tester);
    },
  );

  testWidgets('아래로 끌어 닫기 (0.2 넘김) → 칸으로 줌 아웃 · 탭바 풀로', (tester) async {
    await _openFromCell(tester, 2);
    final center = tester.getCenter(find.byKey(PhotoViewerScreen.cardKey));
    final gesture = await tester.startGesture(center);
    for (var i = 0; i < 12; i++) {
      await gesture.moveBy(const Offset(0, 16));
      await tester.pump(kFrame);
    }
    expect(_viewer(tester).dragLook.chrome, greaterThan(0));
    await gesture.up();
    await settleApp(tester);
    expect(find.byType(PhotoViewerScreen), findsNothing);
    expect(appTabs(tester)!.tabBarModeShown, TabBarV6Mode.full);
    await disposeApp(tester);
  });

  testWidgets(
    '/instant 파트너 사진 = 한 장 보기: 스트립 한 칸 · pill [share-2 · heart] 96 @ 290 · heart = 이 보기만 · trash 없음',
    (tester) async {
      await pumpCameoAppV6(tester, '/instant?session=member');
      expect(find.byType(InstantViewerScreen), findsOneWidget);
      final viewer = _viewer(tester);
      expect(viewer.albumMode, isFalse);
      expectRect(
        tester.getRect(find.byKey(InstantViewerScreen.pillKey)),
        const Rect.fromLTWH(290, 62, 96, 46),
      );
      expect(find.byKey(ThumbStrip.cellKey(0)), findsOneWidget);
      expect(find.byKey(ThumbStrip.cellKey(1)), findsNothing);
      await tester.tap(_pillItem(1));
      await settleApp(tester);
      expect(viewer.partnerLiked, isTrue);
      expect(
        tester
            .state<InstantViewerScreenState>(find.byType(InstantViewerScreen))
            .subject,
        partnerInstant,
      );
      await disposeApp(tester);
    },
  );

  testWidgets('/instant 내 촬영 (앨범 사진) = 그 섹션 보기 · heart = 앨범 좋아요 · trash 있음', (
    tester,
  ) async {
    await pumpCameoAppV6(tester, '/?session=member');
    final photo = lastAlbum.addCapture(
      CapturedPhoto.placeholder(),
      now: DateTime(2026, 9, 29),
    );
    setInstantSubject(
      InstantSubject(
        image: photo.provider,
        share: photo.image,
        albumPhotoId: photo.id,
      ),
    );
    await settleApp(tester);
    CameoNav.openInstant(
      tester.element(find.byType(HomeTimelineScreen)),
      rect: const Rect.fromLTWH(16, 785, 54, 54),
      sourceRadius: 16,
    );
    await settleApp(tester);
    final viewer = _viewer(tester);
    expect(viewer.albumMode, isTrue);
    expect(viewer.photoId, photo.id);
    expect(
      find.descendant(
        of: find.byKey(PhotoViewerScreen.pillKey),
        matching: find.byKey(ScrimPill.itemKey(2)),
      ),
      findsOneWidget,
    );
    await tester.tap(_pillItem(1));
    await settleApp(tester);
    expect(lastAlbum.photoById(photo.id)!.liked, isTrue);
    await disposeApp(tester);
  });
}
