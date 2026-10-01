// Legacy modal camera preview with capture results returned through navigation.

import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import '../../content/app.g.dart';

import '../../components/camera_glass_button.dart';
import '../../components/camera_viewfinder.dart';
import '../../components/segmented_control.dart';
import '../../components/shutter_button.dart';
import '../../content/lab.g.dart';
import '../../design_system/design_system.dart';
import '../../navigation/navigation.dart';
import '../../state/captured_photo.dart';

const CameoColorMode _colorMode = CameoColorMode.light;

abstract final class CameraDemo {
  static const Duration flip = Duration(milliseconds: 1500);
  static const Duration video = Duration(milliseconds: 3000);
  static const Duration photo = Duration(milliseconds: 4000);
  static const Duration shutter = Duration(milliseconds: 5500);
}

final List<SegmentedControlItem<CameraModeId>> cameraModeItems =
    localizedCameraModes(labCamera, appContent);

List<SegmentedControlItem<CameraModeId>> localizedCameraModes(
  CameraContent camera,
  AppContent copy,
) => [
  for (final m in camera.modes)
    SegmentedControlItem(
      id: m.id,
      label: m.label,
      accessibilityLabel: fillTemplate(copy.v6.accessibility.cameraMode, {
        'mode': m.label,
      }),
    ),
];

String cameraShutterLabel(CameraModeId mode, {AppContent copy = appContent}) =>
    switch (mode) {
      CameraModeId.photo => copy.v6.accessibility.photoCapture,
      CameraModeId.video => copy.v6.accessibility.videoCapture,
    };

String cameraFlipLabel(CameraFacing facing, {AppContent copy = appContent}) =>
    switch (facing) {
      CameraFacing.back => copy.v6.accessibility.frontCamera,
      CameraFacing.front => copy.v6.accessibility.backCamera,
    };

///

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key, this.demo = false, this.cameraListLoader});

  final bool demo;

  final CameraListLoader? cameraListLoader;

  static const Key closeKey = ValueKey('cameraScreen.close');

  static const Key flipKey = ValueKey('cameraScreen.flip');

  static const Key shutterRowKey = ValueKey('cameraScreen.shutterRow');

  static const Key bottomBarKey = ValueKey('cameraScreen.bottomBar');

  @override
  State<CameraScreen> createState() => CameraScreenState();
}

class CameraScreenState extends State<CameraScreen> {
  CameraModeId _mode = labCamera.initialMode;
  CameraFacing _facing = CameraFacing.back;
  int _shutterKey = 0;
  bool _capturing = false;
  bool _closed = false;
  final CameraViewfinderController _viewfinder = CameraViewfinderController();

  final DemoTimeline _demo = DemoTimeline();

  late final VoidCallback _unregisterFlowShutter;

  bool _entered = false;
  Animation<double>? _routeAnimation;

  CameraModeId get mode => _mode;
  CameraFacing get facing => _facing;
  bool get isCapturing => _capturing;
  bool get isClosed => _closed;

  @override
  void initState() {
    super.initState();
    if (widget.demo) _demo.start(_demoSteps());

    _unregisterFlowShutter = FlowDemo.register(
      FlowDemoAction.cameraShutter,
      onShutter,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_entered || _routeAnimation != null) return;
    final animation = ModalRoute.of(context)?.animation;
    if (animation == null || animation.isCompleted) {
      _entered = true;
    } else {
      _routeAnimation = animation..addStatusListener(_onRouteStatus);
    }
  }

  void _onRouteStatus(AnimationStatus status) {
    if (!status.isCompleted || !mounted) return;
    _detachRoute();
    setState(() => _entered = true);
  }

  void _detachRoute() {
    _routeAnimation?.removeStatusListener(_onRouteStatus);
    _routeAnimation = null;
  }

  List<DemoStep> _demoSteps() => [
    (at: CameraDemo.flip, run: flip),
    (at: CameraDemo.video, run: () => onModeChange(CameraModeId.video)),
    (at: CameraDemo.photo, run: () => onModeChange(CameraModeId.photo)),
    (at: CameraDemo.shutter, run: onShutter),
  ];

