// Legacy navigation variants built from the shared glass primitives and token-defined
// geometry.

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../design_system/design_system.dart';
import '../navigation/zoom_chrome.dart';

typedef NavBarVariant = GlassNavVariant;

typedef NavBarTone = GlassNavTone;

class NavLeading {
  const NavLeading({
    required this.icon,
    this.onPress,
    required this.accessibilityLabel,
  });

  final CameoIconName icon;
  final VoidCallback? onPress;

  final String accessibilityLabel;
}

class NavAction {
  const NavAction({
    required this.icon,
    this.activeIcon,
    this.active,
    this.onPress,
    required this.accessibilityLabel,
  });

  final CameoIconName icon;

  final CameoIconName? activeIcon;

  final bool? active;
  final VoidCallback? onPress;

  final String accessibilityLabel;
}

typedef NavBarFrame = ({double top, double height, double bottom});

typedef _Spec = ({
  double minTop,
  double height,
  double paddingX,
  double paddingY,
});

_Spec _spec(NavBarVariant variant) => switch (variant) {
  GlassNavVariant.regular => (
    minTop: CameoLayout.navBarTop,
    height: CameoLayout.navBarHeight,
    paddingX: CameoLayout.navBarPaddingX,
    paddingY: CameoLayout.navBarPaddingY,
  ),
  GlassNavVariant.compact => (
    minTop: CameoLayout.navBarCompactTop,
    height: CameoLayout.navBarCompactHeight,
    paddingX: CameoLayout.navBarCompactPaddingX,
    paddingY: CameoLayout.navBarCompactPaddingY,
  ),
  GlassNavVariant.v1 => (
    minTop: CameoLayout.navBarV1Top,
    height: CameoLayout.navBarV1Height,
    paddingX: CameoLayout.navBarV1PaddingX,
    paddingY: CameoLayout.navBarV1PaddingY,
  ),
  GlassNavVariant.borderless => (
    minTop: CameoLayout.navBarBorderlessTop,
    height: CameoLayout.navBarBorderlessHeight,
    paddingX: CameoLayout.navBarBorderlessPaddingX,
    paddingY: CameoLayout.navBarBorderlessPaddingY,
  ),
};

NavBarFrame navBarFrame({
  NavBarVariant variant = GlassNavVariant.regular,
  double safeAreaTop = 0,
}) {
  final s = _spec(variant);
  final top = math.max(safeAreaTop, s.minTop);
  return (top: top, height: s.height, bottom: top + s.height);
}

NavBarFrame navBarFrameOf(
  BuildContext context, {
  NavBarVariant variant = GlassNavVariant.regular,
}) => navBarFrame(
  variant: variant,
  safeAreaTop: MediaQuery.paddingOf(context).top,
);

class NavBar extends StatelessWidget {
  const NavBar({
    super.key,
    this.variant = GlassNavVariant.regular,
    this.tone = GlassNavTone.dark,
    required this.leading,
    this.actions = const [],
    this.safeAreaTop,
  });

  final NavBarVariant variant;

  final NavBarTone tone;
  final NavLeading leading;

  final List<NavAction> actions;

  final double? safeAreaTop;

  @override
  Widget build(BuildContext context) {
    final s = _spec(variant);
    final frame = navBarFrame(
      variant: variant,
      safeAreaTop: safeAreaTop ?? MediaQuery.paddingOf(context).top,
    );
    return Positioned(
      top: frame.top,
      left: 0,
      right: 0,
      height: frame.height,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: s.paddingX,
          vertical: s.paddingY,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,

          children: [
            ZoomChromeScale(
              child: GlassIconButton(
                variant: variant,
                tone: tone,
                icon: leading.icon,
                onPress: leading.onPress,
                accessibilityLabel: leading.accessibilityLabel,
              ),
            ),
            if (actions.isNotEmpty) ZoomChromeScale(child: _trailing()),
          ],
        ),
      ),
    );
  }

  Widget _trailing() {
    if (variant == GlassNavVariant.v1) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        spacing: CameoLayout.navBarV1RightGroupGap,
        children: [
          for (final a in actions)
            GlassIconButton(
              key: ValueKey(a.icon),
              variant: GlassNavVariant.v1,
              icon: a.icon,
              activeIcon: a.activeIcon,
              active: a.active,
              onPress: a.onPress,
              accessibilityLabel: a.accessibilityLabel,
            ),
        ],
      );
    }
    return GlassIconButtonGroup(
      variant: variant,
      tone: tone,
      items: [
        for (final a in actions)
          GlassIconButtonGroupItem(
            icon: a.icon,
            activeIcon: a.activeIcon,
            active: a.active,
            onPress: a.onPress,
            accessibilityLabel: a.accessibilityLabel,
          ),
      ],
    );
  }
}
