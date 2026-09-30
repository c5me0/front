// Shared action pill with light, dark, and frosted-gray variants. Favorite icons use
// their filled twin and retain toggle feedback.

//

import 'package:flutter/widgets.dart';

import '../design_system/design_system.dart';
import 'outside_shadow.dart';
import 'scrim_button.dart';
import 'v6_layout.dart';

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

double scrimPillWidth(int count) => V6Layout.scrimPillWidth(count);

class ScrimPill extends StatelessWidget {
  const ScrimPill({
    super.key,
    required this.items,
    this.tone = ScrimPillTone.light,
  });

  final List<ScrimPillItem> items;

  final ScrimPillTone tone;

  static const Key surfaceKey = ValueKey('scrimPill.surface');
  static const Key shadowKey = ValueKey('scrimPill.shadow');
  static Key itemKey(int index) => ValueKey('scrimPill.item.$index');

  @override
  Widget build(BuildContext context) {
    final scrim = tone != ScrimPillTone.gray;
    final colors = scrimSurfaceColors(tone.buttonTone);
    final palette = CameoPalette.of(tone.buttonTone.mode);
    final iconColor = scrim ? colors.content : palette.foregroundNeutralBase;
    const bw = CameoLayout.scrimPillV6BorderWidth;
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      spacing: CameoLayout.scrimPillV6Gap,
      children: [
        for (var i = 0; i < items.length; i++) _item(i, items[i], iconColor),
      ],
    );
    final box = SizedBox(
      width: scrimPillWidth(items.length),
      height: CameoLayout.scrimPillV6Height,
      child: scrim
          ? GlassSurface(
              key: surfaceKey,
              blur: CameoBlur.scrim,
              tint: colors.tint,
              border: colors.border,
              borderWidth: bw,
              radius: CameoLayout.scrimPillV6Radius,

              padding: const EdgeInsets.all(
                CameoLayout.scrimPillV6Padding - bw,
              ),
              child: row,
            )
          : BlurSurface(
              key: surfaceKey,
              blur: CameoBlur.blur,
              tint: palette.backgroundFillNeutralBase,
              radius: CameoLayout.scrimPillV6Radius,
              padding: const EdgeInsets.all(CameoLayout.scrimPillV6Padding),
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

  Widget _item(int index, ScrimPillItem item, Color iconColor) {
    final body = SizedBox.square(
      key: itemKey(index),
      dimension: CameoLayout.scrimPillV6ItemSize,
      child: Center(
        child: ToggleIcon(
          icon: item.icon,
          activeIcon: filledIconOf(item.icon),
          active: item.active,
          size: CameoLayout.scrimPillV6ItemIconSize,
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
