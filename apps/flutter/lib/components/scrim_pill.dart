// Shared action pill with light, dark, and frosted-gray variants. Favorite icons use
// their filled twin and retain toggle feedback.

//

import 'package:flutter/widgets.dart';

import '../design_system/design_system.dart';
import 'outside_shadow.dart';
import 'scrim_button.dart';

CameoIconName? filledIconOf(CameoIconName icon) {
  final key = '${icon.key}-filled';
  for (final n in CameoIconName.values) {
    if (n.key == key) return n;
  }
  return null;
}

enum ScrimPillTone {
  light,

  dark,

  gray;

  ScrimButtonTone get buttonTone =>
      this == dark ? ScrimButtonTone.dark : ScrimButtonTone.light;
}

@immutable
class ScrimPillItem {
  const ScrimPillItem({
    required this.icon,
    this.active = false,
    this.onPress,
    required this.semanticLabel,
  });

  final CameoIconName icon;

  final bool active;
  final VoidCallback? onPress;

  final String semanticLabel;
}

enum ScrimPillSize { small, navigation, large }

typedef _PillMetrics = ({
  double height,
  double padding,
  double gap,
  double item,
  double icon,
});
_PillMetrics _metrics(ScrimPillSize size) => switch (size) {
  ScrimPillSize.small => (
    height: CameoLayout.scrimPillV6Height,
    padding: CameoLayout.scrimPillV6Padding,
    gap: CameoLayout.scrimPillV6Gap,
    item: CameoLayout.scrimPillV6ItemSize,
    icon: CameoLayout.scrimPillV6ItemIconSize,
  ),
  ScrimPillSize.navigation => (
    height: CameoLayout.silicaNavigationPillHeight,
    padding: CameoLayout.silicaNavigationPillPadding,
    gap: CameoLayout.silicaNavigationPillGap,
    item: CameoLayout.silicaNavigationPillItemSize,
    icon: CameoLayout.silicaNavigationPillIconSize,
  ),
  ScrimPillSize.large => (
    height: CameoLayout.silicaActionPillHeight,
    padding: CameoLayout.silicaActionPillPadding,
    gap: CameoLayout.silicaActionPillGap,
    item: CameoLayout.silicaActionPillItemSize,
    icon: CameoLayout.silicaActionPillIconSize,
  ),
};
double scrimPillWidth(int count, [ScrimPillSize size = ScrimPillSize.small]) {
  final m = _metrics(size);
  return 2 * m.padding + count * m.item + (count > 0 ? count - 1 : 0) * m.gap;
}

class ScrimPill extends StatelessWidget {
  const ScrimPill({
    super.key,
    required this.items,
    this.tone = ScrimPillTone.light,
    this.size = ScrimPillSize.small,
  });

  final List<ScrimPillItem> items;

  final ScrimPillTone tone;
  final ScrimPillSize size;

  static const Key surfaceKey = ValueKey('scrimPill.surface');
  static const Key shadowKey = ValueKey('scrimPill.shadow');
  static Key itemKey(int index) => ValueKey('scrimPill.item.$index');

  @override
  Widget build(BuildContext context) {
    final m = _metrics(size);
    final scrim = tone != ScrimPillTone.gray;
    final colors = scrimSurfaceColors(tone.buttonTone);
    final palette = CameoPalette.of(tone.buttonTone.mode);
    final iconColor = scrim ? colors.content : palette.foregroundNeutralBase;
    const bw = CameoLayout.scrimPillV6BorderWidth;
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      spacing: m.gap,
      children: [
        for (var i = 0; i < items.length; i++) _item(i, items[i], iconColor, m),
      ],
    );
    final box = SizedBox(
      width: scrimPillWidth(items.length, size),
      height: m.height,
      child: scrim
          ? GlassSurface(
              key: surfaceKey,
              blur: CameoBlur.scrim,
              tint: size != ScrimPillSize.small && tone == ScrimPillTone.dark
                  ? palette.backgroundFillNeutralBase
                  : colors.tint,
              border: colors.border,
              borderWidth: bw,
              radius: CameoLayout.scrimPillV6Radius,

              padding: EdgeInsets.all(m.padding - bw),
              child: row,
            )
          : BlurSurface(
              key: surfaceKey,
              blur: CameoBlur.blur,
              tint: palette.backgroundFillNeutralBase,
              radius: CameoLayout.scrimPillV6Radius,
              padding: EdgeInsets.all(m.padding),
              child: row,
            ),
    );
    return scrim
        ? OutsideShadow(
            key: shadowKey,
            shadow: colors.shadow,
            radius: CameoLayout.scrimPillV6Radius,
            child: box,
          )
        : box;
  }

  Widget _item(int index, ScrimPillItem item, Color iconColor, _PillMetrics m) {
    final body = SizedBox.square(
      key: itemKey(index),
      dimension: m.item,
      child: Center(
        child: ToggleIcon(
          icon: item.icon,
          activeIcon: filledIconOf(item.icon),
          active: item.active,
          size: m.icon,
          color: iconColor,
        ),
      ),
    );
    final pressable = tone != ScrimPillTone.gray
        ? GlassPressable(
            onPress: item.onPress,
            accessibilityLabel: item.semanticLabel,
            pressedColor: CameoPalette.of(
              tone.buttonTone.mode,
            ).backgroundFillScrimInteraction,
            pressedRadius: CameoLayout.scrimPillV6Radius,
            child: body,
          )
        : PressScale(
            onPress: item.onPress,
            accessibilityLabel: item.semanticLabel,
            pressedColor: CameoPalette.light.backgroundFillScrimInteraction,
            pressedRadius: CameoLayout.scrimPillV6Radius,
            child: body,
          );
    return Semantics(selected: item.active, child: pressable);
  }
}
