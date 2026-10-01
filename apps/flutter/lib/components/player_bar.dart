// Legacy playback controls with adjustable accessibility actions and token-based
// geometry.

import 'dart:math' as math;
import 'dart:ui' show FontFeature, lerpDouble;

import 'package:flutter/gestures.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import '../content/app.g.dart';

import '../content/lab.g.dart';
import '../design_system/design_system.dart';
import 'playback_controller.dart';

const double _a11yStepSec = 15;

enum PlayerBarTone { light, dark, darkToken }

typedef _Geometry = ({
  double containerPaddingTop,
  double containerPaddingX,
  double containerPaddingBottom,
  double containerHeight,
  double pillPadding,
  double pillHeight,
  double pillBorderWidth,
  double pillRadius,
  double scrubberPaddingX,
  double scrubberPaddingY,
  double scrubberGap,
  double scrubberHeight,
  double trackHeight,
  double trackRadius,
  double progressHeight,
  double progressRadius,
  double markerHeight,
  double markerRadius,
  double thumbSize,
  double thumbRadius,
  double buttonWidth,
  double buttonHeight,
  double buttonPadding,
  double buttonRadius,
  double buttonIconSize,
});

const _Geometry _player = (
  containerPaddingTop: CameoLayout.playerContainerPaddingTop,
  containerPaddingX: CameoLayout.playerContainerPaddingX,
  containerPaddingBottom: CameoLayout.playerContainerPaddingBottom,
  containerHeight: CameoLayout.playerContainerHeight,
  pillPadding: CameoLayout.playerPillPadding,
  pillHeight: CameoLayout.playerPillHeight,
  pillBorderWidth: CameoLayout.playerPillBorderWidth,
  pillRadius: CameoLayout.playerPillRadius,
  scrubberPaddingX: CameoLayout.playerScrubberPaddingX,
  scrubberPaddingY: CameoLayout.playerScrubberPaddingY,
  scrubberGap: CameoLayout.playerScrubberGap,
  scrubberHeight: CameoLayout.playerScrubberHeight,
  trackHeight: CameoLayout.playerTrackHeight,
  trackRadius: CameoLayout.playerTrackRadius,
  progressHeight: CameoLayout.playerProgressHeight,
  progressRadius: CameoLayout.playerProgressRadius,
  markerHeight: CameoLayout.playerMarkerHeight,
  markerRadius: CameoLayout.playerMarkerRadius,
  thumbSize: CameoLayout.playerThumbSize,
  thumbRadius: CameoLayout.playerThumbRadius,
  buttonWidth: CameoLayout.playerButtonWidth,
  buttonHeight: CameoLayout.playerButtonHeight,
  buttonPadding: CameoLayout.playerButtonPadding,
  buttonRadius: CameoLayout.playerButtonRadius,
  buttonIconSize: CameoLayout.playerButtonIconSize,
);

const _Geometry _playerV3 = (
  containerPaddingTop: CameoLayout.playerV3ContainerPaddingTop,
  containerPaddingX: CameoLayout.playerV3ContainerPaddingX,
  containerPaddingBottom: CameoLayout.playerV3ContainerPaddingBottom,
  containerHeight: CameoLayout.playerV3ContainerHeight,
  pillPadding: CameoLayout.playerV3PillPadding,
  pillHeight: CameoLayout.playerV3PillHeight,
  pillBorderWidth: CameoLayout.playerV3PillBorderWidth,
  pillRadius: CameoLayout.playerV3PillRadius,
  scrubberPaddingX: CameoLayout.playerV3ScrubberPaddingX,
  scrubberPaddingY: CameoLayout.playerV3ScrubberPaddingY,
  scrubberGap: CameoLayout.playerV3ScrubberGap,
  scrubberHeight: CameoLayout.playerV3ScrubberHeight,
  trackHeight: CameoLayout.playerV3TrackHeight,
  trackRadius: CameoLayout.playerV3TrackRadius,
  progressHeight: CameoLayout.playerV3ProgressHeight,
  progressRadius: CameoLayout.playerV3ProgressRadius,
  markerHeight: CameoLayout.playerV3MarkerHeight,
  markerRadius: CameoLayout.playerV3MarkerRadius,
  thumbSize: CameoLayout.playerV3ThumbSize,
  thumbRadius: CameoLayout.playerV3ThumbRadius,
  buttonWidth: CameoLayout.playerV3ButtonWidth,
  buttonHeight: CameoLayout.playerV3ButtonHeight,
  buttonPadding: CameoLayout.playerV3ButtonPadding,
  buttonRadius: CameoLayout.playerV3ButtonRadius,
  buttonIconSize: CameoLayout.playerV3ButtonIconSize,
);

