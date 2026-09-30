// Regression coverage for camera viewfinder. Preserve behavior, layout, and interaction
// expectations.

import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:cameo/components/camera_viewfinder.dart';
import 'package:cameo/content/lab.g.dart';
import 'package:cameo/design_system/design_system.dart';
import 'package:cameo/navigation/navigation.dart';
import 'package:cameo/state/captured_photo.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const Duration _frame = Duration(milliseconds: 16);

const MethodChannel _cameraChannel = MethodChannel('plugins.flutter.io/camera');

Future<List<CameraDescription>> _noCameras() async => const [];

Future<List<CameraDescription>> _throws() async =>
    throw CameraException('test', 'no plugin');

Future<List<CameraDescription>> _oneBackCamera() async => const [
  CameraDescription(
    name: 'back',
    lensDirection: CameraLensDirection.back,
    sensorOrientation: 90,
  ),
];

Future<void> _pump(
  WidgetTester tester, {
  CameraFacing facing = CameraFacing.back,
  CameraViewfinderController? controller,
  CameraListLoader loader = _noCameras,
  ValueChanged<CameraViewfinderSource>? onSourceChange,
  bool disableAnimations = false,
  bool active = true,
}) {
  return tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: CameoLayout.cameraScreenViewfinderWidth,
            height: CameoLayout.cameraScreenViewfinderHeight,
            child: CameraViewfinder(
              facing: facing,
              active: active,
              controller: controller,
              cameraListLoader: loader,
              onSourceChange: onSourceChange,
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _run(WidgetTester tester, Duration total) async {
  for (var i = 0; i < total.inMicroseconds ~/ _frame.inMicroseconds; i++) {
    await tester.pump(_frame);
  }
}

Matrix4 _flipMatrix(WidgetTester tester) =>
    tester.widget<Transform>(find.byKey(CameraViewfinder.flipKey)).transform;

double _flipDeg(WidgetTester tester) {
  final m = _flipMatrix(tester);
  return math.atan2(m.entry(0, 2), m.entry(0, 0)) * 180 / math.pi;
}

double _flashOpacity(WidgetTester tester) => tester
    .widget<FadeTransition>(find.byKey(CameraViewfinder.flashKey))
    .opacity
    .value;

void main() {
  group('cameraFlipAngleDeg — RN 과 같은 식', () {
    test('반 바퀴 진행값 → 앞면 0→90°, 새 면 −90°→0 (거울상 없음)', () {
      const a = CameoMotion.cameraFlipAngleDeg;
      expect(cameraFlipAngleDeg(0), 0);
      expect(cameraFlipAngleDeg(0.25), a * 0.25);
      expect(cameraFlipAngleDeg(0.49), moreOrLessEquals(a * 0.49));
      expect(cameraFlipAngleDeg(0.5), -a * 0.5);
      expect(cameraFlipAngleDeg(0.75), -a * 0.25);
      expect(cameraFlipAngleDeg(1), 0);
      expect(cameraFlipAngleDeg(1.25), a * 0.25);

      expect(cameraFlipAngleDeg(1.002), moreOrLessEquals(a * 0.002));
      expect(cameraFlipAngleDeg(0.998), moreOrLessEquals(-a * 0.002));
    });
  });

  group('CameraViewfinder — 소스', () {
    testWidgets('카메라 없음(시뮬레이터) → placeholder 이미지 cover', (tester) async {
      final sources = <CameraViewfinderSource>[];
      await _pump(tester, onSourceChange: sources.add);
      await tester.pump();
      expect(sources, [CameraViewfinderSource.placeholder]);
      final image = tester.widget<Image>(
        find.byKey(CameraViewfinder.placeholderKey),
      );
      expect(
        (image.image as AssetImage).assetName,
        LabImages.cameraPlaceholder,
      );
      expect(image.fit, BoxFit.cover);
      expect(
        tester.getRect(find.byKey(CameraViewfinder.placeholderKey)),
        const Rect.fromLTWH(0, 0, 393, 524),
      );
    });

    testWidgets('확인 중에도 placeholder 를 보여 준다 (Figma 첫 화면)', (tester) async {
      final controller = CameraViewfinderController();
      final cameras = Completer<List<CameraDescription>>();
      await _pump(tester, controller: controller, loader: () => cameras.future);
      expect(controller.source, CameraViewfinderSource.probing);
      expect(find.byKey(CameraViewfinder.placeholderKey), findsOneWidget);
      cameras.complete(const []);
      await tester.pump();
      expect(controller.source, CameraViewfinderSource.placeholder);
      expect(find.byKey(CameraViewfinder.placeholderKey), findsOneWidget);
    });

    testWidgets(
      'active false 동안은 확인하지 않는다 (probing = placeholder) → true 가 되면 한 번만',
      (tester) async {
        final controller = CameraViewfinderController();
        var loads = 0;
        Future<List<CameraDescription>> counting() async {
          loads += 1;
          return const [];
        }

        await _pump(
          tester,
          controller: controller,
          loader: counting,
          active: false,
        );
        await tester.pump();
        expect(loads, 0);
        expect(controller.source, CameraViewfinderSource.probing);
        expect(find.byKey(CameraViewfinder.placeholderKey), findsOneWidget);

        await _pump(tester, controller: controller, loader: counting);
        await tester.pump();
        expect(loads, 1);
        expect(controller.source, CameraViewfinderSource.placeholder);

        await _pump(
          tester,
          controller: controller,
          loader: counting,
          active: false,
        );
        await _pump(tester, controller: controller, loader: counting);
        await tester.pump();
        expect(loads, 1);
      },
    );

    testWidgets('플러그인 오류 → placeholder', (tester) async {
      final sources = <CameraViewfinderSource>[];
      await _pump(tester, loader: _throws, onSourceChange: sources.add);
      await tester.pump();
      expect(sources, [CameraViewfinderSource.placeholder]);
    });

    testWidgets('카메라 시작 실패(권한 거부 등) → placeholder', (tester) async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(_cameraChannel, (call) async {
        throw PlatformException(code: 'CameraAccessDenied');
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(_cameraChannel, null),
      );
      final sources = <CameraViewfinderSource>[];
      await _pump(tester, loader: _oneBackCamera, onSourceChange: sources.add);
      await tester.pumpAndSettle();
      expect(sources, [CameraViewfinderSource.placeholder]);
      expect(find.byKey(CameraViewfinder.placeholderKey), findsOneWidget);
    });

    testWidgets('capture() → placeholder 사진 (768x1024, source placeholder)', (
      tester,
    ) async {
      final controller = CameraViewfinderController();
      await _pump(tester, controller: controller);
      await tester.pump();
      late CapturedPhoto photo;
      controller.capture().then((p) => photo = p);
      await tester.pump();
      expect(photo, CapturedPhoto.placeholder());
      expect(photo.width, 768);
      expect(photo.height, 1024);
      expect(photo.source, CapturedPhotoSource.placeholder);
    });

    test('붙지 않은 컨트롤러 → placeholder 결과 · flash 즉시 완료', () async {
      final controller = CameraViewfinderController();
      expect(await controller.capture(), CapturedPhoto.placeholder());
      await controller.flash();
      expect(controller.source, CameraViewfinderSource.probing);
    });
  });

  group('CameraViewfinder — 전·후면 전환 3D 회전', () {
    testWidgets('facing 변경 → 반 바퀴: 90° 를 지나며 새 면이 −90° → 0 으로 · 원근 · 음영', (
      tester,
    ) async {
      await _pump(tester);
      await tester.pump();
      expect(_flipDeg(tester), moreOrLessEquals(0, epsilon: 1e-6));
      expect(
        _flipMatrix(tester).entry(3, 2),
        moreOrLessEquals(-1 / CameoMotion.cameraFlipPerspective),
      );

      await _pump(tester, facing: CameraFacing.front);
      var sawFront = false;
      var sawBack = false;
      var maxShade = 0.0;
      final settle = springSettleDuration(CameoMotion.cameraFlipSpring);
      for (var t = Duration.zero; t < settle; t += _frame) {
        await tester.pump(_frame);
        final deg = _flipDeg(tester);
        if (deg > 1) sawFront = true;
        if (deg < -1) sawBack = true;
        final shade = tester
            .widgetList<Opacity>(
              find.descendant(
                of: find.byKey(CameraViewfinder.flipKey),
                matching: find.byType(Opacity),
              ),
            )
            .first
            .opacity;
        if (shade > maxShade) maxShade = shade;
      }
      expect(sawFront, isTrue);
      expect(sawBack, isTrue);
      expect(maxShade, greaterThan(CameoMotion.cameraFlipShadeOpacity * 0.8));
      expect(maxShade, lessThanOrEqualTo(CameoMotion.cameraFlipShadeOpacity));
      await tester.pumpAndSettle();
      expect(_flipDeg(tester), moreOrLessEquals(0, epsilon: 1e-3));
    });

    testWidgets('모션 감소 → 회전 없이 즉시', (tester) async {
      await _pump(tester, disableAnimations: true);
      await tester.pump();
      await _pump(tester, facing: CameraFacing.front, disableAnimations: true);
      await tester.pump();
      expect(_flipDeg(tester), moreOrLessEquals(0, epsilon: 1e-6));
    });
  });

  group('CameraViewfinder — 플래시', () {
    testWidgets(
      'flash(): static/white 0 → peak (flashIn) → 0 (flashOut), 끝에 완료',
      (tester) async {
        final controller = CameraViewfinderController();
        await _pump(tester, controller: controller);
        await tester.pump();
        final white = tester.widget<ColoredBox>(
          find.descendant(
            of: find.byKey(CameraViewfinder.flashKey),
            matching: find.byType(ColoredBox),
          ),
        );
        expect(white.color, CameoColors.staticWhite);
        expect(_flashOpacity(tester), 0);

        var done = false;
        controller.flash().then((_) => done = true);
        var peak = 0.0;
        final total = CameoMotion.cameraFlashIn + CameoMotion.cameraFlashOut;
        for (var t = Duration.zero; t < total - _frame; t += _frame) {
          await tester.pump(_frame);
          if (_flashOpacity(tester) > peak) peak = _flashOpacity(tester);
        }
        expect(done, isFalse);
        expect(
          peak,
          moreOrLessEquals(CameoMotion.cameraFlashPeakOpacity, epsilon: 0.02),
        );
        await _run(tester, _frame * 2);
        expect(done, isTrue);
        await tester.pumpAndSettle();
        expect(_flashOpacity(tester), 0);
      },
    );

    testWidgets('dispose 가 대기 중인 flash 를 끝낸다 (타이머 남지 않음)', (tester) async {
      final controller = CameraViewfinderController();
      await _pump(tester, controller: controller);
      await tester.pump();
      var done = false;
      controller.flash().then((_) => done = true);
      await tester.pump(_frame);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(done, isTrue);
    });
  });
}
