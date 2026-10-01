// Full, compact, and camera tab bar states share one mounted glass surface. Morph
// geometry with the same spring; labels may fade, glass must not. Compact mode clears
// the wide backdrop while retaining the capsule.

//

//    (photo → default · canvas → light · camera → dark).

import 'dart:ui' show ImageFilter;
import 'dart:math' as math;

import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

import '../content/app.g.dart';
import '../content/lab.g.dart';
import '../design_system/design_system.dart';
import '../state/session.dart';
import 'outside_shadow.dart';
import 'v6_layout.dart';

enum TabBarV6Mode { full, mini }

enum TabBarV6Variant { album, camera }

enum TabBarV6Tone {
  photo,

  canvas,

  camera;

  LinearGradient gradientOf(CameoPalette c) => switch (this) {
    photo => c.gradients.sectionFadeBottomV6,
    canvas => c.gradients.bottomLinear,
    camera => c.gradients.cameraNavFadeV6,
  };

  GlassBackdropTone get backdrop => switch (this) {
    photo => GlassBackdropTone.defaultTone,
    canvas => GlassBackdropTone.light,
    camera => GlassBackdropTone.dark,
  };
}

List<LabV6TabBarTab> get tabBarV6Tabs => labV6.tabBar.tabs;

List<String> get tabBarV6AccessibilityLabels => tabLabels(appContent);

List<String> tabLabels(AppContent copy) => [
  copy.v6.tabBar.historyLabel,
  copy.v6.tabBar.cameraLabel,
  copy.v6.tabBar.settingsLabel,
];

CameoIconName _iconOf(String key) => CameoIconName.values.firstWhere(
  (n) => n.key == key,
  orElse: () => CameoIconName.borderNone,
);

@immutable
class TabBarCameraSlots {
  const TabBarCameraSlots({
    this.thumbnail,
    this.onFlip,
    required this.flipLabel,
    this.flipDisabled = false,
    this.recording = false,
  });

  final Widget? thumbnail;

  final VoidCallback? onFlip;

  final String flipLabel;

  final bool flipDisabled;
  final bool recording;

  @override
  bool operator ==(Object other) =>
      other is TabBarCameraSlots &&
      other.thumbnail == thumbnail &&
      other.onFlip == onFlip &&
      other.flipLabel == flipLabel &&
      other.flipDisabled == flipDisabled &&
      other.recording == recording;

  @override
  int get hashCode =>
      Object.hash(thumbnail, onFlip, flipLabel, flipDisabled, recording);
}

const double _gone = 0.001;

typedef TabBarV6Frame = ({
  double containerHeight,
  double pillLeft,
  double pillTop,
  double pillWidth,
  double pillHeight,

  double inset,
  double itemWidth,
  double itemHeight,

  double buttonLeft,
  double buttonTop,
  double buttonScale,
  double buttonSize,
  double thumbnailLeft,

  double thumbnail,
});

