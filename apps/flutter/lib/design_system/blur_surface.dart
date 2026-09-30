// Frosted background surface with clipped blur, palette tint, and token-defined shape.
// Keep the clipping bounds aligned with the visible surface.

import 'package:flutter/widgets.dart';

import 'glass_surface.dart';
import 'tokens.g.dart';

class BlurSurface extends StatelessWidget {
  const BlurSurface({
    super.key,
    this.blur,
    this.tint,
    this.border,
    this.borderWidth,
    this.radius = CameoRadius.full,
    this.padding = EdgeInsets.zero,
    required this.child,
  });

  final CameoBlur? blur;
  final Color? tint;
  final Color? border;
  final double? borderWidth;
  final double radius;
  final EdgeInsetsGeometry padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      effect: GlassEffect.blur,
      blur: blur,
      tint: tint,
      border: border,
      borderWidth: borderWidth,
      radius: radius,
      padding: padding,
      child: child,
    );
  }
}
