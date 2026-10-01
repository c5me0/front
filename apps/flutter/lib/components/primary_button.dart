// Retained confirmation button variants with pressed surfaces and spring feedback. New
// v6 screens use SolidButton.

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../content/app.g.dart';
import '../design_system/design_system.dart';

enum PrimaryButtonVariant { prominent, secondary, destructive }

typedef PrimaryButtonRoles = ({Color tint, Color label});

///  prominent = background/neutral/inverse + foreground/neutral/inverse/base
///  secondary = glass/tint-compact + foreground/neutral/base
///  destructive = background/critical/base + static/white
PrimaryButtonRoles primaryButtonRoles(
  CameoPalette palette,
  PrimaryButtonVariant variant,
) => switch (variant) {
  PrimaryButtonVariant.prominent => (
    tint: palette.backgroundNeutralInverse,
    label: palette.foregroundNeutralInverseBase,
  ),
  PrimaryButtonVariant.secondary => (
    tint: palette.glassTintCompact,
    label: palette.foregroundNeutralBase,
  ),
  PrimaryButtonVariant.destructive => (
    tint: palette.backgroundCriticalBase,
    label: palette.staticWhite,
  ),
};

PrimaryButtonRoles primaryButtonDisabledRoles(CameoPalette palette) => (
  tint: palette.backgroundNeutralSubtle,
  label: palette.foregroundNeutralSubtle,
);

///  phase = ((t − i · loadingStagger) / loadingCycle) mod 1,  y = −loadingRise · sin²(π · phase)

double primaryButtonDotOffset(int index, Duration t) {
  final cycle = CameoMotion.primaryButtonLoadingCycle.inMicroseconds;
  final shifted =
      t.inMicroseconds -
      index * CameoMotion.primaryButtonLoadingStagger.inMicroseconds;
  final phase = (shifted % cycle) / cycle;
  final s = math.sin(math.pi * phase);
  return -CameoMotion.primaryButtonLoadingRise * s * s;
}

///

///   AppContent.of(context).common.loading).
class PrimaryButton extends StatefulWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPress,
    this.variant = PrimaryButtonVariant.prominent,
    this.disabled = false,
    this.loading = false,
    this.fullWidth = true,
    this.accessibilityLabel,
  });

  final String label;
  final VoidCallback? onPress;
  final PrimaryButtonVariant variant;
  final bool disabled;
  final bool loading;
  final bool fullWidth;
  final String? accessibilityLabel;

  static const Key surfaceKey = ValueKey('primaryButton.surface');

  static const Key labelKey = ValueKey('primaryButton.label');

  static Key dotKey(int index) => ValueKey('primaryButton.dot.$index');

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton>
    with TickerProviderStateMixin {
  late final AnimationController _enabled = AnimationController.unbounded(
    vsync: this,
    value: widget.disabled ? 0 : 1,
  );

  late final AnimationController _loadingFade = AnimationController(
    vsync: this,
    duration: CameoMotion.primaryButtonLabelFade,
    value: widget.loading ? 1 : 0,
  );

  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: CameoMotion.primaryButtonLoadingCycle,
  );

  late final Listenable _all = Listenable.merge([
    _enabled,
    _loadingFade,
    _loop,
  ]);

  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _syncLoop();
  }

  @override
  void didUpdateWidget(PrimaryButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.disabled != widget.disabled) {
      final target = widget.disabled ? 0.0 : 1.0;
      if (_reduceMotion) {
        _enabled.animateTo(
          target,
          duration: CameoMotion.durationBase,
          curve: CameoMotion.easingStandard,
        );
      } else {
        final v = _enabled.velocity;
        final x = _enabled.value;
        final away = (target > x && v < 0) || (target < x && v > 0);
        _enabled.springTo(
          target,
          CameoMotion.primaryButtonEnableSpring,
          velocity: away ? 0 : v,
        );
      }
    }
    if (oldWidget.loading != widget.loading) {
      if (widget.loading) {
        _loadingFade.forward();
      } else {
        _loadingFade.reverse().then((_) => _syncLoop());
      }
      _syncLoop();
    }
  }

  void _syncLoop() {
    final run = !_reduceMotion && (widget.loading || _loadingFade.value > 0);
    if (run && !_loop.isAnimating) {
      _loop.repeat();
    } else if (!run && _loop.isAnimating) {
      _loop.stop();
      _loop.value = 0;
    }
  }

  @override
  void dispose() {
    _enabled.dispose();
    _loadingFade.dispose();
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = CameoTheme.colorsOf(context);
    final on = primaryButtonRoles(palette, widget.variant);
    final off = primaryButtonDisabledRoles(palette);
    final interactive = !widget.disabled && !widget.loading;
    final label = widget.accessibilityLabel ?? widget.label;

    final content = AnimatedBuilder(
      animation: _all,
      builder: (context, _) {
        final p = _enabled.value.clamp(0.0, 1.0);
        final tint = Color.lerp(off.tint, on.tint, p)!;
        final labelColor = Color.lerp(off.label, on.label, p)!;
        final f = _loadingFade.value;
        final t = CameoMotion.primaryButtonLoadingCycle * _loop.value;
        return GlassSurface(
          key: PrimaryButton.surfaceKey,
          blur: CameoBlur.glassNav,
          tint: tint,
          radius: CameoLayout.primaryButtonRadius,
          padding: const EdgeInsets.symmetric(
            horizontal: CameoLayout.primaryButtonPaddingX,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                key: PrimaryButton.labelKey,
                opacity: 1 - f,
                child: CameoText(
                  widget.label,
                  style: CameoTextStyles.bodyLgStrong,
                  color: labelColor,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                ),
              ),
              Opacity(
                opacity: f,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: CameoLayout.primaryButtonLoadingDotGap,
                  children: [
                    for (var i = 0; i < 3; i++)
                      Transform.translate(
                        key: PrimaryButton.dotKey(i),
                        offset: Offset(
                          0,
                          _reduceMotion ? 0 : primaryButtonDotOffset(i, t),
                        ),
                        child: SizedBox.square(
                          dimension: CameoLayout.primaryButtonLoadingDotSize,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: labelColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );

    return Semantics(
      container: true,
      button: true,
      enabled: !widget.disabled,
      label: widget.loading
          ? '$label, ${AppContent.of(context).common.loading}'
          : label,
      onTap: interactive ? widget.onPress : null,
      excludeSemantics: true,
      child: IgnorePointer(
        ignoring: !interactive,
        child: GlassPressable(
          onPress: interactive ? widget.onPress : null,
          pressedColor:
              (widget.variant == PrimaryButtonVariant.prominent
                      ? CameoPalette.of(
                          CameoTheme.modeOf(context) == CameoColorMode.light
                              ? CameoColorMode.dark
                              : CameoColorMode.light,
                        )
                      : CameoTheme.colorsOf(context))
                  .backgroundFillScrimInteraction,
          pressedRadius: CameoLayout.primaryButtonRadius,
          child: SizedBox(
            width: widget.fullWidth ? double.infinity : null,
            height: CameoLayout.primaryButtonHeight,
            child: content,
          ),
        ),
      ),
    );
  }
}
