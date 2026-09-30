// Map transcript lines to playback intervals and seek targets. Clamp lookup at the
// first and last interval.

import 'package:flutter/foundation.dart';

import '../../content/lab.g.dart';
import '../../design_system/design_system.dart';

typedef TimelineLine = ({String text, bool current, double? solidUntil});

typedef TimelinePlayer = ({int durationSeconds, double progress, bool playing});

TimelineLine timelineLineOf(TranscriptLineContent l) =>
    (text: l.text, current: l.current, solidUntil: l.gradient?.solidUntil);

TimelineLine timelineLineOfV5(TranscriptV5LineContent l) =>
    (text: l.text, current: l.current, solidUntil: null);

TimelinePlayer timelinePlayerOf(PlayerContent p) => (
  durationSeconds: p.durationSeconds,
  progress: p.progress,
  playing: p.playing,
);

TimelinePlayer timelinePlayerOfV5(PlayerV5Content p) => (
  durationSeconds: p.durationSeconds,
  progress: p.progress,
  playing: p.playing,
);

typedef PlaybackOptions = ({
  double durationSec,
  double initialSec,
  bool playing,
});

PlaybackOptions playbackOptionsOf(TimelinePlayer player) => (
  durationSec: player.durationSeconds.toDouble(),
  initialSec: player.progress * player.durationSeconds,
  playing: player.playing,
);

typedef LineRange = ({double start, double end});

@immutable
class TranscriptTimeline {
  const TranscriptTimeline({
    required this.durationSec,
    required this.ranges,
    required this.anchorIndex,
  });

  final double durationSec;

  final List<LineRange> ranges;

  final int anchorIndex;
}

const double _timeEpsilonSec = 1e-6;

final RegExp _space = RegExp(r'\s');

int lineWeight(String text) {
  var n = 0;
  for (final rune in text.runes) {
    if (!_space.hasMatch(String.fromCharCode(rune))) n += 1;
  }
  return n;
}

List<LineRange> _laidOut(List<int> weights, double from, double rate) {
  final out = <LineRange>[];
  var cursor = from;
  for (final w in weights) {
    final end = cursor + w * rate;
    out.add((start: cursor, end: end));
    cursor = end;
  }
  return out;
}

int _sum(Iterable<int> xs) => xs.fold(0, (s, x) => s + x);

///

///

TranscriptTimeline buildTranscriptTimeline(
  List<TranscriptLineContent> lines,
  PlayerContent player,
) => buildTimeline([
  for (final l in lines) timelineLineOf(l),
], timelinePlayerOf(player));

TranscriptTimeline buildTranscriptTimelineV5(
  List<TranscriptV5LineContent> lines,
  PlayerV5Content player, {
  double? anchorFraction,
}) => buildTimeline(
  [for (final l in lines) timelineLineOfV5(l)],
  timelinePlayerOfV5(player),
  anchorFraction: anchorFraction ?? CameoGradients.karaokeV5.fadeStart,
);

TranscriptTimeline buildTimeline(
  List<TimelineLine> lines,
  TimelinePlayer player, {
  double? anchorFraction,
}) {
  final durationSec = player.durationSeconds.toDouble();

  final anchorSec = player.progress * player.durationSeconds;
  final weights = [for (final l in lines) lineWeight(l.text)];
  final anchorIndex = lines.indexWhere((l) => l.current);
  final total = _sum(weights);
  TranscriptTimeline uniform() => TranscriptTimeline(
    durationSec: durationSec,
    ranges: _laidOut(weights, 0, total > 0 ? durationSec / total : 0),
    anchorIndex: anchorIndex,
  );
  if (anchorIndex < 0) return uniform();

  final f = anchorFraction ?? lines[anchorIndex].solidUntil ?? 0;
  final head = weights.sublist(0, anchorIndex + 1);
  final tail = weights.sublist(anchorIndex + 1);
  final before = _sum(head.take(anchorIndex));
  final denom = before + f * weights[anchorIndex];
  if (!(denom > 0) || !(anchorSec > 0)) return uniform();

  final headRanges = _laidOut(head, 0, anchorSec / denom);
  final headEnd = headRanges.last.end;
  if (headEnd > durationSec) return uniform();
  final tailTotal = _sum(tail);
  final tailRanges = _laidOut(
    tail,
    headEnd,
    tailTotal > 0 ? (durationSec - headEnd) / tailTotal : 0,
  );
  return TranscriptTimeline(
    durationSec: durationSec,
    ranges: [...headRanges, ...tailRanges],
    anchorIndex: anchorIndex,
  );
}

int lineIndexAt(List<LineRange> ranges, double t) {
  var index = 0;
  for (var i = 1; i < ranges.length; i += 1) {
    if (t + _timeEpsilonSec >= ranges[i].start) {
      index = i;
    } else {
      break;
    }
  }
  return index;
}

double lineProgressAt(LineRange range, double t) {
  final span = range.end - range.start;
  if (!(span > 0)) return 1;
  return ((t - range.start) / span).clamp(0.0, 1.0).toDouble();
}

double karaokeTimeAt(
  List<LineRange> ranges,
  int current, {
  required double displaySec,
  required double clockSec,
  required double seekOriginSec,
}) => lineIndexAt(ranges, seekOriginSec) == current ? displaySec : clockSec;
