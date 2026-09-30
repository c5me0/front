// Regression coverage for zoom route. Preserve behavior, layout, and interaction
// expectations.

//  s = lerp(s0, 1) · offset = lerp((x0, y0), 0) · hv = lerp(hv0, H) · r = lerp(R0, 0) (s0 = w0/W, hv0 = h0/s0, R0 = flightRadius).

import 'dart:ui' show lerpDouble;

import 'package:cameo/design_system/design_system.dart';
import 'package:cameo/navigation/navigation.dart';
import 'package:cameo/screens/album/album_screen.dart';
import 'package:cameo/screens/album_gangneung/album_gangneung_screen.dart';
import 'package:cameo/screens/home/home_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_harness.dart';

const Rect _card = Rect.fromLTWH(16, 134, 361, 361);
const Size _screen = kIPhone16;

void _expectRect(Rect actual, Rect expected, {double tol = 1e-6}) {
  expect(actual.left, closeTo(expected.left, tol));
  expect(actual.top, closeTo(expected.top, tol));
  expect(actual.width, closeTo(expected.width, tol));
  expect(actual.height, closeTo(expected.height, tol));
}

void main() {
  setUp(() {
    FlowDemo.resetForTesting();
    ZoomSource.clear();
  });
  tearDown(FlowDemo.resetForTesting);

  group('zoomGeometry (순수 — RN 과 같은 값)', () {
    const s0 = 361 / 393;
    const hv0 = 361 / s0;

    test('p = 0: 화면상 rect = 카드 rect · 보이는 콘텐츠 = 위 393 (히어로) · 반경 26', () {
      final g = zoomGeometry(progress: 0, source: _card, screen: _screen);
      expect(g.scale, closeTo(s0, 1e-12));
      expect(g.offset, const Offset(16, 134));
      expect(g.visibleHeight, closeTo(hv0, 1e-9));
      expect(hv0, closeTo(CameoLayout.albumCardHeroWidth, 1e-9));
      expect(g.radius, CameoMotion.transitionZoomFlightRadius);
      expect(g.contentRadius, closeTo(26 / s0, 1e-9));
      _expectRect(g.clip, const Rect.fromLTWH(0, 0, 393, 393), tol: 1e-9);
      _expectRect(g.screenRect, _card);
    });

    test('p = 0.5: 절반씩 (배율 · 이동 · 높이 · 반경)', () {
      final g = zoomGeometry(progress: 0.5, source: _card, screen: _screen);
      expect(g.scale, closeTo((s0 + 1) / 2, 1e-12));
      expect(g.offset.dx, closeTo(8, 1e-12));
      expect(g.offset.dy, closeTo(67, 1e-12));
      expect(g.visibleHeight, closeTo((hv0 + 852) / 2, 1e-9));
      expect(g.radius, closeTo(13, 1e-12));
      expect(g.contentRadius, closeTo(13 / ((s0 + 1) / 2), 1e-9));
      _expectRect(
        g.screenRect,
        Rect.fromLTWH(
          8,
          67,
          393 * (s0 + 1) / 2,
          (hv0 + 852) / 2 * (s0 + 1) / 2,
        ),
      );
    });

    test('p = 1: 전체 화면 · 반경 0 · 변환 = 항등', () {
      final g = zoomGeometry(progress: 1, source: _card, screen: _screen);
      expect(g.scale, 1);
      expect(g.offset, Offset.zero);
      expect(g.visibleHeight, 852);
      expect(g.radius, 0);
      _expectRect(g.screenRect, Offset.zero & _screen);
      expect(g.transform, Matrix4.identity());

      expect(
        zoomGeometry(progress: 1.01, source: _card, screen: _screen).radius,
        0,
      );
    });
  });

  group('앱 — v4 홈 카드 → 줌 (Lab `/home-v4` — v5 에서 줌 라우트는 Lab 전용)', () {
    testWidgets(
      '카드 1 → 16-3 (탭 0 스택 줌): 그린 변환 · 클립 = 식, 홈은 그대로 + dim × p, 끝나면 전체 화면',
      (tester) async {
        await pumpCameoApp(tester, '/home-v4?session=member');
        final homeTop = tester.getTopLeft(find.byType(HomeScreen));
        expect(FlowDemo.run(FlowDemoAction.homeOpenAlbum), isTrue);
        final source = ZoomSource.rectOf(ZoomTarget.gangneung)!;
        _expectRect(source, _card);
        await tester.pump();
        final route =
            CameoRouteActivity.leaf!.key as CameoZoomPageRoute<Object?>;
        expect(route.settings.name, CameoRoutes.albumsGangneung);

        expect(route.navigator, rootNavigator(tester));
        expect(route.animation!.value, 0);

        Transform transform() => tester.widget<Transform>(
          find.byKey(const ValueKey('zoomRoute.transform')),
        );
        expect(
          transform().transform,
          zoomGeometry(progress: 0, source: _card, screen: _screen).transform,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 90));
        final p = route.animation!.value;
        expect(p, inExclusiveRange(0, 1));
        final g = zoomGeometry(progress: p, source: _card, screen: _screen);
        expect(transform().transform, g.transform);
        final clip = tester.widget<ClipRRect>(
          find.byKey(const ValueKey('zoomRoute.clip')),
        );
        final rrect = clip.clipper!.getClip(_screen);
        _expectRect(rrect.outerRect, g.clip);
        expect(rrect.tlRadiusX, closeTo(g.contentRadius, 1e-9));

        expect(tester.getSize(find.byType(AlbumGangneungScreen)), _screen);

        expect(tester.getTopLeft(find.byType(HomeScreen)), homeTop);
        final dim = tester.widget<ColoredBox>(
          find.descendant(
            of: find.byKey(const ValueKey('zoomRoute.dim')),
            matching: find.byType(ColoredBox),
          ),
        );
        expect(dim.color.a, closeTo(CameoMotion.transitionZoomDim.a * p, 1e-6));
        await tester.pumpAndSettle();
        expect(route.animation!.value, 1);
        expect(transform().transform, Matrix4.identity());
        expect(find.byKey(const ValueKey('zoomRoute.dim')), findsNothing);
        expect(
          tester.getRect(find.byType(AlbumGangneungScreen)),
          Offset.zero & _screen,
        );
        expect(FlowDemo.stackSnapshot().top, FlowDemoScreen.gangneung);

        final gangneung = tester.element(find.byType(AlbumGangneungScreen));
        expect(CameoNav.pop(gangneung), isTrue);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));
        final q = route.animation!.value;
        expect(q, inExclusiveRange(0, 1));
        expect(
          transform().transform,
          zoomGeometry(progress: q, source: _card, screen: _screen).transform,
        );
        await tester.pumpAndSettle();
        expect(find.byType(AlbumGangneungScreen), findsNothing);
        expect(CameoRouteActivity.leaf!.name, CameoRoutes.homeV4);
        await disposeApp(tester);
      },
    );

    testWidgets('카드 2 → 16-6 (루트 스택 줌) · 아래 탭 컨테이너는 그대로', (tester) async {
      await pumpCameoApp(tester, '/home-v4?session=member');
      expect(FlowDemo.run(FlowDemoAction.homeOpenDayAlbum), isTrue);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final route = CameoRouteActivity.rootTop!;
      expect(route, isA<CameoZoomPageRoute<Object?>>());
      expect(route.navigator, rootNavigator(tester));
      final source = ZoomSource.rectOf(ZoomTarget.album)!;
      expect(source.top, closeTo(134 + 361 + 16, 1e-6));

      final shell = tester.widget<Transform>(
        find.byKey(const ValueKey('enterApp.scale'), skipOffstage: false),
      );
      expect(shell.transform.entry(0, 0), 1);
      await tester.pumpAndSettle();
      expect(find.byType(AlbumScreen), findsOneWidget);
      expect(FlowDemo.stackSnapshot().top, FlowDemoScreen.album);
      await disposeApp(tester);
    });

    testWidgets('엣지 스와이프: 조금 끌면 복귀 · 폭 절반 넘게 끌면 카드로 줌 아웃 (손가락 = 1 − p)', (
      tester,
    ) async {
      await pumpCameoApp(tester, '/home-v4?session=member');
      FlowDemo.run(FlowDemoAction.homeOpenAlbum);
      await tester.pumpAndSettle();
      final route = CameoRouteActivity.leaf!.key as CameoZoomPageRoute<Object?>;

      final gesture = await tester.startGesture(const Offset(4, 400));
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(8, 0));
        await tester.pump(const Duration(milliseconds: 50));
      }
      final p = route.animation!.value;
      expect(p, lessThan(1));

      expect(1 - p, inInclusiveRange(40 / 393, 80 / 393));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(route.animation!.value, 1);
      expect(find.byType(AlbumGangneungScreen), findsOneWidget);

      await tester.timedDragFrom(
        const Offset(4, 400),
        Offset(_screen.width * lerpDouble(0.5, 0.9, 0.5)!, 0),
        const Duration(seconds: 1),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AlbumGangneungScreen), findsNothing);
      expect(CameoRouteActivity.leaf!.name, CameoRoutes.homeV4);
      await disposeApp(tester);
    });
  });
}
