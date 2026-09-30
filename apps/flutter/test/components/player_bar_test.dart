// Regression coverage for player bar. Preserve behavior, layout, and interaction
// expectations.

import 'dart:ui' show ImageFilter;

import 'package:cameo/components/playback_controller.dart';
import 'package:cameo/components/player_bar.dart';
import 'package:cameo/content/lab.g.dart';
import 'package:cameo/design_system/design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

const Size _screen = Size(393, 852);

final PlayerContent _player = labTranscript.player;
final double _initialSec = _player.progress * _player.durationSeconds;

void _screenSize(WidgetTester tester, [Size size = _screen]) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget _host(
  Widget bar, {
  Size size = _screen,
  double bottomPadding = 34,
  bool disableAnimations = false,
}) {
  return MediaQuery(
    data: MediaQueryData(
      size: size,
      padding: EdgeInsets.only(bottom: bottomPadding),
      disableAnimations: disableAnimations,
    ),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox.fromSize(
        size: size,
        child: Stack(children: [bar]),
      ),
    ),
  );
}

PlaybackController _paused(WidgetTester tester) => PlaybackController(
  vsync: tester,
  durationSec: _player.durationSeconds.toDouble(),
  initialSec: _initialSec,
);

Future<void> _dispose(WidgetTester tester, PlaybackController c) async {
  await tester.pumpWidget(const SizedBox());
  c.dispose();
}

Rect _rect(WidgetTester tester, Key key) => tester.getRect(find.byKey(key));

Finder _icon(CameoIconName name) =>
    find.byWidgetPredicate((w) => w is CameoIcon && w.name == name);

double _iconOpacity(WidgetTester tester, CameoIconName name) => tester
    .widget<Opacity>(
      find.ancestor(of: _icon(name), matching: find.byType(Opacity)).first,
    )
    .opacity;

double _iconScale(WidgetTester tester, CameoIconName name) => tester
    .widget<Transform>(
      find.ancestor(of: _icon(name), matching: find.byType(Transform)).first,
    )
    .transform
    .entry(0, 0);

double _thumbScale(WidgetTester tester) => tester
    .widget<ScaleTransition>(
      find
          .ancestor(
            of: find.byKey(PlayerBarKeys.thumb),
            matching: find.byType(ScaleTransition),
          )
          .first,
    )
    .scale
    .value;

