// Circular glass icon actions with token-driven geometry, accessibility labels, and
// press deformation.

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'cameo_icon.dart';
import 'cameo_theme.dart';
import 'glass_pressable.dart';
import 'glass_surface.dart';
import 'icons.g.dart';
import 'motion.dart';
import 'tokens.g.dart';

///

enum GlassNavVariant { regular, compact, v1, borderless }

enum GlassNavTone { dark, light, camera }

typedef _Roles = ({Color tint, Color? border, Color icon});

_Roles _rolesFor(CameoPalette c, GlassNavVariant variant, GlassNavTone tone) =>
    switch (variant) {
      GlassNavVariant.compact => (
        tint: c.glassTintCompact,
        border: null,
        icon: c.iconOnDarkMuted,
      ),
      GlassNavVariant.v1 => (
        tint: c.glassTintV1,
        border: null,
        icon: c.foregroundNeutralInverseBase,
      ),

      GlassNavVariant.borderless => (
        tint: c.backgroundNeutralBase,
        border: null,
        icon: c.foregroundNeutralBase,
      ),
      GlassNavVariant.regular => switch (tone) {
        GlassNavTone.dark => (
          tint: c.glassTint,
          border: c.glassBorder,
          icon: c.iconOnDark,
        ),
        GlassNavTone.light => (
          tint: c.backgroundNeutralSubtle,
          border: c.strokeNeutralBase,
          icon: c.foregroundNeutralBase,
        ),
        GlassNavTone.camera => (
          tint: c.glassTint,
          border: c.strokeNeutralBase,
          icon: c.foregroundNeutralInverseBase,
        ),
      },
    };

typedef _Circle = ({
  double size,
  double padding,
  double borderWidth,
  double radius,
  double iconSize,
  CameoBlur blur,
});

_Circle _circle(GlassNavVariant variant) => switch (variant) {
  GlassNavVariant.regular => (
    size: CameoLayout.navBarCircleButtonSize,
    padding: CameoLayout.navBarCircleButtonPadding,
    borderWidth: CameoLayout.navBarCircleButtonBorderWidth,
    radius: CameoLayout.navBarCircleButtonRadius,
    iconSize: CameoLayout.navBarCircleButtonIconSize,
    blur: CameoBlur.glassNav,
  ),
  GlassNavVariant.compact => (
    size: CameoLayout.navBarCompactCircleButtonSize,
    padding: CameoLayout.navBarCompactCircleButtonPadding,
    borderWidth: CameoLayout.navBarCompactCircleButtonBorderWidth,
    radius: CameoLayout.navBarCompactCircleButtonRadius,
    iconSize: CameoLayout.navBarCompactCircleButtonIconSize,
    blur: CameoBlur.glassNav,
  ),
  GlassNavVariant.v1 => (
    size: CameoLayout.navBarV1CircleButtonSize,
    padding: CameoLayout.navBarV1CircleButtonPadding,
    borderWidth: CameoLayout.navBarV1CircleButtonBorderWidth,
    radius: CameoLayout.navBarV1CircleButtonRadius,
    iconSize: CameoLayout.navBarV1CircleButtonIconSize,
    blur: CameoBlur.glassFigma,
  ),
  // 2042:3235 backdrop-blur 6px = glassNav → Liquid Glass (G1)
  GlassNavVariant.borderless => (
    size: CameoLayout.navBarBorderlessCircleButtonSize,
    padding: CameoLayout.navBarBorderlessCircleButtonPadding,
    borderWidth: CameoLayout.navBarBorderlessCircleButtonBorderWidth,
    radius: CameoLayout.navBarBorderlessCircleButtonRadius,
    iconSize: CameoLayout.navBarBorderlessCircleButtonIconSize,
    blur: CameoBlur.glassNav,
  ),
};

typedef _Pill = ({
  double height,
  double padding,
  double gap,
  double borderWidth,
  double radius,
  double itemSize,
  double iconSize,
});

