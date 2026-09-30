// Regression coverage for camera screen. Preserve behavior, layout, and interaction
// expectations.

import 'package:camera/camera.dart';
import 'package:cameo/components/camera_viewfinder.dart';
import 'package:cameo/components/segmented_control.dart';
import 'package:cameo/components/shutter_button.dart';
import 'package:cameo/content/lab.g.dart';
import 'package:cameo/design_system/design_system.dart';
import 'package:cameo/navigation/navigation.dart';
import 'package:cameo/screens/camera/camera_screen.dart';
import 'package:cameo/state/captured_photo.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const Size _screen = Size(393, 852);
const Duration _frame = Duration(milliseconds: 16);

Future<List<CameraDescription>> _noCameras() async => const [];

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

class _Host {
  bool closed = false;
  CapturedPhoto? photo;
  int results = 0;
}

Future<void> _run(WidgetTester tester, Duration total) async {
  for (var i = 0; i < total.inMicroseconds ~/ _frame.inMicroseconds; i++) {
    await tester.pump(_frame);
  }
}

Future<_Host> _openCamera(
  WidgetTester tester, {
  bool demo = false,
  bool disableAnimations = false,
}) async {
  _iPhone16(tester, disableAnimations: disableAnimations);
  final navigatorKey = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    WidgetsApp(
      navigatorKey: navigatorKey,
      color: CameoColors.backgroundCanvasBase,
      textStyle: CameoTextStyles.bodyLg,
      onGenerateRoute: (settings) => CameoPageRoute<void>(
        settings: settings,
        builder: (_) =>
            const ColoredBox(color: CameoColors.backgroundCanvasBase),
      ),
    ),
  );
  final host = _Host();
  navigatorKey.currentState!
      .push(
        CameoModalRoute<CapturedPhoto>(
          builder: (_) =>
              CameraScreen(demo: demo, cameraListLoader: _noCameras),
        ),
      )
      .then((photo) {
        host.closed = true;
        host.photo = photo;
        host.results += 1;
      });

  await tester.pump();
  await tester.pump();
  await _run(tester, springSettleDuration(CameoMotion.transitionModalSpring));
  await tester.pump();
  return host;
}

CameraScreenState _state(WidgetTester tester) =>
    tester.state<CameraScreenState>(find.byType(CameraScreen));

void _expectRect(Rect actual, Rect expected, {double eps = 0.01}) {
  expect(actual.left, closeTo(expected.left, eps), reason: 'left');
  expect(actual.top, closeTo(expected.top, eps), reason: 'top');
  expect(actual.width, closeTo(expected.width, eps), reason: 'width');
  expect(actual.height, closeTo(expected.height, eps), reason: 'height');
}

double _flash(WidgetTester tester) => tester
    .widget<FadeTransition>(find.byKey(CameraViewfinder.flashKey))
    .opacity
    .value;

Finder get _segmented => find.byType(SegmentedControl<CameraModeId>);

