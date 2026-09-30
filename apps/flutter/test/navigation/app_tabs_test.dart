// Regression coverage for app tabs. Preserve behavior, layout, and interaction
// expectations.

import 'dart:ui' show lerpDouble;

import 'package:cameo/components/confirm_sheet.dart';
import 'package:cameo/design_system/design_system.dart';
import 'package:cameo/navigation/navigation.dart';
import 'package:cameo/screens/album/album_screen.dart';
import 'package:cameo/screens/album_gangneung/album_gangneung_screen.dart';
import 'package:cameo/screens/call/call_screen.dart';
import 'package:cameo/screens/camera_v6/camera_v6_screen.dart';
import 'package:cameo/screens/home_timeline/home_timeline_screen.dart';
import 'package:cameo/screens/photo_viewer/photo_viewer_screen.dart';
import 'package:cameo/screens/settings/settings_screen.dart';
import 'package:cameo/state/session.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart' show kDoubleTapTimeout;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

import 'app_harness.dart';

Finder _tab(int index) => find.byKey(TabBarV6.tabKey(index));

Rect _barRect(WidgetTester tester) =>
    tester.getRect(find.byKey(TabBarV6.containerKey, skipOffstage: false));

TabBarV6 _bar(WidgetTester tester) =>
    tester.widget<TabBarV6>(find.byType(TabBarV6));

double _layerScale(WidgetTester tester, int tab) => tester
    .widget<Transform>(
      find.byKey(ValueKey('appTabs.scale.$tab'), skipOffstage: false),
    )
    .transform
    .entry(0, 0);

void expectGlassNeverFaded(WidgetTester tester) {
  final glass = find.byType(LiquidGlass, skipOffstage: false).evaluate();
  expect(glass, isNotEmpty);
  for (final e in glass) {
    e.visitAncestorElements((a) {
      final w = a.widget;
      if (w is Opacity) {
        expect(w.opacity, 1, reason: 'Liquid Glass 조상 Opacity');
      }
      if (w is FadeTransition) {
        expect(w.opacity.value, 1, reason: 'Liquid Glass 조상 FadeTransition');
      }
      return true;
    });
  }
}