_Geometry _geometryOf(PlayerBarTone tone) =>
    tone == PlayerBarTone.darkToken ? _playerV3 : _player;

typedef _ToneRoles = ({
  Color fill,
  Color? border,
  Color time,
  Color progress,
  Color marker,
  Color button,
  CameoBlur? buttonBlur,
});

_ToneRoles _roles(CameoPalette c, PlayerBarTone tone) => switch (tone) {
  PlayerBarTone.light => (
    fill: c.backgroundNeutralSubtle,
    border: c.strokeNeutralBase,
    time: c.foregroundNeutralMuted,
    progress: c.playerProgress,
    marker: c.backgroundInfoBase,
    button: c.backgroundCanvasBase,
    buttonBlur: null,
  ),
  PlayerBarTone.dark => (
    fill: c.glassTintBar,
    border: c.glassBorder,
    time: c.transcriptDarkTime,
    progress: c.playerProgressDark,
    marker: c.backgroundInfoBase,
    button: c.backgroundCanvasBase,
    buttonBlur: null,
  ),

  PlayerBarTone.darkToken => (
    fill: c.backgroundNeutralBase,
    border: null,
    time: c.foregroundNeutralMuted,
    progress: c.backgroundNeutralStrong,
    marker: c.backgroundSystemCriticalMuted,
    button: c.backgroundNeutralInteractive,
    buttonBlur: CameoBlur.pauseButtonBlur,
  ),
};

({Color track, Color thumb, BoxShadow thumbShadow, Color buttonIcon})
_fixedRoles(CameoPalette c) => (
  track: c.playerTrack,
  thumb: c.surfaceBackgroundNormal,
  thumbShadow: c.shadows.shadow,
  buttonIcon: c.foregroundNeutralBase,
);

double _thumbHitHalfOf(_Geometry g) =>
    math.max(g.thumbSize, g.scrubberHeight) / 2;

final TextStyle _timeStyle = CameoTextStyles.bodyMd.copyWith(
  fontFeatures: const [FontFeature.tabularFigures()],
);

abstract final class PlayerBarKeys {
  static const Key pill = ValueKey('playerBar.pill');

  static const Key scrubber = ValueKey('playerBar.scrubber');

  static const Key track = ValueKey('playerBar.track');

  static const Key progress = ValueKey('playerBar.progress');

  /// 2042:3228 / 3109 — thumb 24
  static const Key thumb = ValueKey('playerBar.thumb');

  static const Key button = ValueKey('playerBar.button');

  static const Key currentTime = ValueKey('playerBar.currentTime');

  static const Key duration = ValueKey('playerBar.duration');

  static Key marker(int i) => ValueKey('playerBar.marker.$i');
}

double playerBarContainerHeight({
  double bottomInset = 0,
  PlayerBarTone tone = PlayerBarTone.light,
}) {
  final g = _geometryOf(tone);
  return g.containerHeight -
      g.containerPaddingBottom +
      math.max(bottomInset, g.containerPaddingBottom);
}

class PlayerBar extends StatefulWidget {
  const PlayerBar({
    super.key,
    required this.playback,
    this.tone = PlayerBarTone.light,
    this.markers,
    this.bottomInset,
    this.positioned = true,
  });

