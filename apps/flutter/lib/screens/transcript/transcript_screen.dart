// Light transcript, highlights, inline photos, and playback. Active lines change ink
// color while playback and scrubbing share one controller.

//

import 'package:flutter/widgets.dart';
import '../../content/app.g.dart';

import '../../components/highlight_card_v6.dart';
import '../../components/inline_photo_v6.dart';
import '../../components/playback_controller.dart';
import '../../components/player_bar_v6.dart';
import '../../components/transcript_nav_v6.dart';
import '../../components/transcript_v6_layout.dart';
import '../../components/transcript_v6_line.dart';
import '../../components/transcript_v6_title.dart';
import '../../content/lab.g.dart';
import '../../design_system/design_system.dart';
import '../../navigation/cameo_nav.dart';
import '../../navigation/route_params.dart';
import 'stagger_in.dart';
import 'transcript_timeline.dart';

export 'transcript_v3_screen.dart' show TranscriptV3Screen;

const double _lineStartFraction = 0;

abstract final class TranscriptDemoV6 {
  static const Duration pause = Duration(milliseconds: 1500);
  static const Duration seekMarker = Duration(milliseconds: 3000);
  static const Duration play = Duration(milliseconds: 4500);
  static const Duration tapLine = Duration(milliseconds: 6500);
  static const Duration like = Duration(milliseconds: 8000);

  static const int marker = 0;

  static const int line = 0;
}

const String transcriptInlinePhotoLabel = '통화 중 공유한 사진';

class TranscriptScreen extends StatefulWidget {
  const TranscriptScreen({
    super.key,
    this.theme = TranscriptTheme.dark,
    this.demo = false,
    this.content = labTranscriptV5,
  });

  final TranscriptTheme theme;

  final bool demo;

  final TranscriptV5Content content;

  static const Key rootKey = ValueKey('transcript.v6');
  static const Key scrollKey = ValueKey('transcript.scroll');
  static const Key titleKey = ValueKey('transcript.title');
  static const Key headerKey = ValueKey('transcript.header');
  static const Key photoBlockKey = ValueKey('transcript.photoBlock');
  static const Key cardKey = ValueKey('transcript.card');

  static Key rowKey(String id) => ValueKey('transcript.row.$id');

  static Key lineKey(String id) => TranscriptTextV6.keyFor(id);

  @override
  State<TranscriptScreen> createState() => _TranscriptScreenState();
}

