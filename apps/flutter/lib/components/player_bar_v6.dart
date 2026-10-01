// Light transcript playback bar and scrubber. Shared controller state drives the
// displayed time and play/pause action.

//

//

import 'dart:math' as math;
import 'dart:ui' show FontFeature, ImageFilter, lerpDouble;

import 'package:flutter/gestures.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import '../content/app.g.dart';

import '../content/lab.g.dart';
import '../design_system/design_system.dart';
import 'outside_shadow.dart';
import 'playback_controller.dart';
import 'transcript_v6_layout.dart';

const double _a11yStepSec = 15;

final double _thumbHitHalf =
    math.max(
      CameoLayout.transcriptV6PlayerThumbSize,
      CameoLayout.transcriptV6PlayerPauseHeight,
    ) /
    2;

final TextStyle _timeStyle = CameoTextStyles.bodyMd.copyWith(
  fontFeatures: const [FontFeature.tabularFigures()],
);

typedef PlayerBarV6Roles = ({
  Color pillFill,
  Color pillBorder,
  BoxShadow pillShadow,
  Color time,
  Color track,
  Color progress,
  Color marker,
  Color thumb,
  BoxShadow thumbShadow,
  Color pauseFill,
  BoxShadow pauseShadow,
  Color pauseIcon,
  LinearGradient containerFade,
});

PlayerBarV6Roles playerBarV6Roles(CameoPalette c) => (
  pillFill: CameoPalette.light.backgroundFillScrimBase,
  pillBorder: CameoPalette.light.borderScrim,
  pillShadow: CameoPalette.light.shadows.scrim,
  time: c.foregroundNeutralMuted,
  track: c.backgroundFillNeutralStrong,
  progress: c.backgroundFillNeutralInverted,
  marker: c.backgroundSystemCriticalBase,
  thumb: c.staticWhiteBase,
  thumbShadow: c.shadows.shadow,
  pauseFill: c.backgroundFillNeutralInteraction,
  pauseShadow: CameoPalette.light.shadows.scrim,
  pauseIcon: c.foregroundNeutralBase,
  containerFade: c.gradients.bottomLinear,
);

/// RN `<PlayerBarV6 playback markers />`.
class PlayerBarV6 extends StatefulWidget {
  const PlayerBarV6({super.key, required this.playback, required this.markers});

  final PlaybackController playback;

  final List<PlayerV5MarkerContent> markers;

  static const Key containerKey = ValueKey('playerBarV6.container');
  static const Key fadeKey = ValueKey('playerBarV6.fade');
  static const Key shadowKey = ValueKey('playerBarV6.shadow');
  static const Key pillKey = ValueKey('playerBarV6.pill');
  static const Key scrubberKey = ValueKey('playerBarV6.scrubber');
  static const Key trackKey = ValueKey('playerBarV6.track');
  static const Key progressKey = ValueKey('playerBarV6.progress');
  static const Key thumbKey = ValueKey('playerBarV6.thumb');
  static const Key buttonKey = ValueKey('playerBarV6.button');
  static const Key buttonSurfaceKey = ValueKey('playerBarV6.buttonSurface');
  static const Key currentTimeKey = ValueKey('playerBarV6.currentTime');
  static const Key durationKey = ValueKey('playerBarV6.duration');
  static Key markerKey(int i) => ValueKey('playerBarV6.marker.$i');

  @override
  State<PlayerBarV6> createState() => _PlayerBarV6State();
}

