// Development-only surface and tab-bar comparison scenes using the app's own assets and
// tokens.

import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../components/outside_shadow.dart';
import '../../components/scrim_button.dart';
import '../../components/scrim_pill.dart';
import '../../components/tab_bar_v6.dart';
import '../../components/v6_layout.dart';
import '../../content/lab.g.dart';
import '../../design_system/design_system.dart';

enum GlassV6Scene {
  album,
  canvas,
  call,
  camera,
  tabbar;

  static GlassV6Scene? tryParse(String? value) {
    for (final s in values) {
      if (s.name == value) return s;
    }
    return null;
  }
}

CameoIconName _icon(String key) => CameoIconName.values.firstWhere(
  (n) => n.key == key,
  orElse: () => CameoIconName.borderNone,
);

class GlassV6Harness extends StatelessWidget {
  const GlassV6Harness({
    super.key,
    required this.scene,
    this.mode = TabBarV6Mode.full,
    this.variant = TabBarV6Variant.album,
    this.demo = false,
  });

  final GlassV6Scene scene;
  final TabBarV6Mode mode;
  final TabBarV6Variant variant;
  final bool demo;

  @override
  Widget build(BuildContext context) => switch (scene) {
    GlassV6Scene.album => const _AlbumScene(),
    GlassV6Scene.canvas => const _CanvasScene(),
    GlassV6Scene.call => const _CallScene(),
    GlassV6Scene.camera => const _CameraScene(),
    GlassV6Scene.tabbar => _TabBarScene(
      mode: mode,
      variant: variant,
      demo: demo,
    ),
  };
}

Widget _bottom(Widget bar) => Positioned(
  key: const ValueKey('glassV6.bar'),
  left: 0,
  right: 0,
  bottom: 0,
  child: bar,
);

class _AlbumBackdrop extends StatelessWidget {
  const _AlbumBackdrop();

