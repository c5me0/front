// Token-sized Liquid Glass buttons. Tone selects its own palette independently of the
// surrounding screen theme; disabled buttons ignore input.

//

import 'package:flutter/widgets.dart';

import '../design_system/design_system.dart';
import 'outside_shadow.dart';

enum ScrimButtonSize { xl, nav, lg, md, sm }

enum ScrimButtonTone {
  light,

  dark;

  CameoColorMode get mode =>
      this == dark ? CameoColorMode.dark : CameoColorMode.light;
}

typedef V5ButtonMetrics = ({
  double height,
  double padding,
  double iconSize,
  TextStyle label,
});

V5ButtonMetrics scrimButtonMetrics(ScrimButtonSize size) => switch (size) {
  ScrimButtonSize.nav => (
    height: CameoLayout.scrimButtonV6NavHeight,
    padding: CameoLayout.scrimButtonV6NavPadding,
    iconSize: CameoLayout.scrimButtonV6NavIconSize,
    label: CameoTextStyles.bodyLg,
  ),
  ScrimButtonSize.xl => (
    height: CameoLayout.scrimButtonV6XlHeight,
    padding: CameoLayout.scrimButtonV6XlPadding,
    iconSize: CameoLayout.scrimButtonV6XlIconSize,
    label: CameoTextStyles.bodyLg,
  ),
  ScrimButtonSize.lg => (
    height: CameoLayout.scrimButtonV6LgHeight,
    padding: CameoLayout.scrimButtonV6LgPadding,
    iconSize: CameoLayout.scrimButtonV6LgIconSize,
    label: CameoTextStyles.bodyLg,
  ),
  ScrimButtonSize.md => (
    height: CameoLayout.scrimButtonV6MdHeight,
    padding: CameoLayout.scrimButtonV6MdPadding,
    iconSize: CameoLayout.scrimButtonV6MdIconSize,
    label: CameoTextStyles.bodyLg,
  ),
  ScrimButtonSize.sm => (
    height: CameoLayout.scrimButtonV6SmHeight,
    padding: CameoLayout.scrimButtonV6SmPadding,
    iconSize: CameoLayout.scrimButtonV6SmIconSize,
    label: CameoTextStyles.bodyMd,
  ),
};

({Color tint, Color border, Color content, BoxShadow shadow})
scrimSurfaceColors(ScrimButtonTone tone) {
  final p = CameoPalette.of(tone.mode);
  return (
    tint: p.backgroundFillScrimBase,
    border: p.borderScrim,
    content: tone == ScrimButtonTone.dark
        ? p.staticWhiteBase
        : p.foregroundNeutralBase,
    shadow: p.shadows.scrim,
  );
}

Color _faded(Color color, double factor) =>
    color.withValues(alpha: color.a * factor);

class V5ButtonContent extends StatelessWidget {
  const V5ButtonContent({
    super.key,
    required this.metrics,
    required this.gap,
    required this.labelPaddingX,
    required this.color,
    this.icon,
    this.label,
  });

  final V5ButtonMetrics metrics;
  final double gap;
  final double labelPaddingX;
  final Color color;
  final CameoIconName? icon;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final icon = this.icon;
    final label = this.label;
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: gap,
      children: [
        if (icon != null)
          CameoIcon(
            icon,
            key: const ValueKey('v5Button.icon'),
            size: metrics.iconSize,
            color: color,
          ),
        if (label != null)
          Flexible(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: labelPaddingX),
              child: CameoText(
                label,
                key: const ValueKey('v5Button.label'),
                style: metrics.label,
                color: color,
                maxLines: 1,
              ),
            ),
          ),
      ],
    );
  }
}

class ScrimButton extends StatelessWidget {
  const ScrimButton({
    super.key,
    this.size = ScrimButtonSize.lg,
    this.icon,
    this.label,
    this.tone = ScrimButtonTone.light,
    this.disabled = false,
    this.onPress,
    this.semanticLabel,
    this.neutral = false,
  }) : assert(icon != null || label != null, '아이콘이나 라벨 중 하나는 있어야 한다');

  final ScrimButtonSize size;
  final CameoIconName? icon;
  final String? label;
  final ScrimButtonTone tone;

  final bool disabled;
  final VoidCallback? onPress;

  final String? semanticLabel;
  final bool neutral;

  static const Key surfaceKey = ValueKey('scrimButton.surface');
  static const Key shadowKey = ValueKey('scrimButton.shadow');

  @override
  Widget build(BuildContext context) {
    final m = scrimButtonMetrics(size);
    const bw = CameoLayout.scrimButtonV6BorderWidth;
    final colors = scrimSurfaceColors(tone);
    final k = disabled ? CameoLayout.scrimButtonV6DisabledOpacity : 1.0;
    final shadow = colors.shadow;
    final surface = OutsideShadow(
      key: shadowKey,
      shadow: shadow.copyWith(color: _faded(shadow.color, k)),
      radius: CameoLayout.scrimButtonV6Radius,
      child: SizedBox(
        height: m.height,
        child: GlassSurface(
          key: surfaceKey,
          blur: CameoBlur.scrim,
          tint: _faded(
            neutral
                ? CameoPalette.of(tone.mode).backgroundFillNeutralBase
                : colors.tint,
            k,
          ),
          border: _faded(colors.border, k),
          borderWidth: bw,
          radius: CameoLayout.scrimButtonV6Radius,

          padding: EdgeInsets.symmetric(horizontal: m.padding - bw),
          child: V5ButtonContent(
            metrics: m,
            gap: CameoLayout.scrimButtonV6Gap,
            labelPaddingX: size == ScrimButtonSize.nav
                ? CameoLayout.scrimButtonV6NavLabelPaddingX
                : CameoLayout.scrimButtonV6LabelPaddingX,
            color: _faded(colors.content, k),
            icon: icon,
            label: label,
          ),
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
        child: surface,
      );
    }
    return GlassPressable(
      onPress: onPress,
      accessibilityLabel: name,
      pressedColor: CameoPalette.of(tone.mode).backgroundFillScrimInteraction,
      pressedRadius: CameoLayout.scrimButtonV6Radius,
      child: surface,
    );
  }
}
