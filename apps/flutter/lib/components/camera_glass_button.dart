// Circular camera control with Liquid Glass, an inner border, and immediate press
// feedback.

import 'package:flutter/widgets.dart';

import '../design_system/design_system.dart';

class CameraGlassButton extends StatelessWidget {
  const CameraGlassButton({
    super.key,
    required this.icon,
    this.onPress,
    required this.accessibilityLabel,
  });

  final CameoIconName icon;
  final VoidCallback? onPress;

  final String accessibilityLabel;

  @override
  Widget build(BuildContext context) {
    final palette = CameoTheme.colorsOf(context);
    return GlassPressable(
      onPress: onPress,
      accessibilityLabel: accessibilityLabel,
      child: SizedBox.square(
        dimension: CameoLayout.cameraScreenGlassButtonSize,
        child: GlassSurface(
          blur: CameoBlur.glassNav,
          tint: palette.glassTint,
          border: palette.strokeNeutralBase,
          borderWidth: CameoLayout.cameraScreenGlassButtonBorderWidth,
          radius: CameoLayout.cameraScreenGlassButtonRadius,
          padding: const EdgeInsets.all(
            CameoLayout.cameraScreenGlassButtonPadding,
          ),
          child: Center(
            child: CameoIcon(
              icon,
              size: CameoLayout.cameraScreenGlassButtonIconSize,
              color: palette.foregroundNeutralInverseBase,
            ),
          ),
        ),
      ),
    );
  }
}