void main() {
  group('CameraScreen 레이아웃 @ 393x852 (16-14 2056:3280)', () {
    testWidgets('배경 background/neutral/inverse · 닫기 56 @ (16, 62)', (
      tester,
    ) async {
      await _openCamera(tester);
      final root = tester.widget<ColoredBox>(
        find
            .descendant(
              of: find.byType(CameraScreen),
              matching: find.byType(ColoredBox),
            )
            .first,
      );
      expect(root.color, CameoColors.backgroundNeutralInverse);
      _expectRect(
        tester.getRect(find.byKey(CameraScreen.closeKey)),
        const Rect.fromLTWH(16, 62, 56, 56),
      );
    });

    testWidgets(
      '글래스 배경 톤 dark (light 모드 + 검정 캔버스 — effect.liquidGlass.backdrop.cameraScreen) · 컨트롤 = Liquid Glass (G1)',
      (tester) async {
        await _openCamera(tester);
        final close = find.byKey(CameraScreen.closeKey);
        expect(GlassBackdrop.of(tester.element(close)), GlassBackdropTone.dark);
        expect(CameoTheme.modeOf(tester.element(close)), CameoColorMode.light);

        final surfaces = tester
            .widgetList<GlassSurface>(
              find.descendant(
                of: find.byType(CameraScreen),
                matching: find.byType(GlassSurface),
              ),
            )
            .toList();
        expect(surfaces, hasLength(4));
        for (final g in surfaces) {
          expect(g.effect, GlassEffect.glass);
          expect(g.blur!.material, CameoBlurMaterial.glass);
        }
      },
    );

    testWidgets('뷰파인더 393x524 @ y130 (래퍼 118…666, py12) · placeholder', (
      tester,
    ) async {
      await _openCamera(tester);
      _expectRect(
        tester.getRect(find.byType(CameraViewfinder)),
        const Rect.fromLTWH(0, 130, 393, 524),
      );
      expect(find.byKey(CameraViewfinder.placeholderKey), findsOneWidget);
    });

    testWidgets('셔터 행 666…748 · 셔터 74 @ (159.5, 670) · 안쪽 원 60 @ inset 7', (
      tester,
    ) async {
      await _openCamera(tester);
      _expectRect(
        tester.getRect(find.byKey(CameraScreen.shutterRowKey)),
        const Rect.fromLTWH(0, 666, 393, 82),
      );
      _expectRect(
        tester.getRect(find.byKey(ShutterButton.outerKey)),
        const Rect.fromLTWH(159.5, 670, 74, 74),
      );
      _expectRect(
        tester.getRect(find.byKey(ShutterButton.discKey)),
        const Rect.fromLTWH(166.5, 677, 60, 60),
      );
    });

    testWidgets(
      '하단 바 748…852 · 세그먼트 160x56 @ (117, 760) · 전환 56 @ (321, 760)',
      (tester) async {
        await _openCamera(tester);
        _expectRect(
          tester.getRect(find.byKey(CameraScreen.bottomBarKey)),
          const Rect.fromLTWH(0, 748, 393, 104),
        );
        _expectRect(
          tester.getRect(_segmented),
          const Rect.fromLTWH(117, 760, 160, 56),
        );

        _expectRect(
          tester.getRect(find.byKey(SegmentedControl.pillKey)),
          const Rect.fromLTWH(122, 765, 73, 46),
        );
        _expectRect(
          tester.getRect(find.byKey(CameraScreen.flipKey)),
          const Rect.fromLTWH(321, 760, 56, 56),
        );
      },
    );
  });

  group('CameraScreen 상태 전이', () {
    testWidgets('실제 카메라 확인은 모달 슬라이드 업이 끝난 뒤 시작한다 (RN useModalEntered)', (
      tester,
    ) async {
      _iPhone16(tester);
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        WidgetsApp(
          navigatorKey: navigatorKey,
          color: CameoColors.backgroundCanvasBase,
          textStyle: CameoTextStyles.bodyLg,
          onGenerateRoute: (settings) => CameoPageRoute<void>(
            settings: settings,
            builder: (_) =>
                const ColoredBox(color: CameoColors.backgroundCanvasBase),
          ),
        ),
      );
      var loads = 0;
      Future<List<CameraDescription>> counting() async {
        loads += 1;
        return const [];
      }

      navigatorKey.currentState!.push(
        CameoModalRoute<CapturedPhoto>(
          builder: (_) => CameraScreen(cameraListLoader: counting),
        ),
      );
      await tester.pump();
      await tester.pump();
      final settle = springSettleDuration(CameoMotion.transitionModalSpring);

      await _run(tester, settle ~/ 2);
      expect(loads, 0);
      expect(find.byKey(CameraViewfinder.placeholderKey), findsOneWidget);

      await _run(tester, settle);
      await tester.pump();
      expect(loads, 1);
      expect(find.byKey(CameraViewfinder.placeholderKey), findsOneWidget);
    });

    testWidgets('초기: 사진 모드 · 후면 · 셔터 라벨 "사진 촬영"', (tester) async {
      await _openCamera(tester);
      expect(_state(tester).mode, labCamera.initialMode);
      expect(_state(tester).facing, CameraFacing.back);
      expect(
        tester
            .widget<ShutterButton>(find.byType(ShutterButton))
            .accessibilityLabel,
        '사진 촬영',
      );
    });

    testWidgets('세그먼트 탭 → 동영상 (pill 슬라이드) → 사진', (tester) async {
      await _openCamera(tester);
      await tester.tap(find.byKey(SegmentedControl.segmentKey(1)));
      await tester.pump();
      expect(_state(tester).mode, CameraModeId.video);
      await tester.pumpAndSettle();
      _expectRect(
        tester.getRect(find.byKey(SegmentedControl.pillKey)),
        const Rect.fromLTWH(199, 765, 73, 46),
      );
      expect(
        tester
            .widget<ShutterButton>(find.byType(ShutterButton))
            .accessibilityLabel,
        '동영상 촬영',
      );
      await tester.tap(find.byKey(SegmentedControl.segmentKey(0)));
      await tester.pump();
      expect(_state(tester).mode, CameraModeId.photo);
    });

    testWidgets('전환 탭 → 전면 (뷰파인더 반 바퀴) → 다시 후면', (tester) async {
      await _openCamera(tester);
      await tester.tap(find.byKey(CameraScreen.flipKey));
      await tester.pump();
      expect(_state(tester).facing, CameraFacing.front);
      await _run(tester, const Duration(milliseconds: 96));
      final m = tester
          .widget<Transform>(find.byKey(CameraViewfinder.flipKey))
          .transform;
      expect(m.entry(0, 2).abs(), greaterThan(0.1));
      await _run(tester, springSettleDuration(CameoMotion.cameraFlipSpring));
      await tester.pump();
      await tester.tap(find.byKey(CameraScreen.flipKey));
      await tester.pump();
      expect(_state(tester).facing, CameraFacing.back);
      await tester.pumpAndSettle();
    });

    testWidgets('동영상 모드 셔터 → 누름 피드백만 (닫히지 않음)', (tester) async {
      final host = await _openCamera(tester);
      _state(tester).onModeChange(CameraModeId.video);
      await tester.pump();
      await tester.tap(find.byType(ShutterButton));
      await tester.pump();
      expect(
        tester.widget<ShutterButton>(find.byType(ShutterButton)).feedbackKey,
        1,
      );
      await _run(tester, const Duration(milliseconds: 800));
      expect(host.closed, isFalse);
      expect(find.byType(CameraScreen), findsOneWidget);
      expect(_flash(tester), 0);
    });

    testWidgets('사진 모드 셔터 → 흰 플래시가 끝나면 placeholder 사진을 결과로 닫힘', (tester) async {
      final host = await _openCamera(tester);
      await tester.tap(find.byType(ShutterButton));
      await tester.pump();
      expect(_state(tester).isCapturing, isTrue);
      var peak = 0.0;
      final flash = CameoMotion.cameraFlashIn + CameoMotion.cameraFlashOut;
      for (var t = Duration.zero; t < flash - _frame; t += _frame) {
        await tester.pump(_frame);
        if (_flash(tester) > peak) peak = _flash(tester);
        expect(host.closed, isFalse);
      }
      expect(
        peak,
        moreOrLessEquals(CameoMotion.cameraFlashPeakOpacity, epsilon: 0.02),
      );
      await _run(tester, _frame * 2);
      expect(host.closed, isTrue);
      expect(host.photo, CapturedPhoto.placeholder());
      expect(host.photo!.source, CapturedPhotoSource.placeholder);
      expect(host.photo!.uri, labCamera.placeholder);
      await tester.pumpAndSettle();
      expect(find.byType(CameraScreen), findsNothing);
      expect(host.results, 1);
    });

    testWidgets('촬영 중 셔터 재입력은 무시 — 결과 한 번 · 아래 화면은 남는다', (tester) async {
      final host = await _openCamera(tester);
      await tester.tap(find.byType(ShutterButton));
      await tester.pump(_frame);
      _state(tester).onShutter();
      await tester.tap(find.byType(ShutterButton));
      await tester.pumpAndSettle();
      expect(host.results, 1);
      expect(host.photo, CapturedPhoto.placeholder());
      expect(find.byType(CameraScreen), findsNothing);
    });

    testWidgets('촬영 중 닫기(x) → 결과 없이 닫힘, 끝난 촬영은 다시 닫지 않는다', (tester) async {
      final host = await _openCamera(tester);
      await tester.tap(find.byType(ShutterButton));
      await tester.pump(_frame);
      await tester.tap(find.byKey(CameraScreen.closeKey));
      await tester.pumpAndSettle();
      expect(host.results, 1);
      expect(host.photo, isNull);
      expect(find.byType(CameraScreen), findsNothing);
    });

    testWidgets('닫기(x) → 결과 없이 닫힘 (null)', (tester) async {
      final host = await _openCamera(tester);
      await tester.tap(find.byKey(CameraScreen.closeKey));
      await tester.pumpAndSettle();
      expect(host.closed, isTrue);
      expect(host.photo, isNull);
      expect(find.byType(CameraScreen), findsNothing);
    });

    testWidgets('모션 감소 → 전환·세그먼트 즉시', (tester) async {
      await _openCamera(tester, disableAnimations: true);
      await tester.tap(find.byKey(CameraScreen.flipKey));
      await tester.pump();
      final m = tester
          .widget<Transform>(find.byKey(CameraViewfinder.flipKey))
          .transform;
      expect(m.entry(0, 2), moreOrLessEquals(0, epsilon: 1e-9));
      await tester.tap(find.byKey(SegmentedControl.segmentKey(1)));
      await tester.pump();
      await tester.pump();
      _expectRect(
        tester.getRect(find.byKey(SegmentedControl.pillKey)),
        const Rect.fromLTWH(199, 765, 73, 46),
      );
    });
  });

  group('CameraScreen 데모 (?demo=1 · interaction-spec §5)', () {
    testWidgets('1500 전환 · 3000 동영상 · 4000 사진 · 5500 셔터 → 결과로 닫힘', (
      tester,
    ) async {
      final host = await _openCamera(tester, demo: true);

      final opened = springSettleDuration(CameoMotion.transitionModalSpring);
      await _run(tester, CameraDemo.flip - opened);
      expect(_state(tester).facing, CameraFacing.back);
      await _run(tester, const Duration(milliseconds: 64));
      expect(_state(tester).facing, CameraFacing.front);

      await _run(tester, CameraDemo.video - CameraDemo.flip);
      expect(_state(tester).mode, CameraModeId.video);
      await _run(tester, CameraDemo.photo - CameraDemo.video);
      expect(_state(tester).mode, CameraModeId.photo);
      await _run(tester, CameraDemo.shutter - CameraDemo.photo);
      expect(_state(tester).isCapturing, isTrue);
      expect(host.closed, isFalse);
      await _run(
        tester,
        CameoMotion.cameraFlashIn + CameoMotion.cameraFlashOut + _frame * 4,
      );
      expect(host.closed, isTrue);
      expect(host.photo, CapturedPhoto.placeholder());
      await tester.pumpAndSettle();
    });

    testWidgets('데모 없이 열면 아무 것도 예약하지 않는다', (tester) async {
      final host = await _openCamera(tester);
      await _run(tester, CameraDemo.shutter + const Duration(seconds: 1));
      expect(_state(tester).facing, CameraFacing.back);
      expect(_state(tester).mode, CameraModeId.photo);
      expect(host.closed, isFalse);
    });

    testWidgets('흐름 데모 camera.shutter → 셔터와 같은 경로 (플래시 → 결과) · 닫히면 등록 해제', (
      tester,
    ) async {
      final host = await _openCamera(tester);
      expect(FlowDemo.isRegistered(FlowDemoAction.cameraShutter), isTrue);
      expect(FlowDemo.run(FlowDemoAction.cameraShutter), isTrue);
      await tester.pump();
      expect(_state(tester).isCapturing, isTrue);
      await _run(
        tester,
        CameoMotion.cameraFlashIn + CameoMotion.cameraFlashOut + _frame * 4,
      );
      expect(host.photo, CapturedPhoto.placeholder());
      await tester.pumpAndSettle();
      expect(FlowDemo.isRegistered(FlowDemoAction.cameraShutter), isFalse);
    });
  });
}
