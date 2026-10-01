// Legacy call control variants retained for preview routes. Resolve layout and colors
// from each variant's token group.

import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import '../content/app.g.dart';

import '../design_system/design_system.dart';

enum CallControlBarVariant { regular, v1 }

enum CallControlKey { volume, microphone, camera, rewind }

@immutable
class CallControlActive {
  const CallControlActive({
    this.volume = false,
    this.microphone = false,
    this.camera = false,
    this.rewind = false,
  });

  static const CallControlActive none = CallControlActive();

  final bool volume;
  final bool microphone;
  final bool camera;
  final bool rewind;

  bool operator [](CallControlKey key) => switch (key) {
    CallControlKey.volume => volume,
    CallControlKey.microphone => microphone,
    CallControlKey.camera => camera,
    CallControlKey.rewind => rewind,
  };

  CallControlActive toggled(CallControlKey key) => CallControlActive(
    volume: key == CallControlKey.volume ? !volume : volume,
    microphone: key == CallControlKey.microphone ? !microphone : microphone,
    camera: key == CallControlKey.camera ? !camera : camera,
    rewind: key == CallControlKey.rewind ? !rewind : rewind,
  );

  @override
  bool operator ==(Object other) =>
      other is CallControlActive &&
      other.volume == volume &&
      other.microphone == microphone &&
      other.camera == camera &&
      other.rewind == rewind;

  @override
  int get hashCode => Object.hash(volume, microphone, camera, rewind);
}

typedef CallControlBarLayout = ({double top, double height});

typedef _Spec = ({
  double containerPaddingTop,
  double containerPaddingX,
  double containerPaddingBottom,
  double containerHeight,
  double barPadding,
  double barHeight,
  double barBorderWidth,
  double barRadius,
  int buttonFlex,
  double buttonPadding,
  double buttonHeight,
  double buttonRadius,
  double buttonIconSize,
  double endWidth,
  double endPadding,
  double endHeight,
  double endRadius,
  double endIconSize,
  CameoBlur blur,
});

({Color tint, Color? border}) _barRoles(
  CameoPalette c,
  CallControlBarVariant variant,
) => switch (variant) {
  CallControlBarVariant.regular => (
    tint: c.glassTintBar,
    border: c.glassBorderBar,
  ),
  CallControlBarVariant.v1 => (tint: c.glassTintV1, border: null),
};

_Spec _spec(CallControlBarVariant variant) => switch (variant) {
  CallControlBarVariant.regular => (
    containerPaddingTop: CameoLayout.callControlBarContainerPaddingTop,
    containerPaddingX: CameoLayout.callControlBarContainerPaddingX,
    containerPaddingBottom: CameoLayout.callControlBarContainerPaddingBottom,
    containerHeight: CameoLayout.callControlBarContainerHeight,
    barPadding: CameoLayout.callControlBarBarPadding,
    barHeight: CameoLayout.callControlBarBarHeight,
    barBorderWidth: CameoLayout.callControlBarBarBorderWidth,
    barRadius: CameoLayout.callControlBarBarRadius,
    buttonFlex: CameoLayout.callControlBarButtonFlex,
    buttonPadding: CameoLayout.callControlBarButtonPadding,
    buttonHeight: CameoLayout.callControlBarButtonHeight,
    buttonRadius: CameoLayout.callControlBarButtonRadius,
    buttonIconSize: CameoLayout.callControlBarButtonIconSize,
    endWidth: CameoLayout.callControlBarEndButtonWidth,
    endPadding: CameoLayout.callControlBarEndButtonPadding,
    endHeight: CameoLayout.callControlBarEndButtonHeight,
    endRadius: CameoLayout.callControlBarEndButtonRadius,
    endIconSize: CameoLayout.callControlBarEndButtonIconSize,
    blur: CameoBlur.glassBar,
  ),
  CallControlBarVariant.v1 => (
    containerPaddingTop: CameoLayout.callControlBarV1ContainerPaddingTop,
    containerPaddingX: CameoLayout.callControlBarV1ContainerPaddingX,
    containerPaddingBottom: CameoLayout.callControlBarV1ContainerPaddingBottom,
    containerHeight: CameoLayout.callControlBarV1ContainerHeight,
    barPadding: CameoLayout.callControlBarV1BarPadding,
    barHeight: CameoLayout.callControlBarV1BarHeight,
    barBorderWidth: CameoLayout.callControlBarV1BarBorderWidth,
    barRadius: CameoLayout.callControlBarV1BarRadius,
    buttonFlex: CameoLayout.callControlBarV1ButtonFlex,
    buttonPadding: CameoLayout.callControlBarV1ButtonPadding,
    buttonHeight: CameoLayout.callControlBarV1ButtonHeight,
    buttonRadius: CameoLayout.callControlBarV1ButtonRadius,
    buttonIconSize: CameoLayout.callControlBarV1ButtonIconSize,
    endWidth: CameoLayout.callControlBarV1EndButtonWidth,
    endPadding: CameoLayout.callControlBarV1EndButtonPadding,
    endHeight: CameoLayout.callControlBarV1EndButtonHeight,
    endRadius: CameoLayout.callControlBarV1EndButtonRadius,
    endIconSize: CameoLayout.callControlBarV1EndButtonIconSize,
    blur: CameoBlur.glassFigma,
  ),
};

