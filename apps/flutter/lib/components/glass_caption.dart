import 'package:flutter/widgets.dart';

import '../design_system/design_system.dart';
import 'outside_shadow.dart';

/// Shared date and remaining-time capsules from System Silica.
class GlassCaption extends StatelessWidget {
  const GlassCaption({
    super.key,
    required this.label,
    this.small = true,
    this.semanticLabel,
    this.onPress,
  });
  final String label;
  final bool small;
  final String? semanticLabel;
  final VoidCallback? onPress;

  @override
  Widget build(BuildContext context) {
    const colors = CameoPalette.light;
    final body = OutsideShadow(
      shadow: colors.shadows.scrim,
      radius: CameoRadius.full,
      child: SizedBox(
        height: small
            ? CameoLayout.silicaCaptionSmallHeight
            : CameoLayout.silicaCaptionLargeHeight,
        child: GlassSurface(
          blur: CameoBlur.scrim,
          tint: colors.backgroundFillScrimBase,
          border: colors.borderScrim,
          borderWidth: CameoBorderWidth.hairline,
          radius: CameoRadius.full,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: CameoLayout.silicaCaptionTextPaddingX,
            ),
            child: Center(
              widthFactor: 1,
              child: CameoText(
                label,
                style: small ? CameoTextStyles.bodySm : CameoTextStyles.bodyMd,
                color: colors.foregroundNeutralBase,
                maxLines: 1,
              ),
            ),
          ),
        ),
      ),
    );
    return onPress == null
        ? body
        : GlassPressable(
            onPress: onPress,
            accessibilityLabel: semanticLabel ?? label,
            pressedRadius: CameoRadius.full,
            pressedColor: colors.backgroundFillScrimInteraction,
            child: body,
          );
  }
}
