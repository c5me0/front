// Regression coverage for records settings v5. Preserve behavior, layout, and
// interaction expectations.

import 'package:cameo/components/playback_controller.dart';
import 'package:cameo/content/lab.g.dart';
import 'package:cameo/screens/transcript/transcript_timeline.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('타임라인 v5 (anchorFraction = karaokeV5.fadeStart 0)', () {
    test('재생 옵션: 443 · 0.299363 × 443 = 132.617 · 재생 중', () {
      final o = playbackOptionsOf(timelinePlayerOfV5(labTranscriptV5.player));
      expect(o.durationSec, 443);
      expect(o.initialSec, closeTo(132.617, 0.001));
      expect(o.playing, isTrue);
      expect(formatPlaybackTime(o.initialSec), '02:12');
    });

    test(
      '구간 표: l1 17.30 · l2 37.48 · l3 74.96 · l4 132.62 · l5 132.62–158.56 · l6 246.08 · l7 355.48 · l8 443 · 연속 · 시작 = l5 progress 0',
      () {
        final t = buildTranscriptTimelineV5(
          labTranscriptV5.lines,
          labTranscriptV5.player,
        );
        expect(t.anchorIndex, 4);
        const ends = [17.30, 37.48, 74.96, 132.62, 158.56, 246.08, 355.48, 443];
        for (var i = 0; i < ends.length; i++) {
          expect(t.ranges[i].end, closeTo(ends[i], 0.01), reason: 'l${i + 1}');
          if (i > 0) expect(t.ranges[i].start, t.ranges[i - 1].end);
        }
        expect(t.ranges.first.start, 0);
        final start = playbackOptionsOf(
          timelinePlayerOfV5(labTranscriptV5.player),
        ).initialSec;
        expect(lineIndexAt(t.ranges, start), 4);
        expect(lineProgressAt(t.ranges[4], start), closeTo(0, 1e-9));
      },
    );

    test('v3 회귀: 16-13 시작 위치의 l5 진행률 = 0.60577 (gradient.solidUntil)', () {
      final t = buildTranscriptTimeline(
        labTranscript.lines,
        labTranscript.player,
      );
      final start = labTranscript.player.progress * 443;
      expect(lineIndexAt(t.ranges, start), 4);
      expect(lineProgressAt(t.ranges[4], start), closeTo(0.60577, 1e-6));
    });
  });
}
