// Draggable media card with bounded detents and spring dismissal. Dismiss using
// distance or velocity and preserve the release velocity.

import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';
import '../content/app.g.dart';

import '../design_system/design_system.dart';
import '../navigation/rubber_band.dart';

const double _dismissProgress = CameoMotion.mediaCardDismissProgress;
const double _dismissVelocity = CameoMotion.mediaCardDismissVelocity;
const SpringDescription _exitSpring = CameoMotion.mediaCardExitSpring;

const double mediaCardDefaultBottomOffset =
    CameoLayout.callControlBarContainerHeight +
    CameoLayout.mediaCardOffsetAboveControlBar;

const List<String> _detentLabels = ['16:9', '4:3', '1:1'];

final List<double> _extents = [
  for (final a in CameoLayout.mediaCardAspectDetents) 1 / a,
];
int get _last => _extents.length - 1;
double get _min => _extents.first;
double get _max => _extents.last;

int _clampDetent(int detent) => detent.clamp(0, _last);

List<double> mediaCardDetentHeights(double containerWidth) {
  final w = math.max(
    0.0,
    containerWidth - CameoLayout.mediaCardContainerPadding * 2,
  );
  return [for (final a in CameoLayout.mediaCardAspectDetents) w / a];
}

double _rubberBandInverse(double shown, double dimension) {
  final f = shown.abs();
  if (dimension <= 0 || f == 0 || f >= dimension) return shown;
  final x = f / (CameoMotion.rubberBandCoefficient * (1 - f / dimension));
  return shown < 0 ? -x : x;
}

double _band(double raw) {
  if (raw > _max) return _max + rubberBand(raw - _max, _max);
  if (raw < _min) return math.max(0.0, _min - rubberBand(_min - raw, _max));
  return raw;
}

double _unband(double shown) {
  if (shown > _max) return _max + _rubberBandInverse(shown - _max, _max);
  if (shown < _min) return _min - _rubberBandInverse(_min - shown, _max);
  return shown;
}

double _bandSlope(double raw) {
  if (raw > _max) return rubberBandSlope(raw - _max, _max);
  if (raw < _min) return rubberBandSlope(_min - raw, _max);
  return 1;
}

int _snapDetent(double shown, double growVelocity) {
  if (growVelocity >= CameoMotion.mediaCardDetentVelocity) {
    for (var i = 0; i <= _last; i += 1) {
      if (_extents[i] > shown) return i;
    }
    return _last;
  }
  if (growVelocity <= -CameoMotion.mediaCardDetentVelocity) {
    for (var i = _last; i >= 0; i -= 1) {
      if (_extents[i] < shown) return i;
    }
    return 0;
  }
  var best = 0;
  for (var i = 1; i <= _last; i += 1) {
    if ((_extents[i] - shown).abs() < (_extents[best] - shown).abs()) best = i;
  }
  return best;
}

DecorationImage? _decorationImage(ImageProvider? image) =>
    image == null ? null : DecorationImage(image: image, fit: BoxFit.cover);

bool _shouldDismiss(double overRatio, double downVelocity) =>
    overRatio > 0 &&
    overRatio / _dismissProgress + downVelocity / _dismissVelocity > 1;

class MediaCard extends StatefulWidget {
  const MediaCard({
    super.key,
    required this.visible,
    this.detent = 0,
    this.onDetentChange,
    this.onDismiss,
    this.bottomOffset = mediaCardDefaultBottomOffset,
    this.image,
  });

  final bool visible;

  final int detent;

  final ValueChanged<int>? onDetentChange;

  final VoidCallback? onDismiss;

  final double bottomOffset;

  final ImageProvider? image;

  static const Key cardKey = ValueKey<String>('mediaCard.card');

  @override
  State<MediaCard> createState() => _MediaCardState();
}

class _MediaCardState extends State<MediaCard> with TickerProviderStateMixin {
  late final AnimationController _extent = AnimationController.unbounded(
    vsync: this,
    value: widget.visible ? _extents[_clampDetent(widget.detent)] : 0,
  );

  late final AnimationController _opacity = AnimationController(
    vsync: this,
    value: 1,
    animationBehavior: AnimationBehavior.preserve,
  );
  late final Listenable _animation = Listenable.merge([_extent, _opacity]);

  late bool _gone;

  late int _target;

  bool _reduce = false;

  double _cardWidth = 0;

  double _raw = 0;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();