void main() {
  group('PlayerBar 레이아웃 (light 2042:3220–3231)', () {
    testWidgets(
      '컨테이너 393x112 @ y740 · pill 361x60 @ (16,756) · 버튼 80x50 @ (292,761)',
      (tester) async {
        _screenSize(tester);
        final c = _paused(tester);
        await tester.pumpWidget(_host(PlayerBar(playback: c)));

        final container = find
            .descendant(
              of: find.byType(PlayerBar),
              matching: find.byType(Padding),
            )
            .first;
        // 112 = pt16 + pill 60 + pb36
        expect(
          tester.getRect(container),
          const Rect.fromLTWH(0, 740, 393, 112),
        );
        // 2042:3221 — x 16 → 377, y 756 → 816
        expect(
          _rect(tester, PlayerBarKeys.pill),
          const Rect.fromLTWH(16, 756, 361, 60),
        );

        expect(
          _rect(tester, PlayerBarKeys.button),
          const Rect.fromLTWH(292, 761, 80, 50),
        );

        expect(
          _rect(tester, PlayerBarKeys.scrubber),
          const Rect.fromLTWH(21, 763, 271, 46),
        );
        await _dispose(tester, c);
      },
    );

    testWidgets('스크러버 px12 py14 gap8 · 라벨 h18 · 트랙 h6 fill (세로 중앙 786)', (
      tester,
    ) async {
      _screenSize(tester);
      final c = _paused(tester);
      await tester.pumpWidget(_host(PlayerBar(playback: c)));

      final cur = _rect(tester, PlayerBarKeys.currentTime);
      final dur = _rect(tester, PlayerBarKeys.duration);
      final track = _rect(tester, PlayerBarKeys.track);

      expect(cur.left, 21 + 12); // px12
      expect(cur.top, 763 + 14); // py14
      expect(cur.height, 18); // bodyMd line-height/200
      expect(dur.right, 21 + 271 - 12);
      expect(dur.height, 18);
      expect(track.height, 6);
      expect(track.left, cur.right + 8); // gap8
      expect(track.right, dur.left - 8); // gap8
      expect(track.center.dy, 786);
      await _dispose(tester, c);
    });

    testWidgets('트랙 155(Figma 폭)에서 진행 36 · thumb 24..48 · 마커 80/19 · 122/12', (
      tester,
    ) async {
      _screenSize(tester);
      final c = _paused(tester);
      await tester.pumpWidget(_host(PlayerBar(playback: c)));
      final measured = _rect(tester, PlayerBarKeys.track).width;
      final size = Size(393 + _player.trackWidthPx - measured, 852);
      _screenSize(tester, size);
      await tester.pumpWidget(_host(PlayerBar(playback: c), size: size));

      final track = _rect(tester, PlayerBarKeys.track);
      expect(track.width, closeTo(155, 1e-9));

      final progress = _rect(tester, PlayerBarKeys.progress);
      expect(progress.right - track.left, closeTo(36, 1e-3));
      expect(progress.height, 6);
      expect(progress.top, track.top);

      final thumb = _rect(tester, PlayerBarKeys.thumb);
      expect(thumb.width, 24);
      expect(thumb.height, 24);
      expect(thumb.left - track.left, closeTo(24, 1e-3));
      expect(thumb.right - track.left, closeTo(48, 1e-3));
      expect(thumb.center.dy, track.center.dy);

      final m0 = _rect(tester, PlayerBarKeys.marker(0));
      final m1 = _rect(tester, PlayerBarKeys.marker(1));
      expect(m0.left - track.left, closeTo(80, 1e-3));
      expect(m0.width, closeTo(19, 1e-3));
      expect(m1.left - track.left, closeTo(122, 1e-3));
      expect(m1.width, closeTo(12, 1e-3));
      expect(m0.height, 6);
      expect(m0.top, track.top);
      await _dispose(tester, c);
    });

    testWidgets('393 에서도 진행 끝 = thumb 중심 = position × 트랙 폭', (tester) async {
      _screenSize(tester);
      final c = _paused(tester);
      await tester.pumpWidget(_host(PlayerBar(playback: c)));

      final track = _rect(tester, PlayerBarKeys.track);
      final end = track.left + _player.progress * track.width;
      expect(_rect(tester, PlayerBarKeys.progress).right, closeTo(end, 1e-6));
      expect(_rect(tester, PlayerBarKeys.thumb).center.dx, closeTo(end, 1e-6));
      await _dispose(tester, c);
    });

    testWidgets('하단 인셋이 pb36 보다 크면 아래 여백 = 인셋', (tester) async {
      _screenSize(tester);
      final c = _paused(tester);
      await tester.pumpWidget(_host(PlayerBar(playback: c), bottomPadding: 48));
      expect(
        _rect(tester, PlayerBarKeys.pill),
        const Rect.fromLTWH(16, 852 - 48 - 60, 361, 60),
      );
      expect(playerBarContainerHeight(bottomInset: 34), 112);
      expect(playerBarContainerHeight(bottomInset: 48), 16 + 60 + 48);
      await _dispose(tester, c);
    });
  });

  group('PlayerBar 역할 (light / dark 2042:3039–3050)', () {
    testWidgets('light: pill 틴트·테두리 · 시간 muted · 진행 player/progress', (
      tester,
    ) async {
      _screenSize(tester);
      final c = _paused(tester);
      await tester.pumpWidget(_host(PlayerBar(playback: c)));

      final glass = tester.widget<GlassSurface>(find.byType(GlassSurface));
      expect(glass.effect, GlassEffect.glass);
      expect(glass.blur, CameoBlur.glassBar);
      expect(glass.tint, CameoColors.backgroundNeutralSubtle);
      expect(glass.border, CameoColors.strokeNeutralBase);
      expect(glass.borderWidth, 1);
      expect(
        tester.widget<CameoText>(find.byKey(PlayerBarKeys.duration)).color,
        CameoColors.foregroundNeutralMuted,
      );
      final progress = tester.widget<DecoratedBox>(
        find.byKey(PlayerBarKeys.progress),
      );
      expect(
        (progress.decoration as BoxDecoration).color,
        CameoColors.playerProgress,
      );
      await _dispose(tester, c);
    });

    testWidgets(
      'dark: glass/tint-bar · glass/border · transcript/dark-time · player/progress-dark',
      (tester) async {
        _screenSize(tester);
        final c = _paused(tester);
        await tester.pumpWidget(
          _host(PlayerBar(playback: c, tone: PlayerBarTone.dark)),
        );

        final glass = tester.widget<GlassSurface>(find.byType(GlassSurface));
        expect(glass.tint, CameoColors.glassTintBar);
        expect(glass.border, CameoColors.glassBorder);
        expect(
          tester.widget<CameoText>(find.byKey(PlayerBarKeys.currentTime)).color,
          CameoColors.transcriptDarkTime,
        );
        final progress = tester.widget<DecoratedBox>(
          find.byKey(PlayerBarKeys.progress),
        );
        expect(
          (progress.decoration as BoxDecoration).color,
          CameoColors.playerProgressDark,
        );

        expect(
          _rect(tester, PlayerBarKeys.pill),
          const Rect.fromLTWH(16, 756, 361, 60),
        );
        expect(
          _rect(tester, PlayerBarKeys.button),
          const Rect.fromLTWH(292, 761, 80, 50),
        );
        await _dispose(tester, c);
      },
    );
  });

  group('PlayerBar darkToken (16-13 v3 2042:3220–3231, dark 모드)', () {
    Widget dark(Widget bar) =>
        CameoTheme(mode: CameoColorMode.dark, child: _host(bar));

    testWidgets(
      '컨테이너 393x110 @ y742 · pill 361x58 @ (16,758) 테두리 없음 · 스크러버 (20,764) 273x46 · 버튼 80x50 @ (293,762)',
      (tester) async {
        _screenSize(tester);
        final c = _paused(tester);
        await tester.pumpWidget(
          dark(PlayerBar(playback: c, tone: PlayerBarTone.darkToken)),
        );
        final container = find
            .descendant(
              of: find.byType(PlayerBar),
              matching: find.byType(Padding),
            )
            .first;
        // 110 = pt16 + pill 58 + pb36 (2042:3220 y 742)
        expect(
          tester.getRect(container),
          const Rect.fromLTWH(0, 742, 393, 110),
        );
        expect(
          _rect(tester, PlayerBarKeys.pill),
          const Rect.fromLTWH(16, 758, 361, 58),
        );

        expect(
          _rect(tester, PlayerBarKeys.scrubber),
          Rect.fromLTWH(
            16 + CameoLayout.playerV3ScrubberLeft,
            758 + CameoLayout.playerV3ScrubberTop,
            CameoLayout.playerV3ScrubberWidth,
            46,
          ),
        );

        expect(
          _rect(tester, PlayerBarKeys.button),
          Rect.fromLTWH(
            16 + CameoLayout.playerV3ButtonLeft,
            758 + CameoLayout.playerV3ButtonTop,
            80,
            50,
          ),
        );
        expect(_rect(tester, PlayerBarKeys.track).center.dy, 758 + 29);
        expect(
          playerBarContainerHeight(
            bottomInset: 34,
            tone: PlayerBarTone.darkToken,
          ),
          CameoLayout.playerV3ContainerHeight,
        );
        expect(
          playerBarContainerHeight(
            bottomInset: 48,
            tone: PlayerBarTone.darkToken,
          ),
          16 + 58 + 48,
        );
        await _dispose(tester, c);
      },
    );

    testWidgets(
      '역할: background/neutral/base · 시간 muted · 진행 neutral/strong · 마커 system/critical/muted · 버튼 neutral/interactive + pauseButtonBlur',
      (tester) async {
        _screenSize(tester);
        final c = _paused(tester);
        await tester.pumpWidget(
          dark(PlayerBar(playback: c, tone: PlayerBarTone.darkToken)),
        );
        final glass = tester.widget<GlassSurface>(
          find.byType(GlassSurface).first,
        );

        expect(glass.effect, GlassEffect.glass);
        expect(
          find.descendant(
            of: find.byKey(PlayerBarKeys.pill),
            matching: find.byType(LiquidGlass),
          ),
          findsOneWidget,
        );
        expect(
          tester
              .widgetList<BackdropFilter>(
                find.descendant(
                  of: find.byKey(PlayerBarKeys.pill),
                  matching: find.byType(BackdropFilter),
                ),
              )
              .map((b) => b.filter),
          [
            ImageFilter.blur(
              sigmaX: CameoBlur.pauseButtonBlur.sigma,
              sigmaY: CameoBlur.pauseButtonBlur.sigma,
            ),
          ],
        );
        expect(glass.blur, CameoBlur.glassBar);
        expect(glass.tint, CameoColorsDark.backgroundNeutralBase);
        expect(glass.border, isNull);
        expect(glass.borderWidth, CameoLayout.playerV3PillBorderWidth);
        for (final key in [PlayerBarKeys.currentTime, PlayerBarKeys.duration]) {
          expect(
            tester.widget<CameoText>(find.byKey(key)).color,
            CameoColorsDark.foregroundNeutralMuted,
          );
        }
        Color? fill(Key key) =>
            (tester.widget<DecoratedBox>(find.byKey(key)).decoration
                    as BoxDecoration)
                .color;
        expect(
          fill(PlayerBarKeys.progress),
          CameoColorsDark.backgroundNeutralStrong,
        );
        expect(
          fill(PlayerBarKeys.marker(0)),
          CameoColorsDark.backgroundSystemCriticalMuted,
        );
        expect(
          fill(PlayerBarKeys.marker(1)),
          CameoColorsDark.backgroundSystemCriticalMuted,
        );

        expect(
          fill(PlayerBarKeys.thumb),
          CameoColorsDark.surfaceBackgroundNormal,
        );

        expect(
          tester
              .widgetList<DecoratedBox>(
                find.descendant(
                  of: find.byKey(PlayerBarKeys.track),
                  matching: find.byType(DecoratedBox),
                ),
              )
              .map((d) => (d.decoration as BoxDecoration).color),
          contains(CameoColorsDark.playerTrack),
        );
        final button = tester.widget<BlurSurface>(
          find.descendant(
            of: find.byKey(PlayerBarKeys.button),
            matching: find.byType(BlurSurface),
          ),
        );
        expect(button.blur, CameoBlur.pauseButtonBlur);
        expect(button.tint, CameoColorsDark.backgroundNeutralInteractive);
        for (final name in [
          CameoIconName.playerPauseFilled,
          CameoIconName.playerPlayFilled,
        ]) {
          expect(
            tester.widget<CameoIcon>(_icon(name)).color,
            CameoColorsDark.foregroundNeutralBase,
          );
        }
        await _dispose(tester, c);
      },
    );

    testWidgets(
      'light·dark 톤 버튼은 불투명 background/canvas/base (블러 없음) · 마커 info/base',
      (tester) async {
        _screenSize(tester);
        final c = _paused(tester);
        await tester.pumpWidget(
          _host(PlayerBar(playback: c, tone: PlayerBarTone.dark)),
        );
        expect(
          find.descendant(
            of: find.byKey(PlayerBarKeys.button),
            matching: find.byType(BlurSurface),
          ),
          findsNothing,
        );
        expect(
          (tester
                      .widget<DecoratedBox>(find.byKey(PlayerBarKeys.marker(0)))
                      .decoration
                  as BoxDecoration)
              .color,
          CameoColors.backgroundInfoBase,
        );
        await _dispose(tester, c);
      },
    );

    testWidgets('인터랙션 동일: 마커 탭 → 마커 시작점 · 재생 버튼 → 재생', (tester) async {
      _screenSize(tester);
      final c = _paused(tester);
      await tester.pumpWidget(
        dark(PlayerBar(playback: c, tone: PlayerBarTone.darkToken)),
      );
      await tester.tap(find.byKey(PlayerBarKeys.marker(0)));
      await tester.pump();
      expect(
        c.seconds,
        closeTo(_player.markers[0].start * _player.durationSeconds, 1e-6),
      );
      await tester.tap(find.byKey(PlayerBarKeys.button));
      await tester.pump();
      expect(c.playing, isTrue);
      await _dispose(tester, c);
    });
  });

  group('PlayerBar 시계 · 접근성', () {
    testWidgets('라벨 = 실제 시계 01:42 / 07:23, 재생 중 1초 후 01:43', (tester) async {
      _screenSize(tester);
      final semantics = tester.ensureSemantics();
      final c = PlaybackController.fromContent(_player, vsync: tester);
      await tester.pumpWidget(_host(PlayerBar(playback: c)));

      expect(find.text('01:42'), findsOneWidget);
      expect(find.text('07:23'), findsOneWidget);
      expect(
        tester.getSemantics(find.byKey(PlayerBarKeys.scrubber)),
        containsSemantics(
          label: '재생 위치',
          value: '01:42 / 07:23',
          isSlider: true,
          hasIncreaseAction: true,
          hasDecreaseAction: true,
        ),
      );
      expect(find.bySemanticsLabel('일시정지'), findsOneWidget);

      final before = _rect(tester, PlayerBarKeys.thumb).center.dx;

      await tester.pump();
      expect(find.text('01:42'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('01:43'), findsOneWidget);
      expect(_rect(tester, PlayerBarKeys.thumb).center.dx, greaterThan(before));

      semantics.dispose();
      await _dispose(tester, c);
    });
  });

  group('PlayerBar 인터랙션', () {
    testWidgets('트랙 탭 → 시계 즉시 이동, 표시 위치는 seekSpring 으로 따라온다', (tester) async {
      _screenSize(tester);
      final c = _paused(tester);
      await tester.pumpWidget(_host(PlayerBar(playback: c)));

      final track = _rect(tester, PlayerBarKeys.track);
      await tester.tapAt(
        Offset(track.left + 0.75 * track.width, track.center.dy),
      );
      expect(c.seconds, closeTo(0.75 * 443, 1e-6));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(c.position.value, lessThan(0.75));
      expect(c.position.value, greaterThan(_player.progress));
      await tester.pump(const Duration(seconds: 1));
      expect(c.position.value, closeTo(0.75, 1e-6));
      expect(
        _rect(tester, PlayerBarKeys.thumb).center.dx,
        closeTo(track.left + 0.75 * track.width, 1e-6),
      );
      expect(find.text(formatPlaybackTime(0.75 * 443)), findsOneWidget);
      await _dispose(tester, c);
    });

    testWidgets('마커 탭 → 마커 시작점으로', (tester) async {
      _screenSize(tester);
      final c = _paused(tester);
      await tester.pumpWidget(_host(PlayerBar(playback: c)));

      await tester.tapAt(_rect(tester, PlayerBarKeys.marker(1)).center);
      expect(c.seconds, closeTo(_player.markers[1].start * 443, 1e-6));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(c.position.value, closeTo(_player.markers[1].start, 1e-6));
      await _dispose(tester, c);
    });

    testWidgets('thumb 잡기 → 1.15(press) · 드래그 1:1 탐색(자름) · 놓기 → 1(chewy)', (
      tester,
    ) async {
      _screenSize(tester);
      final c = _paused(tester);
      await tester.pumpWidget(_host(PlayerBar(playback: c)));

      final track = _rect(tester, PlayerBarKeys.track);
      final g = await tester.startGesture(
        _rect(tester, PlayerBarKeys.thumb).center,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(
        _thumbScale(tester),
        closeTo(CameoMotion.scrubberThumbGrabScale, 1e-3),
      );

      await g.moveBy(const Offset(20, 0));
      await tester.pump();
      expect(c.scrubbing, isTrue);
      expect(
        c.position.value,
        closeTo(_player.progress + 20 / track.width, 1e-6),
      );

      expect(
        _rect(tester, PlayerBarKeys.thumb).center.dx,
        closeTo(track.left + _player.progress * track.width + 20, 1e-6),
      );

      await g.moveBy(const Offset(-1000, 0));
      await tester.pump();
      expect(c.position.value, 0);

      await g.up();
      expect(c.scrubbing, isFalse);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(_thumbScale(tester), closeTo(1, 1e-3));
      await _dispose(tester, c);
    });

    testWidgets('드래그 중 PlayerBar 가 내려가면 스크럽이 끝나 시계가 다시 흐른다', (tester) async {
      _screenSize(tester);
      final c = PlaybackController.fromContent(_player, vsync: tester);
      await tester.pumpWidget(_host(PlayerBar(playback: c)));

      final g = await tester.startGesture(
        _rect(tester, PlayerBarKeys.thumb).center,
      );
      await g.moveBy(const Offset(10, 0));
      await tester.pump();
      expect(c.scrubbing, isTrue);

      await tester.pumpWidget(_host(const SizedBox()));
      expect(c.scrubbing, isFalse);
      final at = c.seconds;
      await tester.pump(const Duration(seconds: 1));
      expect(c.seconds, closeTo(at + 1, 1e-9));

      await g.up();
      await _dispose(tester, c);
    });

    testWidgets('재생/일시정지: 아이콘 교차 — minScale 까지 줄며 페이드(bouncy)', (tester) async {
      _screenSize(tester);
      final c = PlaybackController.fromContent(_player, vsync: tester);
      await tester.pumpWidget(_host(PlayerBar(playback: c)));

      expect(_iconOpacity(tester, CameoIconName.playerPauseFilled), 1);
      expect(_iconOpacity(tester, CameoIconName.playerPlayFilled), 0);

      await tester.tap(find.byKey(PlayerBarKeys.button));
      expect(c.playing, isFalse);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      final midPause = _iconScale(tester, CameoIconName.playerPauseFilled);
      expect(midPause, lessThan(1));
      expect(midPause, greaterThanOrEqualTo(CameoMotion.playPauseMinScale));

      await tester.pump(const Duration(milliseconds: 1500));
      expect(_iconOpacity(tester, CameoIconName.playerPauseFilled), 0);
      expect(_iconOpacity(tester, CameoIconName.playerPlayFilled), 1);
      expect(find.bySemanticsLabel('재생'), findsOneWidget);

      final paused = c.seconds;
      await tester.pump(const Duration(seconds: 1));
      expect(c.seconds, paused);
      await _dispose(tester, c);
    });

    testWidgets('모션 감소: 탐색·thumb 즉시, 아이콘은 크기 고정 페이드', (tester) async {
      _screenSize(tester);
      final c = PlaybackController.fromContent(_player, vsync: tester);
      await tester.pumpWidget(
        _host(PlayerBar(playback: c), disableAnimations: true),
      );
      expect(c.reduceMotion, isTrue);
      c.pause();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(_iconScale(tester, CameoIconName.playerPauseFilled), 1);
      final fading = _iconOpacity(tester, CameoIconName.playerPauseFilled);
      expect(fading, greaterThan(0));
      expect(fading, lessThan(1));
      await tester.pump(CameoMotion.durationBase);
      expect(_iconOpacity(tester, CameoIconName.playerPauseFilled), 0);

      final track = _rect(tester, PlayerBarKeys.track);
      await tester.tapAt(
        Offset(track.left + 0.4 * track.width, track.center.dy),
      );
      await tester.pump();
      expect(c.position.value, closeTo(0.4, 1e-9));

      final g = await tester.startGesture(
        _rect(tester, PlayerBarKeys.thumb).center,
      );
      await tester.pump();
      expect(_thumbScale(tester), CameoMotion.scrubberThumbGrabScale);
      await g.up();
      await tester.pump();
      expect(_thumbScale(tester), 1);
      await _dispose(tester, c);
    });
  });
}
