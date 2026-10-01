// Legacy photo-backed or dark transcript preview with karaoke highlighting.

import 'package:flutter/widgets.dart';
import '../../content/app.g.dart';

import '../../components/highlight_card.dart';
import '../../components/nav_bar.dart';
import '../../components/playback_controller.dart';
import '../../components/player_bar.dart';
import '../../components/title_block.dart';
import '../../components/transcript_background.dart';
import '../../components/transcript_line.dart';
import '../../content/lab.g.dart';
import '../../design_system/design_system.dart';
import '../../navigation/cameo_nav.dart';
import '../../navigation/route_params.dart';
import 'stagger_in.dart';
import 'transcript_timeline.dart';

abstract final class TranscriptDemo {
  static const Duration pause = Duration(milliseconds: 1500);
  static const Duration seekMarker = Duration(milliseconds: 3000);
  static const Duration play = Duration(milliseconds: 4500);
  static const Duration tapLine = Duration(milliseconds: 6500);

  static const int marker = 0;

  static const int line = 0;
}

CameoColorMode transcriptColorMode(TranscriptTheme theme) =>
    theme == TranscriptTheme.dark ? CameoColorMode.dark : CameoColorMode.light;

typedef TranscriptParts = ({
  TranscriptTone tone,
  NavBarVariant nav,
  PlayerBarTone player,
});

TranscriptParts transcriptParts(TranscriptTheme theme) =>
    theme == TranscriptTheme.dark
    ? (
        tone: TranscriptTone.darkToken,
        nav: GlassNavVariant.borderless,
        player: PlayerBarTone.darkToken,
      )
    : (
        tone: TranscriptTone.dark,
        nav: GlassNavVariant.regular,
        player: PlayerBarTone.dark,
      );

///

class TranscriptV3Screen extends StatefulWidget {
  const TranscriptV3Screen({
    super.key,
    this.theme = TranscriptTheme.dark,
    this.demo = false,
    this.content = labTranscript,
  });

  final TranscriptTheme theme;

  final bool demo;

  final TranscriptContent content;

  @override
  State<TranscriptV3Screen> createState() => _TranscriptV3ScreenState();
}