class _TranscriptScreenState extends State<TranscriptScreen>
    with TickerProviderStateMixin {
  TranscriptV5Content get _content => identical(widget.content, labTranscriptV5)
      ? LabSamples.of(context).labTranscriptV5
      : widget.content;
  late final PlaybackOptions _options = playbackOptionsOf(
    timelinePlayerOfV5(widget.content.player),
  );
  late final PlaybackController _playback = PlaybackController(
    vsync: this,
    durationSec: _options.durationSec,
    initialSec: _options.initialSec,
    playing: _options.playing,
  );
  late final TranscriptTimeline _timeline = buildTranscriptTimelineV5(
    widget.content.lines,
    widget.content.player,
    anchorFraction: _lineStartFraction,
  );

  late int _current;

  bool _liked = false;

  bool _entered = false;
  bool _entranceArmed = false;
  Animation<double>? _routeAnimation;

  final DemoTimeline _demo = DemoTimeline();

  @override
  void initState() {
    super.initState();
    _current = lineIndexAt(_timeline.ranges, _playback.seconds);

    _playback.position.addListener(_onPosition);
    _playback.addListener(_onPosition);
    if (widget.demo) _demo.start(_demoSteps());
  }

  List<DemoStep> _demoSteps() => [
    (at: TranscriptDemoV6.pause, run: _playback.pause),
    (at: TranscriptDemoV6.seekMarker, run: _demoSeekMarker),
    (at: TranscriptDemoV6.play, run: _playback.play),
    (at: TranscriptDemoV6.tapLine, run: _demoTapLine),
    (at: TranscriptDemoV6.like, run: _demoLike),
  ];

  void _demoSeekMarker() {
    final markers = _content.player.markers;
    if (TranscriptDemoV6.marker < markers.length) {
      _playback.seekTo(markers[TranscriptDemoV6.marker].start);
    }
  }

  void _demoTapLine() {
    final lines = _content.lines;
    if (TranscriptDemoV6.line < lines.length) {
      _seekToLine(lines[TranscriptDemoV6.line].id);
    }
  }

  void _demoLike() {
    if (mounted) setState(() => _liked = true);
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
    final index = lineIndexAt(_timeline.ranges, _playback.seconds);
    if (index != _current && mounted) setState(() => _current = index);
  }

  void _seekToLine(String id) {
    final i = _content.lines.indexWhere((l) => l.id == id);
    if (i < 0 || !(_timeline.durationSec > 0)) return;
    _playback.seekTo(_timeline.ranges[i].start / _timeline.durationSec);

    _onPosition();
  }

  void _toggleLike() => setState(() => _liked = !_liked);

  @override
  void dispose() {
    _demo.cancel();
    _routeAnimation?.removeStatusListener(_onRouteStatus);
    _playback.position.removeListener(_onPosition);
    _playback.removeListener(_onPosition);
    _playback.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CameoTheme(
      mode: CameoColorMode.light,
      child: GlassBackdrop(
        tone: GlassBackdropTone.fromToken(
          CameoEffects.liquidGlassBackdropTranscriptV6,
        ),
        child: Builder(builder: _buildBody),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final c = CameoTheme.colorsOf(context);
    final roles = transcriptV6Roles(c);
    final currentId = _content.lines[_current].id;
    final photo = _content.inlinePhoto;
    final outside = [
      for (final l in _content.lines)
        if (!l.inHighlight) l,
    ];
    final cardLines = <HighlightCardV6Line>[
      for (final l in _content.lines)
        if (l.inHighlight)
          (id: l.id, text: l.text, side: l.side, current: l.id == currentId),
    ];

    var order = 0;
    Widget lineRow(TranscriptV5LineContent line) {
      final current = line.id == currentId;
      if (photo.afterLineId != line.id) {
        return StaggerIn(
          key: ValueKey(line.id),
          index: order++,
          active: _entered,
          child: TranscriptLineV6(
            key: TranscriptScreen.rowKey(line.id),
            id: line.id,
            text: line.text,
            side: line.side,
            current: current,
            onPress: () => _seekToLine(line.id),
          ),
        );
      }

      final alignment = inlinePhotoAlignV6(line.side);
      final lineIndex = order++;
      final photoIndex = order++;
      return Padding(
        key: TranscriptScreen.photoBlockKey,
        padding: const EdgeInsets.symmetric(
          horizontal: CameoLayout.transcriptV6LinePaddingX,
          vertical: CameoLayout.transcriptV6LinePaddingY,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: CameoLayout.transcriptV6PhotoGapAbove,
          children: [
            StaggerIn(
              key: ValueKey(line.id),
              index: lineIndex,
              active: _entered,
              child: Align(
                alignment: alignment,
                child: PressScale(
                  onPress: () => _seekToLine(line.id),
                  accessibilityLabel: transcriptLineLabel(line.text),
                  child: TranscriptTextV6(
                    key: TranscriptScreen.lineKey(line.id),
                    text: line.text,
                    side: line.side,
                    current: current,
                  ),
                ),
              ),
            ),
            StaggerIn(
              index: photoIndex,
              active: _entered,
              child: Align(
                alignment: alignment,
                child: InlinePhotoV6(
                  image: photo.image,

                  onPress: () {},
                  semanticLabel: AppContent.of(
                    context,
                  ).v6.accessibility.inlinePhoto,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final rows = [for (final l in outside) lineRow(l)];

    return Stack(
      key: TranscriptScreen.rootKey,
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          key: const ValueKey('transcript.layer.canvas'),
          child: ColoredBox(color: roles.canvas),
        ),
        Positioned.fill(
          key: const ValueKey('transcript.layer.scroll'),
          child: SingleChildScrollView(
            key: TranscriptScreen.scrollKey,

            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),

            padding: const EdgeInsets.only(
              top: CameoLayout.transcriptV6HeaderHeight,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TranscriptTitleV6(
                  key: TranscriptScreen.titleKey,
                  title: _content.title,
                  date: _content.date,
                ),
                ...rows,
                StaggerIn(
                  index: order,
                  active: _entered,
                  child: HighlightCardV6(
                    key: TranscriptScreen.cardKey,
                    lines: cardLines,
                    onLinePress: (line) => _seekToLine(line.id),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          key: const ValueKey('transcript.layer.player'),
          left: 0,
          right: 0,
          bottom: 0,
          child: PlayerBarV6(
            playback: _playback,
            markers: _content.player.markers,
          ),
        ),

        Positioned(
          key: const ValueKey('transcript.layer.header'),
          left: 0,
          right: 0,
          top: 0,
          height: CameoLayout.transcriptV6HeaderHeight,
          child: IgnorePointer(
            child: DecoratedBox(
              key: TranscriptScreen.headerKey,
              decoration: BoxDecoration(gradient: c.gradients.topLinear),
            ),
          ),
        ),
        Positioned(
          key: const ValueKey('transcript.layer.nav'),
          left: 0,
          right: 0,
          top: CameoLayout.topNavV6Top,
          child: TranscriptNavV6(
            onClose: () => CameoNav.pop(context),
            onCall: () => CameoNav.openCall(context),
            liked: _liked,
            onToggleLike: _toggleLike,
          ),
        ),
      ],
    );
  }
}
