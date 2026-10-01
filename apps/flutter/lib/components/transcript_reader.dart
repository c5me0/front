import 'dart:math' as math;
import 'dart:ui' show ImageFilter, lerpDouble;

import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/widgets.dart';

import '../content/app.g.dart';
import '../design_system/design_system.dart';
import 'karaoke_text.dart' show KeepAllText;
import 'playback_controller.dart';
import 'scrim_button.dart';
import 'scrim_pill.dart';
import 'glass_caption.dart';

@immutable
class TranscriptEntry {
  const TranscriptEntry({
    required this.id,
    required this.text,
    required this.start,
    required this.end,
    this.right = false,
    this.highlight,
  });
  final String id, text;
  final double start, end;
  final bool right;
  final String? highlight;
}

/// Shared presentation for recorded calls and local design previews. The caller
/// supplies real timestamps and owns playback, loading and mutations.
class TranscriptReader extends StatefulWidget {
  const TranscriptReader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.entries,
    required this.onClose,
    required this.onCall,
    required this.onLike,
    required this.onDelete,
    required this.liked,
    this.playback,
    this.notice,
    this.media = const [],
  });
  final String title, subtitle;
  final List<TranscriptEntry> entries;
  final PlaybackController? playback;
  final Widget? notice;
  final List<Widget> media;
  final VoidCallback onClose, onCall, onLike, onDelete;
  final bool liked;

  @override
  State<TranscriptReader> createState() => _TranscriptReaderState();
}

