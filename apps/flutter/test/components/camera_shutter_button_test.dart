import 'package:cameo/components/camera_glass_button.dart';
import 'package:cameo/components/shutter_button.dart';
import 'package:cameo/design_system/design_system.dart';
import 'package:cameo/navigation/navigation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const Duration _frame = Duration(milliseconds: 16);

Future<void> _pump(
  WidgetTester tester, {
  VoidCallback? onPress,
  int feedbackKey = 0,
  bool disableAnimations = false,
}) {
  return tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: ShutterButton(
            onPress: onPress,
            feedbackKey: feedbackKey,
            accessibilityLabel: '사진 촬영',
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

double _scale(WidgetTester tester) => tester
    .widget<ScaleTransition>(find.byKey(ShutterButton.outerKey))
    .scale
    .value;

double _disc(WidgetTester tester) => tester
    .widget<FadeTransition>(
      find.ancestor(
        of: find.byKey(ShutterButton.discKey),
        matching: find.byType(FadeTransition),
      ),
    )
    .opacity
    .value;

void main() {
  group('ShutterButton — Figma 2058:3438', () {
    testWidgets(
      '74 원 (글래스 camera/shutter · 테두리 1 camera/shutter-stroke) + 안쪽 원 60 @ inset 7',
      (tester) async {
        await _pump(tester, onPress: () {});
        expect(
          tester.getSize(find.byKey(ShutterButton.outerKey)),
          const Size(74, 74),
        );
        final disc = tester.getRect(find.byKey(ShutterButton.discKey));
        expect(disc, const Rect.fromLTWH(7, 7, 60, 60));
        final surface = tester.widget<GlassSurface>(find.byType(GlassSurface));
        expect(surface.tint, CameoColors.cameraShutter);
        expect(surface.border, CameoColors.cameraShutterStroke);
        expect(surface.borderWidth, 1);
        expect(surface.blur, CameoBlur.glassNav);
        final fill = tester.widget<DecoratedBox>(
          find.descendant(
            of: find.byKey(ShutterButton.discKey),
            matching: find.byType(DecoratedBox),
          ),
        );
        expect(
          (fill.decoration as BoxDecoration).color,
          CameoColors.cameraShutterDisc,
        );
      },
    );

    testWidgets('누름 → shutterPressScale (press) · 놓음 → 1 (chewy) · onPress', (
      tester,
    ) async {
      var presses = 0;
      await _pump(tester, onPress: () => presses++);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(ShutterButton)),
      );
      await _run(tester, springSettleDuration(CameoSprings.press));
      expect(
        _scale(tester),
        moreOrLessEquals(CameoMotion.cameraShutterPressScale, epsilon: 1e-3),
      );
      await gesture.up();
      await tester.pump();
      expect(presses, 1);
      await _run(tester, springSettleDuration(CameoSprings.chewy));
      await tester.pumpAndSettle();
      expect(_scale(tester), 1);
    });

    testWidgets('탭 직후의 feedbackKey 변화 → 안쪽 원 깜빡임만 (스케일 킥 없음)', (tester) async {
      var key = 0;
      await _pump(tester, onPress: () => key++);
      await tester.tap(find.byType(ShutterButton));
      expect(key, 1);
      await _pump(tester, onPress: () => key++, feedbackKey: key);
      var minDisc = 1.0;
      var minScale = 1.0;
      for (
        var t = Duration.zero;
        t < CameoMotion.cameraFlashIn + CameoMotion.cameraFlashOut;
        t += _frame
      ) {
        await tester.pump(_frame);
        if (_disc(tester) < minDisc) minDisc = _disc(tester);
        if (_scale(tester) < minScale) minScale = _scale(tester);
      }
      expect(minDisc, lessThan(1));
      expect(minScale, greaterThan(0.99));
      await tester.pumpAndSettle();
      expect(_scale(tester), 1);
      expect(_disc(tester), 1);
    });

    testWidgets('외부(데모) feedbackKey 변화 → 안쪽 원 discFlashOpacity 까지 깜빡 + 스케일 킥', (
      tester,
    ) async {
      await _pump(tester, onPress: () {});
      await _pump(tester, onPress: () {}, feedbackKey: 1);
      var minDisc = 1.0;
      var minScale = 1.0;
      for (
        var t = Duration.zero;
        t < CameoMotion.cameraFlashIn + CameoMotion.cameraFlashOut;
        t += _frame
      ) {
        await tester.pump(_frame);
        if (_disc(tester) < minDisc) minDisc = _disc(tester);
        if (_scale(tester) < minScale) minScale = _scale(tester);
      }
      expect(
        minDisc,
        moreOrLessEquals(CameoMotion.cameraDiscFlashOpacity, epsilon: 0.02),
      );
      expect(
        minScale,
        moreOrLessEquals(CameoMotion.cameraShutterPressScale, epsilon: 0.01),
      );
      await tester.pumpAndSettle();
      expect(_disc(tester), 1);
      expect(_scale(tester), 1);
    });

    testWidgets('모션 감소 → 외부 발사에 스케일 킥 없음 (깜빡임은 페이드라 유지)', (tester) async {
      await _pump(tester, onPress: () {}, disableAnimations: true);
      await _pump(
        tester,
        onPress: () {},
        feedbackKey: 1,
        disableAnimations: true,
      );
      await _run(tester, CameoMotion.cameraFlashIn);
      expect(_scale(tester), 1);
      expect(_disc(tester), lessThan(1));
      await tester.pumpAndSettle();
    });

    testWidgets('접근성: 버튼 · 한국어 라벨', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, onPress: () {});
      expect(
        tester.getSemantics(find.byType(ShutterButton)),
        matchesSemantics(label: '사진 촬영', isButton: true, hasTapAction: true),
      );
      handle.dispose();
    });
  });

  group('CameraGlassButton — Figma 2056:3347 / 2056:3404', () {
    testWidgets(
      '56 = 1 + 16 + 22 + 16 + 1 · glass/tint · stroke/neutral/base · 아이콘 inverse/base',
      (tester) async {
        await tester.pumpWidget(
          const Directionality(
            textDirection: TextDirection.ltr,
            child: Align(
              alignment: Alignment.topLeft,
              child: CameraGlassButton(
                icon: CameoIconName.refresh,
                accessibilityLabel: '전면 카메라로 전환',
              ),
            ),
          ),
        );
        expect(
          tester.getSize(find.byType(CameraGlassButton)),
          const Size(56, 56),
        );
        final surface = tester.widget<GlassSurface>(find.byType(GlassSurface));
        expect(surface.tint, CameoColors.glassTint);
        expect(surface.border, CameoColors.strokeNeutralBase);
        expect(surface.borderWidth, 1);
        expect(surface.blur, CameoBlur.glassNav);
        final icon = tester.widget<CameoIcon>(find.byType(CameoIcon));
        expect(icon.name, CameoIconName.refresh);
        expect(icon.size, 22);
        expect(icon.color, CameoColors.foregroundNeutralInverseBase);
        expect(
          tester.getRect(find.byType(CameoIcon)),
          const Rect.fromLTWH(17, 17, 22, 22),
        );
      },
    );
  });
}