  void close() {
    if (_closed) return;
    _closed = true;
    CameoNav.pop(context);
  }

  void flip() => setState(() => _facing = _facing.opposite);

  void onModeChange(CameraModeId next) => setState(() => _mode = next);

  Future<void> onShutter() async {
    if (_capturing || _closed) return;
    setState(() => _shutterKey += 1);
    if (_mode != CameraModeId.photo) return;
    _capturing = true;
    final captured = _viewfinder.capture();

    unawaited(
      captured.then((p) {
        if (mounted) unawaited(precacheImage(p.image, context));
      }),
    );
    final (photo, _) = await (captured, _viewfinder.flash()).wait;
    _capturing = false;
    if (!mounted || _closed) return;
    _closed = true;
    CameoNav.pop<CapturedPhoto>(context, photo);
  }

  @override
  void dispose() {
    _detachRoute();
    _demo.cancel();
    _unregisterFlowShutter();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final width = MediaQuery.sizeOf(context).width;
    final navTop = math.max(padding.top, CameoLayout.cameraScreenNavTop);
    final bottomPadding = math.max(
      padding.bottom,
      CameoLayout.cameraScreenBottomBarPaddingBottom,
    );
    final bottomBarHeight =
        CameoLayout.cameraScreenBottomBarPaddingTop +
        CameoLayout.cameraScreenGlassButtonSize +
        bottomPadding;
    final viewfinderHeight =
        width / CameoLayout.cameraScreenViewfinderAspectRatio;

    return CameoTheme(
      mode: _colorMode,

      child: GlassBackdrop(
        tone: GlassBackdropTone.fromToken(
          CameoEffects.liquidGlassBackdropCameraScreen,
        ),
        child: ColoredBox(
          color: CameoPalette.of(_colorMode).backgroundNeutralInverse,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: navTop + CameoLayout.cameraScreenNavHeight,
                height:
                    viewfinderHeight +
                    CameoLayout.cameraScreenViewfinderPaddingY * 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: CameoLayout.cameraScreenViewfinderPaddingY,
                  ),
                  child: CameraViewfinder(
                    facing: _facing,
                    active: _entered,
                    controller: _viewfinder,
                    cameraListLoader: widget.cameraListLoader,
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: navTop,
                height: CameoLayout.cameraScreenNavHeight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: CameoLayout.cameraScreenNavPaddingX,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CameraGlassButton(
                        key: CameraScreen.closeKey,
                        icon: CameoIconName.x,
                        onPress: close,
                        accessibilityLabel: AppContent.of(
                          context,
                        ).v6.album.closeLabel,
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                key: CameraScreen.shutterRowKey,
                left: 0,
                right: 0,
                bottom: bottomBarHeight,
                height: CameoLayout.cameraScreenShutterRowHeight,
                child: Center(
                  child: ShutterButton(
                    onPress: onShutter,
                    feedbackKey: _shutterKey,
                    accessibilityLabel: cameraShutterLabel(
                      _mode,
                      copy: AppContent.of(context),
                    ),
                  ),
                ),
              ),
              Positioned(
                key: CameraScreen.bottomBarKey,
                left: 0,
                right: 0,
                bottom: 0,
                height: bottomBarHeight,
                child: Stack(
                  children: [
                    Positioned(
                      top: CameoLayout.segmentedControlTop,
                      left:
                          width / 2 +
                          CameoLayout.segmentedControlOffsetX -
                          CameoLayout.segmentedControlWidth / 2,
                      child: SegmentedControl<CameraModeId>(
                        items: localizedCameraModes(
                          LabSamples.of(context).labCamera,
                          AppContent.of(context),
                        ),
                        selected: _mode,
                        onChanged: onModeChange,
                      ),
                    ),

                    Positioned(
                      top: CameoLayout.cameraScreenBottomBarPaddingTop,
                      right: CameoLayout.cameraScreenBottomBarPaddingX,
                      child: CameraGlassButton(
                        key: CameraScreen.flipKey,
                        icon: CameoIconName.refresh,
                        onPress: flip,
                        accessibilityLabel: cameraFlipLabel(
                          _facing,
                          copy: AppContent.of(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