  final PlaybackController playback;

  final PlayerBarTone tone;

  final List<PlayerMarkerContent>? markers;

  final double? bottomInset;

  final bool positioned;

  @override
  State<PlayerBar> createState() => _PlayerBarState();
}

class _PlayerBarState extends State<PlayerBar> with TickerProviderStateMixin {
  late final AnimationController _thumbScale = AnimationController.unbounded(
    vsync: this,
    value: 1,
  );

  late final AnimationController _icon = AnimationController.unbounded(
    vsync: this,
    value: widget.playback.playing ? 1 : 0,
  );

  final GlobalKey _trackKey = GlobalKey();
  late bool _playing = widget.playback.playing;
  bool _reduce = false;
  bool _grabbed = false;
  bool _dragging = false;
  double _dragFrom = 0;
  double _dragDownX = 0;

  List<PlayerMarkerContent> get _markers =>
      widget.markers ?? labTranscript.player.markers;

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
  void didUpdateWidget(PlayerBar oldWidget) {
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
    final o = _trackKey.currentContext?.findRenderObject();
    return o is RenderBox && o.hasSize ? o : null;
  }

  double _trackLocalX(Offset global) =>
      _trackBox?.globalToLocal(global).dx ?? double.nan;

  _Geometry get _g => _geometryOf(widget.tone);

  bool _onThumb(Offset global) {
    final w = _trackBox?.size.width ?? 0;
    final lx = _trackLocalX(global);
    return (lx - widget.playback.position.value * w).abs() <=
        _thumbHitHalfOf(_g);
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
    final f = _trackLocalX(d.globalPosition) / w;
    if (f < 0 || f > 1) return;
    var target = f;
    for (final m in _markers) {
      if (f >= m.start && f <= m.start + m.width) {
        target = m.start;
        break;
      }
    }
    widget.playback.seekTo(target);
  }

  void _stepBy(double sec) {
    final d = widget.playback.durationSec;
    if (d <= 0) return;
    widget.playback.seekTo((widget.playback.seconds + sec) / d);
  }

