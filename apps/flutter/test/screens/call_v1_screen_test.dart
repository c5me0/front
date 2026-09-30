// Regression coverage for call v1 screen. Preserve behavior, layout, and interaction
// expectations.

import 'package:cameo/components/call_background.dart';
import 'package:cameo/components/call_control_bar.dart';
import 'package:cameo/components/caller_block.dart';
import 'package:cameo/components/nav_bar.dart';
import 'package:cameo/components/toast.dart';
import 'package:cameo/content/lab.g.dart';
import 'package:cameo/design_system/design_system.dart';
import 'package:cameo/navigation/navigation.dart';
import 'package:cameo/screens/call/call_entrance.dart';
import 'package:cameo/screens/call_v1/call_v1_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const Size _screen = Size(393, 852);
const Duration _frame = Duration(milliseconds: 16);

const double _eps = 0.01;

void _iPhone16(WidgetTester tester, {bool disableAnimations = false}) {
  tester.view.physicalSize = _screen;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
  tester.view.viewPadding = const FakeViewPadding(top: 59, bottom: 34);
  addTearDown(tester.view.reset);
  if (disableAnimations) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }
}

const Key _homeKey = ValueKey('test.home');

Widget _app({
  String initialRoute = CameoRoutes.home,
  GlobalKey<NavigatorState>? navigatorKey,
}) {
  return WidgetsApp(
    navigatorKey: navigatorKey,
    color: CameoColors.backgroundCanvasBase,
    textStyle: CameoTextStyles.bodyLg,
    initialRoute: initialRoute,
    onGenerateRoute: (settings) => settings.name == CameoRoutes.home
        ? CameoPageRoute<dynamic>(
            settings: settings,
            builder: (_) => const ColoredBox(
              key: _homeKey,
              color: CameoColors.backgroundCanvasBase,
            ),
          )
        : onGenerateCameoRoute(settings),
  );
}

Future<void> _run(WidgetTester tester, Duration total) async {
  final frames = total.inMicroseconds ~/ _frame.inMicroseconds;
  for (var i = 0; i < frames; i++) {
    await tester.pump(_frame);
  }
}

Duration get _toastShowAt => CameoMotion.staggerItem * 2;

Future<void> _pumpCallV1(WidgetTester tester) async {
  await tester.pumpWidget(_app(initialRoute: CameoRoutes.callV1));
  await _run(
    tester,
    _toastShowAt +
        springSettleDuration(CameoMotion.toastEnterSpring) +
        _frame * 4,
  );
}

Future<void> _settleToastExit(WidgetTester tester) => _run(
  tester,
  springSettleDuration(CameoMotion.toastExitSpring) + _frame * 4,
);

void _expectRect(Rect actual, Rect expected, {double eps = _eps}) {
  expect(actual.left, closeTo(expected.left, eps), reason: 'left');
  expect(actual.top, closeTo(expected.top, eps), reason: 'top');
  expect(actual.width, closeTo(expected.width, eps), reason: 'width');
  expect(actual.height, closeTo(expected.height, eps), reason: 'height');
}

Finder get _screenFinder => find.byType(CallV1Screen);
Finder get _nav => find.byType(NavBar);
Finder get _circles => find.byType(GlassIconButton);
Finder get _caller => find.byType(CallerBlock);
Finder get _toastFinder => find.byType(Toast);
Finder get _controlBar => find.byType(CallControlBar);
Finder get _bar =>
    find.descendant(of: _controlBar, matching: find.byType(GlassSurface));

Finder _controlButton(int i) =>
    find.descendant(of: _controlBar, matching: find.byType(PressScale)).at(i);

Finder get _pill => find.descendant(
  of: _toastFinder,
  matching: find.byWidgetPredicate(
    (w) =>
        w is DecoratedBox &&
        w.decoration is BoxDecoration &&
        (w.decoration as BoxDecoration).border != null,
  ),
);

Toast _toast(WidgetTester tester) => tester.widget<Toast>(_toastFinder);

double _toastOpacity(WidgetTester tester) => tester
    .widget<Opacity>(
      find.descendant(of: _toastFinder, matching: find.byType(Opacity)),
    )
    .opacity;

double _toastOffsetY(WidgetTester tester) => tester
    .widget<Transform>(
      find.descendant(of: _toastFinder, matching: find.byType(Transform)).first,
    )
    .transform
    .getTranslation()
    .y;

Finder get _callerEntrance =>
    find.ancestor(of: _caller, matching: find.byType(CallEntrance));

double _callerOpacity(WidgetTester tester) => tester
    .widget<Opacity>(
      find.descendant(of: _callerEntrance, matching: find.byType(Opacity)),
    )
    .opacity;