({Color iconInactive, Color iconActive, Color endFill, Color endIcon})
_controlRoles(CameoPalette c) => (
  iconInactive: c.foregroundNeutralInverseSubtle,
  iconActive: c.foregroundNeutralInverseBase,
  endFill: c.backgroundCriticalBase,
  endIcon: c.foregroundNeutralInverseBase,
);

({CameoIconName icon, String label}) _control(
  CallControlKey key,
  AppContent copy,
) => switch (key) {
  CallControlKey.volume => (
    icon: CameoIconName.volume,
    label: copy.v6.accessibility.speaker,
  ),
  CallControlKey.microphone => (
    icon: CameoIconName.microphone,
    label: copy.v6.accessibility.microphone,
  ),
  CallControlKey.camera => (
    icon: CameoIconName.camera,
    label: copy.v6.tabBar.cameraLabel,
  ),
  CallControlKey.rewind => (
    icon: CameoIconName.rewindBackward15,
    label: copy.v6.accessibility.rewind,
  ),
};

String _toggleLabel(CallControlKey key, bool on, AppContent copy) =>
    '${_control(key, copy).label}, ${on ? copy.v6.accessibility.on : copy.v6.accessibility.off}';

double callControlBarContainerHeight({
  CallControlBarVariant variant = CallControlBarVariant.regular,
  double bottomInset = 0,
}) {
  final s = _spec(variant);
  return s.containerHeight -
      s.containerPaddingBottom +
      math.max(bottomInset, s.containerPaddingBottom);
}

double callControlBarContainerHeightOf(
  BuildContext context, {
  CallControlBarVariant variant = CallControlBarVariant.regular,
}) => callControlBarContainerHeight(
  variant: variant,
  bottomInset: (MediaQuery.maybePaddingOf(context) ?? EdgeInsets.zero).bottom,
);

class CallControlBar extends StatefulWidget {
  const CallControlBar({
    super.key,
    this.variant = CallControlBarVariant.regular,
    this.active = CallControlActive.none,
    this.onToggle,
    this.onEndCall,
    this.bottomInset,
    this.positioned = true,
    this.onLayout,
  });

  final CallControlBarVariant variant;

  final CallControlActive active;

  final ValueChanged<CallControlKey>? onToggle;

  final VoidCallback? onEndCall;

  final double? bottomInset;

  final bool positioned;

  final ValueChanged<CallControlBarLayout>? onLayout;

  @override
  State<CallControlBar> createState() => _CallControlBarState();
}

class _CallControlBarState extends State<CallControlBar> {
  CallControlBarLayout? _reported;

