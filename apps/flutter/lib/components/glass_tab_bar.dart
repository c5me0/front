// Legacy glass tab navigation with album, call, and settings actions.

import 'dart:math' as math;

import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

import '../content/lab.g.dart';
import '../design_system/design_system.dart';

const List<String> glassTabBarLabels = ['앨범', '통화', '설정'];

const List<CameoIconName?> _icons = [
  null,
  CameoIconName.phoneFilled,
  CameoIconName.settingsFilled,
];

///    (`foreground/neutral/base`)
enum GlassTabBarTone { photo, canvas }

({Color tint, Color icon}) glassTabBarToneColors(
  CameoPalette palette,
  double t,
) {
  final p = t.clamp(0.0, 1.0);
  return (
    tint: Color.lerp(
      palette.glassTintTabBar,
      palette.backgroundNeutralSubtle,
      p,
    )!,
    icon: Color.lerp(palette.iconOnDark, palette.foregroundNeutralBase, p)!,
  );
}

///

class GlassTabBar extends StatefulWidget {
  const GlassTabBar({
    super.key,
    required this.selectedIndex,
    this.onSelect,
    this.avatar = LabImages.tabbarAvatar,
    this.avatarIcon,
    this.tone = GlassTabBarTone.photo,
  });

  final int selectedIndex;

  final ValueChanged<int>? onSelect;

  final String avatar;

  final CameoIconName? avatarIcon;

  final GlassTabBarTone tone;

  @override
  State<GlassTabBar> createState() => _GlassTabBarState();
}