Finder _toggle(CameoIconName icon) => find.descendant(
  of: _nav,
  matching: find.byWidgetPredicate((w) => w is ToggleIcon && w.icon == icon),
);

CameoIconName _shownNavIcon(WidgetTester tester, CameoIconName icon) => tester
    .widget<CameoIcon>(
      find.descendant(of: _toggle(icon), matching: find.byType(CameoIcon)),
    )
    .name;

bool? _moonActive(WidgetTester tester) =>
    tester.widget<NavBar>(_nav).actions.first.active;

void main() {
  group('레이아웃 (2004:1796 @ 393x852, 안전 영역 59/34)', () {
    testWidgets('칠 순서 = Figma: 배경 → 컨트롤 바 → 발신자 → 토스트 → 내비(맨 위)', (
      tester,
    ) async {
      _iPhone16(tester);
      await _pumpCallV1(tester);

      final stack = tester.widget<Stack>(
        find.descendant(of: _screenFinder, matching: find.byType(Stack)).first,
      );
      final children = stack.children;
      expect(children, hasLength(5));
      expect((children[0] as Positioned).child, isA<CallBackground>());
      final bar = (children[1] as Positioned).child as CallEntrance;
      expect(bar.child, isA<CallControlBar>());
      final caller = (children[2] as Positioned).child as CallEntrance;
      expect(caller.child, isA<CallerBlock>());
      expect((children[3] as Positioned).child, isA<ToastHost>());
      expect(children[4], isA<NavBar>());

      final underlay = tester.widget<ColoredBox>(
        find
            .descendant(of: _screenFinder, matching: find.byType(ColoredBox))
            .first,
      );
      expect(underlay.color, CameoColors.callBackgroundOverlay);
      expect(
        tester.getRect(
          find
              .descendant(of: _screenFinder, matching: find.byType(ColoredBox))
              .first,
        ),
        Offset.zero & _screen,
      );

      expect(
        tester.getRect(find.byType(CallBackground)),
        Offset.zero & _screen,
      );
    });

    testWidgets(
      '내비 v1 (2018:2077): 행 y 62…128 · 원형 50 × 3 (x 16 · 265 · 327, y 70)',
      (tester) async {
        _iPhone16(tester);
        await _pumpCallV1(tester);

        // Figma bottom 724 → 852 − 724 − 66 = 62
        _expectRect(tester.getRect(_nav), const Rect.fromLTWH(0, 62, 393, 66));
        expect(tester.getRect(_nav).top, CameoLayout.navBarV1Top);
        expect(tester.getRect(_nav).height, CameoLayout.navBarV1Height);

        expect(_circles, findsNWidgets(3));

        _expectRect(
          tester.getRect(_circles.at(0)),
          const Rect.fromLTWH(16, 70, 50, 50),
        );
        _expectRect(
          tester.getRect(_circles.at(1)),
          const Rect.fromLTWH(265, 70, 50, 50),
        );
        _expectRect(
          tester.getRect(_circles.at(2)),
          const Rect.fromLTWH(327, 70, 50, 50),
        );

        final buttons = tester.widgetList<GlassIconButton>(_circles).toList();
        expect(buttons.map((b) => b.variant).toSet(), {GlassNavVariant.v1});
        expect(buttons[0].icon, CameoIconName.chevronDown);
        expect(buttons[1].icon, CameoIconName.moon);
        expect(buttons[1].activeIcon, CameoIconName.moonFilled);

        expect(buttons[1].active, isFalse);
        expect(_shownNavIcon(tester, CameoIconName.moon), CameoIconName.moon);
        expect(buttons[2].icon, CameoIconName.focus);
      },
    );

    testWidgets(
      '발신자 v1 (2004:1814): top 128 · 393 x 127.6 · bottom ≈ 256 (Figma bottom 596)',
      (tester) async {
        _iPhone16(tester);
        await _pumpCallV1(tester);

        final r = tester.getRect(_caller);
        _expectRect(r, const Rect.fromLTWH(0, 128, 393, 127.6));
        expect(
          r.top,
          callerBlockTop(
            navBarFrame(variant: NavBarVariant.v1, safeAreaTop: 59).bottom,
          ),
        );
        expect(r.height, closeTo(CameoLayout.callerBlockV1Height, 0.001));

        expect(
          r.bottom,
          closeTo(_screen.height - CameoLayout.callerBlockV1FigmaBottom, 0.41),
        );
        expect(_callerOpacity(tester), 1);

        expect(
          tester.widget<CallerBlock>(_caller).variant,
          CallerBlockVariant.v1,
        );
        expect(find.text('Yurim'), findsOneWidget);
        expect(find.text('00:05'), findsOneWidget);

        final timer = tester.widget<CameoText>(
          find.descendant(of: _caller, matching: find.byType(CameoText)).at(1),
        );
        expect(timer.style, CameoTextStyles.bodyLg);
      },
    );

    testWidgets(
      '토스트 v1 (2004:1817/1818): 컨테이너 665…742 · pill y 681…726 · 가운데 · moonFilled 18',
      (tester) async {
        _iPhone16(tester);
        await _pumpCallV1(tester);

        _expectRect(
          tester.getRect(_toastFinder),
          const Rect.fromLTWH(0, 665, 393, 77),
        );
        expect(tester.getRect(_toastFinder).top, CameoLayout.toastV1FigmaTop);

        final pill = tester.getRect(_pill);
        expect(pill.top, closeTo(681, _eps));
        expect(pill.height, closeTo(CameoLayout.toastPillHeight, _eps));
        expect(pill.bottom, closeTo(726, _eps));
        expect(pill.center.dx, closeTo(_screen.width / 2, _eps));
        expect(pill.width, lessThanOrEqualTo(393 - 2 * 16));

        final toast = _toast(tester);
        expect(toast.variant, ToastVariant.v1);
        expect(toast.visible, isTrue);
        expect(toast.message, 'Yurim님께 취침 모드 전환 요청이 전송되었습니다!');
        expect(toast.message, labInCall.toasts.sleepModeRequest.text);
        expect(toast.icon, CameoIconName.moonFilled);
        final icon = tester.widget<CameoIcon>(
          find.descendant(of: _pill, matching: find.byType(CameoIcon)),
        );
        expect(icon.name, CameoIconName.moonFilled);
        expect(icon.size, 18);
        expect(_toastOpacity(tester), 1);
        expect(_toastOffsetY(tester), 0);
      },
    );

    testWidgets(
      '컨트롤 바 v1 (2004:1798/1799): 컨테이너 742…852 · 바 758…816 (58) · 종료 293…373',
      (tester) async {
        _iPhone16(tester);
        await _pumpCallV1(tester);

        _expectRect(
          tester.getRect(_controlBar),
          const Rect.fromLTWH(0, 742, 393, 110),
        );
        _expectRect(
          tester.getRect(_bar),
          const Rect.fromLTWH(16, 758, 361, 58),
        );
        expect(
          tester.widget<CallControlBar>(_controlBar).variant,
          CallControlBarVariant.v1,
        );

        const toggleWidth = 68.25;
        for (var i = 0; i < 4; i++) {
          _expectRect(
            tester.getRect(_controlButton(i)),
            Rect.fromLTWH(20 + i * toggleWidth, 762, toggleWidth, 50),
          );
          expect(tester.getCenter(_controlButton(i)).dy, closeTo(787, _eps));
        }

        _expectRect(
          tester.getRect(_controlButton(4)),
          const Rect.fromLTWH(293, 762, 80, 50),
        );
      },
    );
  });

  group('마운트 코레오그래피 (통화 화면과 동일: 슬라이드 업 뒤 스태거)', () {
    testWidgets('슬라이드 업 중에는 발신자·바·토스트가 숨어 있고, 끝난 뒤 발신자 → 바 → 토스트 순으로 등장', (
      tester,
    ) async {
      _iPhone16(tester);
      final key = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_app(navigatorKey: key));
      expect(find.byKey(_homeKey), findsOneWidget);
      key.currentState!.pushNamed(CameoRoutes.callV1);
      await tester.pump();
      await tester.pump(_frame);

      final settle = springSettleDuration(CameoMotion.transitionModalSpring);
      await _run(tester, settle ~/ 2);
      expect(
        ModalRoute.of(tester.element(_caller))!.animation!.isCompleted,
        isFalse,
      );
      expect(_callerOpacity(tester), 0);
      expect(_toast(tester).visible, isFalse);
      final routeDy = tester.getTopLeft(_screenFinder).dy;
      expect(tester.getTopLeft(_bar).dy - routeDy, closeTo(758 + 110, _eps));

      await _run(tester, settle ~/ 2 + _frame * 3);
      expect(tester.getTopLeft(_screenFinder).dy, 0);
      await _run(tester, CameoMotion.staggerItem);
      final callerMid = _callerOpacity(tester);
      expect(callerMid, greaterThan(0));
      expect(callerMid, lessThan(1));
      expect(tester.getTopLeft(_caller).dy, greaterThan(128));
      expect(tester.getTopLeft(_bar).dy, greaterThan(758));

      await _run(tester, const Duration(milliseconds: 1500));
      expect(_callerOpacity(tester), 1);
      _expectRect(
        tester.getRect(_caller),
        const Rect.fromLTWH(0, 128, 393, 127.6),
      );
      _expectRect(tester.getRect(_bar), const Rect.fromLTWH(16, 758, 361, 58));
      expect(_toast(tester).visible, isTrue);
      expect(_toast(tester).message, labInCall.toasts.sleepModeRequest.text);
      expect(_toastOpacity(tester), 1);
      expect(tester.getRect(_pill).top, closeTo(681, _eps));
    });

    testWidgets('토스트: p = 0(투명, +24)에서 bouncy 등장 → toastVisible 후 smooth 퇴장', (
      tester,
    ) async {
      _iPhone16(tester);
      await tester.pumpWidget(_app(initialRoute: CameoRoutes.callV1));
      await _run(tester, _toastShowAt);
      await tester.pump();
      expect(_toast(tester).visible, isTrue);

      expect(_toastOpacity(tester), 0);
      expect(_toastOffsetY(tester), CameoMotion.toastEnterOffset);

      await _run(tester, _frame * 3);
      expect(_toastOpacity(tester), greaterThan(0));
      expect(_toastOffsetY(tester), lessThan(CameoMotion.toastEnterOffset));

      await _run(
        tester,
        springSettleDuration(CameoMotion.toastEnterSpring) + _frame * 2,
      );
      expect(_toastOpacity(tester), 1);
      expect(_toastOffsetY(tester), 0);

      await _run(tester, CameoMotion.toastVisible);
      await _settleToastExit(tester);
      expect(_toastOpacity(tester), 0);
      expect(_toast(tester).visible, isFalse);
    });

    testWidgets('모션 감소: 바는 처음부터 제자리, 발신자·토스트는 이동 없이 페이드', (tester) async {
      _iPhone16(tester, disableAnimations: true);
      await tester.pumpWidget(_app(initialRoute: CameoRoutes.callV1));
      _expectRect(tester.getRect(_bar), const Rect.fromLTWH(16, 758, 361, 58));
      _expectRect(
        tester.getRect(_caller),
        const Rect.fromLTWH(0, 128, 393, 127.6),
      );

      await _run(tester, CameoMotion.durationBase ~/ 2);
      final mid = _callerOpacity(tester);
      expect(mid, greaterThan(0));
      expect(mid, lessThan(1));
      _expectRect(
        tester.getRect(_caller),
        const Rect.fromLTWH(0, 128, 393, 127.6),
      );

      expect(_toast(tester).visible, isTrue);
      expect(_toastOffsetY(tester), 0);

      await _run(tester, CameoMotion.durationBase);
      expect(_callerOpacity(tester), 1);
      expect(_toastOpacity(tester), 1);
      expect(_toastOffsetY(tester), 0);
      _expectRect(tester.getRect(_bar), const Rect.fromLTWH(16, 758, 361, 58));
      expect(tester.getRect(_pill).top, closeTo(681, _eps));
    });
  });

  group('동작', () {
    testWidgets('타이머: 00:04 부터 1초마다 증가', (tester) async {
      _iPhone16(tester);
      await tester.pumpWidget(_app(initialRoute: CameoRoutes.callV1));
      expect(find.text('00:04'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('00:05'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('00:06'), findsOneWidget);
    });

    testWidgets('달 켜짐 → moonFilled + 토스트 다시 등장 · 꺼짐 → moon, 토스트 없음', (
      tester,
    ) async {
      _iPhone16(tester);
      await _pumpCallV1(tester);

      await _run(tester, CameoMotion.toastVisible);
      await _settleToastExit(tester);
      expect(_toast(tester).visible, isFalse);
      final keyBefore = _toast(tester).showKey;

      await tester.tap(_circles.at(1));
      await tester.pump();
      expect(_moonActive(tester), isTrue);
      expect(_toast(tester).visible, isTrue);
      expect(_toast(tester).showKey, keyBefore + 1);
      expect(_toast(tester).message, labInCall.toasts.sleepModeRequest.text);
      await _run(
        tester,
        springSettleDuration(CameoMotion.toastEnterSpring) + _frame * 4,
      );
      expect(
        _shownNavIcon(tester, CameoIconName.moon),
        CameoIconName.moonFilled,
      );
      expect(_toastOpacity(tester), 1);

      await _run(tester, CameoMotion.toastVisible);
      await _settleToastExit(tester);
      await tester.tap(_circles.at(1));
      await tester.pump();
      expect(_moonActive(tester), isFalse);
      expect(_shownNavIcon(tester, CameoIconName.moon), CameoIconName.moon);
      expect(_toast(tester).visible, isFalse);
      expect(_toast(tester).showKey, keyBefore + 1);
    });

    testWidgets('진입 토스트가 떠 있는 중에 달을 켜면 처음부터 다시 등장, 그 시점부터 toastVisible 유지', (
      tester,
    ) async {
      _iPhone16(tester);
      await _pumpCallV1(tester);
      final keyBefore = _toast(tester).showKey;

      await tester.tap(_circles.at(1));
      await tester.pump();
      expect(_toast(tester).showKey, keyBefore + 1);
      await _run(
        tester,
        springSettleDuration(CameoMotion.toastEnterSpring) + _frame * 4,
      );
      expect(_toastOpacity(tester), 1);

      await _run(tester, const Duration(milliseconds: 1200));
      expect(_toast(tester).visible, isTrue);
      expect(_toastOpacity(tester), 1);
    });

    testWidgets('컨트롤 토글: 탭하면 해당 키만 활성 (부모 소유 상태)', (tester) async {
      _iPhone16(tester);
      await _pumpCallV1(tester);
      expect(
        tester.widget<CallControlBar>(_controlBar).active,
        CallControlActive.none,
      );

      await tester.tap(_controlButton(0));
      await tester.pump();
      expect(
        tester.widget<CallControlBar>(_controlBar).active,
        const CallControlActive(volume: true),
      );

      await tester.tap(_controlButton(2));
      await tester.pump();
      expect(
        tester.widget<CallControlBar>(_controlBar).active,
        const CallControlActive(volume: true, camera: true),
      );

      await tester.tap(_controlButton(0));
      await tester.pump();
      expect(
        tester.widget<CallControlBar>(_controlBar).active,
        const CallControlActive(camera: true),
      );
    });

    testWidgets('접근성 이름: 닫기 · 취침 모드(켜짐/꺼짐) · 포커스 · 통화 종료 · 토스트 문구', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      _iPhone16(tester);
      await _pumpCallV1(tester);

      expect(find.bySemanticsLabel('닫기'), findsOneWidget);
      expect(find.bySemanticsLabel('취침 모드, 꺼짐'), findsOneWidget);
      expect(find.bySemanticsLabel('포커스'), findsOneWidget);
      expect(find.bySemanticsLabel('통화 종료'), findsOneWidget);
      expect(find.bySemanticsLabel('스피커, 꺼짐'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Yurim님께 취침 모드 전환 요청이 전송되었습니다!'),
        findsOneWidget,
      );

      await tester.tap(_circles.at(1));
      await tester.pump();
      expect(find.bySemanticsLabel('취침 모드, 켜짐'), findsOneWidget);
      semantics.dispose();
    });
  });

  group('닫기 (CameoModalRoute)', () {
    testWidgets('chevron-down → 모달이 닫히고 홈으로', (tester) async {
      _iPhone16(tester);
      await _pumpCallV1(tester);
      await tester.tap(_circles.at(0));
      await _run(tester, const Duration(seconds: 1));
      expect(_screenFinder, findsNothing);
      expect(find.byKey(_homeKey), findsOneWidget);
    });

    testWidgets('종료(X) → 모달이 닫힌다', (tester) async {
      _iPhone16(tester);
      await _pumpCallV1(tester);
      await tester.tap(_controlButton(4));
      await _run(tester, const Duration(seconds: 1));
      expect(_screenFinder, findsNothing);
      expect(find.byKey(_homeKey), findsOneWidget);
    });

    testWidgets('화면(발신자 영역)을 아래로 끌면 닫힌다', (tester) async {
      _iPhone16(tester);
      await _pumpCallV1(tester);
      await tester.dragFrom(
        tester.getCenter(_caller),
        Offset(0, _screen.height * 0.6),
      );
      await _run(tester, const Duration(seconds: 1));
      expect(_screenFinder, findsNothing);
      expect(find.byKey(_homeKey), findsOneWidget);
    });

    testWidgets('달·포커스 탭은 모달을 닫지 않는다 (글래스 버튼이 포인터를 차지)', (tester) async {
      _iPhone16(tester);
      await _pumpCallV1(tester);
      await tester.tap(_circles.at(1));
      await tester.tap(_circles.at(2));
      await _run(tester, const Duration(seconds: 1));
      expect(_screenFinder, findsOneWidget);
      expect(_moonActive(tester), isTrue);
      expect(tester.getTopLeft(_screenFinder).dy, 0);
    });
  });
}
