// Regression coverage for viewer route. Preserve behavior, layout, and interaction
// expectations.

import 'package:cameo/design_system/design_system.dart';
import 'package:cameo/navigation/navigation.dart';
import 'package:cameo/screens/camera_v6/camera_v6_screen.dart';
import 'package:cameo/components/scrim_pill.dart';
import 'package:cameo/screens/home_timeline/album_timeline_model.dart';
import 'package:cameo/screens/home_timeline/home_timeline_screen.dart';
import 'package:cameo/screens/instant_viewer/instant_viewer_screen.dart';
import 'package:cameo/screens/photo_viewer/photo_viewer_screen.dart';
import 'package:cameo/components/confirm_sheet.dart';
import 'package:flutter/gestures.dart' show kDoubleTapTimeout;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

import 'app_harness.dart';

final Rect _card = viewerCardRectV6(kIPhone16.width);

void _expectRect(Rect a, Rect b, {double eps = 1e-6}) {
  expect(a.left, closeTo(b.left, eps), reason: 'left $a vs $b');
  expect(a.top, closeTo(b.top, eps), reason: 'top $a vs $b');
  expect(a.width, closeTo(b.width, eps), reason: 'width $a vs $b');
  expect(a.height, closeTo(b.height, eps), reason: 'height $a vs $b');
}

CameoViewerRoute<Object?> _viewer() =>
    CameoRouteActivity.rootTop! as CameoViewerRoute<Object?>;

Matrix4? _cardTransform(WidgetTester tester, Finder screen) {
  final f = find.descendant(
    of: screen,
    matching: find.byKey(ViewerZoomCard.transformKey),
  );
  if (f.evaluate().isEmpty) return null;
  return tester.widget<Transform>(f).transform;
}

Finder _slide(Finder screen, ViewerChromeEdge edge) => find
    .descendant(
      of: screen,
      matching: find.byWidgetPredicate(
        (w) => w is ViewerChromeSlide && w.edge == edge,
      ),
    )
    .first;

double _chromeDy(WidgetTester tester, Finder screen, ViewerChromeEdge edge) {
  final t = tester.widget<Transform>(
    find
        .descendant(of: _slide(screen, edge), matching: find.byType(Transform))
        .first,
  );
  return t.transform.getTranslation().y;
}

double _chromeDistance(
  WidgetTester tester,
  Finder screen,
  ViewerChromeEdge edge,
) {
  final w = tester.widget<ViewerChromeSlide>(_slide(screen, edge));
  return w.distance ?? ViewerChromeSlide.distanceOf(edge);
}