class _PlayerBarV6State extends State<PlayerBarV6>
    with TickerProviderStateMixin {
  late final AnimationController _thumbScale = AnimationController.unbounded(
    vsync: this,
    value: 1,
  );

  late final AnimationController _icon = AnimationController.unbounded(
    vsync: this,
    value: widget.playback.playing ? 1 : 0,
  );

  final GlobalKey _trackBoxKey = GlobalKey();
  late bool _playing = widget.playback.playing;
  bool _reduce = false;
  bool _grabbed = false;
  bool _dragging = false;
  double _dragFrom = 0;
  double _dragDownX = 0;

  @override
  void initState() {
    super.initState();
    widget.playback.addListener(_onPlayback);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    widget.playback.reduceMotion = _reduce;
  }

  @override
  void didUpdateWidget(PlayerBarV6 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playback == widget.playback) return;
    oldWidget.playback.removeListener(_onPlayback);
    widget.playback
      ..addListener(_onPlayback)
      ..reduceMotion = _reduce;
    _playing = widget.playback.playing;
    _icon.value = _playing ? 1 : 0;
  }

  @override
  void dispose() {
    widget.playback.removeListener(_onPlayback);

    if (_dragging) widget.playback.endScrub();
    _thumbScale.dispose();
    _icon.dispose();
    super.dispose();
  }

  void _onPlayback() {
    final playing = widget.playback.playing;
    if (playing == _playing) return;
    setState(() => _playing = playing);
    final target = playing ? 1.0 : 0.0;
    if (_reduce) {
      _icon.animateTo(
        target,
        duration: CameoMotion.durationBase,
        curve: CameoMotion.easingStandard,
      );
    } else {
      _icon.springTo(target, CameoMotion.playPauseSpring);
    }
  }

  RenderBox? get _trackBox {
    final o = _trackBoxKey.currentContext?.findRenderObject();
    return o is RenderBox && o.hasSize ? o : null;
  }

  double _trackLocalX(Offset global) =>
      _trackBox?.globalToLocal(global).dx ?? double.nan;

  bool _onThumb(Offset global) {
    final w = _trackBox?.size.width ?? 0;
    final lx = _trackLocalX(global);
    return (lx - widget.playback.position.value * w).abs() <= _thumbHitHalf;
  }

  void _scaleThumb(double to, SpringDescription spring) {
    if (_reduce) {
      _thumbScale.value = to;
    } else {
      _thumbScale.springTo(to, spring);
    }
  }

  void _dragDown(DragDownDetails d) {
    _grabbed = true;
    _scaleThumb(
      CameoMotion.scrubberThumbGrabScale,
      CameoMotion.scrubberGrabSpring,
    );
  }

  void _dragStart(DragStartDetails d) {
    _dragging = true;
    _dragFrom = widget.playback.position.value;
    _dragDownX = _trackLocalX(d.globalPosition);
    widget.playback.beginScrub();
  }

  void _dragUpdate(DragUpdateDetails d) {
    final w = _trackBox?.size.width ?? 0;
    if (w <= 0) return;
    widget.playback.scrubTo(
      _dragFrom + (_trackLocalX(d.globalPosition) - _dragDownX) / w,
    );
  }

  void _dragEnd(DragEndDetails d) => _dragRelease();

  void _dragRelease() {
    if (_grabbed) _scaleThumb(1, CameoMotion.scrubberReleaseSpring);
    if (_dragging) widget.playback.endScrub();
    _grabbed = false;
    _dragging = false;
  }

  void _tapUp(TapUpDetails d) {
    final w = _trackBox?.size.width ?? 0;
    if (w <= 0) return;
    final target = playerV6TapTarget(
      _trackLocalX(d.globalPosition) / w,
      widget.markers,
    );
    if (target != null) widget.playback.seekTo(target);
  }

  void _stepBy(double sec) {
    final d = widget.playback.durationSec;
    if (d <= 0) return;
    widget.playback.seekTo((widget.playback.seconds + sec) / d);
  }

  @override
  Widget build(BuildContext context) {
    final roles = playerBarV6Roles(CameoTheme.colorsOf(context));
    final playback = widget.playback;
    final markers = widget.markers;
    final total = formatPlaybackTime(playback.durationSec);

    final scrubber = ListenableBuilder(
      listenable: playback,
      builder: (context, child) {
        final current = formatPlaybackTime(playback.seconds);
        String at(double sec) =>
            formatPlaybackTime(sec.clamp(0.0, playback.durationSec).toDouble());
        return Semantics(
          container: true,
          slider: true,
          label: AppContent.of(context).v6.accessibility.playbackPosition,
          value: '$current / $total',
          increasedValue: '${at(playback.seconds + _a11yStepSec)} / $total',
          decreasedValue: '${at(playback.seconds - _a11yStepSec)} / $total',
          onIncrease: () => _stepBy(_a11yStepSec),
          onDecrease: () => _stepBy(-_a11yStepSec),
          customSemanticsActions: {
            for (var i = 0; i < markers.length; i++)
              CustomSemanticsAction(
                label: fillTemplate(
                  AppContent.of(context).v6.accessibility.jumpHighlight,
                  {'index': i + 1},
                ),
              ): () =>
                  playback.seekTo(markers[i].start),
          },
          excludeSemantics: true,
          child: child,
        );
      },
      child: RawGestureDetector(
        key: PlayerBarV6.scrubberKey,
        behavior: HitTestBehavior.opaque,
        gestures: {
          _ThumbDragRecognizer:
              GestureRecognizerFactoryWithHandlers<_ThumbDragRecognizer>(
                () => _ThumbDragRecognizer(accepts: _onThumb, debugOwner: this),
                (r) => r
                  ..dragStartBehavior = DragStartBehavior.down
                  ..onDown = _dragDown
                  ..onStart = _dragStart
                  ..onUpdate = _dragUpdate
                  ..onEnd = _dragEnd
                  ..onCancel = _dragRelease,
              ),
          TapGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                () => TapGestureRecognizer(debugOwner: this),
                (r) => r..onTapUp = _tapUp,
              ),
        },
        child: Row(
          spacing: CameoLayout.transcriptV6PlayerGap,
          children: [
            ListenableBuilder(
              listenable: playback,
              builder: (context, _) => CameoText(
                formatPlaybackTime(playback.seconds),
                key: PlayerBarV6.currentTimeKey,
                style: _timeStyle,
                color: roles.time,
              ),
            ),
            Expanded(child: _track(markers, roles)),
            CameoText(
              total,
              key: PlayerBarV6.durationKey,
              style: _timeStyle,
              color: roles.time,
            ),
          ],
        ),
      ),
    );

    const iconSize = CameoLayout.solidButtonV6LgIconSize;
    final icons = Center(
      child: SizedBox.square(
        dimension: iconSize,
        child: AnimatedBuilder(
          animation: _icon,
          builder: (context, _) => Stack(
            children: [
              _iconLayer(
                CameoIconName.playerPauseFilled,
                _icon.value,
                roles.pauseIcon,
                iconSize,
              ),
              _iconLayer(
                CameoIconName.playerPlayFilled,
                1 - _icon.value,
                roles.pauseIcon,
                iconSize,
              ),
            ],
          ),
        ),
      ),
    );
    final button = PressScale(
      onPress: playback.toggle,
      pressedColor: CameoPalette.light.backgroundFillScrimInteraction,
      pressedRadius: CameoLayout.transcriptV6PlayerRadius,
      accessibilityLabel: _playing
          ? AppContent.of(context).v6.accessibility.pause
          : AppContent.of(context).v6.accessibility.play,
      child: SizedBox(
        key: PlayerBarV6.buttonKey,
        width: CameoLayout.transcriptV6PlayerPauseWidth,
        height: CameoLayout.transcriptV6PlayerPauseHeight,
        child: OutsideShadow(
          shadow: roles.pauseShadow,
          radius: CameoLayout.transcriptV6PlayerRadius,
          child: BlurSurface(
            key: PlayerBarV6.buttonSurfaceKey,
            blur: CameoBlur.blur,
            tint: roles.pauseFill,
            radius: CameoLayout.transcriptV6PlayerRadius,
            padding: const EdgeInsets.all(
              CameoLayout.transcriptV6PlayerPausePadding,
            ),
            child: icons,
          ),
        ),
      ),
    );

    final insets = playerV6PillInsets();
    final pill = OutsideShadow(
      key: PlayerBarV6.shadowKey,
      shadow: roles.pillShadow,
      radius: CameoLayout.transcriptV6PlayerRadius,
      child: SizedBox(
        key: PlayerBarV6.pillKey,
        height: playerV6PillHeight(),
        child: GlassSurface(
          blur: CameoBlur.scrim,
          tint: roles.pillFill,
          border: roles.pillBorder,
          borderWidth: CameoLayout.transcriptV6PlayerBorderWidth,
          radius: CameoLayout.transcriptV6PlayerRadius,

          padding: EdgeInsets.fromLTRB(
            insets.left,
            insets.y,
            insets.right,
            insets.y,
          ),

          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: CameoLayout.transcriptV6PlayerGap,
            children: [
              Expanded(child: scrubber),
              button,
            ],
          ),
        ),
      ),
    );

    return SizedBox(
      key: PlayerBarV6.containerKey,
      height: playerV6ContainerHeight(),
      child: Stack(
        children: [
          Positioned.fill(
            key: const ValueKey('playerBarV6.layer.fade'),
            child: IgnorePointer(
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: CameoBlur.blur.sigma,
                    sigmaY: CameoBlur.blur.sigma,
                  ),
                  child: DecoratedBox(
                    key: PlayerBarV6.fadeKey,
                    decoration: BoxDecoration(gradient: roles.containerFade),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            key: const ValueKey('playerBarV6.layer.pill'),
            left: CameoLayout.transcriptV6PlayerRowPaddingX,
            right: CameoLayout.transcriptV6PlayerRowPaddingX,
            top: CameoLayout.transcriptV6PlayerRowPaddingY,
            child: pill,
          ),
        ],
      ),
    );
  }

  Widget _track(List<PlayerV5MarkerContent> markers, PlayerBarV6Roles roles) {
    return SizedBox(
      key: _trackBoxKey,
      height: CameoLayout.transcriptV6PlayerTrackHeight,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          return ValueListenableBuilder<double>(
            valueListenable: widget.playback.position,
            builder: (context, p, _) => Stack(
              key: PlayerBarV6.trackKey,
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                      CameoLayout.transcriptV6PlayerRadius,
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: roles.track),
                      child: Stack(
                        children: [
                          Positioned(
                            left: 0,
                            top: 0,
                            width: w,
                            height: CameoLayout.transcriptV6PlayerTrackHeight,
                            child: Transform.translate(
                              offset: Offset((p - 1) * w, 0),
                              child: DecoratedBox(
                                key: PlayerBarV6.progressKey,
                                decoration: BoxDecoration(
                                  color: roles.progress,
                                  borderRadius: BorderRadius.circular(
                                    CameoLayout.transcriptV6PlayerRadius,
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

                for (var i = 0; i < markers.length; i++)
                  Builder(
                    builder: (context) {
                      final f = playerV6MarkerFrame(markers[i], w);
                      return Positioned(
                        left: f.left,
                        top: 0,
                        width: f.width,
                        height: CameoLayout.transcriptV6PlayerMarkerHeight,
                        child: DecoratedBox(
                          key: PlayerBarV6.markerKey(i),
                          decoration: BoxDecoration(
                            color: roles.marker,
                            borderRadius: BorderRadius.circular(
                              CameoLayout.transcriptV6PlayerRadius,
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                Positioned(
                  left: 0,
                  top: playerV6ThumbTop(),
                  width: CameoLayout.transcriptV6PlayerThumbSize,
                  height: CameoLayout.transcriptV6PlayerThumbSize,
                  child: Transform.translate(
                    offset: Offset(playerV6ThumbLeft(p, w), 0),
                    child: ScaleTransition(
                      scale: _thumbScale,
                      child: DecoratedBox(
                        key: PlayerBarV6.thumbKey,
                        decoration: BoxDecoration(
                          color: roles.thumb,
                          shape: BoxShape.circle,
                          boxShadow: [roles.thumbShadow],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _iconLayer(CameoIconName name, double t, Color color, double size) {
    final scale = _reduce
        ? 1.0
        : lerpDouble(CameoMotion.playPauseMinScale, 1, t)!;
    return Positioned.fill(
      child: Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: scale,
          child: CameoIcon(name, size: size, color: color),
        ),
      ),
    );
  }
}

class _ThumbDragRecognizer extends HorizontalDragGestureRecognizer {
  _ThumbDragRecognizer({required this.accepts, super.debugOwner});

  final bool Function(Offset globalPosition) accepts;

  @override
  bool isPointerAllowed(PointerEvent event) =>
      accepts(event.position) && super.isPointerAllowed(event);

  @override
  bool hasSufficientGlobalDistanceToAccept(
    PointerDeviceKind pointerDeviceKind,
    double? deviceTouchSlop,
  ) => true;
}