class _TranscriptV3ScreenState extends State<TranscriptV3Screen>
    with TickerProviderStateMixin {
  TranscriptContent get _content => identical(widget.content, labTranscript)
      ? LabSamples.of(context).labTranscript
      : widget.content;
  late final PlaybackController _playback = PlaybackController.fromContent(
    widget.content.player,
    vsync: this,
  );
  late final TranscriptTimeline _timeline = buildTranscriptTimeline(
    widget.content.lines,
    widget.content.player,
  );

  late int _current;

  late final ValueNotifier<double> _progress;

  bool _liked = false;

  bool _entered = false;
  bool _entranceArmed = false;
  Animation<double>? _routeAnimation;

  final DemoTimeline _demo = DemoTimeline();

  double get _t => _playback.position.value * _playback.durationSec;

  @override
  void initState() {
    super.initState();
    _current = lineIndexAt(_timeline.ranges, _playback.seconds);
    _progress = ValueNotifier<double>(
      lineProgressAt(_timeline.ranges[_current], _t),
    );
    _playback.position.addListener(_onPosition);
    if (widget.demo) _demo.start(_demoSteps());
  }

  List<DemoStep> _demoSteps() => [
    (at: TranscriptDemo.pause, run: _playback.pause),
    (at: TranscriptDemo.seekMarker, run: _demoSeekMarker),
    (at: TranscriptDemo.play, run: _playback.play),
    (at: TranscriptDemo.tapLine, run: _demoTapLine),
  ];

  void _demoSeekMarker() {
    final markers = _content.player.markers;
    if (TranscriptDemo.marker < markers.length) {
      _playback.seekTo(markers[TranscriptDemo.marker].start);
    }
  }

  void _demoTapLine() {
    final lines = _content.lines;
    if (TranscriptDemo.line < lines.length) {
      _seekToLine(lines[TranscriptDemo.line]);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_entranceArmed) return;
    _entranceArmed = true;

    final animation = ModalRoute.of(context)?.animation;
    if (animation == null || animation.isCompleted) {
      _entered = true;
    } else {
      _routeAnimation = animation..addStatusListener(_onRouteStatus);
    }
  }

  void _onRouteStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _routeAnimation?.removeStatusListener(_onRouteStatus);
    _routeAnimation = null;
    if (mounted) setState(() => _entered = true);
  }

  void _onPosition() {
    final ranges = _timeline.ranges;
    final index = lineIndexAt(ranges, _playback.seconds);
    if (index != _current) setState(() => _current = index);
    final t = karaokeTimeAt(
      ranges,
      index,
      displaySec: _t,
      clockSec: _playback.seconds,
      seekOriginSec: _playback.seekOrigin * _playback.durationSec,
    );
    _progress.value = lineProgressAt(ranges[index], t);
  }

  void _seekToLine(TranscriptLineContent line) {
    final i = _content.lines.indexWhere((l) => l.id == line.id);
    if (i < 0 || !(_timeline.durationSec > 0)) return;
    _playback.seekTo(_timeline.ranges[i].start / _timeline.durationSec);

    _onPosition();
  }

  @override
  void dispose() {
    _demo.cancel();
    _routeAnimation?.removeStatusListener(_onRouteStatus);
    _playback.position.removeListener(_onPosition);
    _playback.dispose();
    _progress.dispose();
    super.dispose();
  }

  static TranscriptLineContent _withCurrent(
    TranscriptLineContent l,
    bool current,
  ) => TranscriptLineContent(
    id: l.id,
    nodeIds: l.nodeIds,
    text: l.text,
    side: l.side,
    inHighlight: l.inHighlight,
    current: current,
    gradient: l.gradient,
  );

  @override
  Widget build(BuildContext context) {
    final colorMode = transcriptColorMode(widget.theme);
    final parts = transcriptParts(widget.theme);
    final photo = widget.theme == TranscriptTheme.photo;
    final currentId = _content.lines[_current].id;
    final outside = [
      for (final l in _content.lines)
        if (!l.inHighlight) l,
    ];
    final cardLines = [
      for (final l in _content.lines)
        if (l.inHighlight) _withCurrent(l, l.id == currentId),
    ];

    final titleTop =
        CameoLayout.titleBlockTop +
        (navBarFrameOf(context, variant: parts.nav).bottom -
            navBarFrame(variant: parts.nav).bottom);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return CameoTheme(
      mode: colorMode,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: photo
                ? TranscriptBackground(image: _content.darkBackground)
                : ColoredBox(
                    color: CameoPalette.of(colorMode).backgroundCanvasBase,
                  ),
          ),
          Positioned.fill(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: EdgeInsets.only(
                top: titleTop,
                bottom: playerBarContainerHeight(
                  bottomInset: bottomInset,
                  tone: parts.player,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TitleBlock(
                    title: _content.title,
                    subtitle: _content.date,
                    tone: parts.tone,
                  ),
                  for (final (i, line) in outside.indexed)
                    StaggerIn(
                      key: ValueKey(line.id),
                      index: i,
                      active: _entered,
                      child: TranscriptLine(
                        text: line.text,
                        side: line.side,
                        tone: parts.tone,
                        current: line.id == currentId,
                        progressValue: line.id == currentId ? _progress : null,
                        onPress: () => _seekToLine(line),
                      ),
                    ),
                  StaggerIn(
                    index: outside.length,
                    active: _entered,
                    child: HighlightCard(
                      lines: cardLines,
                      tone: parts.tone,
                      progressValue: _progress,
                      onLinePress: _seekToLine,
                    ),
                  ),
                ],
              ),
            ),
          ),
          PlayerBar(
            playback: _playback,
            tone: parts.player,
            markers: _content.player.markers,
          ),
          NavBar(
            variant: parts.nav,
            leading: NavLeading(
              icon: CameoIconName.chevronLeft,
              onPress: () => CameoNav.pop(context),
              accessibilityLabel: AppContent.of(context).common.back,
            ),
            actions: [
              NavAction(
                icon: CameoIconName.heart,
                activeIcon: CameoIconName.heartFilled,
                active: _liked,
                onPress: () => setState(() => _liked = !_liked),
                accessibilityLabel: AppContent.of(context).v6.album.likeLabel,
              ),
              NavAction(
                icon: CameoIconName.history,
                accessibilityLabel: AppContent.of(
                  context,
                ).v6.accessibility.history,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
