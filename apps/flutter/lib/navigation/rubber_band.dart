// Bounded overscroll resistance using the shared rubber-band coefficient and viewport
// dimension.

import '../design_system/design_system.dart';

//   f(x) = (1 − 1 / (|x|·c / d + 1)) · d · sign(x)

double rubberBand(
  double offset,
  double dimension, {
  double coefficient = CameoMotion.rubberBandCoefficient,
}) {
  if (dimension <= 0 || offset == 0) return 0;
  final x = offset.abs();
  final f = (1 - 1 / (x * coefficient / dimension + 1)) * dimension;
  return offset < 0 ? -f : f;
}

double rubberBandSlope(
  double offset,
  double dimension, {
  double coefficient = CameoMotion.rubberBandCoefficient,
}) {
  if (dimension <= 0) return 0;
  final u = offset.abs() * coefficient / dimension + 1;
  return coefficient / (u * u);
}
