// Full-width authentication action with enabled, disabled, and busy feedback using the
// shared v6 button.

import 'package:flutter/widgets.dart';

import '../design_system/design_system.dart';
import 'solid_button.dart';

class SolidCta extends StatefulWidget {
  const SolidCta({
    super.key,
    required this.label,
    this.variant = SolidButtonVariant.defaultVariant,
    this.enabled = true,
    this.busy = false,
    this.onPress,
  });

  final String label;

  final SolidButtonVariant variant;
  final bool enabled;
  final bool busy;
  final VoidCallback? onPress;

  static const Key fadeKey = ValueKey('solidCta.fade');

  @override
  State<SolidCta> createState() => SolidCtaState();
}

class SolidCtaState extends State<SolidCta>
    with SingleTickerProviderStateMixin {
  static double _targetOf(bool enabled) =>
      enabled ? 1 : CameoLayout.solidButtonV6DisabledOpacity;

  late final AnimationController _opacity = AnimationController.unbounded(
    vsync: this,
    value: _targetOf(widget.enabled),
  );
  bool _reduceMotion = false;

  double get opacity => _opacity.value;

  @override
  void initState() {
    super.initState();
    _opacity;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  }

  @override
  void didUpdateWidget(SolidCta oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled == widget.enabled) return;
    final target = _targetOf(widget.enabled);
    if (_reduceMotion) {
      _opacity.value = target;
    } else {
      _opacity.springTo(
        target,
        CameoSprings.smooth,
        velocity: _opacity.velocity,
      );
    }
  }

  @override
  void dispose() {
    _opacity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final interactive = widget.enabled && !widget.busy;
    return AnimatedBuilder(
      animation: _opacity,
      builder: (context, child) => Opacity(
        key: SolidCta.fadeKey,
        opacity: _opacity.value.clamp(0.0, 1.0),
        child: child,
      ),
      child: Semantics(
        enabled: widget.enabled,
        child: SolidButton(
          label: widget.label,
          variant: widget.variant,
          stretch: true,
          onPress: interactive ? widget.onPress : null,
        ),
      ),
    );
  }
}