class _GlassTabBarState extends State<GlassTabBar>
    with TickerProviderStateMixin {
  late final AnimationController _position;

  late final AnimationController _tone;

  static double _toneTarget(GlassTabBarTone tone) =>
      tone == GlassTabBarTone.canvas ? 1 : 0;

  @override
  void initState() {
    super.initState();
    _position = AnimationController.unbounded(
      vsync: this,
      value: widget.selectedIndex.toDouble(),
    );
    _tone = AnimationController.unbounded(
      vsync: this,
      value: _toneTarget(widget.tone),
    );
  }

  @override
  void didUpdateWidget(GlassTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tone != widget.tone) _animateTone();
    if (oldWidget.selectedIndex == widget.selectedIndex) return;
    final target = widget.selectedIndex.toDouble();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _position.value = target;
      return;
    }

    final v = _position.velocity;
    final from = _position.value;
    final away = (target > from && v < 0) || (target < from && v > 0);
    _position
        .springTo(
          target,
          CameoMotion.tabIndicatorSpring,
          velocity: away ? 0 : v,
        )
        .then((_) {
          if (mounted) _position.value = target;
        });
  }

  void _animateTone() {
    final target = _toneTarget(widget.tone);
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _tone.value = target;
      return;
    }
    final v = _tone.velocity;
    final x = _tone.value;
    final away = (target > x && v < 0) || (target < x && v > 0);
    _tone.springTo(
      target,
      CameoMotion.tabBarToneSpring,
      velocity: away ? 0 : v,
    );
  }

  @override
  void dispose() {
    _position.dispose();
    _tone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: SizedBox(
        key: const ValueKey('glassTabBar.container'),
        width: double.infinity,
        height: CameoLayout.tabBarContainerHeight,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            CameoLayout.tabBarContainerPaddingX,
            CameoLayout.tabBarContainerPaddingTop,
            CameoLayout.tabBarContainerPaddingX,
            CameoLayout.tabBarContainerPaddingBottom,
          ),
          child: SizedBox(
            key: const ValueKey('glassTabBar.pill'),
            height: CameoLayout.tabBarPillHeight,
            child: AnimatedBuilder(
              animation: _tone,
              builder: (context, _) {
                final colors = glassTabBarToneColors(
                  CameoTheme.colorsOf(context),
                  _tone.value,
                );

                return GlassBackdrop(
                  tone: widget.tone == GlassTabBarTone.canvas
                      ? GlassBackdropTone.fromToken(
                          CameoEffects.liquidGlassBackdropCanvasScreen,
                        )
                      : GlassBackdropTone.defaultTone,
                  child: GlassSurface(
                    blur: CameoBlur.glassTabBar,
                    tint: colors.tint,
                    borderWidth: CameoLayout.tabBarPillBorderWidth,
                    radius: CameoLayout.tabBarPillRadius,
                    padding: const EdgeInsets.all(
                      CameoLayout.tabBarPillPadding,
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) =>
                          _tabs(_tabWidth(constraints.maxWidth), colors.icon),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  static double _tabWidth(double contentWidth) {
    final n = glassTabBarLabels.length;
    return math.max(
      0,
      (contentWidth - CameoLayout.tabBarPillGap * (n - 1)) / n,
    );
  }

  Widget _tabs(double tabWidth, Color iconColor) {
    final stride = tabWidth + CameoLayout.tabBarPillGap;
    return Semantics(
      role: SemanticsRole.tabBar,
      container: true,
      explicitChildNodes: true,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            width: tabWidth,
            height: CameoLayout.tabBarTabHeight,
            child: _indicator(stride),
          ),
          Row(
            spacing: CameoLayout.tabBarPillGap,
            children: [
              for (var i = 0; i < glassTabBarLabels.length; i++)
                Expanded(child: _tab(i, iconColor)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _indicator(double stride) {
    return AnimatedBuilder(
      animation: _position,
      builder: (context, child) {
        final s = tabIndicatorStretch(_position.velocity * stride);
        final m = Matrix4.identity()
          ..translateByDouble(_position.value * stride, 0, 0, 1)
          ..scaleByDouble(s.sx, s.sy, 1, 1);
        return Transform(
          alignment: Alignment.center,
          transform: m,
          child: child,
        );
      },
      child: DecoratedBox(
        key: const ValueKey('glassTabBar.indicator'),
        decoration: BoxDecoration(
          color: CameoTheme.colorsOf(context).tabBarSelected,
          borderRadius: const BorderRadius.all(
            Radius.circular(CameoLayout.tabBarTabRadius),
          ),
        ),
      ),
    );
  }

  Widget _tab(int index, Color iconColor) {
    final onSelect = widget.onSelect;
    final onPress = onSelect == null ? null : () => onSelect(index);
    final icon = _icons[index] ?? (index == 0 ? widget.avatarIcon : null);
    return Semantics(
      role: SemanticsRole.tab,
      selected: index == widget.selectedIndex,
      enabled: onPress != null,
      label: glassTabBarLabels[index],
      onTap: onPress,
      excludeSemantics: true,
      child: GlassPressable(
        onPress: onPress,
        accessibilityLabel: glassTabBarLabels[index],
        child: SizedBox(
          key: ValueKey('glassTabBar.tab.$index'),
          height: CameoLayout.tabBarTabHeight,
          child: Padding(
            padding: const EdgeInsets.all(CameoLayout.tabBarTabPadding),
            child: Center(
              child: icon == null
                  ? _avatar()
                  : CameoIcon(
                      icon,
                      size: CameoLayout.tabBarTabIconSize,
                      color: iconColor,
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _avatar() {
    const inset =
        (CameoLayout.tabBarTabIconSize - CameoLayout.tabBarAvatarSize) / 2 +
        CameoLayout.tabBarAvatarOffset;
    return SizedBox.square(
      dimension: CameoLayout.tabBarTabIconSize,
      child: ClipRect(
        child: Stack(
          children: [
            Positioned(
              left: inset,
              top: inset,
              width: CameoLayout.tabBarAvatarSize,
              height: CameoLayout.tabBarAvatarSize,
              child: ClipRRect(
                key: const ValueKey('glassTabBar.avatar'),
                borderRadius: const BorderRadius.all(
                  Radius.circular(CameoLayout.tabBarAvatarRadius),
                ),
                child: Image.asset(widget.avatar, fit: BoxFit.cover),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
