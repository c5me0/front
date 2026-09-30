// Camera mode selector with a sliding indicator, accessibility selection state, and
// shared spring motion.

import 'dart:math' as math;

import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../design_system/design_system.dart';

@immutable
class SegmentedControlItem<T> {
  const SegmentedControlItem({
    required this.id,
    required this.label,
    this.accessibilityLabel,
  });

  final T id;

  final String label;

  final String? accessibilityLabel;
}

const double _stride =
    CameoLayout.segmentedControlSegmentWidth + CameoLayout.segmentedControlGap;

///

class SegmentedControl<T> extends StatefulWidget {
  const SegmentedControl({
    super.key,
    required this.items,
    required this.selected,
    this.onChanged,
  });

  final List<SegmentedControlItem<T>> items;

  final T selected;

  final ValueChanged<T>? onChanged;

  static const Key pillKey = ValueKey('segmentedControl.pill');

  static Key segmentKey(int index) =>
      ValueKey('segmentedControl.segment.$index');

  @override
  State<SegmentedControl<T>> createState() => _SegmentedControlState<T>();
}

class _SegmentedControlState<T> extends State<SegmentedControl<T>>
    with SingleTickerProviderStateMixin {
  late final AnimationController _position = AnimationController.unbounded(
    vsync: this,
    value: _indexOf(widget).toDouble(),
  );

  static int _indexOf<U>(SegmentedControl<U> w) =>
      math.max(0, w.items.indexWhere((it) => it.id == w.selected));

  @override
  void didUpdateWidget(SegmentedControl<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final from = _indexOf(oldWidget);
    final to = _indexOf(widget);
    if (from == to) return;
    HapticFeedback.selectionClick();
    final target = to.toDouble();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _position.value = target;
      return;
    }

    final v = _position.velocity;
    final p = _position.value;
    final away = (target > p && v < 0) || (target < p && v > 0);
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

  @override
  void dispose() {
    _position.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = CameoTheme.colorsOf(context);
    return SizedBox(
      width: CameoLayout.segmentedControlWidth,
      height: CameoLayout.segmentedControlHeight,
      child: GlassSurface(
        blur: CameoBlur.glassNav,
        tint: palette.glassTint,
        border: palette.strokeNeutralBase,
        borderWidth: CameoLayout.segmentedControlBorderWidth,
        radius: CameoLayout.segmentedControlRadius,
        padding: const EdgeInsets.all(CameoLayout.segmentedControlPadding),
        child: Semantics(
          role: SemanticsRole.tabBar,
          container: true,
          explicitChildNodes: true,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                width: CameoLayout.segmentedControlSegmentWidth,
                height: CameoLayout.segmentedControlSegmentHeight,
                child: _pill(palette),
              ),
              Row(
                spacing: CameoLayout.segmentedControlGap,
                children: [
                  for (var i = 0; i < widget.items.length; i++)
                    Expanded(child: _segment(i, palette)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill(CameoPalette palette) {
    return AnimatedBuilder(
      animation: _position,
      builder: (context, child) {
        final s = tabIndicatorStretch(_position.velocity * _stride);
        final m = Matrix4.identity()
          ..translateByDouble(_position.value * _stride, 0, 0, 1)
          ..scaleByDouble(s.sx, s.sy, 1, 1);
        return Transform(
          alignment: Alignment.center,
          transform: m,
          child: child,
        );
      },
      child: DecoratedBox(
        key: SegmentedControl.pillKey,
        decoration: ShapeDecoration(
          color: palette.backgroundCanvasBase,
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(
              CameoLayout.segmentedControlSegmentRadius,
            ),
          ),
        ),
      ),
    );
  }

  Widget _segment(int index, CameoPalette palette) {
    final item = widget.items[index];
    final onChanged = widget.onChanged;
    final onTap = onChanged == null ? null : () => onChanged(item.id);
    return Semantics(
      role: SemanticsRole.tab,
      selected: index == _indexOf(widget),
      enabled: onTap != null,
      label: item.accessibilityLabel ?? item.label,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        key: SegmentedControl.segmentKey(index),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: CameoLayout.segmentedControlSegmentHeight,
          child: Padding(
            padding: const EdgeInsets.all(
              CameoLayout.segmentedControlSegmentPadding,
            ),
            child: Center(
              child: SizedBox(
                height: CameoLayout.segmentedControlLabelHeight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: CameoLayout.segmentedControlLabelPaddingX,
                  ),
                  child: Center(
                    widthFactor: 1,
                    child: AnimatedBuilder(
                      animation: _position,
                      builder: (context, _) => CameoText(
                        item.label,
                        style: CameoTextStyles.bodyLg,
                        color: segmentLabelColor(
                          palette,
                          position: _position.value,
                          index: index,
                        ),
                        maxLines: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Color segmentLabelColor(
  CameoPalette palette, {
  required double position,
  required int index,
}) {
  final activeness = (1 - (position - index).abs()).clamp(0.0, 1.0);
  return Color.lerp(
    palette.foregroundNeutralInverseSubtle,
    palette.foregroundNeutralBase,
    activeness,
  )!;
}
