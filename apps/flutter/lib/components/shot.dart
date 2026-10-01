// Camera shutter with tap capture, long-press recording feedback, and a persistent
// glass surface.

// (docs/v6-notes-call-camera-v6.md §RN 5 · §Flutter).

import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import '../content/app.g.dart';

import '../design_system/design_system.dart';
import 'call_camera_geometry.dart';
import 'outside_shadow.dart';

class Shot extends StatefulWidget {
  const Shot({
    super.key,
    this.onPhoto,
    this.onRecordStart,
    this.onRecordEnd,
    this.feedbackKey = 0,
    this.disabled = false,
    this.buttonKey,
  });

  final VoidCallback? onPhoto;

  final VoidCallback? onRecordStart;

  final ValueChanged<Duration>? onRecordEnd;

  final int feedbackKey;
  final bool disabled;

  final Key? buttonKey;

  static const Key ringKey = ValueKey('shot.ring');
  static const Key discKey = ValueKey('shot.disc');
  static const Key baseKey = ValueKey('shot.base');

  @override
  State<Shot> createState() => ShotState();
}

class ShotState extends State<Shot> with TickerProviderStateMixin {
  late final AnimationController _press = AnimationController.unbounded(
    vsync: this,
    value: 1,
  );

  late final AnimationController _disc = AnimationController.unbounded(
    vsync: this,
    value: 1,
    animationBehavior: AnimationBehavior.preserve,
  );
  late final AnimationController _ringWidth = AnimationController.unbounded(
    vsync: this,
  );

  late final AnimationController _ringProgress = AnimationController(
    vsync: this,
    duration: CameoMotion.shotMaxRecord,
    animationBehavior: AnimationBehavior.preserve,
  );

  bool _recording = false;
  bool _reduceMotion = false;

  bool get recording => _recording;

  double get ringProgress => _ringProgress.value;

  double get ringWidth => _ringWidth.value;

