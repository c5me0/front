// iOS-style switch with spring position and press deformation. Disabled interactions
// and reduced motion preserve an unambiguous on/off state.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../design_system/design_system.dart';
import 'onboarding_v6_layout.dart';

///

/// Semantics: toggled = value · enabled · label [semanticLabel].
class IosSwitch extends StatefulWidget {
  const IosSwitch({
    super.key,
    required this.value,
    this.onValueChange,
    this.disabled = false,
    required this.semanticLabel,
  });

  final bool value;

  final ValueChanged<bool>? onValueChange;
  final bool disabled;

  final String semanticLabel;

  static const Key trackKey = ValueKey('iosSwitch.track');
  static const Key knobKey = ValueKey('iosSwitch.knob');

  @override
  State<IosSwitch> createState() => IosSwitchState();
}

class IosSwitchState extends State<IosSwitch> with TickerProviderStateMixin {
  late final AnimationController _on = AnimationController.unbounded(
    vsync: this,
    value: widget.value ? 1 : 0,
  );
  late final AnimationController _press = AnimationController.unbounded(
    vsync: this,
  );
  bool _reduceMotion = false;

  double get onProgress => _on.value;
  double get pressProgress => _press.value;

  @override
  void initState() {
    super.initState();
    _on;
    _press;
  }

  bool get _interactive => !widget.disabled && widget.onValueChange != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  }

  @override
  void didUpdateWidget(IosSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value == widget.value) return;
    final target = widget.value ? 1.0 : 0.0;
    if (_reduceMotion) {
      _on.value = target;
    } else {
      _on.springTo(target, CameoMotion.switchSpring, velocity: _on.velocity);
    }
  }

  @override
  void dispose() {
    _on.dispose();
    _press.dispose();
    super.dispose();
  }

  void _pressIn() {
    if (!_reduceMotion) _press.springTo(1, CameoMotion.switchPressSpring);
  }

  void _pressOut() {
    if (_reduceMotion) {
      _press.value = 0;
    } else {
      _press.springTo(0, CameoMotion.switchSpring, velocity: _press.velocity);
    }
  }

  void _toggle() {
    HapticFeedback.selectionClick();
    widget.onValueChange?.call(!widget.value);
  }

  @override
  Widget build(BuildContext context) {
    final c = CameoTheme.colorsOf(context);
    final interactive = _interactive;
    return Semantics(
      toggled: widget.value,
      enabled: interactive,
      label: widget.semanticLabel,
      onTap: interactive ? _toggle : null,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: interactive ? (_) => _pressIn() : null,
        onTapUp: interactive ? (_) => _pressOut() : null,
        onTapCancel: interactive ? _pressOut : null,
        onTap: interactive ? _toggle : null,
        child: AnimatedBuilder(
          animation: Listenable.merge([_on, _press]),
          builder: (context, _) {
            final p = _on.value;
            final f = iosSwitchKnobFrame(
              p,
              _press.value,
              CameoMotion.switchPressStretch,
            );
            return SizedBox(
              key: IosSwitch.trackKey,
              width: CameoLayout.settingsV6SwitchWidth,
              height: CameoLayout.settingsV6SwitchHeight,
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: Color.lerp(
                    c.backgroundFillNeutralStrong,
                    c.accentsGreen,
                    p.clamp(0.0, 1.0),
                  ),
                  shape: const StadiumBorder(),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      key: IosSwitch.knobKey,
                      left: f.left,
                      top:
                          (CameoLayout.settingsV6SwitchHeight -
                              CameoLayout.settingsV6SwitchKnobHeight) /
                          2,
                      width: f.width,
                      height: CameoLayout.settingsV6SwitchKnobHeight,
                      child: DecoratedBox(
                        decoration: ShapeDecoration(
                          color: c.switchKnob,
                          shape: const StadiumBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
