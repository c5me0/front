// Shared source-to-destination zoom geometry. Preserve the source rectangle and
// destination aspect ratio throughout interactive reversal.

import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/widgets.dart';

import '../design_system/design_system.dart';
import 'cameo_page_route.dart';
import 'spring_route.dart';
import 'zoom_source.dart';

///

///  - [scale]         s  = lerp(s0, 1)
///  - [offset]        (x, y) = lerp((x0, y0), 0)

@immutable
class ZoomGeometry {
  const ZoomGeometry({
    required this.scale,
    required this.offset,
    required this.width,
    required this.visibleHeight,
    required this.radius,
  });

  final double scale;

  final Offset offset;

  final double width;

  final double visibleHeight;

  final double radius;

  Rect get clip => Rect.fromLTWH(0, 0, width, visibleHeight);

  double get contentRadius => scale > 0 ? radius / scale : 0;

  Rect get screenRect =>
      Rect.fromLTWH(offset.dx, offset.dy, width * scale, visibleHeight * scale);

  Matrix4 get transform => Matrix4.identity()
    ..translateByDouble(offset.dx, offset.dy, 0, 1)
    ..scaleByDouble(scale, scale, 1, 1);

  @override
  String toString() =>
      'ZoomGeometry(scale: $scale, offset: $offset, hv: $visibleHeight, r: $radius)';
}

ZoomGeometry zoomGeometry({
  required double progress,
  required Rect source,
  required Size screen,
  double flightRadius = CameoMotion.transitionZoomFlightRadius,
}) {
  final w = screen.width;
  final h = screen.height;
  final s0 = w > 0 ? source.width / w : 1.0;
  final hv0 = s0 > 0 ? source.height / s0 : h;
  final p = progress;
  return ZoomGeometry(
    scale: lerpDouble(s0, 1, p)!,
    offset: Offset(
      lerpDouble(source.left, 0, p)!,
      lerpDouble(source.top, 0, p)!,
    ),
    width: w,
    visibleHeight: lerpDouble(hv0, h, p)!,
    radius: math.max(0, lerpDouble(flightRadius, 0, p)!),
  );
}

class CameoZoomPageRoute<T> extends PageRoute<T> with CameoSpringRoute<T> {
  CameoZoomPageRoute({
    required this.builder,
    required this.target,
    required this.source,
    super.settings,
    this.maintainState = true,
  });

  final WidgetBuilder builder;

  final ZoomTarget target;

  final Rect source;

  Rect get currentSource => ZoomSource.rectOf(target) ?? source;

  @override
  final bool maintainState;

  @override
  SpringDescription get transitionSpring => CameoMotion.transitionZoomSpring;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool canTransitionTo(TransitionRoute<dynamic> nextRoute) =>
      nextRoute is CameoPageRoute;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return builder(context);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return EdgeSwipeBackDetector(
        route: this,
        completeProgress: CameoMotion.transitionZoomCompleteProgress,
        completeVelocity: CameoMotion.transitionZoomCompleteVelocity,
        child: ReducedMotionTransition(
          primary: animation,
          secondary: secondaryAnimation,
          child: child,
        ),
      );
    }
    return EdgeSwipeBackDetector(
      route: this,
      completeProgress: CameoMotion.transitionZoomCompleteProgress,
      completeVelocity: CameoMotion.transitionZoomCompleteVelocity,
      child: CameoPushTransition(
        primary: kAlwaysCompleteAnimation,
        secondary: secondaryAnimation,
        child: CameoZoomTransition(
          progress: animation,
          source: () => currentSource,
          child: child,
        ),
      ),
    );
  }
}

class CameoZoomTransition extends StatelessWidget {
  const CameoZoomTransition({
    super.key,
    required this.progress,
    required this.source,
    required this.child,
  });

  final Animation<double> progress;

  final Rect Function() source;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screen = constraints.biggest;
        return AnimatedBuilder(
          animation: progress,
          child: SizedBox.fromSize(size: screen, child: child),
          builder: (context, child) {
            final p = progress.value;
            final g = zoomGeometry(
              progress: p,
              source: source(),
              screen: screen,
            );
            final dim = CameoMotion.transitionZoomDim;

            final settled = p >= 1 && g.radius == 0;
            return Stack(
              fit: StackFit.expand,
              children: [
                if (p > 0 && !settled)
                  IgnorePointer(
                    key: const ValueKey('zoomRoute.dim'),
                    child: ColoredBox(
                      color: dim.withValues(alpha: dim.a * p.clamp(0.0, 1.0)),
                    ),
                  ),
                Transform(
                  key: const ValueKey('zoomRoute.transform'),
                  transform: g.transform,
                  child: ClipRRect(
                    key: const ValueKey('zoomRoute.clip'),
                    clipper: _ZoomClipper(g.clip, g.contentRadius),
                    clipBehavior: settled ? Clip.none : Clip.antiAlias,
                    child: child,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _ZoomClipper extends CustomClipper<RRect> {
  const _ZoomClipper(this.rect, this.radius);

  final Rect rect;

  final double radius;

  @override
  RRect getClip(Size size) =>
      RRect.fromRectAndRadius(rect, Radius.circular(radius));

  @override
  bool shouldReclip(_ZoomClipper oldClipper) =>
      oldClipper.rect != rect || oldClipper.radius != radius;
}
