// Transparent photo-viewer route that zooms from a measured source cell. Keep source
// visibility synchronized until the closing transition completes.

//

import 'dart:ui' show lerpDouble;

import 'package:flutter/widgets.dart';

import '../design_system/design_system.dart';
import 'spring_route.dart';

abstract final class ViewerSource {
  static final Map<String, Rect> _rects = {};

  static void set(String key, Rect rect) => _rects[key] = rect;

  static Rect? rectOf(String key) => _rects[key];

  static void clear([String? key]) {
    if (key == null) {
      _rects.clear();
    } else {
      _rects.remove(key);
    }
  }
}

@immutable
class ViewerZoomFlight {
  const ViewerZoomFlight({
    required this.s,
    required this.tx,
    required this.ty,
    required this.hv,
    required this.top,
    required this.d,
    required this.radius,
  });

  final double s;
  final double tx;
  final double ty;
  final double hv;
  final double top;
  final double d;
  final double radius;

  Rect screenRect(Rect card) =>
      Rect.fromLTWH(card.left + tx, card.top + ty, card.width * s, hv * s);

  Matrix4 get transform => Matrix4.identity()
    ..translateByDouble(tx, ty, 0, 1)
    ..scaleByDouble(s, s, 1, 1)
    ..translateByDouble(0, -top, 0, 1);

  Rect clipFor(double width) => Rect.fromLTWH(0, top, width, hv);

  @override
  String toString() =>
      'ViewerZoomFlight(s: $s, t: ($tx, $ty), hv: $hv, top: $top, r: $radius)';
}

ViewerZoomFlight viewerZoomFlight({
  required double progress,
  required Rect target,
  required Rect source,
  double sourceRadius = 0,
  double toRadius = CameoLayout.viewerV6CardRadius,
}) {
  final w = target.width;
  final h = target.height;
  final p = progress;
  final s0 = w > 0 ? source.width / w : 1.0;
  final hv0 = s0 > 0 ? (source.height / s0).clamp(0.0, h) : h;
  final hv = lerpDouble(hv0, h, p)!;
  return ViewerZoomFlight(
    s: lerpDouble(s0, 1, p)!,
    tx: lerpDouble(source.left - target.left, 0, p)!,
    ty: lerpDouble(source.top - target.top, 0, p)!,
    hv: hv,
    top: lerpDouble((h - hv0) / 2, 0, p)!,
    d: h - hv,
    radius: lerpDouble(s0 > 0 ? sourceRadius / s0 : 0, toRadius, p)!,
  );
}

class CameoViewerRoute<T> extends PageRoute<T> with CameoSpringRoute<T> {
  CameoViewerRoute({
    required this.builder,
    super.settings,
    this.source,
    this.sourceKey,
    this.sourceRadius = 0,
  });

  final WidgetBuilder builder;

  final Rect? source;

  final double sourceRadius;

  String? sourceKey;

  final ValueNotifier<double> dimScale = ValueNotifier(1);

  @override
  void dispose() {
    dimScale.dispose();
    super.dispose();
  }

  Rect? get currentSource {
    final key = sourceKey;
    return (key == null ? null : ViewerSource.rectOf(key)) ?? source;
  }

  static CameoViewerRoute<Object?>? maybeOf(BuildContext context) {
    final route = ModalRoute.of(context);
    return route is CameoViewerRoute<Object?> ? route : null;
  }

  @override
  bool get opaque => false;

  @override
  bool get maintainState => true;

  @override
  SpringDescription get transitionSpring => CameoMotion.viewerZoomSpring;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool canTransitionTo(TransitionRoute<dynamic> nextRoute) => false;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => builder(context);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final dim = CameoTheme.colorsOf(context).staticBlackBase;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(
          key: const ValueKey('viewerRoute.dim'),
          child: AnimatedBuilder(
            animation: Listenable.merge([animation, dimScale]),
            builder: (context, _) {
              final k =
                  animation.value.clamp(0.0, 1.0) *
                  dimScale.value.clamp(0.0, 1.0);
              final fill = ColoredBox(
                key: const ValueKey('viewerRoute.dimFill'),
                color: dim.withValues(alpha: dim.a * k),
              );

              return fill;
            },
          ),
        ),
        ViewerZoomScope(
          progress: animation,
          source: () => currentSource,
          sourceRadius: sourceRadius,
          reduceMotion: reduceMotion,
          child: _ViewerDragDetector(route: this, child: child),
        ),
      ],
    );
  }
}

class ViewerZoomScope extends InheritedWidget {
  const ViewerZoomScope({
    super.key,
    required this.progress,
    required this.source,
    this.sourceRadius = 0,
    required this.reduceMotion,
    required super.child,
  });

  final Animation<double> progress;

  final Rect? Function() source;
  final double sourceRadius;
  final bool reduceMotion;

  static ViewerZoomScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ViewerZoomScope>();

  @override
  bool updateShouldNotify(ViewerZoomScope oldWidget) =>
      progress != oldWidget.progress ||
      sourceRadius != oldWidget.sourceRadius ||
      reduceMotion != oldWidget.reduceMotion;
}

