// Legacy glass shutter retained for camera preview routes.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../design_system/design_system.dart';

class ShutterButton extends StatefulWidget {
  const ShutterButton({
    super.key,
    this.onPress,
    this.feedbackKey = 0,
    required this.accessibilityLabel,
  });

  final VoidCallback? onPress;

  final int feedbackKey;

  final String accessibilityLabel;

  static const Key outerKey = ValueKey('shutterButton.outer');

  static const Key discKey = ValueKey('shutterButton.disc');

  @override
  State<ShutterButton> createState() => _ShutterButtonState();
}

class _ShutterButtonState extends State<ShutterButton>
    with TickerProviderStateMixin {
  late final AnimationController _scale = AnimationController.unbounded(
    vsync: this,
    value: 1,
  );

  late final AnimationController _disc = AnimationController.unbounded(
    vsync: this,
    value: 1,
    animationBehavior: AnimationBehavior.preserve,
  );

  bool _touchFired = false;

  bool get _reduceMotion =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  void _down() {
    _touchFired = false;
    _reduceMotion
        ? _scale.value = CameoMotion.cameraShutterPressScale
        : _scale.springTo(
            CameoMotion.cameraShutterPressScale,
            CameoSprings.press,
          );
  }

  void _release() =>
      _reduceMotion ? _scale.value = 1 : _scale.springTo(1, CameoSprings.chewy);

  void _tap() {
    _touchFired = true;
    widget.onPress?.call();
  }

  @override
  void didUpdateWidget(ShutterButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.feedbackKey == widget.feedbackKey) return;
    final kick = !_touchFired && !_reduceMotion;
    _touchFired = false;
    HapticFeedback.mediumImpact();

    _disc
        .animateTo(
          CameoMotion.cameraDiscFlashOpacity,
          duration: CameoMotion.cameraFlashIn,
          curve: CameoMotion.easingDecelerate,
        )
        .then((_) {
          if (!mounted) return;
          _disc.animateTo(
            1,
            duration: CameoMotion.cameraFlashOut,
            curve: CameoMotion.easingStandard,
          );
        });
    if (kick) {
      final impulse = springImpulse(
        CameoSprings.chewy,
        CameoMotion.cameraShutterPressScale,
      );
      _scale.value = 1;
      _scale.springTo(1, CameoSprings.chewy, velocity: impulse.velocity).then((
        _,
      ) {
        if (mounted) _scale.value = 1;
      });
    }
  }

  @override
  void dispose() {
    _scale.dispose();
    _disc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = CameoTheme.colorsOf(context);
    final enabled = widget.onPress != null;
    return Semantics(
      button: enabled,
      label: widget.accessibilityLabel,
      onTap: enabled ? _tap : null,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _down() : null,
        onTapUp: enabled ? (_) => _release() : null,
        onTapCancel: enabled ? _release : null,
        onTap: enabled ? _tap : null,
        child: ScaleTransition(
          key: ShutterButton.outerKey,
          scale: _scale,
          child: SizedBox.square(
            dimension: CameoLayout.cameraScreenShutterSize,
            child: GlassSurface(
              blur: CameoBlur.glassNav,
              tint: palette.cameraShutter,
              border: palette.cameraShutterStroke,
              borderWidth: CameoLayout.cameraScreenShutterBorderWidth,
              radius: CameoLayout.cameraScreenShutterRadius,
              child: Center(
                child: FadeTransition(
                  opacity: _disc,
                  child: SizedBox.square(
                    key: ShutterButton.discKey,
                    dimension: CameoLayout.cameraScreenShutterDiscSize,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: palette.cameraShutterDisc,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
