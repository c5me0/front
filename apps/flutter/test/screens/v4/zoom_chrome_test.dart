// Regression coverage for zoom chrome. Preserve behavior, layout, and interaction
// expectations.

import 'package:cameo/components/nav_bar.dart';
import 'package:cameo/design_system/design_system.dart';
import 'package:cameo/navigation/navigation.dart';
import 'package:cameo/screens/album/album_screen.dart';
import 'package:cameo/screens/album_gangneung/album_gangneung_screen.dart';
import 'package:cameo/screens/home/home_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'v4_harness.dart';

ZoomChromeState _chrome(WidgetTester tester, Type screen) =>
    tester.state<ZoomChromeState>(
      find.descendant(
        of: find.byType(screen),
        matching: find.byType(ZoomChrome),
      ),
    );

List<double> _chromeScales(WidgetTester tester, Type screen) {
  final chrome = find.descendant(
    of: find.byType(screen),
    matching: find.byType(ZoomChromeScale),
  );
  return [
    for (var i = 0; i < chrome.evaluate().length; i++)
      tester
          .widget<ScaleTransition>(
            find
                .descendant(
                  of: chrome.at(i),
                  matching: find.byType(ScaleTransition),
                )
                .first,
          )
          .scale
          .value,
  ];
}

void main() {
  setUp(() {
    FlowDemo.resetForTesting();
    ZoomSource.clear();
  });
  tearDown(FlowDemo.resetForTesting);

  testWidgets(
    '홈 카드 1 → 16-3 줌: 크롬 0.01 로 시작 · 줌 동안 그대로 · 끝나면 bouncy 로 1 (넘쳤다 돌아옴) · 불투명도 없음',
    (tester) async {
      await pumpCameoApp(tester, '/home-v4?session=member');
      expect(FlowDemo.run(FlowDemoAction.homeOpenAlbum), isTrue);
      await tester.pump();
      final route = CameoRouteActivity.leaf!.key as CameoZoomPageRoute<Object?>;
      final chrome = _chrome(tester, AlbumGangneungScreen);
      expect(chrome.phase, ZoomChromePhase.entering);
      expect(chrome.scale, CameoMotion.transitionZoomChromeScaleFrom);

      expect(_chromeScales(tester, AlbumGangneungScreen), [
        CameoMotion.transitionZoomChromeScaleFrom,
        CameoMotion.transitionZoomChromeScaleFrom,
      ]);
      expect(
        tester
            .widget<ScaleTransition>(
              find
                  .descendant(
                    of: find.byType(ZoomChromeScale),
                    matching: find.byType(ScaleTransition),
                  )
                  .first,
            )
            .alignment,
        Alignment.center,
      );

      var maxScale = 0.0;
      while (!route.animation!.isCompleted) {
        expectGlassNeverFaded(tester);
        expect(chrome.scale, CameoMotion.transitionZoomChromeScaleFrom);
        await tester.pump(kFrame);
      }

      expect(chrome.phase, ZoomChromePhase.shown);
      for (var i = 0; i < 90; i++) {
        await tester.pump(kFrame);
        maxScale = chrome.scale > maxScale ? chrome.scale : maxScale;
        expectGlassNeverFaded(tester);
      }
      expect(maxScale, greaterThan(1.0), reason: 'bouncy 오버슈트');
      expect(chrome.scale, 1);

      final back = tester.getRect(
        find
            .descendant(
              of: find.byType(AlbumGangneungScreen),
              matching: find.byType(GlassIconButton),
            )
            .first,
      );
      expectRect(back, const Rect.fromLTWH(16, 62, 46, 46));
      await disposeApp(tester);
    },
  );

  testWidgets('뒤로(pop · 흐름 데모 back) 시작 = press 로 0.01 → 카드로 줌 아웃', (
    tester,
  ) async {
    await pumpCameoApp(tester, '/home-v4?session=member');
    FlowDemo.run(FlowDemoAction.homeOpenAlbum);
    await settleApp(tester);
    final chrome = _chrome(tester, AlbumGangneungScreen);
    expect(chrome.scale, 1);
    expect(FlowDemo.run(FlowDemoAction.back), isTrue);
    await tester.pump();
    expect(chrome.phase, ZoomChromePhase.hidden);
    await tester.pump(const Duration(milliseconds: 150));
    expect(chrome.scale, lessThan(0.5));
    await settleApp(tester);
    expect(find.byType(AlbumGangneungScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
    await disposeApp(tester);
  });

  testWidgets('엣지 스와이프: 시작 = 0.01 · 취소(놓음) 순간 다시 1 · 끝까지 닫으면 0.01 그대로', (
    tester,
  ) async {
    await pumpCameoApp(tester, '/home-v4?session=member');
    FlowDemo.run(FlowDemoAction.homeOpenAlbum);
    await settleApp(tester);
    final route = CameoRouteActivity.leaf!.key as CameoZoomPageRoute<Object?>;
    final chrome = _chrome(tester, AlbumGangneungScreen);

    var g = await tester.startGesture(const Offset(5, 450));
    for (var i = 0; i < 6; i++) {
      await g.moveBy(const Offset(15, 0));
      await tester.pump(kFrame);
    }
    expect(chrome.phase, ZoomChromePhase.hidden);
    expect(route.animation!.value, lessThan(1));
    await tester.pump(const Duration(milliseconds: 300));
    await g.moveBy(const Offset(-40, 0));
    await tester.pump(const Duration(milliseconds: 300));
    await g.up();

    expect(chrome.phase, ZoomChromePhase.shown);
    expect(route.animation!.isCompleted, isFalse);
    await settleApp(tester);
    expect(chrome.scale, 1);
    expect(find.byType(AlbumGangneungScreen), findsOneWidget);

    g = await tester.startGesture(const Offset(5, 450));
    for (var i = 0; i < 20; i++) {
      await g.moveBy(const Offset(15, 0));
      await tester.pump(kFrame);
    }
    await tester.pump(const Duration(milliseconds: 300));
    await g.up();
    await tester.pump();
    expect(chrome.phase, ZoomChromePhase.hidden);
    await settleApp(tester);
    expect(find.byType(AlbumGangneungScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
    await disposeApp(tester);
  });

  testWidgets(
    '홈 카드 2 → 16-6 (루트 줌) 도 같은 규칙 · 16-3 히어로 → 16-6 (푸시) · 딥링크 /album 은 처음부터 1',
    (tester) async {
      await pumpCameoApp(tester, '/home-v4?session=member');
      expect(FlowDemo.run(FlowDemoAction.homeOpenDayAlbum), isTrue);
      await tester.pump();
      expect(_chrome(tester, AlbumScreen).phase, ZoomChromePhase.entering);
      expect(
        _chrome(tester, AlbumScreen).scale,
        CameoMotion.transitionZoomChromeScaleFrom,
      );
      await settleApp(tester);
      expect(_chrome(tester, AlbumScreen).scale, 1);
      CameoNav.pop(tester.element(find.byType(AlbumScreen)));
      await settleApp(tester);

      FlowDemo.run(FlowDemoAction.homeOpenAlbum);
      await settleApp(tester);
      expect(FlowDemo.run(FlowDemoAction.gangneungOpenAlbum), isTrue);
      await tester.pump();
      expect(_chrome(tester, AlbumScreen).phase, ZoomChromePhase.static);
      expect(_chrome(tester, AlbumScreen).scale, 1);
      expect(_chromeScales(tester, AlbumScreen), [1, 1]);
      await disposeApp(tester);
      await pumpCameoApp(tester, '/album');
      expect(_chrome(tester, AlbumScreen).phase, ZoomChromePhase.static);
      expect(_chromeScales(tester, AlbumScreen), [1, 1]);
      await disposeApp(tester);
    },
  );

  testWidgets('모션 감소: 같은 상태 기계 · 값은 즉시 (0.01 → 진입 끝에 바로 1 → 뒤로 시작에 바로 0.01)', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpCameoApp(tester, '/home-v4?session=member');
    FlowDemo.run(FlowDemoAction.homeOpenAlbum);
    await tester.pump();
    final route = CameoRouteActivity.leaf!.key as CameoZoomPageRoute<Object?>;
    final chrome = _chrome(tester, AlbumGangneungScreen);
    expect(chrome.scale, CameoMotion.transitionZoomChromeScaleFrom);
    while (!route.animation!.isCompleted) {
      await tester.pump(kFrame);
    }
    expect(chrome.scale, 1);
    CameoNav.pop(tester.element(find.byType(NavBar)));
    await tester.pump();
    expect(chrome.scale, CameoMotion.transitionZoomChromeScaleFrom);
    await settleApp(tester);
    await disposeApp(tester);
  });
}
