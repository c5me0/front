// Photo viewer thumbnail strip. Keep the current photo centered without an extra
// selection marker and preserve the image order.

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../content/app.g.dart';
import '../design_system/design_system.dart';
import '../screens/home_timeline/album_timeline_model.dart' show stripOffsetX;

class ThumbStrip extends StatelessWidget {
  const ThumbStrip({
    super.key,
    required this.images,
    required this.position,
    this.onTap,
  });

  final List<ImageProvider> images;

  final Animation<double> position;
  final ValueChanged<int>? onTap;

  static const Key rowKey = ValueKey('thumbStrip.row');
  static Key cellKey(int index) => ValueKey('thumbStrip.cell.$index');

  @override
  Widget build(BuildContext context) {
    const cell = CameoLayout.viewerV6StripCellSize;
    const step = cell + CameoLayout.viewerV6StripGap;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return ClipRRect(
          key: rowKey,
          borderRadius: BorderRadius.circular(
            CameoLayout.viewerV6StripRowRadius,
          ),
          child: SizedBox(
            width: width,
            height: cell,
            child: AnimatedBuilder(
              animation: position,
              builder: (context, _) {
                final x0 = stripOffsetX(position.value, width);

                final first = math.max(0, ((-x0 - cell) / step).floor());
                final last = math.min(
                  images.length - 1,
                  ((width - x0) / step).ceil(),
                );
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (var k = first; k <= last; k++)
                      Positioned(
                        key: ValueKey('thumbStrip.slot.$k'),
                        left: x0 + k * step,
                        top: 0,
                        width: cell,
                        height: cell,
                        child: Semantics(
                          button: onTap != null,
                          label: fillTemplate(
                            AppContent.of(context).v6.viewer.thumbnailLabel,
                            {'index': k + 1},
                          ),
                          excludeSemantics: true,
                          child: PressScale(
                            key: cellKey(k),
                            onPress: onTap == null ? null : () => onTap!(k),
                            child: Image(
                              image: images[k],
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                              excludeFromSemantics: true,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}
