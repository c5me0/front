// Spring-driven vertical modal route with interactive drag dismissal.

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../design_system/design_system.dart';
import 'cameo_page_route.dart';
import 'rubber_band.dart';
import 'spring_route.dart';
import 'spring_timing.dart';

class CameoModalRoute<T> extends PageRoute<T> with CameoSpringRoute<T> {
  CameoModalRoute({
    required this.builder,
    super.settings,
    this.maintainState = true,
  }) : super(fullscreenDialog: true);

  final WidgetBuilder builder;

  @override
  final bool maintainState;

  @override
  SpringDescription get transitionSpring => CameoMotion.transitionModalSpring;

  @override
  Color? get barrierColor => CameoMotion.transitionModalDim;

  @override
  Curve get barrierCurve => Curves.linear;

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
    final page = DragToDismissDetector(route: this, child: child);
    if (MediaQuery.disableAnimationsOf(context)) {
      return ReducedMotionTransition(
        primary: animation,
        secondary: secondaryAnimation,
        child: page,
      );
    }
    return CameoModalTransition(
      primary: animation,
      secondary: secondaryAnimation,
      child: page,
    );
  }
}

class CameoModalTransition extends StatelessWidget {
  const CameoModalTransition({
    super.key,
    required this.primary,
    required this.secondary,
    required this.child,
  });

  final Animation<double> primary;
  final Animation<double> secondary;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([primary, secondary]),
      child: child,
      builder: (context, child) {
        final p = primary.value;
        final s = secondary.value;
        return FractionalTranslation(
          translation: Offset(-s * CameoMotion.transitionPushParallax, 1 - p),
          child: TransitionDim(
            amount: s,
            color: CameoMotion.transitionPushDim,
            child: child!,
          ),
        );
      },
    );
  }
}

class DragToDismissDetector extends StatefulWidget {
  const DragToDismissDetector({
    super.key,
    required this.route,
    required this.child,
  });

  final CameoSpringRoute<dynamic> route;
  final Widget child;

  @override
  State<DragToDismissDetector> createState() => _DragToDismissDetectorState();
}

class _DragToDismissDetectorState extends State<DragToDismissDetector>
    with SingleTickerProviderStateMixin {
  late final AnimationController _overscroll = AnimationController.unbounded(
    vsync: this,
    value: 0,
  );

  bool _active = false;

  double _drag = 0;

  double get _height => context.size?.height ?? 0;

  void _start(DragStartDetails details) {
    if (!widget.route.transitionGestureEnabled) return;
    _active = true;
    _drag = 0;
    _overscroll.stop();
    widget.route.startTransitionGesture();
  }

  void _update(DragUpdateDetails details) {
    if (!_active) return;
    final h = _height;
    if (h <= 0) return;
    _drag += details.primaryDelta!;
    if (_drag >= 0) {
      _overscroll.value = 0;
      widget.route.updateTransitionGesture(1 - _drag / h);
    } else {
      widget.route.updateTransitionGesture(1);

      final reduceMotion =
          MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      _overscroll.value = reduceMotion ? 0 : rubberBand(_drag, h);
    }
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
      completeProgress: CameoMotion.transitionModalDismissProgress,
      completeVelocity: CameoMotion.transitionModalDismissVelocity,
    );
    _releaseOverscroll(vy);
    widget.route.endTransitionGesture(
      dismiss: dismiss,
      velocity: h > 0 ? -vy / h : 0,
    );
  }

  void _cancel() {
    if (!_active) return;
    _active = false;
    _releaseOverscroll(0);
    widget.route.endTransitionGesture(dismiss: false, velocity: 0);
  }

  void _releaseOverscroll(double fingerVelocity) {
    if (_overscroll.value == 0) return;
    final h = _height;
    final slope = _drag < 0 && h > 0 ? rubberBandSlope(_drag, h) : 0.0;
    _overscroll.animateWith(
      cameoSpringSimulation(
        widget.route.transitionSpring,
        from: _overscroll.value,
        to: 0,
        velocity: fingerVelocity * slope,
      ),
    );
  }

  @override
  void dispose() {
    _overscroll.dispose();
    if (_active) {
      final nav = widget.route.navigator;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (nav != null && nav.mounted && nav.userGestureInProgress) {
          nav.didStopUserGesture();
        }
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: _start,
      onVerticalDragUpdate: _update,
      onVerticalDragEnd: _end,
      onVerticalDragCancel: _cancel,
      child: AnimatedBuilder(
        animation: _overscroll,
        child: widget.child,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, _overscroll.value),
          child: child,
        ),
      ),
    );
  }
}
