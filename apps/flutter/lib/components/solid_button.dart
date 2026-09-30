// Shared v6 solid button sizes and semantic color variants. Press feedback updates
// immediately on pointer-down and cancels when the gesture becomes a drag.

// solid.button.lg / md / sm v6 (Figma product 2166:3575 · 2166:4286 · 2166:4557 — docs/v6-plan.md §7 · F3 · docs/v6-infra-brief.md §1).

//

//      gray            `background/fill/neutral/base`     + `foreground/neutral/base`
//      system          `system/red`                       + `static/white/base`

import 'package:flutter/widgets.dart';

import '../design_system/design_system.dart';
import 'scrim_button.dart';

enum SolidButtonSize { lg, md, sm }

enum SolidButtonVariant { defaultVariant, gray, system, ghost }

V5ButtonMetrics solidButtonMetrics(SolidButtonSize size) => switch (size) {
  SolidButtonSize.lg => (
    height: CameoLayout.solidButtonV6LgHeight,
    padding: CameoLayout.solidButtonV6LgPadding,
    iconSize: CameoLayout.solidButtonV6LgIconSize,
    label: CameoTextStyles.bodyLg,
  ),
  SolidButtonSize.md => (
    height: CameoLayout.solidButtonV6MdHeight,
    padding: CameoLayout.solidButtonV6MdPadding,
    iconSize: CameoLayout.solidButtonV6MdIconSize,
    label: CameoTextStyles.bodyLg,
  ),
  SolidButtonSize.sm => (
    height: CameoLayout.solidButtonV6SmHeight,
    padding: CameoLayout.solidButtonV6SmPadding,
    iconSize: CameoLayout.solidButtonV6SmIconSize,
    label: CameoTextStyles.bodyMd,
  ),
};

({Color? fill, Color content}) solidButtonColors(
  CameoPalette c,
  SolidButtonVariant variant, {
  bool disabled = false,
}) => switch (variant) {
  SolidButtonVariant.defaultVariant => (
    fill: c.backgroundFillNeutralInverted,
    content: c.foregroundInvertedBase,
  ),
  SolidButtonVariant.system => (fill: c.systemRed, content: c.staticWhiteBase),
  SolidButtonVariant.ghost => (
    fill: null,
    content: disabled ? c.foregroundNeutralSubtle : c.foregroundNeutralBase,
  ),
  _ => (fill: c.backgroundFillNeutralBase, content: c.foregroundNeutralBase),
};

class SolidButton extends StatelessWidget {
  const SolidButton({
    super.key,
    this.size = SolidButtonSize.lg,
    this.icon,
    this.label,
    this.variant = SolidButtonVariant.defaultVariant,
    this.disabled = false,
    this.stretch = false,
    this.onPress,
    this.semanticLabel,
  }) : assert(icon != null || label != null, '아이콘이나 라벨 중 하나는 있어야 한다');

  final SolidButtonSize size;
  final CameoIconName? icon;
  final String? label;
  final SolidButtonVariant variant;
  final bool disabled;

  final bool stretch;
  final VoidCallback? onPress;
  final String? semanticLabel;

  static const Key surfaceKey = ValueKey('solidButton.surface');

  @override
  Widget build(BuildContext context) {
    final c = CameoTheme.colorsOf(context);
    final m = solidButtonMetrics(size);
    final colors = solidButtonColors(c, variant, disabled: disabled);
    final surface = SizedBox(
      height: m.height,
      width: stretch ? double.infinity : null,
      child: BlurSurface(
        key: surfaceKey,
        blur: CameoBlur.blur,
        tint: colors.fill,
        radius: CameoLayout.solidButtonV6Radius,
        padding: EdgeInsets.symmetric(horizontal: m.padding),

        child: V5ButtonContent(
          metrics: m,
          gap: CameoLayout.solidButtonV6Gap,
          labelPaddingX: CameoLayout.solidButtonV6LabelPaddingX,
          color: colors.content,
          icon: icon,
          label: label,
        ),
      ),
    );
    final name = semanticLabel ?? label;
    if (disabled) {
      return Semantics(
        button: true,
        enabled: false,
        label: name,
        excludeSemantics: true,
        child: variant == SolidButtonVariant.ghost
            ? surface
            : Opacity(
                opacity: CameoLayout.solidButtonV6DisabledOpacity,
                child: surface,
              ),
      );
    }
    return PressScale(
      onPress: onPress,
      accessibilityLabel: name,
      pressedColor:
          (variant == SolidButtonVariant.defaultVariant
                  ? CameoPalette.of(
                      CameoTheme.modeOf(context) == CameoColorMode.light
                          ? CameoColorMode.dark
                          : CameoColorMode.light,
                    )
                  : c)
              .backgroundFillScrimInteraction,
      pressedRadius: CameoLayout.solidButtonV6Radius,
      child: surface,
    );
  }
}