void main() {
  setUp(() {
    FlowDemo.resetForTesting();
    ViewerSource.clear();
  });
  tearDown(FlowDemo.resetForTesting);

  group('식 (RN viewerZoomFlight 와 같다)', () {
    const cell = Rect.fromLTWH(8, 661, 73.8, 73.8);
    test(
      'p = 0 → 화면 띠 = 칸 (가운데 띠, 반경 = 칸 반경) · p = 1 → 카드 r26 · 모두 p 에 선형',
      () {
        final f0 = viewerZoomFlight(progress: 0, target: _card, source: cell);
        _expectRect(f0.screenRect(_card), cell);
        final s0 = cell.width / _card.width;
        expect(f0.s, closeTo(s0, 1e-12));
        expect(f0.hv, closeTo(cell.height / s0, 1e-9));
        expect(f0.top, closeTo((_card.height - f0.hv) / 2, 1e-9));
        expect(f0.radius, 0);
        expect(f0.d, closeTo(_card.height - f0.hv, 1e-9));
        final f1 = viewerZoomFlight(progress: 1, target: _card, source: cell);
        _expectRect(f1.screenRect(_card), _card);
        expect(f1.top, 0);
        expect(f1.radius, CameoLayout.viewerV6CardRadius);
        final a = viewerZoomFlight(progress: 0.25, target: _card, source: cell);
        expect(a.s, closeTo(s0 + (1 - s0) * 0.25, 1e-12));
        expect(a.ty, closeTo((cell.top - _card.top) * 0.75, 1e-9));

        const thumb = Rect.fromLTWH(16, 770, 54, 54);
        final t0 = viewerZoomFlight(
          progress: 0,
          target: _card,
          source: thumb,
          sourceRadius: 16,
        );
        expect(t0.radius * t0.s, closeTo(16, 1e-9));

        final tall = viewerZoomFlight(
          progress: 0,
          target: _card,
          source: const Rect.fromLTWH(0, 0, 10, 1000),
        );
        expect(tall.hv, _card.height);
        expect(tall.top, 0);
      },
    );

    test('변환 = 이동 · 배율 · 띠 위를 맨 위로 (카드 콘텐츠의 띠 → 화면 띠) · 크롬 이동 거리', () {
      final f = viewerZoomFlight(progress: 0.4, target: _card, source: cell);
      final m = f.transform;
      final topLeft = MatrixUtils.transformPoint(m, Offset(0, f.top));
      expect(topLeft.dx, closeTo(f.tx, 1e-9));
      expect(topLeft.dy, closeTo(f.ty, 1e-9));
      final bottomRight = MatrixUtils.transformPoint(
        m,
        Offset(_card.width, f.top + f.hv),
      );
      _expectRect(
        Rect.fromPoints(topLeft, bottomRight).shift(_card.topLeft),
        f.screenRect(_card),
        eps: 1e-9,
      );
      expect(
        f.clipFor(_card.width),
        Rect.fromLTWH(0, f.top, _card.width, f.hv),
      );

      expect(ViewerChromeSlide.distanceOf(ViewerChromeEdge.top), -108);
      expect(ViewerChromeSlide.distanceOf(ViewerChromeEdge.bottom), 96);
    });
  });

  group('앱 — 홈 칸 → 사진 보기', () {
    testWidgets(
      '첫 프레임 = 칸 · 전환 중 = 식 + dim × p · 크롬은 화면 밖에서 이동만 · 홈은 그대로 · 끝 = 카드 · 닫기 = 옮긴 칸으로',
      (tester) async {
        await pumpCameoApp(tester, '/?session=member');
        final first = lastAlbum.sections.first;
        final cellFinder = find.byKey(
          HomeTimelineScreen.cellKey(first.photos.first.id),
        );
        final cell = tester.getRect(cellFinder);
        await tester.tap(cellFinder);

        await tester.pump(kDoubleTapTimeout);
        final route = _viewer();
        final viewer = find.byType(PhotoViewerScreen);
        expect(
          route.settings.name,
          CameoRoutes.photo(sectionId: first.id, index: 0),
        );
        expect(route.sourceKey, first.photos.first.id);
        expect(ViewerSource.rectOf(first.photos.first.id), cell);
        expect(route.opaque, isFalse);
        expect(route.animation!.value, 0);
        expect(
          _cardTransform(tester, viewer),
          viewerZoomFlight(progress: 0, target: _card, source: cell).transform,
        );
        expect(
          _chromeDy(tester, viewer, ViewerChromeEdge.top),
          _chromeDistance(tester, viewer, ViewerChromeEdge.top),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 90));
        final p = route.animation!.value;
        expect(p, inExclusiveRange(0, 1));
        expect(
          _cardTransform(tester, viewer),
          viewerZoomFlight(progress: p, target: _card, source: cell).transform,
        );
        expect(
          _chromeDy(tester, viewer, ViewerChromeEdge.bottom),
          closeTo(
            (1 - p) * _chromeDistance(tester, viewer, ViewerChromeEdge.bottom),
            1e-9,
          ),
        );
        final dim = tester.widget<ColoredBox>(
          find.descendant(
            of: find.byKey(const ValueKey('viewerRoute.dim')),
            matching: find.byType(ColoredBox),
          ),
        );
        final role = CameoPalette.of(CameoColorMode.light).dimScrim;
        expect(dim.color.a, closeTo(role.a * p, 1e-3));
        expect(tester.getTopLeft(find.byType(HomeTimelineScreen)), Offset.zero);
        await settleApp(tester);
        expect(
          _cardTransform(tester, viewer),
          viewerZoomFlight(progress: 1, target: _card, source: cell).transform,
        );
        expect(_chromeDy(tester, viewer, ViewerChromeEdge.top), 0);
        expect(FlowDemo.stackSnapshot().top, FlowDemoScreen.photo);
        for (final e in find.byType(LiquidGlass).evaluate()) {
          e.visitAncestorElements((a) {
            if (a.widget is Opacity) expect((a.widget as Opacity).opacity, 1);
            return true;
          });
        }

        const moved = Rect.fromLTWH(160, 400, 73.8, 73.8);
        ViewerSource.set(first.photos.first.id, moved);
        await tester.tap(find.byKey(PhotoViewerScreen.closeKey));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));
        final q = route.animation!.value;
        expect(q, inExclusiveRange(0, 1));
        expect(
          _cardTransform(tester, viewer),
          viewerZoomFlight(progress: q, target: _card, source: moved).transform,
        );
        await settleApp(tester);
        expect(find.byType(PhotoViewerScreen), findsNothing);
        expect(FlowDemo.stackSnapshot().top, FlowDemoScreen.home);
        await disposeApp(tester);
      },
    );

    testWidgets(
      '하트 = 좋아요 토글 (heart-filled) · viewer.like settle · 공유 = ShareService + 공유함 · 휴지통 = 확인 시트 → 지움 + 닫힘',
      (tester) async {
        await pumpCameoApp(tester, '/?session=member');
        final photo = lastAlbum.sections.first.photos[1];
        await tester.tap(find.byKey(HomeTimelineScreen.cellKey(photo.id)));
        await tester.pump(kDoubleTapTimeout);
        await settleApp(tester);
        expect(photo.liked, isFalse);
        final before = FlowDemo.settleCount(FlowDemoAction.viewerLike);
        expect(FlowDemo.run(FlowDemoAction.viewerLike), isTrue);
        await tester.pump();
        expect(lastAlbum.photoById(photo.id)!.liked, isTrue);

        expect(FlowDemo.settleCount(FlowDemoAction.viewerLike), before);
        await tester.pump(springSettleDuration(CameoMotion.heartPopSpring));
        expect(FlowDemo.settleCount(FlowDemoAction.viewerLike), before + 1);
        await settleApp(tester);
        Finder item(int i) => find.descendant(
          of: find.byKey(PhotoViewerScreen.pillKey),
          matching: find.byKey(ScrimPill.itemKey(i)),
        );
        expect(
          find.descendant(
            of: item(1),
            matching: find.byWidgetPredicate(
              (w) => w is CameoIcon && w.name == CameoIconName.heartFilled,
            ),
          ),
          findsOneWidget,
        );
        await tester.tap(item(0));
        await tester.pump();
        expect(simulatedShare.requests.single, [photo.image]);
        expect(lastAlbum.photoById(photo.id)!.shared, isTrue);

        await tester.tap(item(2));
        await settleApp(tester);
        expect(lastAlbum.photoById(photo.id), isNotNull);
        await tester.tap(find.byKey(ConfirmSheet.confirmKey));
        await tester.pump();
        expect(lastAlbum.photoById(photo.id), isNull);
        expect(lastAlbum.anyPhotoById(photo.id)!.deleted, isTrue);
        await settleApp(tester);
        expect(find.byType(PhotoViewerScreen), findsNothing);
        await disposeApp(tester);
      },
    );

    testWidgets('아래로 끌기 = 카드가 따라온다 (dim 배율) · 조금 = 제자리로 · 0.2 넘게 = 닫힘 (칸으로)', (
      tester,
    ) async {
      await pumpCameoApp(tester, '/?session=member');
      final first = lastAlbum.sections.first;
      await tester.tap(
        find.byKey(HomeTimelineScreen.cellKey(first.photos.first.id)),
      );
      await tester.pump(kDoubleTapTimeout);
      await settleApp(tester);
      final route = _viewer();
      final g = await tester.startGesture(const Offset(196, 400));
      for (var i = 0; i < 6; i++) {
        await g.moveBy(const Offset(0, 10));
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(route.animation!.value, 1);
      expect(route.dimScale.value, inExclusiveRange(0.7, 1));
      await g.up();
      await settleApp(tester);
      expect(find.byType(PhotoViewerScreen), findsOneWidget);
      expect(route.dimScale.value, 1);
      await tester.timedDragFrom(
        const Offset(196, 400),
        const Offset(0, 300),
        const Duration(milliseconds: 300),
      );
      await tester.pump();
      expect(route.animation!.status, AnimationStatus.reverse);
      await settleApp(tester);
      expect(find.byType(PhotoViewerScreen), findsNothing);
      await disposeApp(tester);
    });

    testWidgets(
      '딥링크 /photo (원점 없음) = 줌 없이 카드가 제자리에서 페이드 · 모션 감소 = 카드만 페이드 (글래스는 페이드 없음)',
      (tester) async {
        await pumpCameoApp(tester, '/?session=member');
        rootNavigator(tester).pushNamed('/photo?section=sungsu&index=0');
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 60));
        final route = _viewer();
        expect(route.source, isNull);
        expect(route.animation!.value, inExclusiveRange(0, 1));
        final viewer = find.byType(PhotoViewerScreen);
        expect(_cardTransform(tester, viewer), isNull);
        _expectRect(
          tester.getRect(
            find.descendant(
              of: viewer,
              matching: find.byKey(ViewerZoomCard.clipKey),
            ),
          ),
          _card,
        );
        await settleApp(tester);
        await disposeApp(tester);

        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        await pumpCameoApp(tester, '/?session=member');
        await tester.tap(
          find.byKey(
            HomeTimelineScreen.cellKey(
              lastAlbum.sections.first.photos.first.id,
            ),
          ),
        );
        await tester.pump(kDoubleTapTimeout);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        final fade = tester.widget<FadeTransition>(
          find
              .ancestor(
                of: find.byKey(ViewerZoomCard.clipKey),
                matching: find.byType(FadeTransition),
              )
              .first,
        );
        expect(fade.opacity.value, inExclusiveRange(0, 1));
        for (final e in find.byType(LiquidGlass).evaluate()) {
          e.visitAncestorElements((a) {
            final w = a.widget;
            if (w is FadeTransition) {
              expect(w.opacity.value, 1, reason: '글래스 조상 페이드');
            }
            return true;
          });
        }
        await settleApp(tester);
        await disposeApp(tester);
      },
    );
  });

  testWidgets(
    '인스턴트 보기 (v6 사진 보기 — F9): 카메라 탭 썸네일 rect (r16) 에서 줌 · dim × p · 뒤로 = 카메라 탭',
    (tester) async {
      await pumpCameoApp(tester, '/capture?session=member');
      final thumb = tester.getRect(find.byKey(CameraV6Screen.thumbnailKey));
      expect(thumb.size, const Size(54, 54));
      await tester.tap(find.byKey(CameraV6Screen.thumbnailKey));
      await tester.pump();
      final route = _viewer();
      expect(route.settings.name, CameoRoutes.instant);
      expect(route.source, thumb);
      expect(route.sourceRadius, CameoLayout.tabBarV6CameraThumbnailRadius);
      final viewer = find.byType(InstantViewerScreen);
      expect(
        _cardTransform(tester, viewer),
        viewerZoomFlight(
          progress: 0,
          target: _card,
          source: thumb,
          sourceRadius: 16,
        ).transform,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      final dim = tester.widget<ColoredBox>(
        find.descendant(
          of: find.byKey(const ValueKey('viewerRoute.dim')),
          matching: find.byType(ColoredBox),
        ),
      );
      final role = CameoPalette.of(CameoColorMode.light).dimScrim;
      expect(dim.color.a, closeTo(role.a * route.animation!.value, 1e-3));
      await settleApp(tester);

      expect(FlowDemo.stackSnapshot().top, FlowDemoScreen.photo);
      expect(FlowDemo.run(FlowDemoAction.back), isTrue);
      await settleApp(tester);
      expect(FlowDemo.stackSnapshot().top, FlowDemoScreen.capture);
      await disposeApp(tester);
    },
  );
}
