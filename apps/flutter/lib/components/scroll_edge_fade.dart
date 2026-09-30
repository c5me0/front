// Noninteractive scroll-edge gradient. Position relative to the viewport rather than
// the scrolling content.

import 'package:flutter/widgets.dart';

import '../design_system/design_system.dart';

double scrollEdgeFadeHeight(double safeTop) =>
    safeTop +
    CameoLayout.homeScreenHeaderHeight +
    CameoLayout.homeScreenScrollEdgeExtra;

class ScrollEdgeFade extends StatelessWidget {
  const ScrollEdgeFade({super.key, required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ExcludeSemantics(
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: CameoTheme.colorsOf(context).gradients.scrollEdgeTop,
            ),
          ),
        ),
      ),
    );
  }
}