TabBarV6Frame tabBarV6Frame(
  double width, {
  double mini = 0,
  double camera = 0,
  double recording = 0,
}) {
  final l = V6Layout(width);
  double lerp(double a, double b, double t) => a + (b - a) * t;
  final fullWidth = lerp(
    l.tabBarFullPillWidth,
    l.tabBarCameraPillWidth,
    camera,
  );
  final fullLeft = lerp(l.tabBarFullPillLeft, l.tabBarCameraPillLeft, camera);
  final pillWidth = lerp(fullWidth, CameoLayout.tabBarV6MiniPillWidth, mini);
  final pillHeight = lerp(
    CameoLayout.tabBarV6FullPillHeight,
    CameoLayout.tabBarV6MiniPillHeight,
    mini,
  );
  final inset = lerp(
    CameoLayout.tabBarV6FullPillPadding,
    CameoLayout.tabBarV6MiniPillPadding +
        CameoLayout.tabBarV6MiniPillBorderWidth,
    mini,
  );
  final containerHeight = lerp(
    CameoLayout.tabBarV6FullContainerHeight,
    CameoLayout.tabBarV6MiniContainerHeight,
    mini,
  );

  const button = CameoLayout.tabBarV6FullCallButtonSize;
  const buttonBottom =
      CameoLayout.tabBarV6FullContainerHeight -
      CameoLayout.tabBarV6FullRowPaddingTop -
      (CameoLayout.tabBarV6FullPillHeight + button) / 2;
  return (
    containerHeight: containerHeight,
    pillLeft: lerp(fullLeft, l.tabBarMiniPillLeft, mini),
    pillTop: lerp(
      CameoLayout.tabBarV6FullRowPaddingTop,
      CameoLayout.tabBarV6MiniRowPaddingTop,
      mini,
    ),
    pillWidth: pillWidth,
    pillHeight: pillHeight,
    inset: inset,
    itemWidth: (pillWidth - 2 * inset) / 3,
    itemHeight: pillHeight - 2 * inset,
    buttonLeft: lerp(
      l.tabBarCallButtonLeft + mini * CameoMotion.tabBarV6CallButtonExitOffsetX,
      width -
          CameoLayout.silicaRecordingSideInset -
          CameoLayout.silicaRecordingSideSize,
      recording,
    ),
    buttonTop: lerp(containerHeight - buttonBottom - button, 0, recording),
    buttonSize: lerp(button, CameoLayout.silicaRecordingSideSize, recording),
    buttonScale: lerp(
      lerp(1, CameoMotion.tabBarV6CallButtonExitScale, mini),
      1,
      recording,
    ),
    thumbnailLeft: lerp(
      CameoLayout.tabBarV6FullPaddingX,
      CameoLayout.silicaRecordingSideInset,
      recording,
    ),
    thumbnail: lerp(camera * (1 - mini), camera, recording),
  );
}

class TabBarV6 extends StatefulWidget {
  const TabBarV6({
    super.key,
    this.mode = TabBarV6Mode.full,
    required this.selected,
    this.onSelect,
    this.onCall,
    this.variant = TabBarV6Variant.album,
    this.tone = TabBarV6Tone.photo,
    this.backdrop,
    this.camera,
    this.hidden = false,
    this.tabsDisabled = false,
  });

  final TabBarV6Mode mode;

  final int selected;

  final ValueChanged<int>? onSelect;

  final VoidCallback? onCall;
  final TabBarV6Variant variant;

  final TabBarV6Tone tone;

  final GlassBackdropTone? backdrop;

  final TabBarCameraSlots? camera;

  final bool hidden;

  final bool tabsDisabled;

  static const Key containerKey = ValueKey('tabBarV6.container');
  static const Key fadeKey = ValueKey('tabBarV6.fade');
  static const Key pillKey = ValueKey('tabBarV6.pill');
  static const Key indicatorKey = ValueKey('tabBarV6.indicator');

  static const Key buttonKey = ValueKey('tabBarV6.button');
  static const Key callIconKey = ValueKey('tabBarV6.button.call');
  static const Key flipIconKey = ValueKey('tabBarV6.button.flip');
  static const Key thumbnailKey = ValueKey('tabBarV6.thumbnail');
  static Key tabKey(int index) => ValueKey('tabBarV6.tab.$index');
  static Key labelKey(int index) => ValueKey('tabBarV6.label.$index');
  static Key iconKey(int index) => ValueKey('tabBarV6.icon.$index');

  @override
  State<TabBarV6> createState() => TabBarV6State();
}

class TabBarV6State extends State<TabBarV6> with TickerProviderStateMixin {
  late final AnimationController _mini;
  late final AnimationController _record;

  late final AnimationController _label;

  late final AnimationController _camera;

  late final AnimationController _position;

  late final AnimationController _hide;

  late final AnimationController _tone;
  LinearGradient? _toneFrom;

  late final Listenable _all;

