// Regression coverage for glass surface. Preserve behavior, layout, and interaction
// expectations.

import 'dart:ui' show ImageFilter;

import 'package:cameo/design_system/design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget surface, {
  double devicePixelRatio = 1,
  CameoColorMode mode = CameoColorMode.light,
  GlassBackdropTone? backdrop,
}) async {
  tester.view.physicalSize = Size(
    393 * devicePixelRatio,
    852 * devicePixelRatio,
  );
  tester.view.devicePixelRatio = devicePixelRatio;
  addTearDown(tester.view.reset);
  Widget child = Center(child: surface);
  if (backdrop != null) child = GlassBackdrop(tone: backdrop, child: child);
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: CameoTheme(mode: mode, child: child),
    ),
  );
}

GlassSurface _surface(GlassEffect effect, CameoBlur? blur) => GlassSurface(
  effect: effect,
  blur: blur,
  tint: CameoColors.glassTint,
  child: const SizedBox.square(dimension: CameoLayout.navBarCircleButtonSize),
);

void _expectFrosted(WidgetTester tester, double sigma) {
  expect(find.byType(LiquidGlass), findsNothing);
  final filter = tester.widget<BackdropFilter>(find.byType(BackdropFilter));
  expect(filter.filter, ImageFilter.blur(sigmaX: sigma, sigmaY: sigma));
}

LiquidGlassSettings _settings(WidgetTester tester) =>
    tester.widget<LiquidGlass>(find.byType(LiquidGlass)).ownLayerConfig!.$1;

void main() {
  group('GlassSurface 렌더러 = blur 토큰 material (G1)', () {
    for (final blur in [
      CameoBlur.glassNav,
      CameoBlur.glassBar,
      CameoBlur.glassTabBar,
      CameoBlur.glassFigma,
    ]) {
      testWidgets('effect glass + ${blur.name} → Liquid Glass', (tester) async {
        await _pump(tester, _surface(GlassEffect.glass, blur));
        expect(find.byType(LiquidGlass), findsOneWidget);
        expect(find.byType(BackdropFilter), findsNothing);
      });
    }

    testWidgets('effect glass 기본 blur(glassBar) → Liquid Glass', (
      tester,
    ) async {
      await _pump(tester, _surface(GlassEffect.glass, null));
      expect(find.byType(LiquidGlass), findsOneWidget);
    });

    for (final blur in [
      CameoBlur.backgroundBlur,
      CameoBlur.backgroundBlurStrong,
      CameoBlur.pauseButtonBlur,
    ]) {
      testWidgets('${blur.name} → Frosted σ${blur.sigma} (effect glass 여도)', (
        tester,
      ) async {
        await _pump(tester, _surface(GlassEffect.glass, blur));
        _expectFrosted(tester, blur.sigma);
      });
    }

    testWidgets('effect blur 는 glass 토큰이어도 항상 Frosted', (tester) async {
      await _pump(tester, _surface(GlassEffect.blur, CameoBlur.glassFigma));
      _expectFrosted(tester, CameoBlur.glassFigma.sigma);
    });

    testWidgets('Frosted 틴트 채움 = 역할 색 그대로 (source-over)', (tester) async {
      await _pump(tester, _surface(GlassEffect.blur, CameoBlur.backgroundBlur));
      final box = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(BackdropFilter),
          matching: find.byType(DecoratedBox),
        ),
      );
      expect((box.decoration as ShapeDecoration).color, CameoColors.glassTint);
    });
  });

  group('Liquid Glass 설정 = effect.liquidGlass.renderer', () {
    testWidgets(
      '셰이더 σ = 토큰 σ × blurSigmaScale · thickness = dp × devicePixelRatio · glassColor 투명 + 틴트 채움 레이어',
      (tester) async {
        await _pump(
          tester,
          _surface(GlassEffect.glass, CameoBlur.glassNav),
          devicePixelRatio: 3,
        );
        final s = _settings(tester);
        expect(
          s.blur,
          CameoBlur.glassNav.sigma *
              CameoEffects.liquidGlassRendererBlurSigmaScale,
        );
        expect(s.thickness, CameoEffects.liquidGlassRendererThickness * 3);
        expect(
          s.refractiveIndex,
          CameoEffects.liquidGlassRendererRefractiveIndex,
        );
        expect(s.saturation, CameoEffects.liquidGlassRendererSaturation);
        expect(s.glassColor.a, 0);
        final box = tester.widget<DecoratedBox>(
          find.descendant(
            of: find.byType(LiquidGlass),
            matching: find.byType(DecoratedBox),
          ),
        );
        expect(
          (box.decoration as ShapeDecoration).color,
          CameoColors.glassTint,
        );
      },
    );

    testWidgets('림 세기: 기본 배경 톤 = lightIntensity', (tester) async {
      await _pump(tester, _surface(GlassEffect.glass, CameoBlur.glassBar));
      expect(
        _settings(tester).lightIntensity,
        CameoEffects.liquidGlassRendererLightIntensity,
      );
    });

    testWidgets('림 세기: dark 색 모드 = 배경 톤 dark (16-13)', (tester) async {
      await _pump(
        tester,
        _surface(GlassEffect.glass, CameoBlur.glassBar),
        mode: CameoColorMode.dark,
      );
      expect(
        _settings(tester).lightIntensity,
        CameoEffects.liquidGlassRendererLightIntensityDarkBackdrop,
      );
    });

    testWidgets('림 세기: light 모드 + GlassBackdrop dark (16-14 카메라)', (
      tester,
    ) async {
      await _pump(
        tester,
        _surface(GlassEffect.glass, CameoBlur.glassNav),
        backdrop: GlassBackdropTone.fromToken(
          CameoEffects.liquidGlassBackdropCameraScreen,
        ),
      );
      expect(
        _settings(tester).lightIntensity,
        CameoEffects.liquidGlassRendererLightIntensityDarkBackdrop,
      );
    });
  });
}
