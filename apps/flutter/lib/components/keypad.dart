// In-app numeric keypad with press feedback and a controller for flow playback. The
// bottom row is empty, zero, delete; include the device's bottom inset.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../content/app.g.dart';
import '../design_system/design_system.dart';
import 'onboarding_v6_layout.dart';

export 'onboarding_v6_layout.dart' show keypadDeleteKey, keypadV6Rows;

double keypadHeight({double bottomInset = 0}) => keypadV6Height(bottomInset);

double keypadHeightOf(BuildContext context) =>
    keypadHeight(bottomInset: MediaQuery.paddingOf(context).bottom);

class KeypadController {
  _KeypadState? _state;

  bool get isAttached => _state != null;

  bool pressKey(String key) => _state?._pressProgrammatic(key) ?? false;
}

///

class Keypad extends StatefulWidget {
  const Keypad({
    super.key,
    this.onKey,
    this.onDelete,
    this.disabled = false,
    this.dimmed,
    this.controller,
    this.bottomInset,
  });

  final ValueChanged<String>? onKey;

  final VoidCallback? onDelete;

  final bool disabled;

  final bool? dimmed;
  final KeypadController? controller;

  final double? bottomInset;

  static Key keyKey(String key) => ValueKey('keypad.key.$key');

  static Key highlightKey(String key) => ValueKey('keypad.highlight.$key');

  static Key labelKey(String key) => ValueKey('keypad.label.$key');

  @override
  State<Keypad> createState() => _KeypadState();
}

class _KeypadState extends State<Keypad> with TickerProviderStateMixin {
  final Map<String, AnimationController> _press = {};
  final Map<String, Timer> _holds = {};
  bool _reduceMotion = false;

  static final Set<String> _known = {
    for (final row in keypadV6Rows)
      for (final key in row)
        if (key != null) key,
  };

  AnimationController _controllerFor(String key) => _press.putIfAbsent(
    key,
    () => AnimationController.unbounded(vsync: this, value: 0),
  );

  @override
  void initState() {
    super.initState();
    widget.controller?._state = this;

    for (final key in _known) {
      _controllerFor(key);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  }

  @override
  void didUpdateWidget(Keypad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      if (oldWidget.controller?._state == this) {
        oldWidget.controller!._state = null;
      }
      widget.controller?._state = this;
    }
  }

  @override
  void dispose() {
    if (widget.controller?._state == this) widget.controller!._state = null;
    for (final t in _holds.values) {
      t.cancel();
    }
    for (final c in _press.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _pressIn(String key) {
    _holds.remove(key)?.cancel();
    final c = _controllerFor(key);
    if (_reduceMotion) {
      c.value = 1;
    } else {
      c.springTo(1, CameoMotion.keypadPressSpring);
    }
  }

  void _release(String key) {
    final c = _controllerFor(key);
    if (_reduceMotion) {
      c.value = 0;
    } else {
      c.springTo(0, CameoMotion.keypadReleaseSpring, velocity: c.velocity);
    }
  }

  void _fire(String key) {
    if (widget.disabled) return;
    HapticFeedback.selectionClick();
    if (key == keypadDeleteKey) {
      widget.onDelete?.call();
    } else {
      widget.onKey?.call(key);
    }
  }

  void _down(String key) {
    if (widget.disabled) return;
    _pressIn(key);
    _fire(key);
  }

  bool _pressProgrammatic(String key) {
    if (!mounted || widget.disabled || !_known.contains(key)) return false;
    _pressIn(key);
    _fire(key);
    _holds[key] = Timer(CameoMotion.durationFast, () {
      _holds.remove(key);
      if (mounted) _release(key);
    });
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final inset = widget.bottomInset ?? MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(
        left: CameoLayout.keypadV6PaddingX,
        right: CameoLayout.keypadV6PaddingX,
        bottom: math.max(inset, CameoLayout.keypadV6BottomInset),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: CameoLayout.keypadV6RowGap,
        children: [
          for (final row in keypadV6Rows)
            SizedBox(
              height: CameoLayout.keypadV6RowHeight,
              child: Row(
                children: [
                  for (final key in row)
                    Expanded(
                      child: key == null ? const SizedBox.shrink() : _key(key),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _key(String key) {
    final palette = CameoTheme.colorsOf(context);
    final disabled = widget.disabled;
    final isDelete = key == keypadDeleteKey;
    final label = isDelete ? appContent.common.delete : key;
    final c = _controllerFor(key);
    final glyph = isDelete
        ? CameoIcon(
            CameoIconName.backspace,
            size: CameoLayout.keypadV6BackspaceIconSize,
            color: palette.foregroundNeutralSubtle,
          )
        : CameoText(
            key,
            style: CameoTextStyles.headingMd,
            color: (widget.dimmed ?? disabled)
                ? palette.foregroundNeutralSubtle
                : palette.foregroundNeutralBase,
            maxLines: 1,
          );
    return Semantics(
      button: true,
      enabled: !disabled,
      label: label,
      onTap: disabled ? null : () => _pressProgrammatic(key),
      excludeSemantics: true,
      child: Listener(
        key: Keypad.keyKey(key),
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => _down(key),
        onPointerUp: (_) => _release(key),
        onPointerCancel: (_) => _release(key),
        child: AnimatedBuilder(
          animation: c,
          child: glyph,
          builder: (context, glyph) {
            final p = c.value;
            return Stack(
              fit: StackFit.expand,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: CameoLayout.keypadV6HighlightInsetX,
                  ),
                  child: Opacity(
                    key: Keypad.highlightKey(key),
                    opacity: p.clamp(0.0, 1.0),
                    child: DecoratedBox(
                      decoration: ShapeDecoration(
                        color: palette.backgroundFillNeutralBase,
                        shape: const StadiumBorder(),
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Transform.scale(
                    key: Keypad.labelKey(key),
                    scale: 1 - (1 - CameoMotion.keypadPressScale) * p,
                    child: glyph,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