  double get pressScale => _press.value;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  }

  @override
  void didUpdateWidget(Shot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.feedbackKey != oldWidget.feedbackKey) _fire();
  }

  void _spring(
    AnimationController c,
    double target,
    SpringDescription spring, {
    VoidCallback? onDone,
  }) {
    if (_reduceMotion) {
      c
        ..stop()
        ..value = target;
      onDone?.call();
      return;
    }
    c.springTo(target, spring).then((_) {
      if (!mounted || c.isAnimating) return;
      c.value = target;
      onDone?.call();
    });
  }

  void _fire() {
    HapticFeedback.mediumImpact();
    _disc
        .animateTo(
          CameoMotion.cameraDiscFlashOpacity,
          duration: CameoMotion.cameraFlashIn,
          curve: CameoMotion.easingDecelerate,
        )
        .then((_) {
          if (!mounted) return;
          _disc.animateTo(
            1,
            duration: CameoMotion.cameraFlashOut,
            curve: CameoMotion.easingStandard,
          );
        });
  }

  void _pressIn() =>
      _spring(_press, CameoMotion.shotPressScale, CameoMotion.shotPressSpring);

  void _pressOut() => _spring(_press, 1, CameoMotion.shotReleaseSpring);

  void _startRecording() {
    if (_recording || widget.disabled) return;
    _recording = true;
    HapticFeedback.mediumImpact();
    _ringProgress
      ..stop()
      ..value = 0;
    _spring(
      _ringWidth,
      CameoLayout.shotV6RingStrokeWidth,
      CameoMotion.shotRingSpring,
    );
    _ringProgress.forward(from: 0).then((_) {
      if (mounted && _recording && _ringProgress.value >= 1) _stopRecording();
    });
    setState(() {});
    widget.onRecordStart?.call();
  }

  void _stopRecording() {
    if (!_recording) return;
    _recording = false;
    final elapsed = CameoMotion.shotMaxRecord * _ringProgress.value;
    _ringProgress.stop();
    HapticFeedback.lightImpact();
    _spring(
      _ringWidth,
      0,
      CameoMotion.shotRingExitSpring,
      onDone: () {
        if (mounted && !_recording) _ringProgress.value = 0;
      },
    );
    setState(() {});
    widget.onRecordEnd?.call(elapsed);
  }

  @override
  void dispose() {
    _press.dispose();
    _disc.dispose();
    _ringWidth.dispose();
    _ringProgress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = CameoTheme.colorsOf(context);
    final box = shotRingBox();

    const light = CameoPalette.light;
    final base = OutsideShadow(
      key: Shot.baseKey,
      shadow: light.shadows.scrim,
      radius: CameoRadius.full,
      child: GlassSurface(
        blur: CameoBlur.scrim,
        tint: light.backgroundFillScrimBase,
        radius: CameoRadius.full,
        child: SizedBox.square(
          dimension: CameoLayout.shotV6BaseSize,
          child: Center(
            child: AnimatedBuilder(
              animation: Listenable.merge([_press, _disc]),
              builder: (context, _) => Opacity(
                opacity: _disc.value.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: _press.value,
                  child: SizedBox.square(
                    key: Shot.discKey,
                    dimension: CameoLayout.shotV6DiscSize,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: c.staticWhiteBase,
                        shape: BoxShape.circle,
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
    final button = RawGestureDetector(
      key: widget.buttonKey,
      behavior: HitTestBehavior.opaque,
      gestures: widget.disabled
          ? const {}
          : {
              TapGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                    TapGestureRecognizer.new,
                    (r) {
                      r.onTapDown = (_) {
                        _pressIn();
                      };
                      r.onTapUp = (_) {
                        _pressOut();
                        widget.onPhoto?.call();
                      };
                      r.onTapCancel = () {
                        if (!_recording) _pressOut();
                      };
                    },
                  ),
              LongPressGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<
                    LongPressGestureRecognizer
                  >(
                    () => LongPressGestureRecognizer(
                      duration: CameoMotion.shotHold,
                    ),
                    (r) {
                      r.onLongPressStart = (_) {
                        _pressIn();
                        _startRecording();
                      };
                      r.onLongPressEnd = (_) {
                        _pressOut();
                        _stopRecording();
                      };
                      r.onLongPressCancel = () {
                        _pressOut();
                        _stopRecording();
                      };
                    },
                  ),
            },
      child: Semantics(
        button: true,
        enabled: !widget.disabled,
        label: AppContent.of(context).v6.accessibility.shutter,
        hint: AppContent.of(context).v6.accessibility.shutterHint,
        onTap: widget.disabled ? null : widget.onPhoto,
        onLongPress: widget.disabled ? null : _toggleRecordingForA11y,
        excludeSemantics: true,
        child: base,
      ),
    );
    return SizedBox.square(
      dimension: box,
      child: Stack(
        alignment: Alignment.center,
        children: [
          IgnorePointer(
            child: AnimatedBuilder(
              animation: Listenable.merge([_ringWidth, _ringProgress]),
              builder: (context, _) => CustomPaint(
                key: Shot.ringKey,
                size: Size.square(box),
                painter: _RingPainter(
                  color: c.systemRed,
                  width: math.max(0, _ringWidth.value),
                  progress: _ringProgress.value,
                ),
              ),
            ),
          ),
          button,
        ],
      ),
    );
  }

  void _toggleRecordingForA11y() =>
      _recording ? _stopRecording() : _startRecording();
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.color,
    required this.width,
    required this.progress,
  });

  final Color color;
  final double width;
  final double progress;

  double get sweepDeg => progress.clamp(0.0, 1.0) * 360;

  @override
  void paint(Canvas canvas, Size size) {
    final sweep = progress.clamp(0.0, 1.0) * 2 * math.pi;
    if (width <= 0 || sweep <= 0) return;
    final center = size.center(Offset.zero);
    final rect = Rect.fromCircle(
      center: center,
      radius: CameoLayout.shotV6RingRadius,
    );
    canvas.drawArc(
      rect,
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.color != color || old.width != width || old.progress != progress;
}

double shotRingPainterSweepDeg(CustomPaint paint) =>
    (paint.painter! as _RingPainter).sweepDeg;

double shotRingPainterWidth(CustomPaint paint) =>
    (paint.painter! as _RingPainter).width;

Color shotRingPainterColor(CustomPaint paint) =>
    (paint.painter! as _RingPainter).color;