  @override
  void initState() {
    super.initState();
    final recording = widget.camera?.recording ?? false;
    final mini = widget.mode == TabBarV6Mode.mini || recording;
    _mini = AnimationController.unbounded(
      vsync: this,
      value: widget.mode == TabBarV6Mode.mini ? 1 : 0,
    );
    _record = AnimationController.unbounded(
      vsync: this,
      value: recording ? 1 : 0,
    );
    _label = AnimationController(vsync: this, value: mini ? 0 : 1);
    _camera = AnimationController.unbounded(
      vsync: this,
      value: widget.variant == TabBarV6Variant.camera ? 1 : 0,
    );
    _position = AnimationController.unbounded(
      vsync: this,
      value: widget.selected.toDouble(),
    );
    _hide = AnimationController.unbounded(
      vsync: this,
      value: widget.hidden ? 1 : 0,
    );
    _tone = AnimationController.unbounded(vsync: this, value: 1);
    _all = Listenable.merge([
      _mini,
      _record,
      _label,
      _camera,
      _position,
      _hide,
      _tone,
    ]);
  }

  double get miniProgress => _mini.value;

  double get cameraProgress => _camera.value;

  double get labelOpacity => _label.value;

  double get indicatorPosition => _position.value;

  bool get _reduceMotion =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  void _spring(
    AnimationController c,
    double target,
    SpringDescription spring, {
    bool preserveVelocity = false,
  }) {
    if (_reduceMotion) {
      c.value = target;
      return;
    }
    final v = c.velocity;
    final x = c.value;
    final away = (target > x && v < 0) || (target < x && v > 0);
    c
        .springTo(target, spring, velocity: away && !preserveVelocity ? 0 : v)
        .then((_) {
          if (mounted && !c.isAnimating) c.value = target;
        });
  }

