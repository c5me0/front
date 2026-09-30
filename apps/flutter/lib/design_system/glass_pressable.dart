// Glass press deformation and pointer lifecycle. Cancel tracking before disposing
// controllers; drag, cancellation, and disabled state never activate a tap.

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'motion.dart';
import 'press_feedback.dart';
import 'tokens.g.dart';

const double _tapSlop = 10;

class GlassPressable extends StatefulWidget {
  const GlassPressable({
    super.key,
    this.onPress,
    this.accessibilityLabel,
    this.pressedColor,
    this.pressedRadius = 0,
    required this.child,
  });

  final VoidCallback? onPress;

  final String? accessibilityLabel;
  final Color? pressedColor;
  final double pressedRadius;
  final Widget child;

  @override
  State<GlassPressable> createState() => _GlassPressableState();
}

class _GlassPressableState extends State<GlassPressable>
    with TickerProviderStateMixin {
  late final AnimationController _press;
  late final AnimationController _tx;
  late final AnimationController _ty;
  late final AnimationController _sx;
  late final AnimationController _sy;
  late final Listenable _all;

  Offset _origin = Offset.zero;
  Offset _translation = Offset.zero;
  VelocityTracker? _tracker;

  int? _pointer;

  bool _reduceMotion = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _press = _unbounded(1);
    _tx = _unbounded(0);
    _ty = _unbounded(0);
    _sx = _unbounded(1);
    _sy = _unbounded(1);
    _all = Listenable.merge([_press, _tx, _ty, _sx, _sy]);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  }

  AnimationController _unbounded(double value) =>
      AnimationController.unbounded(vsync: this, value: value);

  void _down(PointerDownEvent e) {
    if (_disposed || _pointer != null) return;
    _pointer = e.pointer;
    _origin = e.position;
    _translation = Offset.zero;
    _tracker = VelocityTracker.withKind(e.kind)
      ..addPosition(e.timeStamp, e.position);
    if (_reduceMotion) {
      _press.value = CameoMotion.glassPressScale;
    } else {
      _press.springTo(CameoMotion.glassPressScale, CameoSprings.press);
    }
    HapticFeedback.lightImpact();
  }

  void _move(PointerMoveEvent e) {
    if (e.pointer != _pointer) return;
    _tracker?.addPosition(e.timeStamp, e.position);
    _translation = e.position - _origin;
    final size = context.size ?? Size.zero;
    final s = glassStretch(
      _translation.dx,
      _translation.dy,
      size.width,
      size.height,
    );
    _tx.stop();
    _ty.stop();
    _sx.stop();
    _sy.stop();
    _tx.value = s.tx;
    _ty.value = s.ty;
    _sx.value = s.sx;
    _sy.value = s.sy;
  }

  void _up(PointerUpEvent e) {
    if (e.pointer != _pointer) return;
    final box = context.findRenderObject() as RenderBox?;
    final inside =
        box != null &&
        box.hasSize &&
        (Offset.zero & box.size).contains(box.globalToLocal(e.position));
    final activate = _translation.distance < _tapSlop && inside;
    _release();
    if (activate) widget.onPress?.call();
  }

  void _cancel(PointerCancelEvent e) {
    if (e.pointer != _pointer) return;
    _release();
  }

  void _release() {
    if (_disposed) return;
    _pointer = null;
    final v = _tracker?.getVelocity().pixelsPerSecond ?? Offset.zero;
    _tracker = null;
    if (_reduceMotion) {
      _press.value = 1;
      _tx.value = 0;
      _ty.value = 0;
      _sx.value = 1;
      _sy.value = 1;
      return;
    }
    final k =
        CameoMotion.glassStretch /
        (1 + _translation.distance * CameoMotion.glassResistance);
    _press.springTo(1, CameoSprings.chewy);
    _tx.springTo(0, CameoSprings.chewy, velocity: v.dx * k);
    _ty.springTo(0, CameoSprings.chewy, velocity: v.dy * k);
    _sx.springTo(1, CameoSprings.chewy);
    _sy.springTo(1, CameoSprings.chewy);
  }

  @override
  void dispose() {
    _disposed = true;
    _pointer = null;
    _tracker = null;
    for (final c in [_press, _tx, _ty, _sx, _sy]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: widget.onPress != null,
      label: widget.accessibilityLabel,
      onTap: widget.onPress,
      child: _gesture(),
    );
  }

  Widget _gesture() {
    return RawGestureDetector(
      excludeFromSemantics: true,
      gestures: <Type, GestureRecognizerFactory>{
        EagerGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<EagerGestureRecognizer>(
              EagerGestureRecognizer.new,
              (_) {},
            ),
      },
      child: _listener(),
    );
  }

  Widget _listener() {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _down,
      onPointerMove: _move,
      onPointerUp: _up,
      onPointerCancel: _cancel,
      child: AnimatedBuilder(
        animation: _all,
        builder: (context, child) {
          final m = Matrix4.identity()
            ..translateByDouble(_tx.value, _ty.value, 0, 1)
            ..scaleByDouble(
              _press.value * _sx.value,
              _press.value * _sy.value,
              1,
              1,
            );
          return Transform(
            alignment: Alignment.center,
            transform: m,
            child: switch (widget.pressedColor) {
              final color? => PressFeedback(
                progress:
                    (_press.value - 1) / (CameoMotion.glassPressScale - 1),
                color: color,
                radius: widget.pressedRadius,
                child: child!,
              ),
              null => child,
            },
          );
        },
        child: widget.child,
      ),
    );
  }
}
