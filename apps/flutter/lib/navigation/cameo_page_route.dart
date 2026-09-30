// Horizontal page transition and interactive edge-swipe back gesture. Respect route
// activity, first-route state, and PopScope before starting a gesture.

import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../design_system/design_system.dart';
import 'spring_route.dart';

const double kCameoEdgeSwipeWidth = CameoMotion.gestureEdgeWidth;

class CameoPageRoute<T> extends PageRoute<T> with CameoSpringRoute<T> {
  CameoPageRoute({
    required this.builder,
    super.settings,
    this.maintainState = true,
    this.entry = CameoPageEntry.slide,
  });

  final WidgetBuilder builder;

  @override
  final bool maintainState;

  final CameoPageEntry entry;

  @override
  SpringDescription get transitionSpring => entry == CameoPageEntry.fade
      ? CameoMotion.transitionEnterAppSpring
      : CameoMotion.transitionPushSpring;

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
    final page = EdgeSwipeBackDetector(route: this, child: child);
    if (MediaQuery.disableAnimationsOf(context)) {
      return ReducedMotionTransition(
        primary: animation,
        secondary: secondaryAnimation,
        child: page,
      );
    }
    return CameoPushTransition(
      primary: animation,
      secondary: secondaryAnimation,
      fade: entry == CameoPageEntry.fade,
      child: page,
    );
  }
}

enum CameoPageEntry { slide, fade }

class CameoPushTransition extends StatelessWidget {
  const CameoPushTransition({
    super.key,
    required this.primary,
    required this.secondary,
    this.fade = false,
    required this.child,
  });

  final Animation<double> primary;
  final Animation<double> secondary;
  final bool fade;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([primary, secondary]),
      child: child,
      builder: (context, child) {
        final p = primary.value;
        final s = secondary.value;
        return Opacity(
          opacity: fade ? p.clamp(0.0, 1.0) : 1,
          child: FractionalTranslation(
            translation: Offset(
              (fade ? 0 : 1 - p) - s * CameoMotion.transitionPushParallax,
              0,
            ),
            child: TransitionDim(
              amount: s,
              color: CameoMotion.transitionPushDim,
              child: child!,
            ),
          ),
        );
      },
    );
  }
}

class EdgeSwipeBackDetector extends StatefulWidget {
  const EdgeSwipeBackDetector({
    super.key,
    required this.route,
    this.completeProgress = CameoMotion.transitionPushCompleteProgress,
    this.completeVelocity = CameoMotion.transitionPushCompleteVelocity,
    required this.child,
  });

  final CameoSpringRoute<dynamic> route;

  final double completeProgress;

  final double completeVelocity;

  final Widget child;

  @override
  State<EdgeSwipeBackDetector> createState() => _EdgeSwipeBackDetectorState();
}

class _EdgeSwipeBackDetectorState extends State<EdgeSwipeBackDetector> {
  late final HorizontalDragGestureRecognizer _recognizer =
      HorizontalDragGestureRecognizer(debugOwner: this)
        ..onStart = _start
        ..onUpdate = _update
        ..onEnd = _end
        ..onCancel = _cancel;

  bool _active = false;

  double get _width => context.size?.width ?? 0;

  void _pointerDown(PointerDownEvent event) {
    if (widget.route.transitionGestureEnabled) _recognizer.addPointer(event);
  }

  void _start(DragStartDetails details) {
    if (!widget.route.transitionGestureEnabled) return;
    _active = true;
    widget.route.startTransitionGesture();
  }

  void _update(DragUpdateDetails details) {
    if (!_active || _width <= 0) return;
    widget.route.updateTransitionGesture(
      widget.route.transitionProgress - details.primaryDelta! / _width,
    );
  }

  void _end(DragEndDetails details) {
    if (!_active) return;
    _active = false;
    final width = _width;
    final vx = details.velocity.pixelsPerSecond.dx;
    final pop = shouldCompleteDismiss(
      drag: (1 - widget.route.transitionProgress) * width,
      velocity: vx,
      extent: width,
      completeProgress: widget.completeProgress,
      completeVelocity: widget.completeVelocity,
    );
    widget.route.endTransitionGesture(
      dismiss: pop,
      velocity: width > 0 ? -vx / width : 0,
    );
  }

  void _cancel() {
    if (!_active) return;
    _active = false;
    widget.route.endTransitionGesture(dismiss: false, velocity: 0);
  }

  @override
  void dispose() {
    _recognizer.dispose();
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
    final edge = math.max(
      kCameoEdgeSwipeWidth,
      MediaQuery.paddingOf(context).left,
    );
    return Stack(
      fit: StackFit.passthrough,
      children: [
        widget.child,
        PositionedDirectional(
          start: 0,
          width: edge,
          top: 0,
          bottom: 0,
          child: Listener(
            onPointerDown: _pointerDown,
            behavior: HitTestBehavior.translucent,
          ),
        ),
      ],
    );
  }
}
