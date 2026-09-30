// Regression coverage for player playback controller. Preserve behavior, layout, and
// interaction expectations.

import 'package:cameo/components/playback_controller.dart';
import 'package:cameo/content/lab.g.dart';
import 'package:flutter_test/flutter_test.dart';

final PlayerContent _player = labTranscript.player;

void main() {
  group('formatPlaybackTime (2042:3223 / 3229)', () {
    test('mm:ss, 소수 버림, 음수/NaN → 00:00', () {
      expect(formatPlaybackTime(443), '07:23');
      expect(formatPlaybackTime(_player.progress * 443), '01:42');
      expect(formatPlaybackTime(59.99), '00:59');
      expect(formatPlaybackTime(0), '00:00');
      expect(formatPlaybackTime(-3), '00:00');
      expect(formatPlaybackTime(double.nan), '00:00');
      expect(formatPlaybackTime(double.infinity), '00:00');
    });
  });

  group('PlaybackController', () {
    testWidgets('fromContent = Figma 스냅샷 (position 0.232258, 재생 중)', (
      tester,
    ) async {
      final c = PlaybackController.fromContent(_player, vsync: tester);
      expect(c.durationSec, 443);
      expect(c.position.value, closeTo(_player.progress, 1e-9));
      expect(c.wholeSeconds, 102);
      expect(c.playing, isTrue);
      c.dispose();
    });

    testWidgets('재생 중으로 만들면 첫 프레임이 끝난 뒤부터 흐른다 (DemoTimeline 과 같은 시각 0)', (
      tester,
    ) async {
      final c = PlaybackController(
        vsync: tester,
        durationSec: 443,
        playing: true,
      );

      await tester.pump(const Duration(milliseconds: 400));
      expect(c.seconds, 0);

      await tester.pump();
      expect(c.seconds, 0);
      await tester.pump(const Duration(milliseconds: 250));
      expect(c.seconds, closeTo(0.25, 1e-9));
      c.dispose();
    });

    testWidgets('첫 프레임 전에 dispose 해도 시작 콜백이 죽은 Ticker 를 건드리지 않는다', (
      tester,
    ) async {
      final c = PlaybackController(
        vsync: tester,
        durationSec: 443,
        playing: true,
      );
      c.dispose();
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('재생 중 실시간 진행 · 정수 초가 바뀔 때만 알림', (tester) async {
      final c = PlaybackController(
        vsync: tester,
        durationSec: 443,
        playing: true,
      );
      var notified = 0;
      c.addListener(() => notified++);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(c.seconds, closeTo(0.5, 1e-9));
      expect(notified, 0);
      await tester.pump(const Duration(milliseconds: 600));
      expect(c.seconds, closeTo(1.1, 1e-9));
      expect(c.wholeSeconds, 1);
      expect(notified, 1);
      expect(c.position.value, closeTo(1.1 / 443, 1e-9));
      c.dispose();
    });

    testWidgets('끝에 닿으면 멈추고, 다시 재생하면 처음부터', (tester) async {
      final c = PlaybackController(
        vsync: tester,
        durationSec: 443,
        initialSec: 442.5,
        playing: true,
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(c.seconds, 443);
      expect(c.playing, isFalse);
      expect(c.position.value, 1);
      c.play();
      expect(c.seconds, 0);
      expect(c.playing, isTrue);
      c.pause();
      await tester.pump();
      c.dispose();
    });

    testWidgets('seekTo: 시계는 즉시, 표시 위치는 seekSpring · 자름', (tester) async {
      final c = PlaybackController(vsync: tester, durationSec: 100);
      c.seekTo(0.5);
      expect(c.seconds, 50);
      expect(c.position.value, 0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(c.position.value, greaterThan(0));
      expect(c.position.value, lessThan(0.5));
      await tester.pump(const Duration(seconds: 1));
      expect(c.position.value, closeTo(0.5, 1e-9));

      c.seekTo(2);
      expect(c.seconds, 100);
      c.seekTo(-1, animated: false);
      expect(c.seconds, 0);
      expect(c.position.value, 0);
      await tester.pump(const Duration(seconds: 1));
      c.dispose();
    });

    testWidgets('seekOrigin: 탐색 스프링 출발 위치 · 즉시 이동·스크럽이면 옮긴 위치', (tester) async {
      final c = PlaybackController(
        vsync: tester,
        durationSec: 100,
        initialSec: 40,
      );
      expect(c.seekOrigin, closeTo(0.4, 1e-12));
      c.seekTo(0.7);
      expect(c.seekOrigin, closeTo(0.4, 1e-12), reason: '스프링 출발 = 이전 표시 위치');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      final mid = c.position.value;
      expect(mid, greaterThan(0.4));
      expect(mid, lessThan(0.7));

      c.seekTo(0.1);
      expect(c.seekOrigin, closeTo(mid, 1e-12));
      c.seekTo(0.3, animated: false);
      expect(c.seekOrigin, closeTo(0.3, 1e-12));
      c.beginScrub();
      expect(c.seekOrigin, closeTo(0.3, 1e-12));
      c.scrubTo(0.55);
      expect(c.seekOrigin, closeTo(0.55, 1e-12));
      c.endScrub();
      c.reduceMotion = true;
      c.seekTo(0.9);
      expect(c.seekOrigin, closeTo(0.9, 1e-12));
      await tester.pump(const Duration(seconds: 1));
      c.dispose();
    });

    testWidgets('NaN 위치 → 0 (RN clamp01 과 동일)', (tester) async {
      final c = PlaybackController(
        vsync: tester,
        durationSec: 100,
        initialSec: 50,
      );
      c.seekTo(double.nan, animated: false);
      expect(c.seconds, 0);
      expect(c.position.value, 0);
      c.scrubTo(0.5);
      c.scrubTo(double.nan);
      expect(c.seconds, 0);
      c.dispose();
    });

    testWidgets('reduceMotion 이면 seekTo 즉시', (tester) async {
      final c = PlaybackController(vsync: tester, durationSec: 100)
        ..reduceMotion = true;
      c.seekTo(0.3);
      expect(c.position.value, closeTo(0.3, 1e-9));
      c.dispose();
    });

    testWidgets('스크럽 중에는 시계가 멈추고, 끝나면 그 위치에서 이어간다', (tester) async {
      final c = PlaybackController(
        vsync: tester,
        durationSec: 100,
        playing: true,
      );
      await tester.pump();
      c.beginScrub();
      c.scrubTo(0.2);
      await tester.pump(const Duration(seconds: 1));
      expect(c.seconds, 20);
      expect(c.scrubbing, isTrue);
      c.scrubTo(5);
      expect(c.position.value, 1);
      c.scrubTo(0.2);
      c.endScrub();
      await tester.pump(const Duration(seconds: 1));
      expect(c.seconds, closeTo(21, 1e-9));
      c.pause();
      await tester.pump();
      c.dispose();
    });
  });
}