  @override
  void didUpdateWidget(TabBarV6 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode ||
        oldWidget.camera?.recording != widget.camera?.recording) {
      final recording = widget.camera?.recording ?? false;
      final mini = widget.mode == TabBarV6Mode.mini || recording;
      _spring(
        _record,
        recording ? 1 : 0,
        CameoMotion.tabBarV6MorphSpring,
        preserveVelocity: true,
      );
      _spring(
        _mini,
        widget.mode == TabBarV6Mode.mini ? 1 : 0,
        CameoMotion.tabBarV6MorphSpring,
        preserveVelocity: true,
      );
      if (_reduceMotion) {
        _label.value = mini ? 0 : 1;
      } else {
        _label.animateTo(
          mini ? 0 : 1,
          duration: CameoMotion.tabBarV6LabelFade,
          curve: CameoMotion.easingStandard,
        );
      }
    }
    if (oldWidget.variant != widget.variant) {
      _spring(
        _camera,
        widget.variant == TabBarV6Variant.camera ? 1 : 0,
        CameoMotion.tabBarV6MorphSpring,
      );
    }
    if (oldWidget.selected != widget.selected) {
      _spring(
        _position,
        widget.selected.toDouble(),
        CameoMotion.tabBarV6IndicatorSpring,
      );
    }
    if (oldWidget.hidden != widget.hidden) {
      _spring(_hide, widget.hidden ? 1 : 0, CameoMotion.selectModeSpring);
    }
    if (oldWidget.tone != widget.tone) {
      _toneFrom = _gradient(CameoTheme.colorsOf(context), oldWidget.tone);
      _tone.value = 0;
      _spring(_tone, 1, CameoMotion.tabBarToneSpring);
    }
  }

  @override
  void dispose() {
    for (final c in [
      _mini,
      _record,
      _label,
      _camera,
      _position,
      _hide,
      _tone,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  LinearGradient _gradient(CameoPalette c, TabBarV6Tone tone) {
    final to = tone.gradientOf(c);
    final from = _toneFrom;
    final t = _tone.value.clamp(0.0, 1.0);
    if (from == null || t >= 1) return to;
    return LinearGradient.lerp(from, to, t) ?? to;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => AnimatedBuilder(
        animation: _all,
        builder: (context, _) => _bar(context, constraints.maxWidth),
      ),
    );
  }

  Widget _bar(BuildContext context, double width) {
    final c = CameoTheme.colorsOf(context);
    final cam = _camera.value.clamp(0.0, 1.0);
    final f = tabBarV6Frame(
      width,
      mini: math.max(_mini.value, _record.value),
      camera: cam,
      recording: _record.value.clamp(0.0, 1.0),
    );
    final backdropVisibility =
        1 +
        (CameoMotion.tabBarV6MiniBackdropVisibility - 1) *
            _mini.value.clamp(0.0, 1.0);
    final backdropGradient = _gradient(c, widget.tone);
    Color mix(Color Function(CameoPalette p) role) =>
        Color.lerp(role(CameoPalette.light), role(CameoPalette.dark), cam)!;
    final shadow = BoxShadow.lerp(
      CameoPalette.light.shadows.scrim,
      CameoPalette.dark.shadows.scrim,
      cam,
    )!;
    final hidden = widget.hidden;
    final button = f.buttonSize;
    final bar = SizedBox(
      key: TabBarV6.containerKey,
      width: width,
      height: f.containerHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            key: const ValueKey('tabBarV6.layer.fade'),
            child: IgnorePointer(
              child: ClipRect(
                child: BackdropFilter(
                  enabled: backdropVisibility > 0,
                  filter: ImageFilter.blur(
                    sigmaX: CameoBlur.blur.sigma * backdropVisibility,
                    sigmaY: CameoBlur.blur.sigma * backdropVisibility,
                  ),
                  child: DecoratedBox(
                    key: TabBarV6.fadeKey,
                    decoration: BoxDecoration(
                      gradient: backdropVisibility == 1
                          ? backdropGradient
                          : backdropGradient.scale(backdropVisibility),
                    ),
                  ),
                ),
              ),
            ),
          ),

          Positioned(
            key: const ValueKey('tabBarV6.layer.thumbnail'),
            left: f.thumbnailLeft,
            top: f.buttonTop,
            width: button,
            height: button,
            child: f.thumbnail <= _gone
                ? const SizedBox.shrink()
                : IgnorePointer(
                    ignoring: f.thumbnail < 0.5 || hidden,
                    child: Opacity(
                      key: TabBarV6.thumbnailKey,
                      opacity: f.thumbnail.clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: 0.5 + 0.5 * f.thumbnail,
                        child: widget.camera?.thumbnail ?? const SizedBox(),
                      ),
                    ),
                  ),
          ),
          // 3) pill (Liquid Glass)
          Positioned(
            key: const ValueKey('tabBarV6.layer.pill'),
            left: f.pillLeft,
            top: f.pillTop,
            width: f.pillWidth,
            height: f.pillHeight,
            child: OutsideShadow(
              shadow: shadow,
              radius: CameoLayout.tabBarV6FullPillRadius,
              child: GlassSurface(
                key: TabBarV6.pillKey,
                blur: CameoBlur.scrim,
                tint: Color.lerp(
                  CameoPalette.light.backgroundFillScrimBase,
                  CameoPalette.dark.backgroundFillNeutralBase,
                  cam,
                )!,
                border: mix((p) => p.borderScrim),
                borderWidth: CameoLayout.tabBarV6FullPillBorderWidth,
                radius: CameoLayout.tabBarV6FullPillRadius,

                child: _items(f, mix),
              ),
            ),
          ),

          Positioned(
            key: const ValueKey('tabBarV6.layer.button'),
            left: f.buttonLeft,
            top: f.buttonTop,
            width: button,
            height: button,
            child: f.buttonScale <= _gone
                ? const SizedBox.shrink()
                : IgnorePointer(
                    ignoring: _mini.value > 0.1 || hidden,
                    child: Transform.scale(
                      scale: f.buttonScale,
                      child: _button(cam, shadow, mix),
                    ),
                  ),
          ),
        ],
      ),
    );
    return GlassBackdrop(
      tone: widget.backdrop ?? widget.tone.backdrop,
      child: IgnorePointer(
        ignoring: hidden,
        child: Transform.translate(
          offset: Offset(0, _hide.value * f.containerHeight),
          child: bar,
        ),
      ),
    );
  }

  Widget _button(
    double cam,
    BoxShadow shadow,
    Color Function(Color Function(CameoPalette p) role) mix,
  ) {
    final slots = widget.camera;
    final flip = cam >= 0.5;
    final disabled = flip && (slots?.flipDisabled ?? false);
    final k = disabled ? CameoLayout.scrimButtonV6DisabledOpacity : 1.0;
    Color faded(Color color) => color.withValues(alpha: color.a * k);

    final content = faded(
      Color.lerp(
        CameoPalette.light.foregroundNeutralBase,
        CameoPalette.dark.staticWhiteBase,
        cam,
      )!,
    );
    final icon =
        CameoLayout.silicaActionPillIconSize -
        CameoSpace.s4 * _record.value.clamp(0.0, 1.0);
    final surface = OutsideShadow(
      shadow: shadow.copyWith(color: faded(shadow.color)),
      radius: CameoLayout.scrimButtonV6Radius,
      child: GlassSurface(
        key: TabBarV6.buttonKey,
        blur: CameoBlur.scrim,
        tint: faded(
          Color.lerp(
            CameoPalette.light.backgroundFillScrimBase,
            CameoPalette.dark.backgroundFillNeutralBase,
            cam,
          )!,
        ),
        border: faded(mix((p) => p.borderScrim)),
        borderWidth: CameoLayout.scrimButtonV6BorderWidth,
        radius: CameoLayout.scrimButtonV6Radius,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: 1 - cam,
              child: CameoIcon(
                _iconOf(LabV6.of(context).tabBar.callIcon),
                key: TabBarV6.callIconKey,
                size: icon,
                color: content,
              ),
            ),
            Opacity(
              opacity: cam,
              child: CameoIcon(
                CameoIconName.refresh,
                key: TabBarV6.flipIconKey,
                size: icon,
                color: content,
              ),
            ),
          ],
        ),
      ),
    );
    final onPress = flip ? slots?.onFlip : widget.onCall;
    final label = flip
        ? slots?.flipLabel
        : AppContent.of(context).v6.tabBar.callLabel;
    if (disabled) {
      return Semantics(
        button: true,
        enabled: false,
        label: label,
        excludeSemantics: true,
        child: surface,
      );
    }
    return GlassPressable(
      onPress: onPress,
      accessibilityLabel: label,
      pressedColor: mix((p) => p.backgroundFillScrimInteraction),
      pressedRadius: CameoLayout.scrimButtonV6Radius,
      child: surface,
    );
  }

  Widget _avatar(Color color, double size) {
    final name = SessionScope.maybeOf(context)?.session.name;
    final initial = name == null || name.trim().isEmpty
        ? 'C'
        : name.trim().characters.first.toUpperCase();
    final palette = CameoTheme.colorsOf(context);
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(CameoLayout.silicaAvatarRadius),
        ),
        child: Center(
          child: CameoText(
            initial,
            style: CameoTextStyles.bodyMd,
            color: _camera.value > 0.5
                ? palette.staticBlackBase
                : palette.staticWhiteBase,
            maxLines: 1,
          ),
        ),
      ),
    );
  }

  Widget _items(
    TabBarV6Frame f,
    Color Function(Color Function(CameoPalette p) role) mix,
  ) {
    final onSelect = widget.onSelect;
    const bw = CameoLayout.tabBarV6FullPillBorderWidth;
    final inset = f.inset - bw;
    final pos = _position.value;
    final stretch = tabIndicatorStretch(_position.velocity * f.itemWidth);
    final selectedColor = mix((p) => p.foregroundNeutralBase);
    final idleColor = mix((p) => p.foregroundNeutralSubtle);
    final label = _label.value.clamp(0.0, 1.0);
    final tabs = LabV6.of(context).tabBar.tabs;
    final names = tabLabels(AppContent.of(context));
    return Semantics(
      role: onSelect == null ? null : SemanticsRole.tabBar,
      container: true,
      explicitChildNodes: true,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            key: const ValueKey('tabBarV6.layer.indicator'),
            left: inset,
            top: inset,
            width: f.itemWidth,
            height: f.itemHeight,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..translateByDouble(pos * f.itemWidth, 0, 0, 1)
                ..scaleByDouble(stretch.sx, stretch.sy, 1, 1),
              child: DecoratedBox(
                key: TabBarV6.indicatorKey,
                decoration: ShapeDecoration(
                  color: mix((p) => p.backgroundFillScrimInteraction),
                  shape: const StadiumBorder(),
                ),
              ),
            ),
          ),
          for (var i = 0; i < tabs.length; i++)
            Positioned(
              key: ValueKey('tabBarV6.layer.tab.$i'),
              left: inset + i * f.itemWidth,
              top: inset,
              width: f.itemWidth,
              height: f.itemHeight,
              child: _tab(
                i,
                tabs[i],
                names[i],
                Color.lerp(
                  idleColor,
                  selectedColor,
                  (1 - (pos - i).abs()).clamp(0.0, 1.0),
                )!,
                label,
                enabled:
                    onSelect != null &&
                    (!widget.tabsDisabled || i == widget.selected),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tab(
    int i,
    LabV6TabBarTab tab,
    String name,
    Color color,
    double labelOpacity, {
    required bool enabled,
  }) {
    final onSelect = widget.onSelect;
    if (!enabled && onSelect != null) {
      color = color.withValues(
        alpha: color.a * CameoLayout.scrimButtonV6DisabledOpacity,
      );
    }
    final pad =
        CameoLayout.tabBarV6FullItemPadding +
        (CameoLayout.tabBarV6MiniItemPadding -
                CameoLayout.tabBarV6FullItemPadding) *
            math.max(_mini.value, _record.value).clamp(0.0, 1.0);
    const icon = CameoLayout.tabBarV6FullIconSize;
    final body = ClipRect(
      key: TabBarV6.tabKey(i),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: pad,
            left: 0,
            right: 0,
            height: icon,
            child: Center(
              child: i == 2
                  ? _avatar(color, icon)
                  : CameoIcon(
                      _iconOf(tab.icon),
                      key: TabBarV6.iconKey(i),
                      size: icon,
                      color: color,
                    ),
            ),
          ),

          Positioned(
            top: pad + icon,
            left: 0,
            right: 0,
            height: CameoLayout.tabBarV6FullLabelLineHeight,
            child: Opacity(
              opacity: labelOpacity,
              child: Center(
                child: CameoText(
                  tab.label,
                  key: TabBarV6.labelKey(i),
                  style: CameoTextStyles.tabLabel,
                  color: color,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
    final active = enabled && onSelect != null;
    return Semantics(
      role: onSelect == null ? null : SemanticsRole.tab,
      selected: i == widget.selected,
      enabled: active,
      label: name,
      onTap: active ? () => onSelect(i) : null,
      excludeSemantics: true,
      child: active
          ? GlassPressable(
              onPress: () => onSelect(i),
              pressedColor: Color.lerp(
                CameoPalette.light.backgroundFillScrimInteraction,
                CameoPalette.dark.backgroundFillScrimInteraction,
                _camera.value.clamp(0.0, 1.0),
              ),
              pressedRadius: CameoLayout.tabBarV6FullItemRadius,
              child: body,
            )
          : body,
    );
  }
}

/// docs/v6-notes-call-camera-v6.md):

class TabBarThumbnail extends StatefulWidget {
  const TabBarThumbnail({
    super.key,
    required this.image,
    this.onPress,
    required this.semanticLabel,
    this.video = false,
    this.anchor,
    this.popKey,
    this.onPopSettled,
  });

  final ImageProvider? image;
  final VoidCallback? onPress;
  final String semanticLabel;

  final bool video;

  final GlobalKey? anchor;

  final Object? popKey;

  final VoidCallback? onPopSettled;

  static const Key videoKey = ValueKey('tabBarThumbnail.video');
  static const Key borderKey = ValueKey('tabBarThumbnail.border');

  @override
  State<TabBarThumbnail> createState() => TabBarThumbnailState();
}

typedef _ThumbLayer = ({Object key, ImageProvider? image, bool video});

class TabBarThumbnailState extends State<TabBarThumbnail>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController.unbounded(
    vsync: this,
    value: 1,
  );

  _ThumbLayer? _below;

  late Object _key = widget.popKey ?? _fixedKey;
  static const Object _fixedKey = 'thumbnail';

  double get popScale => _pop.value;
  bool get hasBelow => _below != null;

  @override
  void didUpdateWidget(TabBarThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    final key = widget.popKey ?? _fixedKey;
    if (key == _key) return;
    _key = key;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _pop.value = 1;
      _below = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onPopSettled?.call();
      });
      return;
    }

    _below = (
      key: oldWidget.popKey ?? _fixedKey,
      image: oldWidget.image,
      video: oldWidget.video,
    );
    _pop.value = 0;
    _pop.springTo(1, CameoMotion.heartPopSpring).then((_) {
      if (!mounted || _pop.isAnimating) return;
      _pop.value = 1;
      setState(() => _below = null);
      widget.onPopSettled?.call();
    });
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  Widget _layer(_ThumbLayer layer, Color glyph) => Stack(
    fit: StackFit.expand,
    children: [
      if (layer.image case final image?)
        Image(
          image: image,
          fit: BoxFit.cover,
          excludeFromSemantics: true,
          gaplessPlayback: true,
        )
      else
        const SizedBox.shrink(),
      if (layer.video)
        Center(
          key: TabBarThumbnail.videoKey,
          child: CameoIcon(
            CameoIconName.playerPlayFilled,
            size: CameoLayout.scrimButtonV6SmIconSize,
            color: glyph,
          ),
        )
      else
        const SizedBox.shrink(),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final c = CameoTheme.colorsOf(context);
    const radius = CameoLayout.tabBarV6CameraThumbnailRadius;
    final below = _below;
    final top = (key: _key, image: widget.image, video: widget.video);
    final box = SizedBox.square(
      dimension: CameoLayout.tabBarV6CameraThumbnailSize,
      child: ClipRSuperellipse(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            KeyedSubtree(
              key: const ValueKey('tabBarThumbnail.below'),
              child: below == null
                  ? const SizedBox.shrink()
                  : _layer(below, c.staticWhiteBase),
            ),
            KeyedSubtree(
              key: ValueKey(('tabBarThumbnail.top', _key)),
              child: AnimatedBuilder(
                animation: _pop,
                builder: (context, child) => Transform.scale(
                  scale: _pop.value.clamp(0.0, double.infinity),
                  child: child,
                ),
                child: _layer(top, c.staticWhiteBase),
              ),
            ),
            IgnorePointer(
              key: TabBarThumbnail.borderKey,
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  shape: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.circular(radius),
                    side: BorderSide(
                      color: c.staticWhiteBase,
                      width: CameoLayout.tabBarV6CameraThumbnailBorderWidth,
                      strokeAlign: BorderSide.strokeAlignInside,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return Semantics(
      button: widget.onPress != null,
      image: true,
      label: widget.semanticLabel,
      onTap: widget.onPress,
      excludeSemantics: true,
      child: PressScale(
        onPress: widget.onPress,
        child: KeyedSubtree(key: widget.anchor, child: box),
      ),
    );
  }
}
