// Paint shadows outside translucent shapes only. A shadow behind transparent glass
// would be refracted and make the surface appear too dark.

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

class OutsideShadow extends StatelessWidget {
  const OutsideShadow({
    super.key,
    required this.shadow,
    required this.radius,
    required this.child,
  });

  final BoxShadow shadow;

  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _OutsideShadowPainter(shadow, radius), child: child);
}

class _OutsideShadowPainter extends CustomPainter {
  _OutsideShadowPainter(this.shadow, this.radius);

  final BoxShadow shadow;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final r = math.min(radius, size.shortestSide / 2);
    final shape = RRect.fromRectAndRadius(rect, Radius.circular(r));

    final reach =
        shadow.blurRadius * 2 +
        shadow.offset.distance +
        shadow.spreadRadius.abs();
    canvas
      ..save()
      ..clipPath(
        Path()
          ..fillType = PathFillType.evenOdd
          ..addRect(rect.inflate(reach))
          ..addRRect(shape),
      )
      ..drawRRect(
        shape.shift(shadow.offset).inflate(shadow.spreadRadius),
        shadow.toPaint(),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_OutsideShadowPainter old) =>
      old.shadow != shadow || old.radius != radius;
}