Animation<double> _clamped(Animation<double> progress) =>
    progress.drive(Animatable.fromCallback((v) => v.clamp(0.0, 1.0)));

/// RN `<ViewerZoomCard source target>`.
class ViewerZoomCard extends StatelessWidget {
  const ViewerZoomCard({
    super.key,
    required this.card,
    this.radius = CameoLayout.viewerV6CardRadius,
    required this.child,
  });

  final Rect card;
  final double radius;
  final Widget child;

  static const Key transformKey = ValueKey('viewerZoomCard.transform');
  static const Key clipKey = ValueKey('viewerZoomCard.clip');

  @override
  Widget build(BuildContext context) {
    final scope = ViewerZoomScope.maybeOf(context);
    if (scope == null) return _still(null);
    return AnimatedBuilder(
      animation: scope.progress,
      builder: (context, _) {
        final source = scope.source();

        if (source == null || scope.reduceMotion) {
          return _still(scope.progress);
        }
        final f = viewerZoomFlight(
          progress: scope.progress.value,
          target: card,
          source: source,
          sourceRadius: scope.sourceRadius,
          toRadius: radius,
        );
        return Positioned.fromRect(
          rect: card,
          child: Transform(
            key: transformKey,
            transform: f.transform,
            child: ClipRRect(
              key: clipKey,
              clipper: _BandClipper(f.clipFor(card.width), f.radius),
              child: child,
            ),
          ),
        );
      },
    );
  }

  Widget _still(Animation<double>? fade) {
    final clipped = ClipRRect(
      key: clipKey,
      borderRadius: BorderRadius.circular(radius),
      child: child,
    );
    return Positioned.fromRect(
      rect: card,
      child: fade == null
          ? clipped
          : FadeTransition(opacity: _clamped(fade), child: clipped),
    );
  }
}

class _BandClipper extends CustomClipper<RRect> {
  const _BandClipper(this.rect, this.radius);

  final Rect rect;
  final double radius;

  @override
  RRect getClip(Size size) =>
      RRect.fromRectAndRadius(rect, Radius.circular(radius < 0 ? 0 : radius));

  @override
  bool shouldReclip(_BandClipper oldClipper) =>
      oldClipper.rect != rect || oldClipper.radius != radius;
}

enum ViewerChromeEdge { top, bottom }

class ViewerChromeSlide extends StatelessWidget {
  const ViewerChromeSlide({
    super.key,
    required this.edge,
    this.distance,
    required this.child,
  });

  final ViewerChromeEdge edge;

  final double? distance;
  final Widget child;

  static double distanceOf(ViewerChromeEdge edge) =>
      edge == ViewerChromeEdge.top
      ? -(CameoLayout.topNavV6Top + CameoLayout.topNavV6ButtonSize)
      : CameoLayout.viewerV6BottomHeight;

  @override
  Widget build(BuildContext context) {
    final scope = ViewerZoomScope.maybeOf(context);
    if (scope == null) return child;
    final distance = this.distance ?? distanceOf(edge);
    return AnimatedBuilder(
      animation: scope.progress,
      child: child,
      builder: (context, child) => Transform.translate(
        offset: Offset(
          0,
          (1 - scope.progress.value.clamp(0.0, 1.0)) * distance,
        ),
        child: child,
      ),
    );
  }
}

class _ViewerDragDetector extends StatefulWidget {
  const _ViewerDragDetector({required this.route, required this.child});

  final CameoViewerRoute<Object?> route;
  final Widget child;

  @override
  State<_ViewerDragDetector> createState() => _ViewerDragDetectorState();
}

class _ViewerDragDetectorState extends State<_ViewerDragDetector> {
  bool _active = false;

  double _drag = 0;

  double get _height => context.size?.height ?? 0;

  void _start(DragStartDetails details) {
    if (!widget.route.transitionGestureEnabled) return;
    _active = true;
    _drag = 0;
    widget.route.startTransitionGesture();
  }

  void _update(DragUpdateDetails details) {
    if (!_active) return;
    final h = _height;
    if (h <= 0) return;
    _drag = (_drag + details.primaryDelta!).clamp(0.0, h);
    widget.route.updateTransitionGesture(1 - _drag / h);
  }

  void _end(DragEndDetails details) {
    if (!_active) return;
    _active = false;
    final h = _height;
    final vy = details.primaryVelocity ?? 0;
    final dismiss = shouldCompleteDismiss(
      drag: _drag,
      velocity: vy,
      extent: h,
      completeProgress: CameoMotion.viewerDismissProgress,
      completeVelocity: CameoMotion.viewerDismissVelocity,
    );
    widget.route.endTransitionGesture(
      dismiss: dismiss,
      velocity: h > 0 ? -vy / h : 0,
    );
  }

  void _cancel() {
    if (!_active) return;
    _active = false;
    widget.route.endTransitionGesture(dismiss: false, velocity: 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: _start,
      onVerticalDragUpdate: _update,
      onVerticalDragEnd: _end,
      onVerticalDragCancel: _cancel,
      child: widget.child,
    );
  }
}
