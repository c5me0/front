// Pressed color overlay that preserves its child subtree. Do not fade or remount the
// underlying glass surface.

import 'package:flutter/widgets.dart';

class PressFeedback extends StatelessWidget {
  const PressFeedback({
    super.key,
    required this.progress,
    required this.color,
    required this.radius,
    required this.child,
  });

  final double progress;
  final Color color;
  final double radius;
  final Widget child;

  static const Key overlayKey = ValueKey('pressFeedback.overlay');

  @override
  Widget build(BuildContext context) => DecoratedBox(
    key: overlayKey,
    position: DecorationPosition.foreground,
    decoration: BoxDecoration(
      color: color.withValues(alpha: color.a * progress.clamp(0.0, 1.0)),
      borderRadius: BorderRadius.circular(radius),
    ),
    child: child,
  );
}
