// Immediate press scaling for opaque controls. Release on drag or cancellation, ignore
// disabled controls, and use immediate transforms under reduced motion.

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import 'motion.dart';
import 'press_feedback.dart';
import 'tokens.g.dart';

class PressScale extends StatefulWidget {
  const PressScale({
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
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scale;

  bool _reduceMotion = false;
  int? _pointer;
  Offset _origin = Offset.zero;
  bool _cancelled = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _scale = AnimationController.unbounded(vsync: this, value: 1);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  }

  void _down() => _reduceMotion
      ? _scale.value = CameoMotion.pressScale
      : _scale.springTo(CameoMotion.pressScale, CameoSprings.press);

  void _release() {
    if (_disposed) return;
    _reduceMotion ? _scale.value = 1 : _scale.springTo(1, CameoSprings.chewy);
  }

  void _pointerDown(PointerDownEvent event) {
    if (_disposed || _pointer != null || widget.onPress == null) return;
    _pointer = event.pointer;
    _origin = event.position;
    _cancelled = false;
    _down();
  }

  void _pointerMove(PointerMoveEvent event) {
    if (event.pointer != _pointer || _cancelled) return;
    if ((event.position - _origin).distance > kTouchSlop) {
      _cancelled = true;
      _release();
    }
  }

  void _pointerEnd(PointerEvent event) {
    if (event.pointer != _pointer) return;
    _pointer = null;
    _release();
  }

  void _cancel() {
    _cancelled = true;
    _release();
  }

  @override
  void didUpdateWidget(PressScale oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.onPress != null && widget.onPress == null) {
      _pointer = null;
      _cancelled = true;
      _scale.value = 1;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _pointer = null;
    _cancelled = true;
    _scale.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPress != null;
    return Semantics(
      button: enabled,
      label: widget.accessibilityLabel,
      onTap: widget.onPress,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _pointerDown,
        onPointerMove: _pointerMove,
        onPointerUp: _pointerEnd,
        onPointerCancel: (event) {
          if (event.pointer != _pointer) return;
          _cancelled = true;
          _pointerEnd(event);
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTapCancel: enabled ? _cancel : null,
          onTap: enabled
              ? () {
                  if (!_cancelled) widget.onPress?.call();
                }
              : null,
          child: AnimatedBuilder(
            animation: _scale,
            child: widget.child,
            builder: (context, child) => ScaleTransition(
              scale: _scale,
              child: switch (widget.pressedColor) {
                final color? => PressFeedback(
                  progress: (1 - _scale.value) / (1 - CameoMotion.pressScale),
                  color: color,
                  radius: widget.pressedRadius,
                  child: child!,
                ),
                null => child,
              },
            ),
          ),
        ),
      ),
    );
  }
}
