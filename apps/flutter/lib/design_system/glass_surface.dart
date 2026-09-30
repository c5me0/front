// Liquid Glass surfaces with palette tint, borders, and token effects. Use frosted blur
// when the effect's material is blur.

import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

import 'glass_backdrop.dart';
import 'tokens.g.dart';

enum GlassEffect { glass, blur }

///

class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    this.effect = GlassEffect.glass,
    this.blur,
    this.tint,
    this.border,
    this.borderWidth,
    this.radius = CameoRadius.full,
    this.padding = EdgeInsets.zero,
    required this.child,
  });

  final GlassEffect effect;

  final CameoBlur? blur;

  final Color? tint;

  final Color? border;

  final double? borderWidth;

  final double radius;
  final EdgeInsetsGeometry padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bw =
        borderWidth ?? (border != null ? CameoBorderWidth.hairline : 0.0);
    final content = Padding(
      padding: padding.add(EdgeInsets.all(bw)),
      child: child,
    );
    final shape = RoundedSuperellipseBorder(
      borderRadius: BorderRadius.circular(radius),
      side: border == null || bw == 0
          ? BorderSide.none
          : BorderSide(color: border!, width: bw),
    );
    final token =
        blur ??
        (effect == GlassEffect.glass
            ? CameoBlur.glassBar
            : CameoBlur.backgroundBlur);
    final sigma = token.sigma;
    final liquid =
        effect == GlassEffect.glass &&
        token.material == CameoBlurMaterial.glass;

    return switch (liquid) {
      true => LiquidGlass.withOwnLayer(
        settings: LiquidGlassSettings(
          blur: sigma * CameoEffects.liquidGlassRendererBlurSigmaScale,

          glassColor: const Color(0x00000000),

          thickness:
              CameoEffects.liquidGlassRendererThickness *
              MediaQuery.devicePixelRatioOf(context),
          refractiveIndex: CameoEffects.liquidGlassRendererRefractiveIndex,
          chromaticAberration:
              CameoEffects.liquidGlassRendererChromaticAberration,
          lightIntensity: switch (GlassBackdrop.of(context)) {
            GlassBackdropTone.dark =>
              CameoEffects.liquidGlassRendererLightIntensityDarkBackdrop,
            GlassBackdropTone.light =>
              CameoEffects.liquidGlassRendererLightIntensityLightBackdrop,
            GlassBackdropTone.defaultTone =>
              CameoEffects.liquidGlassRendererLightIntensity,
          },
          lightAngle:
              CameoEffects.liquidGlassRendererLightAngleDeg * math.pi / 180,
          ambientStrength: CameoEffects.liquidGlassRendererAmbientStrength,
          saturation: CameoEffects.liquidGlassRendererSaturation,
        ),
        shape: LiquidRoundedSuperellipse(borderRadius: radius),
        child: DecoratedBox(
          decoration: ShapeDecoration(color: tint, shape: shape),
          child: content,
        ),
      ),
      false => ClipRSuperellipse(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: DecoratedBox(
            decoration: ShapeDecoration(color: tint, shape: shape),
            child: content,
          ),
        ),
      ),
    };
  }
}
