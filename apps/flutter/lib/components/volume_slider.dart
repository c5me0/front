// Call volume slider backed by the volume service. Track system changes, provide
// accessible adjustment, and cancel obsolete drag updates.

import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import '../content/app.g.dart';

import '../design_system/design_system.dart';
import '../state/volume_service.dart';
import 'call_camera_geometry.dart';
import 'outside_shadow.dart';

enum VolumeSliderInteraction { start, end }

class VolumeSlider extends StatefulWidget {
  const VolumeSlider({
    super.key,
    required this.visible,
    this.onShown,
    this.onHidden,
    this.onInteraction,
    this.volume,
  });

  final bool visible;

  final VoidCallback? onShown;
  final VoidCallback? onHidden;
  final ValueChanged<VolumeSliderInteraction>? onInteraction;

  final VolumeService? volume;

  static const Key pillKey = ValueKey('volumeSlider.pill');
  static const Key trackKey = ValueKey('volumeSlider.track');
  static const Key fillKey = ValueKey('volumeSlider.fill');
  static const Key thumbKey = ValueKey('volumeSlider.thumb');

  @override
  State<VolumeSlider> createState() => VolumeSliderState();
}

class VolumeSliderState extends State<VolumeSlider>
    with TickerProviderStateMixin {
  late final AnimationController _appear = AnimationController.unbounded(
    vsync: this,
  );

  late final AnimationController _level = AnimationController.unbounded(
    vsync: this,
  );

  late final AnimationController _grab = AnimationController.unbounded(
    vsync: this,
    value: 1,
  );

  VolumeService? _service;
  StreamSubscription<double>? _subscription;
  bool _dragging = false;
  bool _started = false;
  bool _reduceMotion = false;

  double get level => _level.value;

  double get appear => _appear.value;

  VolumeService get _volume => widget.volume ?? VolumeService.of(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _bind(_volume);
    if (!_started) {
      _started = true;
      if (widget.visible) _show();
    }
  }

  @override
  void didUpdateWidget(VolumeSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    _bind(_volume);
    if (widget.visible != oldWidget.visible) {
      widget.visible ? _show() : _hide();
    }
  }

  void _bind(VolumeService service) {
    if (identical(service, _service)) return;
    _subscription?.cancel();
    _service = service;
    _subscription = service.stream.listen(_onVolume);
    service.get().then((v) {
      if (mounted && identical(_service, service) && !_dragging) {
        _level.value = v;
      }
    });
  }

  void _onVolume(double v) {
    if (!mounted || _dragging) return;
    _level.stop();
    _level.value = v;
    setState(() {});
  }

  void _spring(
    AnimationController controller,
    double target,
    SpringDescription spring, {
    VoidCallback? onDone,
  }) {
    if (_reduceMotion) {
      controller.value = target;
      onDone?.call();
      return;
    }
    final v = controller.velocity;
    final x = controller.value;
    final away = (target > x && v < 0) || (target < x && v > 0);
    controller.springTo(target, spring, velocity: away ? 0 : v).then((_) {
      if (!mounted || controller.isAnimating) return;
      controller.value = target;
      onDone?.call();
    });
  }

  void _show() => _spring(
    _appear,
    1,
    CameoMotion.sliderAppearSpring,
    onDone: () {
      if (widget.visible) widget.onShown?.call();
    },
  );

  void _hide() => _spring(
    _appear,
    0,
    CameoMotion.sliderExitSpring,
    onDone: () {
      if (!widget.visible) widget.onHidden?.call();
    },
  );

  void _setFromPill(Offset local) {
    final v = sliderValueAt(local.dx - sliderTrackInset);
    _spring(_level, v, CameoMotion.sliderDragSpring);
    _volume.set(v);
  }

  void _onStart(DragStartDetails d) {
    if (!widget.visible) return;
    _dragging = true;
    _spring(_grab, CameoMotion.sliderGrabScale, CameoMotion.sliderDragSpring);
    _setFromPill(d.localPosition);
    widget.onInteraction?.call(VolumeSliderInteraction.start);
  }

  void _onUpdate(DragUpdateDetails d) {
    if (!_dragging) return;
    _setFromPill(d.localPosition);
  }

  void _onEnd() {
    if (!_dragging) return;
    _dragging = false;
    _spring(_grab, 1, CameoMotion.sliderDragSpring);
    widget.onInteraction?.call(VolumeSliderInteraction.end);
  }

  void _step(double delta) {
    final next = (_level.value + delta).clamp(0.0, 1.0);
    _volume.set(next);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _appear.dispose();
    _level.dispose();
    _grab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = CameoTheme.colorsOf(context);

    const dark = CameoPalette.dark;
    const bw = CameoLayout.sliderV6PillBorderWidth;
    const step = CameoMotion.sleepVolumeTarget;
    final percent = (_level.value.clamp(0.0, 1.0) * 100).round();
    final track = SizedBox(
      key: VolumeSlider.trackKey,
      width: CameoLayout.sliderV6TrackWidth,
      height: CameoLayout.sliderV6TrackHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: dark.backgroundFillNeutralBase,
                shape: const StadiumBorder(),
              ),
            ),
          ),
          AnimatedBuilder(
            animation: Listenable.merge([_level, _grab]),
            builder: (context, _) {
              final v = _level.value;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    key: VolumeSlider.fillKey,
                    left: CameoLayout.sliderV6FillLeft,
                    top: 0,
                    width: sliderFillWidth(v),
                    height: CameoLayout.sliderV6TrackHeight,
                    child: DecoratedBox(
                      decoration: ShapeDecoration(
                        color: dark.backgroundFillNeutralInverted,
                        shape: const StadiumBorder(),
                      ),
                    ),
                  ),
                  Positioned(
                    key: VolumeSlider.thumbKey,
                    left: sliderThumbLeft(v),
                    top:
                        (CameoLayout.sliderV6TrackHeight -
                            CameoLayout.sliderV6ThumbSize) /
                        2,
                    width: CameoLayout.sliderV6ThumbSize,
                    height: CameoLayout.sliderV6ThumbSize,
                    child: Transform.scale(
                      scale: _grab.value,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: c.staticWhiteBase,
                          shape: BoxShape.circle,
                          boxShadow: [c.shadows.shadow],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
    final pill = OutsideShadow(
      shadow: dark.shadows.scrim,
      radius: CameoLayout.sliderV6PillRadius,
      child: SizedBox(
        key: VolumeSlider.pillKey,
        width: CameoLayout.sliderV6PillWidth,
        height: CameoLayout.sliderV6PillHeight,
        child: GlassSurface(
          blur: CameoBlur.scrim,
          tint: dark.backgroundFillScrimBase,
          border: dark.borderScrim,
          borderWidth: bw,
          radius: CameoLayout.sliderV6PillRadius,

          padding: const EdgeInsets.symmetric(
            horizontal: CameoLayout.sliderV6PillPadding,
          ),
          child: Center(child: track),
        ),
      ),
    );
    return SizedBox(
      height: CameoLayout.sliderV6ContainerHeight,
      child: Center(
        child: IgnorePointer(
          ignoring: !widget.visible,
          child: Semantics(
            slider: true,
            label: AppContent.of(context).v6.accessibility.volume,
            value: '$percent%',
            increasedValue:
                '${((_level.value + step).clamp(0.0, 1.0) * 100).round()}%',
            decreasedValue:
                '${((_level.value - step).clamp(0.0, 1.0) * 100).round()}%',
            onIncrease: () => _step(step),
            onDecrease: () => _step(-step),
            excludeSemantics: true,
            child: RawGestureDetector(
              behavior: HitTestBehavior.opaque,
              gestures: {
                _EagerPanGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<
                      _EagerPanGestureRecognizer
                    >(_EagerPanGestureRecognizer.new, (r) {
                      r
                        ..dragStartBehavior = DragStartBehavior.down
                        ..onStart = _onStart
                        ..onUpdate = _onUpdate
                        ..onCancel = _onEnd
                        ..onEnd = (_) {
                          _onEnd();
                        };
                    }),
              },
              child: AnimatedBuilder(
                animation: _appear,
                child: pill,
                builder: (context, child) {
                  final t = sliderPillTransform(_appear.value);
                  return Transform.translate(
                    offset: Offset(0, t.translateY),
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.diagonal3Values(t.scaleX, t.scaleY, 1),
                      child: child,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// blocksExternalGesture).
class _EagerPanGestureRecognizer extends PanGestureRecognizer {
  _EagerPanGestureRecognizer();

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}
