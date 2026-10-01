// Light transcript, highlights, inline photos, and playback. Active lines change ink
// color while playback and scrubbing share one controller.

//

import 'package:flutter/widgets.dart';

import '../../components/playback_controller.dart';
import '../../components/transcript_reader.dart';
import '../../components/transcript_v6_line.dart';
import '../../content/lab.g.dart';
import '../../navigation/cameo_nav.dart';
import '../../navigation/route_params.dart';
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
  late final _timeline = buildTranscriptTimelineV5(
    widget.content.lines,
    widget.content.player,
    anchorFraction: _lineStartFraction,
  );
  late final _playback = PlaybackController(
    vsync: this,
    durationSec: _timeline.durationSec,
    initialSec: widget.content.player.progress * _timeline.durationSec,
    playing: widget.content.player.playing,
  );
  final _demo = DemoTimeline();
  bool _liked = false;

  @override
  void initState() {
    super.initState();
    if (widget.demo) {
      _demo.start([
        (at: TranscriptDemoV6.pause, run: _playback.pause),
        (
          at: TranscriptDemoV6.seekMarker,
          run: () => _playback.seekTo(
            widget.content.player.markers.firstOrNull?.start ?? 0,
          ),
        ),
        (at: TranscriptDemoV6.play, run: _playback.play),
        (at: TranscriptDemoV6.tapLine, run: () => _playback.seekTo(0)),
        (
          at: TranscriptDemoV6.like,
          run: () {
            if (mounted) setState(() => _liked = true);
          },
        ),
      ]);
    }
  }

  @override
  void dispose() {
    _demo.cancel();
    _playback.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entries = [
      for (var i = 0; i < _content.lines.length; i++)
        TranscriptEntry(
          id: _content.lines[i].id,
          text: _content.lines[i].text,
          start: _timeline.ranges[i].start,
          end: _timeline.ranges[i].end,
          right: _content.lines[i].side == LabAlign.right,
          highlight: _content.lines[i].inHighlight ? 'highlight' : null,
        ),
    ];
    return TranscriptReader(
      key: TranscriptScreen.rootKey,
      title: _content.title,
      subtitle: _content.date,
      entries: entries,
      playback: _playback,
      liked: _liked,
      onClose: () => CameoNav.pop(context),
      onCall: () => CameoNav.openCall(context),
      onLike: () => setState(() => _liked = !_liked),
      onDelete: () => CameoNav.pop(context),
    );
  }
}