_Pill _pill(GlassNavVariant variant) => switch (variant) {
  GlassNavVariant.compact => (
    height: CameoLayout.navBarCompactActionPillHeight,
    padding: CameoLayout.navBarCompactActionPillPadding,
    gap: CameoLayout.navBarCompactActionPillGap,
    borderWidth: CameoLayout.navBarCompactActionPillBorderWidth,
    radius: CameoLayout.navBarCompactActionPillRadius,
    itemSize: CameoLayout.navBarCompactActionItemSize,
    iconSize: CameoLayout.navBarCompactActionItemIconSize,
  ),
  // 2042:3237 backdrop-blur 6px = glassNav → Liquid Glass (G1)
  GlassNavVariant.borderless => (
    height: CameoLayout.navBarBorderlessActionPillHeight,
    padding: CameoLayout.navBarBorderlessActionPillPadding,
    gap: CameoLayout.navBarBorderlessActionPillGap,
    borderWidth: CameoLayout.navBarBorderlessActionPillBorderWidth,
    radius: CameoLayout.navBarBorderlessActionPillRadius,
    itemSize: CameoLayout.navBarBorderlessActionItemSize,
    iconSize: CameoLayout.navBarBorderlessActionItemIconSize,
  ),

  GlassNavVariant.regular || GlassNavVariant.v1 => (
    height: CameoLayout.navBarActionPillHeight,
    padding: CameoLayout.navBarActionPillPadding,
    gap: CameoLayout.navBarActionPillGap,
    borderWidth: CameoLayout.navBarActionPillBorderWidth,
    radius: CameoLayout.navBarActionPillRadius,
    itemSize: CameoLayout.navBarActionItemSize,
    iconSize: CameoLayout.navBarActionItemIconSize,
  ),
};

typedef SpringImpulse = ({double velocity, Duration peak});

SpringImpulse springImpulse(SpringDescription spring, double peak) {
  final alpha = spring.damping / (2 * spring.mass);
  final w0 = math.sqrt(spring.stiffness / spring.mass);
  double t;
  double gain;
  if (alpha < w0) {
    final wd = math.sqrt(w0 * w0 - alpha * alpha);
    t = math.atan2(wd, alpha) / wd;
    gain = math.exp(-alpha * t) / w0;
  } else if (alpha == w0) {
    t = 1 / w0;
    gain = t * math.exp(-w0 * t);
  } else {
    final b = math.sqrt(alpha * alpha - w0 * w0);
    final r1 = -alpha + b;
    final r2 = -alpha - b;
    t = math.log(r2 / r1) / (r1 - r2);
    gain = (math.exp(r1 * t) - math.exp(r2 * t)) / (r1 - r2);
  }
  return (
    velocity: (peak - 1) / gain,
    peak: Duration(microseconds: (t * Duration.microsecondsPerSecond).round()),
  );
}

String? toggleAccessibilityLabel(String? label, bool? active) {
  if (label == null || active == null) return label;
  return '$label, ${active ? '켜짐' : '꺼짐'}';
}

class ToggleIcon extends StatefulWidget {
  const ToggleIcon({
    super.key,
    required this.icon,
    this.activeIcon,
    this.active = false,
    required this.size,
    required this.color,
  });

  final CameoIconName icon;

  final CameoIconName? activeIcon;
  final bool active;
  final double size;
  final Color color;

  @override
  State<ToggleIcon> createState() => _ToggleIconState();
}

class _ToggleIconState extends State<ToggleIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scale = AnimationController.unbounded(
    vsync: this,
    value: 1,
  )..addListener(_swapAtPeak);

  late bool _showActive = widget.active;

  Duration? _swapAt;

  void _swapAtPeak() {
    final at = _swapAt;
    if (at == null) return;
    final t = _scale.lastElapsedDuration;
    if (t != null && t < at) return;
    _swapAt = null;
    setState(() => _showActive = true);
  }

  void _kick(SpringDescription spring, double velocity) {
    final x = _scale.value;
    final away = (x < 1 && velocity < 0) || (x > 1 && velocity > 0);
    _scale.springTo(1, spring, velocity: away ? 0 : velocity).then((_) {
      if (mounted) _scale.value = 1;
    });
  }

  @override
  void didUpdateWidget(ToggleIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active == widget.active) return;
    _swapAt = null;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _scale.value = 1;
      _showActive = widget.active;
      return;
    }
    if (widget.active) {
      const spring = CameoMotion.heartPopSpring;
      final pop = springImpulse(spring, CameoMotion.heartPopOvershootScale);
      _kick(spring, pop.velocity);
      _swapAt = pop.peak;
    } else {
      const spring = CameoSprings.press;
      final dip = springImpulse(spring, CameoMotion.pressScale);
      _showActive = false;
      _kick(spring, dip.velocity);
    }
  }

  @override
  void dispose() {
    _scale.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeIcon = widget.activeIcon;
    return ScaleTransition(
      scale: _scale,
      child: CameoIcon(
        _showActive && activeIcon != null ? activeIcon : widget.icon,
        size: widget.size,
        color: widget.color,
      ),
    );
  }
}