    _gone = !widget.visible;
    _target = _clampDetent(widget.detent);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  }

  @override
  void didUpdateWidget(MediaCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final index = _clampDetent(widget.detent);

    if (widget.visible != oldWidget.visible) {
      if (widget.visible) {
        _gone = false;
        _target = index;
        _enter(_extents[index]);
      } else if (!_gone) {
        _gone = true;
        _exit(0);
      }
      return;
    }
    if (widget.visible && !_gone && index != _target) {
      _target = index;
      _snapTo(_extents[index], 0);
    }
  }

  @override
  void dispose() {
    _extent.dispose();
    _opacity.dispose();
    super.dispose();
  }

  Tolerance get _tolerance => _cardWidth > 0
      ? Tolerance(
          distance: CameoMotion.restThresholdDisplacement / _cardWidth,
          velocity: CameoMotion.restThresholdVelocity / _cardWidth,
        )
      : cameoSpringTolerance;

  void _spring(double to, SpringDescription spring, double velocity) {
    _extent.animateWith(
      SpringSimulation(
        spring,
        _extent.value,
        to,
        velocity,
        tolerance: _tolerance,
        snapToEnd: true,
      ),
    );
  }

  void _snapTo(double to, double velocity) {
    if (_reduce) {
      _extent.value = to;
      return;
    }
    _spring(to, CameoMotion.mediaCardDetentSpring, velocity);
  }

  void _enter(double to) {
    if (_reduce) {
      if (_extent.value <= 0) _opacity.value = 0;
      _extent.value = to;
      _opacity.animateTo(
        1,
        duration: CameoMotion.durationBase,
        curve: CameoMotion.easingStandard,
      );
      return;
    }
    _opacity.value = 1;
    _spring(to, CameoMotion.mediaCardEnterSpring, 0);
  }

  void _exit(double velocity) {
    if (_reduce) {
      _opacity
          .animateTo(
            0,
            duration: CameoMotion.durationBase,
            curve: CameoMotion.easingStandard,
          )
          .then((_) {
            if (mounted && _gone) _extent.value = 0;
          });
      return;
    }
    _extent.animateWith(
      _ClampedSpringSimulation(
        _exitSpring,
        from: _extent.value,
        to: 0,
        velocity: math.min(0.0, velocity),
        tolerance: _tolerance,
      ),
    );
  }

  void _settle(int next) {
    _target = next;
    if (next != _clampDetent(widget.detent)) widget.onDetentChange?.call(next);
  }

  void _dismiss(double velocity) {
    _gone = true;
    _exit(velocity);
    widget.onDismiss?.call();
  }

  void _dragStart(DragStartDetails details) {
    if (_gone) return;
    _dragging = true;
    _extent.stop();
    _raw = _unband(_extent.value);
  }

  void _dragUpdate(DragUpdateDetails details) {
    if (!_dragging || _gone || _cardWidth <= 0) return;
    _raw -= details.primaryDelta! / _cardWidth;
    _extent.value = _band(_raw);
  }

  void _dragEnd(DragEndDetails details) =>
      _release(details.primaryVelocity ?? 0);

  void _dragCancel() => _release(0);

  void _release(double velocityY) {
    if (!_dragging) return;
    _dragging = false;
    if (_gone) return;
    final grow = -velocityY;
    final growExtent = _cardWidth > 0 ? grow / _cardWidth : 0.0;
    if (widget.onDismiss != null &&
        _shouldDismiss((_min - _raw) / _min, -grow)) {
      _dismiss(growExtent * _bandSlope(_raw));
      return;
    }
    final next = _snapDetent(_extent.value, grow);
    _snapTo(_extents[next], growExtent * _bandSlope(_raw));
    _settle(next);
  }

  void _step(int delta) {
    if (_gone) return;
    final next = _clampDetent(_clampDetent(widget.detent) + delta);
    _snapTo(_extents[next], 0);
    _settle(next);
  }

  @override
  Widget build(BuildContext context) {
    final index = _clampDetent(widget.detent);
    final dismissible = widget.onDismiss != null;
    return LayoutBuilder(
      builder: (context, constraints) {
        _cardWidth = math.max(
          0.0,
          constraints.maxWidth - CameoLayout.mediaCardContainerPadding * 2,
        );
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: widget.bottomOffset,
              child: Padding(
                padding: const EdgeInsets.all(
                  CameoLayout.mediaCardContainerPadding,
                ),
                child: IgnorePointer(
                  ignoring: !widget.visible,
                  child: ExcludeSemantics(
                    excluding: !widget.visible,
                    child: Semantics(
                      container: true,
                      label: AppContent.of(context).v6.accessibility.mediaCard,
                      hint: dismissible
                          ? AppContent.of(
                              context,
                            ).v6.accessibility.resizeDismissMedia
                          : AppContent.of(context).v6.accessibility.resizeMedia,
                      value: _detentLabels[index],
                      increasedValue: index < _last
                          ? _detentLabels[index + 1]
                          : null,
                      decreasedValue: index > 0
                          ? _detentLabels[index - 1]
                          : null,
                      onIncrease: index < _last ? () => _step(1) : null,
                      onDecrease: index > 0 ? () => _step(-1) : null,
                      onDismiss: dismissible
                          ? () {
                              if (!_gone) _dismiss(0);
                            }
                          : null,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,

                        excludeFromSemantics: true,
                        onVerticalDragStart: _dragStart,
                        onVerticalDragUpdate: _dragUpdate,
                        onVerticalDragEnd: _dragEnd,
                        onVerticalDragCancel: _dragCancel,
                        child: AnimatedBuilder(
                          animation: _animation,
                          builder: (context, child) => Opacity(
                            opacity: _opacity.value.clamp(0.0, 1.0),
                            child: SizedBox(
                              key: MediaCard.cardKey,
                              height: math.max(0.0, _extent.value) * _cardWidth,
                              child: child,
                            ),
                          ),

                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: CameoTheme.colorsOf(context).mediaCard,
                              borderRadius: const BorderRadius.all(
                                Radius.circular(
                                  CameoLayout.mediaCardCardRadius,
                                ),
                              ),
                              image: _decorationImage(widget.image),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ClampedSpringSimulation extends Simulation {
  _ClampedSpringSimulation(
    SpringDescription spring, {
    required double from,
    required double to,
    required double velocity,
    required super.tolerance,
  }) : _from = from,
       _to = to,
       _spring = SpringSimulation(
         spring,
         from,
         to,
         velocity,
         tolerance: tolerance,
         snapToEnd: true,
       );

  final double _from;
  final double _to;
  final SpringSimulation _spring;

  bool _past(double x) => _from >= _to ? x <= _to : x >= _to;

  @override
  double x(double time) {
    final v = _spring.x(time);
    return _past(v) ? _to : v;
  }

  @override
  double dx(double time) => _past(_spring.x(time)) ? 0 : _spring.dx(time);

  @override
  bool isDone(double time) => _past(_spring.x(time)) || _spring.isDone(time);
}
