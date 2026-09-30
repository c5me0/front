// Shared spring route lifecycle and interactive gesture completion. Progress, velocity,
// and transition activity must agree before a route is considered settled.

import 'package:flutter/widgets.dart';

import '../design_system/design_system.dart';
import 'route_activity.dart';
import 'spring_timing.dart';

///

mixin CameoSpringRoute<T> on PageRoute<T> {
  SpringDescription get transitionSpring;

  double? _releaseVelocity;

  bool get reduceMotion {
    final media = navigator?.context
        .getInheritedWidgetOfExactType<MediaQuery>();
    return media?.data.disableAnimations ??
        WidgetsBinding
            .instance
            .platformDispatcher
            .accessibilityFeatures
            .disableAnimations;
  }

  @override
  Duration get transitionDuration => reduceMotion
      ? CameoMotion.durationBase
      : springSettleDuration(transitionSpring);

  @override
  Duration get reverseTransitionDuration => transitionDuration;

  @override
  void install() {
    super.install();
    CameoRouteActivity.attach(this);
  }

  @override
  void dispose() {
    CameoRouteActivity.detach(this);
    super.dispose();
  }

  Simulation _simulationTo(double target, double velocity) {
    final from = controller!.value;
    if (reduceMotion) {
      return EasedTimingSimulation(
        from: from,
        to: target,
        duration: CameoMotion.durationBase,
        curve: CameoMotion.easingStandard,
      );
    }
    return cameoSpringSimulation(
      transitionSpring,
      from: from,
      to: target,
      velocity: velocity,
    );
  }

  ///

  @override
  Simulation? createSimulation({required bool forward}) {
    final velocity = _releaseVelocity ?? 0.0;
    _releaseVelocity = null;
    final simulation = _simulationTo(forward ? 1.0 : 0.0, velocity);
    if (!forward) return simulation;
    final held = FirstFrameHeldSimulation(simulation);

    WidgetsBinding.instance.addPostFrameCallback((_) => held.release());
    return held;
  }

  bool get transitionGestureEnabled {
    if (isFirst || willHandlePopInternally) return false;
    if (popDisposition == RoutePopDisposition.doNotPop) return false;
    if (!animation!.isCompleted) return false;
    if (!(secondaryAnimation?.isDismissed ?? true)) return false;
    if (navigator?.userGestureInProgress ?? true) return false;
    return true;
  }

  double get transitionProgress => controller!.value;

  void startTransitionGesture() {
    navigator!.didStartUserGesture();
    controller!.stop();
  }

  void updateTransitionGesture(double progress) {
    controller!.value = progress.clamp(0.0, 1.0);
  }

  void endTransitionGesture({required bool dismiss, required double velocity}) {
    final nav = navigator!;
    final c = controller!;
    if (dismiss) {
      _releaseVelocity = velocity;
      if (isCurrent) {
        nav.pop();
      } else {
        nav.removeRoute(this);
      }
    } else if (!c.isCompleted) {
      c.animateWith(_simulationTo(1, velocity));
    }
    if (c.isAnimating) {
      late final AnimationStatusListener onStatus;
      onStatus = (status) {
        if (status == AnimationStatus.completed ||
            status == AnimationStatus.dismissed) {
          nav.didStopUserGesture();
          c.removeStatusListener(onStatus);
        }
      };
      c.addStatusListener(onStatus);
    } else {
      nav.didStopUserGesture();
    }
  }
}

bool shouldCompleteDismiss({
  required double drag,
  required double velocity,
  required double extent,
  required double completeProgress,
  required double completeVelocity,
}) {
  if (extent <= 0) return false;
  return (drag / extent) / completeProgress + velocity / completeVelocity > 1;
}

///

class FirstFrameHeldSimulation extends Simulation {
  FirstFrameHeldSimulation(this.inner) : super(tolerance: inner.tolerance);

  final Simulation inner;

  bool _released = false;
  double? _origin;

  void release() => _released = true;

  bool get isReleased => _released;

  @override
  double x(double time) {
    if (!_released) return inner.x(0);
    final origin = _origin ??= time;
    return inner.x(time - origin);
  }

  @override
  double dx(double time) {
    final origin = _origin;
    return origin == null ? 0 : inner.dx(time - origin);
  }

  @override
  bool isDone(double time) {
    final origin = _origin;
    return origin != null && inner.isDone(time - origin);
  }
}

class EasedTimingSimulation extends Simulation {
  EasedTimingSimulation({
    required this.from,
    required this.to,
    required Duration duration,
    required this.curve,
  }) : _seconds = duration.inMicroseconds / Duration.microsecondsPerSecond;

  final double from;
  final double to;
  final Curve curve;
  final double _seconds;

  double _t(double time) =>
      _seconds <= 0 ? 1 : (time / _seconds).clamp(0.0, 1.0);

  @override
  double x(double time) => from + (to - from) * curve.transform(_t(time));

  @override
  double dx(double time) {
    if (_seconds <= 0 || time >= _seconds) return 0;
    const h = 1e-4;
    return (x(time + h) - x(time)) / h;
  }

  @override
  bool isDone(double time) => time >= _seconds;
}

class TransitionDim extends StatelessWidget {
  const TransitionDim({
    super.key,
    required this.amount,
    required this.color,
    required this.child,
  });

  final double amount;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: [
        child,
        if (amount > 0)
          Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(
                color: color.withValues(alpha: color.a * amount),
              ),
            ),
          ),
      ],
    );
  }
}

class ReducedMotionTransition extends StatelessWidget {
  const ReducedMotionTransition({
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
    return FadeTransition(
      opacity: primary,
      child: AnimatedBuilder(
        animation: secondary,
        child: child,
        builder: (context, child) => TransitionDim(
          amount: secondary.value,
          color: CameoMotion.transitionPushDim,
          child: child!,
        ),
      ),
    );
  }
}
