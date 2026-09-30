// Tab-container entry and logout transitions. Keep the outgoing screen mounted until
// the session transition completes.

import 'dart:ui' show lerpDouble;

import 'package:flutter/widgets.dart';

import '../design_system/design_system.dart';
import 'cameo_page_route.dart';
import 'cameo_viewer_route.dart';
import 'spring_route.dart';

///

class CameoShellRoute<T> extends PageRoute<T> with CameoSpringRoute<T> {
  CameoShellRoute({
    required this.builder,
    super.settings,
    this.maintainState = true,
  });

  final WidgetBuilder builder;

  @override
  final bool maintainState;

  Route<dynamic>? _next;

  @override
  SpringDescription get transitionSpring =>
      CameoMotion.transitionEnterAppSpring;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool canTransitionTo(TransitionRoute<dynamic> nextRoute) =>
      nextRoute is CameoPageRoute || nextRoute is CameoViewerRoute;

  bool get coveredByViewer => _next is CameoViewerRoute;

  @override
  void didChangeNext(Route<dynamic>? nextRoute) {
    if (nextRoute != null) _next = nextRoute;
    super.didChangeNext(nextRoute);
  }

  @override
  void didPopNext(Route<dynamic> nextRoute) {
    _next = nextRoute;
    super.didPopNext(nextRoute);
  }

  bool get _exitingToFade {
    final next = _next;
    return next is CameoPageRoute && next.entry == CameoPageEntry.fade;
  }

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
      return ReducedMotionTransition(
        primary: animation,
        secondary: secondaryAnimation,
        child: child,
      );
    }
    return CameoEnterAppTransition(
      primary: animation,
      secondary: secondaryAnimation,
      exitScale: () => _exitingToFade,
      stayStill: () => coveredByViewer,
      child: child,
    );
  }
}

class CameoEnterAppTransition extends StatelessWidget {
  const CameoEnterAppTransition({
    super.key,
    required this.primary,
    required this.secondary,
    required this.exitScale,
    this.stayStill,
    required this.child,
  });

  final Animation<double> primary;
  final Animation<double> secondary;

  final bool Function() exitScale;

  final bool Function()? stayStill;

  final Widget child;

  static double scaleAt({required double primary, required double secondary}) =>
      lerpDouble(CameoMotion.transitionEnterAppScaleFrom, 1, primary)! *
      lerpDouble(1, CameoMotion.transitionEnterAppExitScaleTo, secondary)!;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([primary, secondary]),
      child: child,
      builder: (context, child) {
        final p = primary.value;
        final s = (stayStill?.call() ?? false) ? 0.0 : secondary.value;
        final exiting = exitScale();
        return Opacity(
          key: const ValueKey('enterApp.opacity'),
          opacity: p.clamp(0.0, 1.0),
          child: Transform.scale(
            key: const ValueKey('enterApp.scale'),
            scale: scaleAt(primary: p, secondary: exiting ? s : 0),
            child: FractionalTranslation(
              translation: Offset(
                exiting ? 0 : -s * CameoMotion.transitionPushParallax,
                0,
              ),
              child: TransitionDim(
                amount: exiting ? 0 : s,
                color: CameoMotion.transitionPushDim,
                child: child!,
              ),
            ),
          ),
        );
      },
    );
  }
}
