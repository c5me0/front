// Estimate transition settlement using the same physical spring and rest thresholds as
// the rendered route.

import 'package:flutter/animation.dart';
import 'package:flutter/physics.dart';

import '../design_system/design_system.dart';

//

SpringSimulation cameoSpringSimulation(
  SpringDescription spring, {
  required double from,
  required double to,
  double velocity = 0,
}) {
  return SpringSimulation(
    spring,
    from,
    to,
    velocity,
    snapToEnd: true,
    tolerance: cameoSpringTolerance,
  );
}

const double _stepSeconds = 1 / 1000;

const double _maxSeconds = 10;

final Map<(double, double, double, double, double, double), double>
_settleCache = {};

double springSettleSeconds(
  SpringDescription spring, {
  double from = 0,
  double to = 1,
  double velocity = 0,
}) {
  final key = (
    spring.mass,
    spring.stiffness,
    spring.damping,
    from,
    to,
    velocity,
  );
  return _settleCache.putIfAbsent(key, () {
    final sim = cameoSpringSimulation(
      spring,
      from: from,
      to: to,
      velocity: velocity,
    );
    var t = 0.0;
    var i = 0;
    while (!sim.isDone(t) && t < _maxSeconds) {
      i++;
      t = i * _stepSeconds;
    }
    return t;
  });
}

Duration springSettleDuration(
  SpringDescription spring, {
  double from = 0,
  double to = 1,
  double velocity = 0,
}) {
  final s = springSettleSeconds(spring, from: from, to: to, velocity: velocity);
  return Duration(microseconds: (s * Duration.microsecondsPerSecond).round());
}

///

class SpringCurve extends Curve {
  SpringCurve(this.spring)
    : _seconds = springSettleSeconds(spring),
      _sim = cameoSpringSimulation(spring, from: 0, to: 1);

  final SpringDescription spring;
  final double _seconds;
  final SpringSimulation _sim;

  Duration get duration => Duration(
    microseconds: (_seconds * Duration.microsecondsPerSecond).round(),
  );

  @override
  double transformInternal(double t) => _sim.x(t * _seconds);
}
