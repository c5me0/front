// Selection and favorite controls. The legacy design variant named disable=true
// represents the checked state, not a disabled interaction.

//

// HeartControl (22):

import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';
import '../content/app.g.dart';

import '../design_system/design_system.dart';

class SelectControl extends StatefulWidget {
  const SelectControl({
    super.key,
    required this.selected,
    this.showRing = true,
  });

  final bool selected;

  final bool showRing;

  static const Key ringKey = ValueKey('selectControl.ring');
  static const Key discKey = ValueKey('selectControl.disc');

  @override
  State<SelectControl> createState() => _SelectControlState();
}

class _SelectControlState extends State<SelectControl>
    with SingleTickerProviderStateMixin {
  late final AnimationController _disc;

  @override
  void initState() {
    super.initState();
    _disc = AnimationController.unbounded(
      vsync: this,
      value: widget.selected ? 1 : 0,
    );
  }

  @override
  void didUpdateWidget(SelectControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected == widget.selected) return;
    final target = widget.selected ? 1.0 : 0.0;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _disc.value = target;
      return;
    }
    final v = _disc.velocity;
    final x = _disc.value;
    final away = (target > x && v < 0) || (target < x && v > 0);
    _disc.springTo(
      target,
      CameoMotion.selectModeCheckSpring,
      velocity: away ? 0 : v,
    );
  }

  @override
  void dispose() {
    _disc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = CameoTheme.colorsOf(context);
    const size = CameoLayout.controlCheckSize;
    final blur = CameoBlur.shadowV5.sigma;
    return Semantics(
      checked: widget.selected,
      child: SizedBox.square(
        dimension: size,

        child: AnimatedBuilder(
          animation: _disc,
          builder: (context, _) {
            final p = _disc.value;
            return Stack(
              fit: StackFit.expand,
              clipBehavior: Clip.none,
              children: [
                ClipOval(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                    child: p < 1 && widget.showRing
                        ? DecoratedBox(
                            key: SelectControl.ringKey,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: c.staticWhiteBase,
                                width: CameoLayout.controlCheckRingWidth,
                              ),
                            ),
                          )
                        : const SizedBox.expand(),
                  ),
                ),
                if (p > 0)
                  Transform.scale(
                    scale: p,
                    child: DecoratedBox(
                      key: SelectControl.discKey,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: c.staticWhiteBase,
                        boxShadow: [c.shadows.shadowV5],
                      ),
                      child: Center(
                        child: CameoIcon(
                          CameoIconName.check,
                          size: CameoLayout.controlCheckGlyphSize,
                          color: c.staticBlackBase,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class HeartControl extends StatelessWidget {
  const HeartControl({
    super.key,
    required this.active,
    this.onPress,
    this.semanticLabel,
  });

  final bool active;
  final VoidCallback? onPress;
  final String? semanticLabel;

  static const Key shadowKey = ValueKey('heartControl.shadow');

  @override
  Widget build(BuildContext context) {
    final c = CameoTheme.colorsOf(context);
    const size = CameoLayout.controlHeartSize;
    final shadow = c.shadows.heartShadow;
    final sigma = Shadow.convertRadiusToSigma(shadow.blurRadius);
    final heart = SizedBox.square(
      dimension: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (active)
            Positioned.fill(
              child: Transform.translate(
                key: shadowKey,
                offset: shadow.offset,
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                  child: CameoIcon(
                    CameoIconName.heartFilled,
                    size: size,
                    color: shadow.color,
                  ),
                ),
              ),
            ),
          ToggleIcon(
            icon: CameoIconName.heart,
            activeIcon: CameoIconName.heartFilled,
            active: active,
            size: size,
            color: c.staticWhiteBase,
          ),
        ],
      ),
    );
    final label = toggleAccessibilityLabel(
      semanticLabel ?? AppContent.of(context).v6.album.likeLabel,
      active,
      copy: AppContent.of(context),
    );
    final onPress = this.onPress;
    if (onPress == null) {
      return Semantics(label: label, excludeSemantics: true, child: heart);
    }
    return PressScale(
      onPress: onPress,
      accessibilityLabel: label,
      child: heart,
    );
  }
}
