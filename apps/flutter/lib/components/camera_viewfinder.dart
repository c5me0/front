// Camera preview and permission lifecycle. Use a bundled placeholder when hardware is
// unavailable; dispose camera resources when the view is removed.

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';

import '../content/lab.g.dart';
import '../design_system/design_system.dart';
import '../state/captured_photo.dart';

enum CameraFacing {
  back,
  front;

  CameraFacing get opposite =>
      this == CameraFacing.back ? CameraFacing.front : CameraFacing.back;

  CameraLensDirection get lensDirection => this == CameraFacing.back
      ? CameraLensDirection.back
      : CameraLensDirection.front;
}

enum CameraViewfinderSource { probing, camera, placeholder }

typedef CameraListLoader = Future<List<CameraDescription>> Function();

const double _radiansPerDegree = math.pi / 180;

double cameraFlipAngleDeg(double turns) {
  final f = turns - turns.floorToDouble();
  return (f < 0.5 ? f : f - 1) * CameoMotion.cameraFlipAngleDeg;
}

class CameraViewfinderController {
  _CameraViewfinderState? _state;

  CameraViewfinderSource get source =>
      _state?._source ?? CameraViewfinderSource.probing;

  Future<CapturedPhoto> capture() =>
      _state?._capture() ?? Future.value(CapturedPhoto.placeholder());

  Future<void> flash() => _state?._runFlash() ?? Future<void>.value();
}

///

class CameraViewfinder extends StatefulWidget {
  const CameraViewfinder({
    super.key,
    required this.facing,
    this.active = true,
    this.controller,
    this.placeholder = LabImages.cameraPlaceholder,
    this.onSourceChange,
    this.cameraListLoader,
    this.radius = CameoLayout.cameraScreenViewfinderRadius,
    this.flashColor,
    this.shadeColor,
  });

  final CameraFacing facing;

  final bool active;

  final CameraViewfinderController? controller;

  final String placeholder;

  final ValueChanged<CameraViewfinderSource>? onSourceChange;

  final CameraListLoader? cameraListLoader;

  final double radius;

  final Color? flashColor;

  final Color? shadeColor;

  static const Key flipKey = ValueKey('cameraViewfinder.flip');

  static const Key flashKey = ValueKey('cameraViewfinder.flash');

  static const Key placeholderKey = ValueKey('cameraViewfinder.placeholder');

  @override
  State<CameraViewfinder> createState() => _CameraViewfinderState();
}