  void _scheduleReport() {
    if (widget.onLayout == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.onLayout == null) return;
      final box = context.findRenderObject();
      if (box is! RenderBox || !box.hasSize) return;
      final parent = box.parent;
      final top = box
          .localToGlobal(
            Offset.zero,
            ancestor: parent is RenderBox ? parent : null,
          )
          .dy;
      final next = (top: top, height: box.size.height);
      if (next == _reported) return;
      _reported = next;
      widget.onLayout!(next);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = _spec(widget.variant);
    final palette = CameoTheme.colorsOf(context);
    final barRoles = _barRoles(palette, widget.variant);
    final roles = _controlRoles(palette);
    final safeBottom =
        (MediaQuery.maybePaddingOf(context) ?? EdgeInsets.zero).bottom;

    if (widget.onLayout != null) MediaQuery.maybeSizeOf(context);
    _scheduleReport();

    Widget bar = Padding(
      padding: EdgeInsets.fromLTRB(
        s.containerPaddingX,
        s.containerPaddingTop,
        s.containerPaddingX,
        math.max(widget.bottomInset ?? safeBottom, s.containerPaddingBottom),
      ),
      child: SizedBox(
        height: s.barHeight,
        child: GlassSurface(
          blur: s.blur,
          tint: barRoles.tint,
          border: barRoles.border,
          borderWidth: s.barBorderWidth,
          radius: s.barRadius,
          padding: EdgeInsets.all(s.barPadding),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final key in CallControlKey.values)
                Expanded(
                  flex: s.buttonFlex,
                  child: PressScale(
                    onPress: widget.onToggle == null
                        ? null
                        : () => widget.onToggle!(key),
                    accessibilityLabel: _toggleLabel(
                      key,
                      widget.active[key],
                      AppContent.of(context),
                    ),
                    child: SizedBox(
                      height: s.buttonHeight,
                      child: Padding(
                        padding: EdgeInsets.all(s.buttonPadding),
                        child: Center(
                          child: _ToggleIcon(
                            icon: _control(key, AppContent.of(context)).icon,
                            size: s.buttonIconSize,
                            active: widget.active[key],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              PressScale(
                onPress: widget.onEndCall,
                accessibilityLabel: AppContent.of(
                  context,
                ).v6.accessibility.endCall,
                child: SizedBox(
                  width: s.endWidth,
                  height: s.endHeight,
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: roles.endFill,
                      shape: RoundedSuperellipseBorder(
                        borderRadius: BorderRadius.circular(s.endRadius),
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(s.endPadding),
                      child: Center(
                        child: CameoIcon(
                          CameoIconName.x,
                          size: s.endIconSize,
                          color: roles.endIcon,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (widget.positioned) {
      bar = Positioned(left: 0, right: 0, bottom: 0, child: bar);
    }
    return bar;
  }
}

class _Clamp01 extends Animatable<double> {
  const _Clamp01();

  @override
  double transform(double t) => t.clamp(0.0, 1.0);
}

class _ToggleIcon extends StatefulWidget {
  const _ToggleIcon({
    required this.icon,
    required this.size,
    required this.active,
  });

  final CameoIconName icon;
  final double size;
  final bool active;

  @override
  State<_ToggleIcon> createState() => _ToggleIconState();
}

class _ToggleIconState extends State<_ToggleIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _p = AnimationController.unbounded(
    vsync: this,
    value: widget.active ? 1 : 0,
  );
  late final Animation<double> _opacity = _p.drive(const _Clamp01());

  @override
  void didUpdateWidget(_ToggleIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active == widget.active) return;
    final target = widget.active ? 1.0 : 0.0;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _p.animateTo(
        target,
        duration: CameoMotion.durationBase,
        curve: CameoMotion.easingStandard,
      );
    } else {
      _p.springTo(target, CameoMotion.controlToggleSpring);
    }
  }

  @override
  void dispose() {
    _p.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final roles = _controlRoles(CameoTheme.colorsOf(context));
    return SizedBox.square(
      dimension: widget.size,
      child: Stack(
        children: [
          CameoIcon(widget.icon, size: widget.size, color: roles.iconInactive),
          FadeTransition(
            opacity: _opacity,
            child: CameoIcon(
              widget.icon,
              size: widget.size,
              color: roles.iconActive,
            ),
          ),
        ],
      ),
    );
  }
}