  @override
  Widget build(BuildContext context) {
    final palette = CameoTheme.colorsOf(context);
    final roles = _roles(palette, widget.tone);
    final g = _g;
    final playback = widget.playback;
    final markers = _markers;
    final safeBottom =
        (MediaQuery.maybePaddingOf(context) ?? EdgeInsets.zero).bottom;
    final total = formatPlaybackTime(playback.durationSec);

    // 2042:3222 'stroke picker' — fill, px12 py14 gap8 → h46
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
        key: PlayerBarKeys.scrubber,
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
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: g.scrubberPaddingX,
            vertical: g.scrubberPaddingY,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: g.scrubberGap,
            children: [
              ListenableBuilder(
                listenable: playback,
                builder: (context, _) => CameoText(
                  formatPlaybackTime(playback.seconds),
                  key: PlayerBarKeys.currentTime,
                  style: _timeStyle,
                  color: roles.time,
                ),
              ),
              Expanded(child: _track(markers, roles)),
              CameoText(
                total,
                key: PlayerBarKeys.duration,
                style: _timeStyle,
                color: roles.time,
              ),
            ],
          ),
        ),
      ),
    );

    // 2042:3230 — 80x50 p14 r999 (50 = 14 + 22 + 14)

    final icons = Center(
      child: SizedBox.square(
        dimension: g.buttonIconSize,
        child: AnimatedBuilder(
          animation: _icon,
          builder: (context, _) => Stack(
            children: [
              _iconLayer(CameoIconName.playerPauseFilled, _icon.value),
              _iconLayer(CameoIconName.playerPlayFilled, 1 - _icon.value),
            ],
          ),
        ),
      ),
    );
    final buttonBlur = roles.buttonBlur;
    final button = PressScale(
      onPress: playback.toggle,
      accessibilityLabel: _playing
          ? AppContent.of(context).v6.accessibility.pause
          : AppContent.of(context).v6.accessibility.play,
      child: SizedBox(
        key: PlayerBarKeys.button,
        width: g.buttonWidth,
        height: g.buttonHeight,
        child: buttonBlur != null
            // 2042:3230 (v3) — background/neutral/interactive + backdrop-blur (pauseButtonBlur)
            ? BlurSurface(
                blur: buttonBlur,
                tint: roles.button,
                radius: g.buttonRadius,
                padding: EdgeInsets.all(g.buttonPadding),
                child: icons,
              )
            : DecoratedBox(
                decoration: ShapeDecoration(
                  color: roles.button,
                  shape: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.circular(g.buttonRadius),
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.all(g.buttonPadding),
                  child: icons,
                ),
              ),
      ),
    );

    Widget bar = Padding(
      padding: EdgeInsets.fromLTRB(
        g.containerPaddingX,
        g.containerPaddingTop,
        g.containerPaddingX,
        math.max(widget.bottomInset ?? safeBottom, g.containerPaddingBottom),
      ),

      child: SizedBox(
        key: PlayerBarKeys.pill,
        height: g.pillHeight,
        child: GlassSurface(
          blur: CameoBlur.glassBar,
          tint: roles.fill,
          border: roles.border,
          borderWidth: g.pillBorderWidth,
          radius: g.pillRadius,
          padding: EdgeInsets.all(g.pillPadding),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: scrubber),
              button,
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

  Widget _track(List<PlayerMarkerContent> markers, _ToneRoles roles) {
    final fixed = _fixedRoles(CameoTheme.colorsOf(context));
    final g = _g;
    return SizedBox(
      key: _trackKey,
      height: g.trackHeight,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          return ValueListenableBuilder<double>(
            valueListenable: widget.playback.position,
            builder: (context, p, _) => Stack(
              key: PlayerBarKeys.track,
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(g.trackRadius),
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: fixed.track),
                      child: Stack(
                        children: [
                          Positioned(
                            left: 0,
                            top: 0,
                            width: w,
                            height: g.progressHeight,
                            child: Transform.translate(
                              offset: Offset((p - 1) * w, 0),
                              child: DecoratedBox(
                                key: PlayerBarKeys.progress,
                                decoration: BoxDecoration(
                                  color: roles.progress,
                                  borderRadius: BorderRadius.circular(
                                    g.progressRadius,
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
                  Positioned(
                    left: markers[i].start * w,
                    top: 0,
                    width: markers[i].width * w,
                    height: g.markerHeight,
                    child: DecoratedBox(
                      key: PlayerBarKeys.marker(i),
                      decoration: BoxDecoration(
                        color: roles.marker,
                        borderRadius: BorderRadius.circular(g.markerRadius),
                      ),
                    ),
                  ),

                Positioned(
                  left: 0,
                  top: (g.trackHeight - g.thumbSize) / 2,
                  width: g.thumbSize,
                  height: g.thumbSize,
                  child: Transform.translate(
                    offset: Offset(p * w - g.thumbSize / 2, 0),
                    child: ScaleTransition(
                      scale: _thumbScale,
                      child: DecoratedBox(
                        key: PlayerBarKeys.thumb,
                        decoration: BoxDecoration(
                          color: fixed.thumb,
                          borderRadius: BorderRadius.circular(g.thumbRadius),
                          boxShadow: [fixed.thumbShadow],
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

  Widget _iconLayer(CameoIconName name, double t) {
    final buttonIcon = _fixedRoles(CameoTheme.colorsOf(context)).buttonIcon;
    final scale = _reduce
        ? 1.0
        : lerpDouble(CameoMotion.playPauseMinScale, 1, t)!;
    return Positioned.fill(
      child: Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: scale,
          child: CameoIcon(name, size: _g.buttonIconSize, color: buttonIcon),
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
