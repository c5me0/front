// Persistent Liquid Glass call controls. Active icons reflect their associated panel
// state; sleep-mode transitions move the bar without fading the glass.

import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';

import '../content/lab.g.dart';
import '../design_system/design_system.dart';
import 'call_camera_geometry.dart';
import 'outside_shadow.dart';

enum CallBarSlot { volume, microphone, camera, highlight, end }

CameoIconName _iconOf(String name) => CameoIconName.values.firstWhere(
  (i) => i.key == name,
  orElse: () => CameoIconName.x,
);

final List<({CallBarSlot slot, CameoIconName icon, String label})>
callBarV6Slots = [
  for (final (i, s) in const [
    (CallBarSlot.volume, '볼륨'),
    (CallBarSlot.microphone, '마이크'),
    (CallBarSlot.camera, '사진 보내기'),
    (CallBarSlot.highlight, '전후 15초 하이라이트 저장'),
    (CallBarSlot.end, '통화 종료'),
  ].indexed)
    (slot: s.$1, icon: _iconOf(labV6.call.barIcons[i]), label: s.$2),
];

class CallBarV6 extends StatelessWidget {
  const CallBarV6({super.key, this.selected = const {}, required this.onPress});

  final Set<CallBarSlot> selected;
  final ValueChanged<CallBarSlot> onPress;

  static const Key containerKey = ValueKey('callBarV6');
  static const Key fadeKey = ValueKey('callBarV6.fade');
  static const Key barKey = ValueKey('callBarV6.bar');
  static Key slotKey(CallBarSlot slot) => ValueKey('callBarV6.${slot.name}');

  @override
  Widget build(BuildContext context) {
    final c = CameoTheme.colorsOf(context);
    const dark = CameoPalette.dark;
    const bw = CameoLayout.callV6BottomNavBarBorderWidth;
    final w = MediaQuery.sizeOf(context).width;
    return SizedBox(
      key: containerKey,
      height: CameoLayout.callV6BottomNavHeight,
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: CameoBlur.blur.sigma,
                    sigmaY: CameoBlur.blur.sigma,
                  ),
                  child: DecoratedBox(
                    key: fadeKey,
                    decoration: BoxDecoration(
                      gradient: c.gradients.sectionFadeBottomV6,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: CameoLayout.callV6BottomNavPaddingX,
            top: CameoLayout.callV6BottomNavPaddingTop,
            width: callBarWidth(w),
            height: CameoLayout.callV6BottomNavBarHeight,
            child: OutsideShadow(
              shadow: dark.shadows.scrim,
              radius: CameoLayout.callV6BottomNavBarRadius,
              child: GlassSurface(
                key: barKey,
                blur: CameoBlur.scrim,
                tint: dark.backgroundFillScrimBase,
                border: dark.borderScrim,
                borderWidth: bw,
                radius: CameoLayout.callV6BottomNavBarRadius,

                padding: const EdgeInsets.all(
                  CameoLayout.callV6BottomNavBarPadding - bw,
                ),
                child: Row(
                  children: [
                    for (final s in callBarV6Slots)
                      Expanded(
                        child: _CallBarItem(
                          key: slotKey(s.slot),
                          slot: s.slot,
                          icon: s.icon,
                          label:
                              s.slot == CallBarSlot.microphone &&
                                  selected.contains(CallBarSlot.microphone)
                              ? '마이크 켜기'
                              : s.label,
                          selected:
                              s.slot != CallBarSlot.end &&
                              selected.contains(s.slot),
                          onPress: () => onPress(s.slot),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CallBarItem extends StatefulWidget {
  const _CallBarItem({
    super.key,
    required this.slot,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onPress,
  });

  final CallBarSlot slot;
  final CameoIconName icon;
  final String label;
  final bool selected;
  final VoidCallback onPress;

  @override
  State<_CallBarItem> createState() => _CallBarItemState();
}

class _CallBarItemState extends State<_CallBarItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _on;

  @override
  void initState() {
    super.initState();
    _on = AnimationController(
      vsync: this,
      duration: CameoMotion.durationFast,
      value: widget.selected ? 1 : 0,
    );
  }

  @override
  void didUpdateWidget(_CallBarItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected == oldWidget.selected) return;
    final to = widget.selected ? 1.0 : 0.0;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _on
        ..stop()
        ..value = to;
      return;
    }
    _on.animateTo(to, curve: CameoMotion.easingStandard);
  }

  @override
  void dispose() {
    _on.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const dark = CameoPalette.dark;
    final end = widget.slot == CallBarSlot.end;
    final Widget icon = end
        ? CameoIcon(
            widget.icon,
            size: CameoLayout.callV6BottomNavIconSize,
            color: dark.staticWhiteBase,
          )
        : AnimatedBuilder(
            animation: _on,
            builder: (context, _) => CameoIcon(
              widget.icon,
              size: CameoLayout.callV6BottomNavIconSize,
              color: Color.lerp(
                dark.foregroundNeutralSubtle,
                dark.foregroundNeutralBase,
                _on.value,
              )!,
            ),
          );
    return Semantics(
      selected: end ? null : widget.selected,
      child: GlassPressable(
        onPress: widget.onPress,
        accessibilityLabel: widget.label,
        pressedColor:
            (end ? CameoPalette.light : dark).backgroundFillScrimInteraction,
        pressedRadius: CameoLayout.callV6BottomNavItemRadius,
        child: SizedBox(
          height: CameoLayout.callV6BottomNavItemHeight,
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: end ? dark.systemRed : null,
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(
                  CameoLayout.callV6BottomNavItemRadius,
                ),
              ),
            ),
            child: Center(child: icon),
          ),
        ),
      ),
    );
  }
}