  @override
  Widget build(BuildContext context) {
    final light = CameoPalette.light;
    final w = MediaQuery.sizeOf(context).width;
    return Positioned.fill(
      child: ColoredBox(
        color: light.sectionTint,
        child: Stack(
          children: [
            SizedBox(
              width: w,
              height: w,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(LabImages.albumSungsuCover, fit: BoxFit.cover),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: light.gradients.albumHeroV6,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: CameoLayout.screenV6TopAreaHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: light.gradients.sectionFadeTopV6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlbumScene extends StatelessWidget {
  const _AlbumScene();

  @override
  Widget build(BuildContext context) {
    final l = V6Layout.of(context);
    final items = [
      for (final icon in labV6.album.navActions)
        ScrimPillItem(icon: _icon(icon), semanticLabel: icon, onPress: () {}),
    ];
    return CameoTheme(
      mode: CameoColorMode.light,
      child: GlassBackdrop(
        tone: GlassBackdropTone.fromToken(
          CameoEffects.liquidGlassBackdropAlbumV6,
        ),
        child: Stack(
          key: const ValueKey('glassV6.album'),
          children: [
            const _AlbumBackdrop(),
            Positioned(
              left: CameoLayout.topNavV6PaddingX,
              top: CameoLayout.topNavV6Top,
              child: ScrimButton(
                size: ScrimButtonSize.md,
                label: labV6.album.selectLabel,
                onPress: () {},
              ),
            ),
            Positioned(
              left: l.topNavPillLeft(items.length),
              top: CameoLayout.topNavV6Top,
              child: ScrimPill(items: items),
            ),
          ],
        ),
      ),
    );
  }
}

class _CanvasScene extends StatelessWidget {
  const _CanvasScene();

  @override
  Widget build(BuildContext context) {
    return CameoTheme(
      mode: CameoColorMode.light,
      child: ColoredBox(
        key: const ValueKey('glassV6.canvas'),
        color: CameoPalette.light.backgroundCanvasNeutralStrong,
        child: Stack(
          children: [
            _bottom(
              TabBarV6(
                selected: 2,
                onSelect: (_) {},
                onCall: () {},
                tone: TabBarV6Tone.canvas,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CallScene extends StatelessWidget {
  const _CallScene();

  @override
  Widget build(BuildContext context) {
    final light = CameoPalette.light;
    final dark = CameoPalette.dark;
    final l = V6Layout.of(context);
    final barIcons = labV6.call.barIcons;
    const barRadius = CameoLayout.callV6BottomNavBarRadius;
    return CameoTheme(
      mode: CameoColorMode.light,
      child: GlassBackdrop(
        tone: GlassBackdropTone.fromToken(
          CameoEffects.liquidGlassBackdropCallV6,
        ),
        child: ColoredBox(
          key: const ValueKey('glassV6.call'),
          color: dark.backgroundCanvasBase,
          child: Stack(
            children: [
              Positioned.fill(
                child: Opacity(
                  opacity: CameoLayout.callV6BackgroundPhotoOpacity,
                  child: Image.asset(
                    LabImages.albumSungsuCover,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: light.gradients.callBackgroundV6,
                  ),
                ),
              ),
              Positioned(
                left: CameoLayout.topNavV6PaddingX,
                top: CameoLayout.topNavV6Top,
                child: ScrimButton(
                  size: ScrimButtonSize.md,
                  icon: _icon(labV6.call.navIcons[0]),
                  semanticLabel: 'chevron',
                  onPress: () {},
                ),
              ),
              Positioned(
                left: l.topNavRightButtonLeft,
                top: CameoLayout.topNavV6Top,
                child: ScrimButton(
                  size: ScrimButtonSize.md,
                  icon: _icon(labV6.call.navIcons[1]),
                  semanticLabel: 'moon',
                  onPress: () {},
                ),
              ),

              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: CameoLayout.callV6BottomNavHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: light.gradients.sectionFadeBottomV6,
                  ),
                ),
              ),
              Positioned(
                left: CameoLayout.callV6BottomNavPaddingX,
                right: CameoLayout.callV6BottomNavPaddingX,
                bottom: CameoLayout.screenV6HomeIndicatorHeight,
                height: CameoLayout.callV6BottomNavBarHeight,
                child: CameoTheme(
                  mode: CameoColorMode.dark,
                  child: OutsideShadow(
                    shadow: dark.shadows.scrim,
                    radius: barRadius,
                    child: GlassSurface(
                      blur: CameoBlur.scrim,
                      tint: dark.backgroundFillScrimBase,
                      border: dark.borderScrim,
                      borderWidth: CameoLayout.callV6BottomNavBarBorderWidth,
                      radius: barRadius,
                      padding: const EdgeInsets.all(
                        CameoLayout.callV6BottomNavBarPadding -
                            CameoLayout.callV6BottomNavBarBorderWidth,
                      ),
                      child: Row(
                        children: [
                          for (var i = 0; i < barIcons.length; i++)
                            Expanded(
                              child: SizedBox(
                                height: CameoLayout.callV6BottomNavItemHeight,
                                child: DecoratedBox(
                                  decoration: ShapeDecoration(
                                    color: i == barIcons.length - 1
                                        ? dark.systemRed
                                        : null,
                                    shape: RoundedSuperellipseBorder(
                                      borderRadius: BorderRadius.circular(
                                        CameoLayout.callV6BottomNavItemRadius,
                                      ),
                                    ),
                                  ),
                                  child: Center(
                                    child: CameoIcon(
                                      _icon(barIcons[i]),
                                      size: CameoLayout.callV6BottomNavIconSize,
                                      color: i == barIcons.length - 1
                                          ? dark.staticWhiteBase
                                          : dark.foregroundNeutralSubtle,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
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
  }
}

class _CameraScene extends StatelessWidget {
  const _CameraScene();

  @override
  Widget build(BuildContext context) {
    final light = CameoPalette.light;
    final dark = CameoPalette.dark;
    final l = V6Layout.of(context);
    return CameoTheme(
      mode: CameoColorMode.dark,
      child: ColoredBox(
        key: const ValueKey('glassV6.camera'),
        color: dark.backgroundCanvasBase,
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                LabImages.cameraViewfinderV5,
                fit: BoxFit.cover,
              ),
            ),
            Positioned.fill(child: ColoredBox(color: light.dimScrim)),
            Positioned(
              left: CameoLayout.cameraV6ViewfinderLeft,
              top: CameoLayout.cameraV6ViewfinderTop,
              width: l.cameraViewfinderWidth,
              height: l.cameraViewfinderHeight,
              child: ClipRSuperellipse(
                borderRadius: BorderRadius.circular(
                  CameoLayout.cameraV6ViewfinderRadius,
                ),
                child: Image.asset(
                  LabImages.cameraViewfinderV5,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            _bottom(
              TabBarV6(
                selected: 1,
                onSelect: (_) {},
                variant: TabBarV6Variant.camera,
                tone: TabBarV6Tone.camera,
                camera: TabBarCameraSlots(
                  thumbnail: TabBarThumbnail(
                    image: const AssetImage(LabImages.albumSungsuGridR5c4Hires),
                    semanticLabel: 'thumbnail',
                    onPress: () {},
                  ),
                  onFlip: () {},
                  flipLabel: 'flip',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabBarScene extends StatefulWidget {
  const _TabBarScene({
    required this.mode,
    required this.variant,
    required this.demo,
  });

  final TabBarV6Mode mode;
  final TabBarV6Variant variant;
  final bool demo;

  @override
  State<_TabBarScene> createState() => _TabBarSceneState();
}

class _TabBarSceneState extends State<_TabBarScene> {
  static const _steps = [
    (mode: TabBarV6Mode.full, variant: TabBarV6Variant.album, selected: 0),
    (mode: TabBarV6Mode.mini, variant: TabBarV6Variant.album, selected: 0),
    (mode: TabBarV6Mode.full, variant: TabBarV6Variant.album, selected: 0),
    (mode: TabBarV6Mode.full, variant: TabBarV6Variant.camera, selected: 1),
    (mode: TabBarV6Mode.full, variant: TabBarV6Variant.album, selected: 2),
  ];
  static const _stepDuration = Duration(milliseconds: 1600);

  int _step = 0;
  late int _selected = widget.variant == TabBarV6Variant.camera ? 1 : 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.demo) {
      _timer = Timer.periodic(
        _stepDuration,
        (_) => setState(() => _step = (_step + 1) % _steps.length),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.demo
        ? _steps[_step]
        : (mode: widget.mode, variant: widget.variant, selected: _selected);
    return CameoTheme(
      mode: CameoColorMode.light,
      child: Stack(
        key: const ValueKey('glassV6.tabbar'),
        children: [
          const _AlbumBackdrop(),
          _bottom(
            TabBarV6(
              mode: s.mode,
              selected: s.selected,
              onSelect: (i) => setState(() => _selected = i),
              onCall: () {},
              variant: s.variant,
              camera: s.variant == TabBarV6Variant.camera
                  ? TabBarCameraSlots(
                      thumbnail: TabBarThumbnail(
                        image: const AssetImage(LabImages.albumSungsuCover),
                        semanticLabel: 'thumbnail',
                        onPress: () {},
                      ),
                      onFlip: () {},
                      flipLabel: 'flip',
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
