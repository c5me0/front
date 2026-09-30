// Hide floating destination chrome during source-card zooms using translation and
// scale. Reveal it only after the zoom settles; never fade glass.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../design_system/design_system.dart';
import 'cameo_zoom_route.dart';

enum ZoomChromePhase { static, entering, shown, hidden }

///

class ZoomChrome extends StatefulWidget {
  const ZoomChrome({super.key, required this.child});

  final Widget child;

  static Animation<double>? maybeScaleOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ZoomChromeScope>()?.scale;

  @override
  State<ZoomChrome> createState() => ZoomChromeState();
}

class ZoomChromeState extends State<ZoomChrome>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scale = AnimationController.unbounded(
    vsync: this,
    value: 1,
  );
  ZoomChromePhase _phase = ZoomChromePhase.static;
  ModalRoute<Object?>? _route;
  ValueListenable<bool>? _gesture;

  bool _swiping = false;
  bool _reduceMotion = false;

  double get scale => _scale.value;

  ZoomChromePhase get phase => _phase;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final route = ModalRoute.of(context);
    if (identical(route, _route)) return;
    _detach();
    _route = route;
    if (route is! CameoZoomPageRoute) {
      _phase = ZoomChromePhase.static;
      _scale.value = 1;
      return;
    }
    route.animation?.addStatusListener(_onStatus);
    final gesture = route.navigator?.userGestureInProgressNotifier;
    gesture?.addListener(_onGesture);
    _gesture = gesture;
    if (route.animation?.isCompleted ?? true) {
      _phase = ZoomChromePhase.shown;
      _scale.value = 1;
    } else {
      _phase = ZoomChromePhase.entering;
      _scale.value = CameoMotion.transitionZoomChromeScaleFrom;
    }
  }

  void _detach() {
    _route?.animation?.removeStatusListener(_onStatus);
    _gesture?.removeListener(_onGesture);
    _gesture = null;
  }

  @override
  void dispose() {
    _detach();
    _scale.dispose();
    super.dispose();
  }

  void _onStatus(AnimationStatus status) {
    if (!mounted) return;
    switch (status) {
      case AnimationStatus.completed:
        if (!_swiping) _show();
      case AnimationStatus.reverse:
        _swiping = false;
        _hide();
      case AnimationStatus.forward:
      case AnimationStatus.dismissed:
        break;
    }
  }

  void _onGesture() {
    final route = _route;
    final gesture = _gesture;
    if (!mounted || route == null || gesture == null) return;
    if (gesture.value) {
      if (route.isCurrent && !_swiping && _phase == ZoomChromePhase.shown) {
        _swiping = true;
        _hide();
      }
    } else if (_swiping) {
      _swiping = false;
      if (route.animation?.status != AnimationStatus.reverse) _show();
    }
  }

  void _onPointerEnd(PointerEvent _) {
    if (!_swiping) return;
    scheduleMicrotask(() {
      final route = _route;
      if (!mounted || !_swiping || route == null) return;
      if (route.animation?.status == AnimationStatus.reverse) return;
      _swiping = false;
      _show();
    });
  }

  void _show() {
    if (_phase == ZoomChromePhase.shown) return;
    _phase = ZoomChromePhase.shown;
    _animate(1, CameoMotion.transitionZoomChromeSpring);
  }

  void _hide() {
    if (_phase == ZoomChromePhase.hidden || _phase == ZoomChromePhase.static) {
      return;
    }
    _phase = ZoomChromePhase.hidden;
    _animate(
      CameoMotion.transitionZoomChromeScaleFrom,
      CameoMotion.transitionZoomChromeExitSpring,
    );
  }

  void _animate(double target, SpringDescription spring) {
    if (_reduceMotion) {
      _scale.value = target;
      return;
    }
    final v = _scale.velocity;
    final x = _scale.value;
    final away = (target > x && v < 0) || (target < x && v > 0);
    _scale.springTo(target, spring, velocity: away ? 0 : v);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerUp: _onPointerEnd,
      onPointerCancel: _onPointerEnd,
      child: _ZoomChromeScope(scale: _scale, child: widget.child),
    );
  }
}

class _ZoomChromeScope extends InheritedWidget {
  const _ZoomChromeScope({required this.scale, required super.child});

  final Animation<double> scale;

  @override
  bool updateShouldNotify(_ZoomChromeScope oldWidget) =>
      scale != oldWidget.scale;
}

class ZoomChromeScale extends StatelessWidget {
  const ZoomChromeScale({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scale = ZoomChrome.maybeScaleOf(context);
    if (scale == null) return child;
    return ScaleTransition(scale: scale, child: child);
  }
}