void main() {
  setUp(() {
    FlowDemo.resetForTesting();
    ZoomSource.clear();
    ViewerSource.clear();
  });
  tearDown(FlowDemo.resetForTesting);

  testWidgets(
    '탭바 v6 는 컨테이너에 한 번 (0, 750, 393 × 102) · pill (16, 762) 299 × 56 (W 규칙) · 탭 97 × 48 · 통화 버튼 (323, 763) · 선택 0 · 앱 진입 때 올라온다',
    (tester) async {
      await pumpCameoApp(tester, '/?session=member', settle: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      expect(_barRect(tester).top, greaterThan(750));
      await settleApp(tester);
      expect(find.byType(TabBarV6), findsOneWidget);
      expect(find.byType(HomeTimelineScreen), findsOneWidget);
      expect(_barRect(tester), const Rect.fromLTWH(0, 750, 393, 102));
      expect(
        tester.getRect(find.byKey(TabBarV6.pillKey)),
        const Rect.fromLTWH(16, 762, 299, 56),
      );
      for (var i = 0; i < 3; i++) {
        expect(
          tester.getRect(_tab(i)),
          Rect.fromLTWH(20 + 97.0 * i, 766, 97, 48),
        );
      }
      expect(
        tester.getRect(find.byKey(TabBarV6.buttonKey)),
        const Rect.fromLTWH(323, 763, 54, 54),
      );
      final bar = _bar(tester);
      expect(bar.selected, 0);
      expect(bar.mode, TabBarV6Mode.full);
      expect(bar.variant, TabBarV6Variant.album);
      expect(bar.tone, TabBarV6Tone.photo);
      await disposeApp(tester);
    },
  );

  testWidgets(
    '탭 1 카메라: 카메라 v6 (탭 모드 — 슬롯 = 썸네일 · 전환) · 컨테이너 탭바 = camera 변형 (보임 · pill 78) · 잎 = /capture · 탭 history → 앨범',
    (tester) async {
      await pumpCameoApp(tester, '/?session=member');
      await tester.tap(_tab(1));
      await settleApp(tester);
      final tabs = appTabs(tester)!;
      expect(tabs.selectedTab, CameoTabs.camera);
      expect(tabs.tabBarHidden, isFalse);
      expect(tabs.tabBarVariant, TabBarV6Variant.camera);
      final camera = tester.widget<CameraV6Screen>(find.byType(CameraV6Screen));
      expect(camera.mode, CameraV6Mode.tab);
      expect(_barRect(tester).top, closeTo(750, 0.5));
      expect(tester.getRect(find.byKey(TabBarV6.pillKey)).left, 78);
      expect(find.byKey(CameraV6Screen.thumbnailKey), findsOneWidget);
      expect(FlowDemo.stackSnapshot().top, FlowDemoScreen.capture);
      expect(CameoRouteActivity.leaf!.name, CameoRoutes.capture);
      await tester.tap(_tab(CameoTabs.albums));
      await settleApp(tester);
      expect(tabs.selectedTab, CameoTabs.albums);
      expect(tabs.tabBarHidden, isFalse);
      expect(tabs.tabBarVariant, TabBarV6Variant.album);
      expect(_barRect(tester).top, closeTo(750, 0.5));

      expect(find.byType(CameraV6Screen, skipOffstage: false), findsOneWidget);
      await disposeApp(tester);
    },
  );

  testWidgets(
    '탭 전환 = snap 스프링 스케일 0.985 → 1 (불투명도 없음 — 글래스 G1) · 전환은 흐름 데모에 센다 · 끝나면 나간 탭은 Offstage',
    (tester) async {
      await pumpCameoApp(tester, '/?session=member');
      await tester.tap(_tab(2));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      final tabs = appTabs(tester)!;
      expect(tabs.selectedTab, CameoTabs.settings);
      expect(CameoRouteActivity.isIdle, isFalse);
      final scale = _layerScale(tester, CameoTabs.settings);
      expect(scale, inExclusiveRange(CameoMotion.transitionTabScaleFrom, 1));
      expect(_layerScale(tester, CameoTabs.albums), 1);

      expectGlassNeverFaded(tester);
      expect(
        scale,
        greaterThanOrEqualTo(
          lerpDouble(CameoMotion.transitionTabScaleFrom, 1, 0)!,
        ),
      );
      final ends = CameoRouteActivity.transitionEnds;
      await settleApp(tester);
      expect(CameoRouteActivity.transitionEnds, greaterThan(ends));
      expect(_layerScale(tester, CameoTabs.settings), 1);
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.byType(HomeTimelineScreen), findsNothing); // Offstage
      expect(
        find.byType(HomeTimelineScreen, skipOffstage: false),
        findsOneWidget,
      );
      expect(_bar(tester).selected, 2);
      expect(FlowDemo.stackSnapshot().top, FlowDemoScreen.settings);
      await disposeApp(tester);
    },
  );

  testWidgets('선택 모드 (v6 album) = 탭바 mini (숨지 않는다 — TabBarMode) · 해제 = full', (
    tester,
  ) async {
    await pumpCameoApp(tester, '/?session=member');
    await tester.tap(find.byKey(HomeTimelineScreen.selectKey));
    await settleApp(tester);
    expect(appTabs(tester)!.tabBarHidden, isFalse);
    expect(appTabs(tester)!.tabBarModeShown, TabBarV6Mode.mini);
    expect(_barRect(tester), const Rect.fromLTWH(0, 762, 393, 90));
    await tester.tap(find.byKey(HomeTimelineScreen.selectCloseKey));
    await settleApp(tester);
    expect(appTabs(tester)!.tabBarModeShown, TabBarV6Mode.full);
    expect(_barRect(tester).top, closeTo(750, 0.5));
    await disposeApp(tester);
  });

  testWidgets(
    '보기 라우트가 덮으면 탭바는 mini 로 모핑 (v6 F6 — 숨지 않는다) · 닫히면 full (컨테이너는 패럴랙스하지 않는다)',
    (tester) async {
      await pumpCameoApp(tester, '/?session=member');
      final first = lastAlbum.sections.first;
      await tester.tap(
        find.byKey(HomeTimelineScreen.cellKey(first.photos.first.id)),
      );
      await tester.pump(kDoubleTapTimeout);
      await settleApp(tester);
      expect(find.byType(PhotoViewerScreen), findsOneWidget);
      expect(appTabs(tester)!.tabBarModeShown, TabBarV6Mode.mini);
      expect(_bar(tester).mode, TabBarV6Mode.mini);
      expect(_barRect(tester), const Rect.fromLTWH(0, 762, 393, 90));
      expect(
        tester.getRect(find.byKey(TabBarV6.pillKey)).width,
        CameoLayout.tabBarV6MiniPillWidth,
      );

      expect(tester.getTopLeft(find.byType(HomeTimelineScreen)), Offset.zero);
      expect(FlowDemo.run(FlowDemoAction.back), isTrue);
      await settleApp(tester);
      expect(find.byType(PhotoViewerScreen), findsNothing);
      expect(_bar(tester).mode, TabBarV6Mode.full);
      expect(_barRect(tester), const Rect.fromLTWH(0, 750, 393, 102));
      await disposeApp(tester);
    },
  );

  testWidgets(
    'TabBarMode.report (선택 · 좋아요 · 삭제 보기) = mini 모핑 · full 로 되돌림 · 탭을 바꾸면 그 탭의 값',
    (tester) async {
      await pumpCameoApp(tester, '/?session=member');
      final home = tester.element(find.byType(HomeTimelineScreen));
      TabBarMode.report(home, TabBarV6Mode.mini);
      await settleApp(tester);
      expect(appTabs(tester)!.tabBarMode, TabBarV6Mode.mini);
      expect(_barRect(tester), const Rect.fromLTWH(0, 762, 393, 90));
      expect(
        tester.getRect(find.byKey(TabBarV6.pillKey)),
        Rect.fromLTWH((393 - 190) / 2, 774, 190, 44),
      );
      expect(
        tester.getRect(find.byKey(TabBarV6.buttonKey)).left,
        greaterThan(393),
      );
      expectGlassNeverFaded(tester);

      await tester.tap(_tab(2));
      await settleApp(tester);
      expect(_bar(tester).mode, TabBarV6Mode.full);
      await tester.tap(_tab(0));
      await settleApp(tester);
      expect(_bar(tester).mode, TabBarV6Mode.mini);
      TabBarMode.report(home, TabBarV6Mode.full);
      await settleApp(tester);
      expect(_barRect(tester), const Rect.fromLTWH(0, 750, 393, 102));
      await disposeApp(tester);
    },
  );

  testWidgets('TabBarTone: 톤 알림이 컨테이너 톤 · 글래스 배경 톤은 톤에서 (RN useTabBarTone)', (
    tester,
  ) async {
    await pumpCameoApp(tester, '/?session=member');
    final home = tester.element(find.byType(HomeTimelineScreen));
    TabBarTone.report(home, TabBarV6Tone.canvas);
    await settleApp(tester);
    expect(_bar(tester).tone, TabBarV6Tone.canvas);

    expect(_bar(tester).backdrop, isNull);
    expect(TabBarV6Tone.canvas.backdrop, GlassBackdropTone.fromToken('light'));

    await tester.tap(_tab(2));
    await settleApp(tester);
    expect(_bar(tester).tone, TabBarV6Tone.canvas);
    await disposeApp(tester);
  });

  testWidgets(
    '통화 버튼 = 통화 모달 (루트 — v5 홈 phone-call 과 같은 동작) · 흐름 데모 home.call 도 컨테이너가 등록',
    (tester) async {
      await pumpCameoApp(tester, '/?session=member');
      await tester.tap(find.byKey(TabBarV6.buttonKey));
      await settleApp(tester);
      expect(find.byType(CallScreen), findsOneWidget);
      expect(CameoRouteActivity.rootTop!.settings.name, '/call');
      await disposeApp(tester);
    },
  );

  testWidgets(
    '카메라 탭이 TabBarCamera 슬롯을 주면 탭바 = 카메라 변형 (보임 · 톤 camera) · 전환 원 → onFlip · 다른 탭 = album 변형',
    (tester) async {
      await pumpCameoApp(tester, '/?session=member');
      await tester.tap(_tab(1));
      await settleApp(tester);
      final tabs = appTabs(tester)!;
      expect(tabs.tabBarHidden, isFalse);
      expect(tabs.tabBarVariant, TabBarV6Variant.camera);
      expect(_bar(tester).tone, TabBarV6Tone.camera);
      expect(_barRect(tester).top, closeTo(750, 0.5));
      expect(tester.getRect(find.byKey(TabBarV6.pillKey)).left, 78);
      final state = tester.state<CameraV6ScreenState>(
        find.byType(CameraV6Screen),
      );
      final before = state.facing;
      await tester.tap(find.byKey(TabBarV6.buttonKey));
      await settleApp(tester);
      expect(state.facing, isNot(before));

      await tester.tap(_tab(2));
      await settleApp(tester);
      expect(tabs.tabBarVariant, TabBarV6Variant.album);
      expect(tabs.tabBarHidden, isFalse);
      await disposeApp(tester);
    },
  );

  testWidgets(
    'v6 딥링크: /?view=liked → 탭 0 루트 이름 그대로 (HomeTimelineScreen.initialView) · /capture?review=1 → CameraV6Screen.review',
    (tester) async {
      await pumpCameoApp(tester, '/?view=liked&session=member');
      expect(
        tester
            .widget<HomeTimelineScreen>(find.byType(HomeTimelineScreen))
            .initialView,
        AlbumView.liked,
      );
      expect(CameoRouteActivity.leaf!.name, '/?view=liked');
      expect(FlowDemo.stackSnapshot().top, FlowDemoScreen.home);
      await disposeApp(tester);
      await pumpCameoApp(tester, '/capture?review=1&session=member');
      expect(
        tester.widget<CameraV6Screen>(find.byType(CameraV6Screen)).review,
        isTrue,
      );
      expect(appTabs(tester)!.selectedTab, CameoTabs.camera);
      await disposeApp(tester);
    },
  );

  testWidgets(
    '탭 0 스택: 16-3 을 올리고 설정 → 앨범으로 돌아와도 그대로 · 선택된 탭 0 재탭 = 루트로 (pop)',
    (tester) async {
      await pumpCameoApp(tester, '/?session=member');
      final home = tester.element(find.byType(HomeTimelineScreen));
      CameoNav.push<void>(home, CameoRoutes.albumsGangneung);
      await settleApp(tester);
      final gangneung = tester.widget<AlbumGangneungScreen>(
        find.byType(AlbumGangneungScreen),
      );
      expect(gangneung.inTabs, isTrue);
      expect(find.byType(TabBarV6), findsOneWidget);
      expect(appTabs(tester)!.albumsNavigator!.canPop(), isTrue);
      expect(FlowDemo.stackSnapshot().top, FlowDemoScreen.gangneung);

      await tester.tap(_tab(2));
      await settleApp(tester);
      await tester.tap(_tab(0));
      await settleApp(tester);
      expect(find.byType(AlbumGangneungScreen), findsOneWidget);

      await tester.tap(_tab(0));
      await settleApp(tester);
      expect(find.byType(AlbumGangneungScreen), findsNothing);
      expect(find.byType(HomeTimelineScreen), findsOneWidget);
      await disposeApp(tester);
    },
  );

  testWidgets(
    'CameoNav: 16-3(탭 안)의 히어로 → 16-6 은 루트 · 16-3 뒤로 = 탭 0 스택 pop · 덮인 컨테이너의 화면은 맨 위가 아니다',
    (tester) async {
      await pumpCameoApp(tester, '/albums/gangneung?session=member');
      expect(find.byType(AlbumGangneungScreen), findsOneWidget);
      final gangneung = tester.element(find.byType(AlbumGangneungScreen));
      expect(CameoNav.isTop(gangneung), isTrue);
      expect(FlowDemo.run(FlowDemoAction.gangneungOpenAlbum), isTrue);
      await settleApp(tester);
      expect(find.byType(AlbumScreen), findsOneWidget);
      expect(CameoRouteActivity.rootTop!.settings.name, '/album');
      expect(CameoNav.isTop(gangneung), isFalse);
      expect(FlowDemo.run(FlowDemoAction.gangneungOpenAlbum), isFalse);
      expect(FlowDemo.run(FlowDemoAction.back), isTrue);
      await settleApp(tester);
      expect(FlowDemo.stackSnapshot().top, FlowDemoScreen.gangneung);
      expect(CameoNav.pop(gangneung), isTrue);
      await settleApp(tester);
      expect(FlowDemo.stackSnapshot().top, FlowDemoScreen.home);
      expect(FlowDemo.run(FlowDemoAction.back), isFalse);
      await disposeApp(tester);
    },
  );

  testWidgets('숨은 탭의 화면은 맨 위가 아니다 · selectTab (0 · 1 · 2)', (tester) async {
    await pumpCameoApp(tester, '/?session=member');
    final home = tester.element(find.byType(HomeTimelineScreen));
    expect(CameoNav.isTop(home), isTrue);
    expect(CameoNav.selectTab(home, CameoTabs.camera), isTrue);
    await settleApp(tester);
    expect(CameoNav.isTop(home), isFalse);
    expect(FlowDemo.run(FlowDemoAction.homeCall), isFalse);
    expect(CameoNav.selectTab(home, CameoTabs.settings), isTrue);
    await settleApp(tester);
    expect(appTabs(tester)!.selectedTab, CameoTabs.settings);
    await disposeApp(tester);
  });

  testWidgets(
    '상태바: 홈 타임라인 = light 글리프 · 카메라 탭 = light · 설정(v4 밝은 canvas) = dark',
    (tester) async {
      await pumpCameoApp(tester, '/?session=member');
      await tester.pump();
      expect(
        SystemChrome.latestStyle,
        CameoStatusBarStyle.lightContent.overlay,
      );
      await tester.tap(_tab(2));
      await settleApp(tester);
      await tester.pump();
      expect(SystemChrome.latestStyle, CameoStatusBarStyle.darkContent.overlay);
      await tester.tap(_tab(1));
      await settleApp(tester);
      await tester.pump();
      expect(
        SystemChrome.latestStyle,
        CameoStatusBarStyle.lightContent.overlay,
      );
      await disposeApp(tester);
    },
  );

  testWidgets(
    '흐름 데모 등록: tabs.camera · tabs.settings = 탭 누름과 같은 select · 통화(루트 모달)가 덮으면 거부',
    (tester) async {
      await pumpCameoApp(tester, '/?session=member');
      expect(FlowDemo.isRegistered(FlowDemoAction.tabsCamera), isTrue);
      expect(FlowDemo.isRegistered(FlowDemoAction.tabsSettings), isTrue);
      expect(FlowDemo.run(FlowDemoAction.tabsCamera), isTrue);
      await settleApp(tester);
      expect(appTabs(tester)!.selectedTab, CameoTabs.camera);
      expect(FlowDemo.run(FlowDemoAction.tabsSettings), isTrue);
      await settleApp(tester);
      expect(appTabs(tester)!.selectedTab, CameoTabs.settings);
      await tester.tap(_tab(0));
      await settleApp(tester);

      expect(FlowDemo.run(FlowDemoAction.homeCall), isTrue);
      await settleApp(tester);
      expect(find.byType(CallScreen), findsOneWidget);
      final call = CameoRouteActivity.rootTop!;
      expect(call.settings.name, '/call');
      expect(call.navigator, rootNavigator(tester));
      expect(FlowDemo.run(FlowDemoAction.tabsSettings), isFalse);
      await disposeApp(tester);
      expect(FlowDemo.isRegistered(FlowDemoAction.tabsCamera), isFalse);
    },
  );

  testWidgets(
    '설정: 로그아웃 행 → 시트 (라우트 아님 — 잎은 설정) · 등장 끝 = settle · 시트 로그아웃 → 웰컴',
    (tester) async {
      final session = await pumpCameoApp(tester, '/settings?session=member');
      expect(FlowDemo.run(FlowDemoAction.sheetConfirm), isFalse);
      final before = FlowDemo.settleCount(FlowDemoAction.settingsLogout);
      await scrollIntoCenter(
        tester,
        find.byKey(const ValueKey('settings.logout')),
      );
      await tester.tap(find.byKey(const ValueKey('settings.logout')));
      await tester.pump();
      expect(find.byKey(const ValueKey('settings.sheet')), findsOneWidget);
      expect(FlowDemo.settleCount(FlowDemoAction.settingsLogout), before);
      await settleApp(tester);
      expect(FlowDemo.settleCount(FlowDemoAction.settingsLogout), before + 1);
      expect(FlowDemo.stackSnapshot().top, FlowDemoScreen.settings);
      await tester.tap(find.byKey(ConfirmSheet.confirmKey));
      await settleApp(tester);
      expect(session.session.status, SessionStatus.signedOut);
      expect(FlowDemo.stackSnapshot().top, FlowDemoScreen.welcome);
      await disposeApp(tester);
    },
  );
}