class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    this.activeIcon,
    this.active,
    this.onPress,
    this.variant = GlassNavVariant.regular,
    this.tone = GlassNavTone.dark,
    this.tint,
    this.border,
    this.iconColor,
    this.accessibilityLabel,
  });

  final CameoIconName icon;

  final CameoIconName? activeIcon;

  final bool? active;
  final VoidCallback? onPress;
  final GlassNavVariant variant;
  final GlassNavTone tone;

  final Color? tint;
  final Color? border;
  final Color? iconColor;
  final String? accessibilityLabel;

  @override
  Widget build(BuildContext context) {
    final spec = _circle(variant);
    final roles = _rolesFor(CameoTheme.colorsOf(context), variant, tone);
    return GlassPressable(
      onPress: onPress,
      accessibilityLabel: toggleAccessibilityLabel(accessibilityLabel, active),
      child: SizedBox.square(
        dimension: spec.size,
        child: GlassSurface(
          blur: spec.blur,
          tint: tint ?? roles.tint,
          border: border ?? roles.border,
          borderWidth: spec.borderWidth,
          radius: spec.radius,
          padding: EdgeInsets.all(spec.padding),
          child: Center(
            child: ToggleIcon(
              icon: icon,
              activeIcon: activeIcon,
              active: active ?? false,
              size: spec.iconSize,
              color: iconColor ?? roles.icon,
            ),
          ),
        ),
      ),
    );
  }
}

class GlassIconButtonGroupItem {
  const GlassIconButtonGroupItem({
    required this.icon,
    this.activeIcon,
    this.active,
    this.onPress,
    this.iconColor,
    this.accessibilityLabel,
  });

  final CameoIconName icon;

  final CameoIconName? activeIcon;

  final bool? active;
  final VoidCallback? onPress;
  final Color? iconColor;
  final String? accessibilityLabel;
}

class GlassIconButtonGroup extends StatelessWidget {
  const GlassIconButtonGroup({
    super.key,
    required this.items,
    this.variant = GlassNavVariant.regular,
    this.tone = GlassNavTone.dark,
    this.tint,
    this.border,
    this.iconColor,
  }) : assert(variant != GlassNavVariant.v1, 'v1 에는 액션 pill 이 없다');

  final List<GlassIconButtonGroupItem> items;
  final GlassNavVariant variant;
  final GlassNavTone tone;
  final Color? tint;
  final Color? border;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final pill = _pill(variant);
    final roles = _rolesFor(CameoTheme.colorsOf(context), variant, tone);
    return SizedBox(
      height: pill.height,
      child: GlassSurface(
        blur: CameoBlur.glassNav,
        tint: tint ?? roles.tint,
        border: border ?? roles.border,
        borderWidth: pill.borderWidth,
        radius: pill.radius,
        padding: EdgeInsets.all(pill.padding),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: pill.gap,
          children: [
            for (final item in items)
              GlassPressable(
                key: ValueKey(item.icon),
                onPress: item.onPress,
                accessibilityLabel: toggleAccessibilityLabel(
                  item.accessibilityLabel,
                  item.active,
                ),
                child: SizedBox.square(
                  dimension: pill.itemSize,
                  child: Center(
                    child: ToggleIcon(
                      icon: item.icon,
                      activeIcon: item.activeIcon,
                      active: item.active ?? false,
                      size: pill.iconSize,
                      color: item.iconColor ?? iconColor ?? roles.icon,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