class _CameraViewfinderState extends State<CameraViewfinder>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  CameraViewfinderSource _source = CameraViewfinderSource.probing;
  List<CameraDescription> _cameras = const [];
  CameraController? _camera;

  late final AnimationController _turns = AnimationController.unbounded(
    vsync: this,
    value: 0,
  );
  int _turnsTarget = 0;

  int _liveTurns = 0;
  late final CameraFacing _initialFacing = widget.facing;

  late final AnimationController _flash = AnimationController.unbounded(
    vsync: this,
    value: 0,
    animationBehavior: AnimationBehavior.preserve,
  );
  final Set<Timer> _timers = {};
  final Set<Completer<void>> _flashes = {};

  CameraFacing get _liveFacing =>
      _liveTurns.isEven ? _initialFacing : _initialFacing.opposite;

  bool get _reduceMotion =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  @override
  void initState() {
    super.initState();
    widget.controller?._state = this;
    WidgetsBinding.instance.addObserver(this);
    _turns.addListener(_onTurns);
    if (widget.active) _probe();
  }

  bool _probed = false;

  @override
  void didUpdateWidget(CameraViewfinder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      if (oldWidget.controller?._state == this) {
        oldWidget.controller?._state = null;
      }
      widget.controller?._state = this;
    }
    if (widget.active && !oldWidget.active) _probe();
    if (oldWidget.facing != widget.facing) {
      _turnsTarget += 1;
      final target = _turnsTarget.toDouble();
      if (_reduceMotion) {
        _turns.value = target;
      } else {
        _turns.springTo(target, CameoMotion.cameraFlipSpring).then((_) {
          if (mounted) _turns.value = target;
        });
      }
    }
  }

  void _onTurns() {
    final r = _turns.value.round();
    if (r == _liveTurns) return;
    _liveTurns = r;
    _switchLive();
  }

  void _settle(CameraViewfinderSource next) {
    if (!mounted || _source == next) return;
    setState(() => _source = next);
    widget.onSourceChange?.call(next);
  }

  Future<void> _probe() async {
    if (_probed) return;
    _probed = true;
    try {
      final cameras = await (widget.cameraListLoader ?? availableCameras)();
      if (!mounted) return;
      if (cameras.isEmpty) return _settle(CameraViewfinderSource.placeholder);
      _cameras = cameras;
      await _open();
    } catch (_) {
      _settle(CameraViewfinderSource.placeholder);
    }
  }

  CameraDescription _descriptionFor(CameraFacing facing) => _cameras.firstWhere(
    (c) => c.lensDirection == facing.lensDirection,
    orElse: () => _cameras.first,
  );

  Future<void> _open() async {
    final controller = CameraController(
      _descriptionFor(_liveFacing),
      ResolutionPreset.max,
      enableAudio: false,
    );
    _camera = controller;
    try {
      await controller.initialize();
    } catch (_) {
      if (_camera == controller) _camera = null;
      _settle(CameraViewfinderSource.placeholder);
      unawaited(_disposeQuietly(controller));
      return;
    }
    if (!mounted || _camera != controller) {
      unawaited(_disposeQuietly(controller));
      return;
    }
    setState(() {});
    _settle(CameraViewfinderSource.camera);
  }

  static Future<void> _disposeQuietly(CameraController controller) async {
    try {
      await controller.dispose();
    } catch (_) {}
  }

  Future<void> _switchLive() async {
    final controller = _camera;
    if (controller == null || _source != CameraViewfinderSource.camera) return;
    final next = _descriptionFor(_liveFacing);
    if (controller.description == next) return;
    try {
      await controller.setDescription(next);
      if (mounted) setState(() {});
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_source != CameraViewfinderSource.camera) return;
    if (state == AppLifecycleState.inactive) {
      final controller = _camera;
      _camera = null;
      if (controller != null) unawaited(_disposeQuietly(controller));
      if (mounted) setState(() {});
    } else if (state == AppLifecycleState.resumed && _camera == null) {
      _open();
    }
  }

  Future<CapturedPhoto> _capture() async {
    final controller = _camera;
    if (_source == CameraViewfinderSource.camera &&
        controller != null &&
        controller.value.isInitialized) {
      try {
        final file = await controller.takePicture();
        final size = await _encodedSize(file);
        return CapturedPhoto(
          uri: file.path,
          width: size.width,
          height: size.height,
          source: CapturedPhotoSource.camera,
        );
      } catch (_) {}
    }
    return CapturedPhoto.placeholder(widget.placeholder);
  }

  static Future<Size> _encodedSize(XFile file) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(
      await file.readAsBytes(),
    );
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    final size = Size(
      descriptor.width.toDouble(),
      descriptor.height.toDouble(),
    );
    descriptor.dispose();
    buffer.dispose();
    return size;
  }

  Future<void> _runFlash() {
    final done = Completer<void>();
    _flashes.add(done);
    _flash
        .animateTo(
          CameoMotion.cameraFlashPeakOpacity,
          duration: CameoMotion.cameraFlashIn,
          curve: CameoMotion.easingDecelerate,
        )
        .then((_) {
          if (!mounted) return;
          _flash.animateTo(
            0,
            duration: CameoMotion.cameraFlashOut,
            curve: CameoMotion.easingStandard,
          );
        });

    late final Timer timer;
    timer = Timer(CameoMotion.cameraFlashIn + CameoMotion.cameraFlashOut, () {
      _timers.remove(timer);
      _flashes.remove(done);
      done.complete();
    });
    _timers.add(timer);
    return done.future;
  }

  @override
  void dispose() {
    if (widget.controller?._state == this) widget.controller?._state = null;
    WidgetsBinding.instance.removeObserver(this);
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
    for (final c in _flashes) {
      if (!c.isCompleted) c.complete();
    }
    _flashes.clear();
    _turns.dispose();
    _flash.dispose();
    final controller = _camera;
    _camera = null;
    if (controller != null) unawaited(_disposeQuietly(controller));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = CameoTheme.colorsOf(context);
    final content = ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_source == CameraViewfinderSource.camera) _preview(),
          if (_source != CameraViewfinderSource.camera)
            Image.asset(
              widget.placeholder,
              key: CameraViewfinder.placeholderKey,
              fit: BoxFit.cover,
              excludeFromSemantics: true,
              gaplessPlayback: true,
            ),
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _turns,
              builder: (context, _) {
                final deg = cameraFlipAngleDeg(_turns.value);
                final shade =
                    math.sin(deg * _radiansPerDegree).abs() *
                    CameoMotion.cameraFlipShadeOpacity;
                return Opacity(
                  opacity: shade,
                  child: ColoredBox(
                    color:
                        widget.shadeColor ?? palette.backgroundNeutralInverse,
                  ),
                );
              },
            ),
          ),
          IgnorePointer(
            child: FadeTransition(
              key: CameraViewfinder.flashKey,
              opacity: _flash,
              child: ColoredBox(
                color: widget.flashColor ?? palette.staticWhite,
              ),
            ),
          ),
        ],
      ),
    );
    return Semantics(
      image: true,
      label: '카메라 미리보기',
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: _turns,
        builder: (context, child) {
          final m = Matrix4.identity()
            ..setEntry(3, 2, -1 / CameoMotion.cameraFlipPerspective)
            ..rotateY(cameraFlipAngleDeg(_turns.value) * _radiansPerDegree);
          return Transform(
            key: CameraViewfinder.flipKey,
            alignment: Alignment.center,
            transform: m,
            child: child,
          );
        },
        child: content,
      ),
    );
  }

  Widget _preview() {
    final controller = _camera;
    final size = controller?.value.previewSize;
    if (controller == null || !controller.value.isInitialized || size == null) {
      return const SizedBox.expand();
    }
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: size.shortestSide,
        height: size.longestSide,
        child: CameraPreview(controller),
      ),
    );
  }
}
