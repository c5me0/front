// Shared physical spring helpers and rest thresholds. Carry velocity through
// interrupted transitions where required.

import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/physics.dart';

import 'tokens.g.dart';

const Tolerance cameoSpringTolerance = Tolerance(
  distance: CameoMotion.restThresholdDisplacement,
  velocity: CameoMotion.restThresholdVelocity,
);

extension CameoSpringController on AnimationController {
  TickerFuture springTo(
    double target,
    SpringDescription spring, {
    double velocity = 0,
  }) {
    return animateWith(
      SpringSimulation(
        spring,
        value,
        target,
        velocity,
        tolerance: cameoSpringTolerance,

        snapToEnd: true,
      ),
    );
  }
}

typedef GlassStretch = ({double tx, double ty, double sx, double sy});

GlassStretch glassStretch(double dx, double dy, double width, double height) {
  const resistance = CameoMotion.glassResistance;
  const stretch = CameoMotion.glassStretch;
  const stretchMax = CameoMotion.glassStretchMax;
  final mag = math.sqrt(dx * dx + dy * dy);
  final k = mag == 0 ? 0.0 : (1 / (1 + mag * resistance)) * stretch;
  final tx = dx * k;
  final ty = dy * k;
  final ax = width > 0 ? tx.abs() / width : 0.0;
  final ay = height > 0 ? ty.abs() / height : 0.0;
  final raw = math.sqrt((1 + ax) / (1 + ay));
  final sx = raw.clamp(1 / stretchMax, stretchMax).toDouble();
  return (tx: tx, ty: ty, sx: sx, sy: 1 / sx);
}

typedef TabIndicatorStretch = ({double sx, double sy});

TabIndicatorStretch tabIndicatorStretch(double velocity) {
  final sx = math.min(
    CameoMotion.tabIndicatorStretchMax,
    1 + velocity.abs() * CameoMotion.tabIndicatorStretchPerVelocity,
  );
  return (sx: sx, sy: 1 / sx);
}
