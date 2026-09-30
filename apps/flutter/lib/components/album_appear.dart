// Staggered album content entrance. Animate opacity and vertical offset for text and
// photos; do not fade a Liquid Glass surface.

import 'package:flutter/widgets.dart';

class AlbumAppear extends StatelessWidget {
  const AlbumAppear({
    super.key,
    required this.progress,
    required this.rise,
    required this.child,
  });

  final Animation<double>? progress;

  final double rise;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = progress;
    if (p == null) return child;
    return AnimatedBuilder(
      animation: p,
      child: child,
      builder: (context, child) {
        final v = p.value;
        return Opacity(
          opacity: v.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - v) * rise),
            child: child,
          ),
        );
      },
    );
  }
}