class _TranscriptReaderState extends State<TranscriptReader>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final _fold = AnimationController.unbounded(vsync: this);
  final _scroll = ScrollController();
  bool _collapsed = false, _expanded = true;
  int _contextMinutes = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.playback?.reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (ModalRoute.of(context)?.isCurrent == false) widget.playback?.pause();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) widget.playback?.pause();
  }

  void _setCollapsed(bool value) {
    if (_collapsed == value || (value && widget.playback?.scrubbing == true)) {
      return;
    }
    _collapsed = value;
    if (MediaQuery.disableAnimationsOf(context)) {
      _fold.value = value ? 1 : 0;
    } else {
      _fold.springTo(value ? 1 : 0, CameoSprings.smooth);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fold.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CameoTheme(
    mode: CameoColorMode.light,
    child: Builder(builder: _body),
  );

  Widget _body(BuildContext context) {
    final c = CameoTheme.colorsOf(context),
        copy = AppContent.of(context).v6.record;
    final playback = widget.playback;
    final firstHighlight = widget.entries.indexWhere(
      (entry) => entry.highlight != null,
    );
    final anchor = firstHighlight < 0
        ? 0.0
        : widget.entries[firstHighlight].start;
    final start = math.max(0.0, anchor - _contextMinutes * 60);
    final visible = widget.entries.where((entry) => entry.end > start).toList();
    final groups = <List<TranscriptEntry>>[];
    for (final entry in visible) {
      if (entry.highlight != null &&
          groups.isNotEmpty &&
          groups.last.last.highlight == entry.highlight) {
        groups.last.add(entry);
      } else {
        groups.add([entry]);
      }
    }
    Widget conversation() {
      var highlightNumber = 0;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.notice != null) widget.notice!,
          if (firstHighlight > 0)
            _contextButton(
              start > 0 ? copy.viewContext : copy.collapseContext,
              CameoIconName.chevronDown,
              () => setState(
                () => _contextMinutes = start > 0 ? _contextMinutes + 5 : 0,
              ),
              flipped: start <= 0,
            ),
          for (final group in groups)
            if (group.first.highlight != null) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 16, 8, 16),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: c.backgroundCanvasElevatedBase,
                    borderRadius: BorderRadius.circular(CameoRadius.xl),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                          child: CameoText(
                            fillTemplate(copy.highlight, {
                              'number': ++highlightNumber,
                              'time': formatPlaybackTime(group.first.start),
                            }),
                            style: CameoTextStyles.bodyMd,
                            color: c.foregroundNeutralMuted,
                          ),
                        ),
                        for (final entry in group)
                          _line(context, entry, highlighted: true),
                      ],
                    ),
                  ),
                ),
              ),
              _contextButton(
                _expanded ? copy.collapse : copy.expand,
                CameoIconName.chevronDown,
                () => setState(() => _expanded = !_expanded),
                flipped: _expanded,
              ),
            ] else if (_expanded ||
                firstHighlight < 0 ||
                group.first.end <= anchor)
              _line(context, group.first),
          ...widget.media,
        ],
      );
    }

    return ColoredBox(
      color: c.backgroundCanvasNeutralStrong,
      child: Stack(
        children: [
          Positioned.fill(
            child: MouseRegion(
              onEnter: (_) => _setCollapsed(false),
              onExit: (_) => _setCollapsed(true),
              child: NotificationListener<UserScrollNotification>(
                onNotification: (event) {
                  if (event.direction != ScrollDirection.idle) {
                    _setCollapsed(true);
                  }
                  return false;
                },
                child: SingleChildScrollView(
                  key: const ValueKey('transcript.scroll'),
                  controller: _scroll,
                  padding: const EdgeInsets.only(
                    top: CameoLayout.silicaTranscriptHeaderHeight,
                    bottom: CameoLayout.silicaTranscriptFooterHeight,
                  ),
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  child: playback == null
                      ? conversation()
                      : AnimatedBuilder(
                          animation: playback,
                          builder: (_, __) => conversation(),
                        ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: CameoLayout.silicaTranscriptHeaderHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: c.gradients.topLinear),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: CameoLayout.screenV6StatusBarHeight),
                  Semantics(
                    button: true,
                    label: AppContent.of(context).v6.album.closeLabel,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: widget.onClose,
                      onVerticalDragEnd: (details) {
                        if ((details.primaryVelocity ?? 0) > 0) {
                          widget.onClose();
                        }
                      },
                      child: SizedBox(
                        height: CameoLayout.silicaTranscriptHandleAreaHeight,
                        child: Center(
                          child: Container(
                            width: CameoLayout.silicaTranscriptHandleWidth,
                            height: CameoLayout.silicaTranscriptHandleHeight,
                            decoration: BoxDecoration(
                              color: c.backgroundFillNeutralBase,
                              borderRadius: BorderRadius.circular(
                                CameoRadius.full,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        CameoText(
                          widget.title,
                          key: const ValueKey('transcript.title'),
                          style: CameoTextStyles.headingLg,
                          color: c.foregroundNeutralBase,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 8),
                        CameoText(
                          widget.subtitle,
                          style: CameoTextStyles.bodyMd,
                          color: c.foregroundNeutralMuted,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(left: 0, right: 0, bottom: 0, child: _footer(context)),
        ],
      ),
    );
  }

  Widget _contextButton(
    String label,
    CameoIconName icon,
    VoidCallback action, {
    bool flipped = false,
  }) => SizedBox(
    height: CameoLayout.silicaTranscriptContextHeight,
    child: Center(
      child: PressScale(
        onPress: action,
        accessibilityLabel: label,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: CameoText(
                  label,
                  style: CameoTextStyles.bodyMd,
                  color: CameoPalette.light.foregroundNeutralBase,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 8),
              RotatedBox(
                quarterTurns: flipped ? 2 : 0,
                child: CameoIcon(
                  icon,
                  size: 18,
                  color: CameoPalette.light.foregroundNeutralBase,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _line(
    BuildContext context,
    TranscriptEntry entry, {
    bool highlighted = false,
  }) {
    final playback = widget.playback, c = CameoTheme.colorsOf(context);
    final seconds = playback?.seconds ?? -1;
    final current = seconds >= entry.start && seconds < entry.end;
    final progress = entry.end > entry.start
        ? ((seconds - entry.start) / (entry.end - entry.start)).clamp(0.0, 1.0)
        : 0.0;
    Widget text = KeepAllText(
      entry.text,
      style: highlighted || current
          ? CameoTextStyles.headingMdStrong
          : CameoTextStyles.headingSmStrong,
      color: current ? c.foregroundNeutralBase : c.foregroundNeutralSubtle,
      textAlign: entry.right ? TextAlign.right : TextAlign.left,
    );
    if (current) {
      text = ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (bounds) => LinearGradient(
          colors: [c.foregroundNeutralBase, c.staticWhiteSubtle],
          stops: [progress, math.min(1, progress + .75)],
        ).createShader(bounds),
        child: text,
      );
    }
    return Padding(
      key: ValueKey('transcript.row.${entry.id}'),
      padding: EdgeInsets.symmetric(
        horizontal: CameoLayout.silicaTranscriptLinePaddingX,
        vertical: highlighted
            ? CameoSpace.s16
            : CameoLayout.silicaTranscriptLinePaddingY,
      ),
      child: Align(
        alignment: entry.right ? Alignment.centerRight : Alignment.centerLeft,
        child: Semantics(
          selected: current,
          child: PressScale(
            onPress: playback == null || playback.durationSec <= 0
                ? null
                : () => playback.seekTo(entry.start / playback.durationSec),
            accessibilityLabel: entry.text,
            child: text,
          ),
        ),
      ),
    );
  }

  Widget _footer(BuildContext context) {
    final playback = widget.playback;
    return AnimatedBuilder(
      animation: Listenable.merge([
        _fold,
        if (playback != null) playback,
        if (playback != null) playback.position,
      ]),
      builder: (context, _) {
        final c = CameoTheme.colorsOf(context), copy = AppContent.of(context);
        final folded = _fold.value.clamp(0.0, 1.0);
        final trackHeight = playback?.scrubbing == true
            ? CameoLayout.silicaTranscriptScrubTrackHeight
            : CameoLayout.silicaTranscriptTrackHeight;
        final fullHeight =
            CameoLayout.silicaTranscriptFooterHeight +
            trackHeight -
            CameoLayout.silicaTranscriptTrackHeight;
        final height = lerpDouble(
          fullHeight,
          CameoLayout.silicaTranscriptCollapsedFooterHeight,
          folded,
        )!;
        final remaining = math.max(
          0.0,
          (playback?.durationSec ?? 0) - (playback?.seconds ?? 0),
        );
        return ClipRect(
          child: SizedBox(
            height: height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: CameoBlur.blur.sigma,
                        sigmaY: CameoBlur.blur.sigma,
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: c.gradients.bottomLinear,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top:
                      CameoLayout.silicaTranscriptFadeHeight +
                      folded * fullHeight,
                  child: IgnorePointer(
                    ignoring: _collapsed,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal:
                                CameoLayout.silicaTranscriptSliderPaddingX,
                          ),
                          child: Column(
                            children: [
                              _track(context, trackHeight),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  CameoText(
                                    formatPlaybackTime(playback?.seconds ?? 0),
                                    style: CameoTextStyles.bodyMd,
                                    color: c.foregroundNeutralBase,
                                  ),
                                  CameoText(
                                    formatPlaybackTime(
                                      playback?.durationSec ?? 0,
                                    ),
                                    style: CameoTextStyles.bodyMd,
                                    color: c.foregroundNeutralSubtle,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              ScrimPill(
                                size: ScrimPillSize.large,
                                items: [
                                  ScrimPillItem(
                                    icon: CameoIconName.trash,
                                    semanticLabel: copy.v6.backend.delete,
                                    onPress: widget.onDelete,
                                  ),
                                  ScrimPillItem(
                                    icon: CameoIconName.heart,
                                    active: widget.liked,
                                    semanticLabel: widget.liked
                                        ? copy.v6.album.unlikeLabel
                                        : copy.v6.album.likeLabel,
                                    onPress: widget.onLike,
                                  ),
                                  ScrimPillItem(
                                    icon: CameoIconName.phoneCall,
                                    semanticLabel: copy.v6.tabBar.callLabel,
                                    onPress: () {
                                      playback?.pause();
                                      widget.onCall();
                                    },
                                  ),
                                ],
                              ),
                              ScrimButton(
                                size: ScrimButtonSize.xl,
                                icon: playback?.playing == true
                                    ? CameoIconName.playerPauseFilled
                                    : CameoIconName.playerPlayFilled,
                                semanticLabel: playback?.playing == true
                                    ? copy.v6.record.pause
                                    : copy.v6.record.play,
                                disabled: playback == null,
                                onPress: playback?.toggle,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top:
                      CameoLayout.silicaTranscriptFadeHeight +
                      (1 - folded) * fullHeight,
                  child: Center(
                    child: GlassCaption(
                      label: fillTemplate(copy.v6.record.remaining, {
                        'time': formatPlaybackTime(remaining),
                      }),
                      semanticLabel: copy.v6.record.showControls,
                      onPress: () => _setCollapsed(false),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _track(BuildContext context, double height) {
    final playback = widget.playback, c = CameoTheme.colorsOf(context);
    return LayoutBuilder(
      builder: (_, constraints) {
        void start(Offset position) {
          if (playback == null) return;
          _setCollapsed(false);
          if (!playback.scrubbing) playback.beginScrub();
          playback.scrubTo(position.dx / constraints.maxWidth);
        }

        return Semantics(
          slider: true,
          label: AppContent.of(context).v6.record.seek,
          value: formatPlaybackTime(playback?.seconds ?? 0),
          increasedValue: playback == null
              ? null
              : formatPlaybackTime(
                  math.min(playback.durationSec, playback.seconds + 10),
                ),
          decreasedValue: playback == null
              ? null
              : formatPlaybackTime(math.max(0, playback.seconds - 10)),
          onIncrease: playback == null
              ? null
              : () => playback.seekTo(
                  (playback.seconds + 10) / playback.durationSec,
                ),
          onDecrease: playback == null
              ? null
              : () => playback.seekTo(
                  (playback.seconds - 10) / playback.durationSec,
                ),
          child: GestureDetector(
            key: const ValueKey('transcript.slider'),
            behavior: HitTestBehavior.opaque,
            onTapDown: playback == null
                ? null
                : (details) => start(details.localPosition),
            onTapUp: (_) => playback?.endScrub(),
            onTapCancel: playback?.endScrub,
            onHorizontalDragStart: playback == null
                ? null
                : (details) => start(details.localPosition),
            onHorizontalDragUpdate: (details) => playback?.scrubTo(
              details.localPosition.dx / constraints.maxWidth,
            ),
            onHorizontalDragEnd: (_) => playback?.endScrub(),
            onHorizontalDragCancel: playback?.endScrub,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(CameoRadius.full),
                child: SizedBox(
                  height: height,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(color: c.backgroundFillNeutralBase),
                      FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: playback?.position.value ?? 0,
                        child: ColoredBox(color: c.foregroundNeutralBase),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
