// Regression coverage for transcript screen. Preserve behavior, layout, and interaction
// expectations.

import 'package:cameo/components/highlight_card.dart';
import 'package:cameo/components/karaoke_text.dart';
import 'package:cameo/components/nav_bar.dart';
import 'package:cameo/components/playback_controller.dart';
import 'package:cameo/components/player_bar.dart';
import 'package:cameo/components/title_block.dart';
import 'package:cameo/components/transcript_background.dart';
import 'package:cameo/components/transcript_line.dart';
import 'package:cameo/content/lab.g.dart';
import 'package:cameo/design_system/design_system.dart';
import 'package:cameo/navigation/navigation.dart';
import 'package:cameo/screens/transcript/stagger_in.dart';
import 'package:cameo/screens/transcript/transcript_route.dart';
import 'package:cameo/screens/transcript/transcript_v3_screen.dart';
import 'package:cameo/screens/transcript/transcript_timeline.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const Size _screen = Size(393, 852);
const EdgeInsets _insets = EdgeInsets.only(top: 59, bottom: 34);
const double _tol = 0.001;

const double _figmaFade = 0.60577;

final TranscriptLineContent _l1 = labTranscript.lines[0];
final TranscriptLineContent _l5 = labTranscript.lines[4];
final TranscriptLineContent _l6 = labTranscript.lines[5];
final TranscriptLineContent _l7 = labTranscript.lines[6];

void _screenSize(WidgetTester tester) {
  tester.view.physicalSize = _screen;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget _host(Widget child, {bool disableAnimations = false}) {
  return MediaQuery(
    data: MediaQueryData(
      size: _screen,
      padding: _insets,
      viewPadding: _insets,
      disableAnimations: disableAnimations,
    ),
    child: Directionality(textDirection: TextDirection.ltr, child: child),
  );
}

TranscriptContent _figmaShaped() {
  const twoLines = {'l3', 'l4'};
  return TranscriptContent(
    screenNodeIds: labTranscript.screenNodeIds,
    title: '가나다',
    date: labTranscript.date,
    darkBackground: labTranscript.darkBackground,
    lines: [
      for (final l in labTranscript.lines)
        TranscriptLineContent(
          id: l.id,
          nodeIds: l.nodeIds,
          text: twoLines.contains(l.id) ? '가나\n다라' : '가나다',
          side: l.side,
          inHighlight: l.inHighlight,
          current: l.current,
          gradient: l.gradient,
        ),
    ],
    player: labTranscript.player,
  );
}

Future<void> _advance(WidgetTester tester, Duration total) async {
  const step = Duration(milliseconds: 50);
  var left = total;
  while (left > Duration.zero) {
    final d = left < step ? left : step;
    await tester.pump(d);
    left -= d;
  }
}

Future<void> _unmount(WidgetTester tester) =>
    tester.pumpWidget(const SizedBox());

Finder _lineText(String text) =>
    find.byWidgetPredicate((w) => w is KeepAllText && w.text == text);

KaraokeTextState _karaoke(WidgetTester tester) =>
    tester.state<KaraokeTextState>(find.byType(KaraokeText));

String _karaokeText(WidgetTester tester) =>
    tester.widget<KaraokeText>(find.byType(KaraokeText)).text;

Finder _icon(CameoIconName name) =>
    find.byWidgetPredicate((w) => w is CameoIcon && w.name == name);

void _expectRect(Rect actual, Rect expected) {
  expect(actual.left, closeTo(expected.left, _tol), reason: 'left');
  expect(actual.top, closeTo(expected.top, _tol), reason: 'top');
  expect(actual.width, closeTo(expected.width, _tol), reason: 'width');
  expect(actual.height, closeTo(expected.height, _tol), reason: 'height');
}

typedef _Figma = ({
  Rect back,
  Rect pill,
  Rect card,
  double wrapperHeight,
  Rect playerPill,
  Rect playerButton,
  double playerContainer,
});

const _Figma _figmaDark = (
  back: Rect.fromLTWH(16, 62, 54, 54), // 2042:3235
  pill: Rect.fromLTWH(273, 62, 104, 54), // 2042:3237
  card: Rect.fromLTWH(8, 394, 377, 272), // 2042:3250
  wrapperHeight: 288, // 2042:3249
  playerPill: Rect.fromLTWH(16, 758, 361, 58), // 2042:3221
  playerButton: Rect.fromLTWH(293, 762, 80, 50), // 2042:3230
  playerContainer: 110, // 2042:3220
);

const _Figma _figmaPhoto = (
  back: Rect.fromLTWH(16, 62, 56, 56), // 2042:3075
  pill: Rect.fromLTWH(377 - 106, 62, 106, 56), // 2042:3077
  card: Rect.fromLTWH(8, 394, 377, 274),
  wrapperHeight: 290, // 2042:3138
  playerPill: Rect.fromLTWH(16, 756, 361, 60), // 2042:3040
  playerButton: Rect.fromLTWH(292, 761, 80, 50), // 2042:3049
  playerContainer: 112, // 2042:3039
);

Future<void> _expectFigmaGeometry(WidgetTester tester, _Figma f) async {
  _expectRect(tester.getRect(find.byType(GlassIconButton)), f.back);
  _expectRect(tester.getRect(find.byType(GlassIconButtonGroup)), f.pill);

  _expectRect(
    tester.getRect(find.byType(TitleBlock)),
    const Rect.fromLTWH(0, 118, 393, 92),
  );

  final rows = find.byType(TranscriptLine);
  expect(rows, findsNWidgets(3));
  _expectRect(tester.getRect(rows.at(0)), const Rect.fromLTWH(0, 210, 393, 48));
  _expectRect(tester.getRect(rows.at(1)), const Rect.fromLTWH(0, 258, 393, 48));
  _expectRect(tester.getRect(rows.at(2)), const Rect.fromLTWH(0, 306, 393, 80));

  _expectRect(
    tester.getRect(find.byType(HighlightCard)),
    Rect.fromLTWH(0, 386, 393, f.wrapperHeight),
  );
  _expectRect(
    tester.getRect(
      find.descendant(
        of: find.byType(HighlightCard),
        matching: find.byType(BlurSurface),
      ),
    ),
    f.card,
  );

  _expectRect(tester.getRect(find.byKey(PlayerBarKeys.pill)), f.playerPill);
  _expectRect(tester.getRect(find.byKey(PlayerBarKeys.button)), f.playerButton);

  final scroll = tester.widget<SingleChildScrollView>(
    find.byType(SingleChildScrollView),
  );
  expect(scroll.padding, EdgeInsets.only(top: 118, bottom: f.playerContainer));
}

void main() {
  group(
    '줄 ↔ 시간 매핑 (transcript_timeline.dart, RN transcriptTimeline.ts 와 같은 값)',
    () {
      final timeline = buildTranscriptTimeline(
        labTranscript.lines,
        labTranscript.player,
      );
      final t0 =
          labTranscript.player.progress * labTranscript.player.durationSeconds;

      test('가중치 = 공백 뺀 글자 수', () {
        expect(
          [for (final l in labTranscript.lines) lineWeight(l.text)],
          [12, 14, 26, 40, 18, 8, 10, 8],
        );
      });

      test('구간이 0 → 07:23 을 빈틈없이 덮는다', () {
        final r = timeline.ranges;
        expect(r.length, labTranscript.lines.length);
        expect(r.first.start, 0);
        expect(r.last.end, closeTo(443, 1e-9));
        for (var i = 1; i < r.length; i++) {
          expect(r[i].start, r[i - 1].end);
        }
      });

      test('시작 위치(0.232258 × 443)의 current = l5, 줄 안 위치 = Figma 0.60577', () {
        expect(timeline.anchorIndex, 4);
        expect(lineIndexAt(timeline.ranges, t0), 4);
        expect(
          lineProgressAt(timeline.ranges[4], t0),
          closeTo(_figmaFade, 1e-9),
        );
      });

      test('구간 값 (초) — RN 과 같은 수식', () {
        const expected = [
          (0.0, 11.9984),
          (11.9984, 25.9966),
          (25.9966, 51.9931),
          (51.9931, 91.9879),
          (91.9879, 109.9855),
          (109.9855, 212.4515),
          (212.4515, 340.5340),
          (340.5340, 443.0),
        ];
        for (final (i, (s, e)) in expected.indexed) {
          expect(
            timeline.ranges[i].start,
            closeTo(s, 1e-4),
            reason: 'l${i + 1}',
          );
          expect(timeline.ranges[i].end, closeTo(e, 1e-4), reason: 'l${i + 1}');
        }
      });

      test('탐색 목표 = 줄 시작 → 부동소수 왕복 뒤에도 그 줄이 current', () {
        for (var i = 0; i < timeline.ranges.length; i++) {
          final f = timeline.ranges[i].start / timeline.durationSec;
          expect(lineIndexAt(timeline.ranges, f * timeline.durationSec), i);
        }
      });
    },
  );

  group('Figma 좌표 (393x852, 인셋 59/34)', () {
    testWidgets('16-13 dark v3 (2042:3219) — 기본 변형', (tester) async {
      _screenSize(tester);
      await tester.pumpWidget(
        _host(TranscriptV3Screen(content: _figmaShaped())),
      );
      await _advance(tester, const Duration(seconds: 2));
      await _expectFigmaGeometry(tester, _figmaDark);

      expect(find.byType(TranscriptBackground), findsNothing);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is ColoredBox &&
              w.color == CameoColorsDark.backgroundCanvasBase,
        ),
        findsOneWidget,
      );
      await _unmount(tester);
    });

    testWidgets('16-12 photo (2042:2933)', (tester) async {
      _screenSize(tester);
      await tester.pumpWidget(
        _host(
          TranscriptV3Screen(
            theme: TranscriptTheme.photo,
            content: _figmaShaped(),
          ),
        ),
      );
      await _advance(tester, const Duration(seconds: 2));
      await _expectFigmaGeometry(tester, _figmaPhoto);
      _expectRect(
        tester.getRect(find.byType(TranscriptBackground)),
        const Rect.fromLTWH(0, 0, 393, 852),
      );
      await _unmount(tester);
    });

    for (final theme in TranscriptTheme.values) {
      testWidgets(
        '안전 영역 top 80 → 내비가 18 내려가면 제목도 18 (Figma 내비–제목 간격 유지, ${theme.param})',
        (tester) async {
          _screenSize(tester);
          const insets = EdgeInsets.only(top: 80, bottom: 34);
          await tester.pumpWidget(
            MediaQuery(
              data: const MediaQueryData(
                size: _screen,
                padding: insets,
                viewPadding: insets,
              ),
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: TranscriptV3Screen(
                  theme: theme,
                  content: _figmaShaped(),
                ),
              ),
            ),
          );
          await _advance(tester, const Duration(seconds: 1));
          final back = tester.getRect(find.byType(GlassIconButton));
          final title = tester.getRect(find.byType(TitleBlock));
          expect(back.top, 80);
          expect(title.top, 118 + 18);

          expect(
            title.top - back.bottom,
            theme == TranscriptTheme.dark
                ? CameoLayout.titleBlockTop -
                      CameoLayout.navBarBorderlessTopAreaHeight
                : 0,
          );
          await _unmount(tester);
        },
      );
    }

    testWidgets('실제 문구: 같은 흐름 배치 (제목 118 → 줄 → 카드, 각 요소가 앞 요소 바로 아래)', (
      tester,
    ) async {
      _screenSize(tester);
      await tester.pumpWidget(_host(const TranscriptV3Screen()));
      await _advance(tester, const Duration(seconds: 2));
      final title = tester.getRect(find.byType(TitleBlock));
      expect(title.top, 118);
      final rows = find.byType(TranscriptLine);
      expect(rows, findsNWidgets(3));
      var bottom = title.bottom;
      for (var i = 0; i < 3; i++) {
        final r = tester.getRect(rows.at(i));
        expect(r.top, closeTo(bottom, _tol));
        expect(r.width, 393);
        bottom = r.bottom;
      }

      expect(tester.getRect(rows.at(0)).height, closeTo(48, _tol));
      expect(tester.getRect(rows.at(1)).height, closeTo(48, _tol));

      expect(
        tester.getRect(_lineText(labTranscript.lines[0].text)).left,
        closeTo(CameoLayout.transcriptLinePaddingX, _tol),
      );
      expect(
        tester.getRect(_lineText(labTranscript.lines[1].text)).right,
        closeTo(393 - CameoLayout.transcriptLinePaddingX, _tol),
      );
      expect(
        tester.getRect(find.byType(HighlightCard)).top,
        closeTo(bottom, _tol),
      );
      await _unmount(tester);
    });
  });

  group('변형 구성 (v3-plan Q2)', () {
    testWidgets(
      'dark: CameoTheme dark · 톤 darkToken · 내비 borderless · 플레이어 darkToken · 색 역할',
      (tester) async {
        _screenSize(tester);
        await tester.pumpWidget(_host(const TranscriptV3Screen()));
        await _advance(tester, const Duration(seconds: 1));
        expect(transcriptColorMode(TranscriptTheme.dark), CameoColorMode.dark);
        expect(
          tester.widget<CameoTheme>(find.byType(CameoTheme)).mode,
          CameoColorMode.dark,
        );
        expect(
          tester.widget<NavBar>(find.byType(NavBar)).variant,
          GlassNavVariant.borderless,
        );
        expect(
          tester.widget<PlayerBar>(find.byType(PlayerBar)).tone,
          PlayerBarTone.darkToken,
        );
        expect(
          tester.widget<TitleBlock>(find.byType(TitleBlock)).tone,
          TranscriptTone.darkToken,
        );
        expect(
          tester.widget<HighlightCard>(find.byType(HighlightCard)).tone,
          TranscriptTone.darkToken,
        );

        expect(
          tester.widget<KeepAllText>(_lineText(labTranscript.title)).color,
          CameoColorsDark.foregroundNeutralBase,
        );
        expect(
          tester.widget<KeepAllText>(_lineText(_l1.text)).color,
          CameoColorsDark.foregroundNeutralMuted,
        );
        expect(
          tester.widget<KeepAllText>(_lineText(_l6.text)).color,
          CameoColorsDark.foregroundNeutralSubtle,
        );
        expect(
          tester.widget<KaraokeText>(find.byType(KaraokeText)).karaoke,
          CameoGradientsDark.karaokeDarkToken,
        );
        await _unmount(tester);
      },
    );

    testWidgets(
      'photo: CameoTheme light · 톤 dark · 내비 regular dark · 플레이어 dark',
      (tester) async {
        _screenSize(tester);
        await tester.pumpWidget(
          _host(const TranscriptV3Screen(theme: TranscriptTheme.photo)),
        );
        await _advance(tester, const Duration(seconds: 1));
        expect(
          transcriptColorMode(TranscriptTheme.photo),
          CameoColorMode.light,
        );
        expect(
          tester.widget<CameoTheme>(find.byType(CameoTheme)).mode,
          CameoColorMode.light,
        );
        final navBar = tester.widget<NavBar>(find.byType(NavBar));
        expect(navBar.variant, GlassNavVariant.regular);
        expect(navBar.tone, GlassNavTone.dark);
        expect(
          tester.widget<PlayerBar>(find.byType(PlayerBar)).tone,
          PlayerBarTone.dark,
        );
        expect(
          tester.widget<HighlightCard>(find.byType(HighlightCard)).tone,
          TranscriptTone.dark,
        );
        expect(
          tester.widget<KeepAllText>(_lineText(_l1.text)).color,
          CameoColors.transcriptDarkLine,
        );
        expect(
          tester.widget<KaraokeText>(find.byType(KaraokeText)).karaoke,
          CameoGradients.karaokeDark,
        );

        expect(
          tester
              .widget<BlurSurface>(
                find.descendant(
                  of: find.byType(HighlightCard),
                  matching: find.byType(BlurSurface),
                ),
              )
              .blur,
          CameoBlur.backgroundBlurStrong,
        );
        await _unmount(tester);
      },
    );
  });

  group('카라오케 동기화', () {
    testWidgets('첫 프레임 = Figma: 카드 안 l5 가 현재 줄, progress 0.60577 · 일시정지 아이콘', (
      tester,
    ) async {
      _screenSize(tester);
      await tester.pumpWidget(_host(const TranscriptV3Screen()));
      expect(find.byType(KaraokeText), findsOneWidget);
      expect(_karaokeText(tester), _l5.text);
      expect(
        find.descendant(
          of: find.byType(HighlightCard),
          matching: find.byType(KaraokeText),
        ),
        findsOneWidget,
      );
      expect(_karaoke(tester).shownProgress, closeTo(_figmaFade, 1e-9));

      expect(
        tester.widget<KaraokeText>(find.byType(KaraokeText)).align,
        LabAlign.right,
      );

      final pause = tester.widget<Opacity>(
        find
            .ancestor(
              of: _icon(CameoIconName.playerPauseFilled),
              matching: find.byType(Opacity),
            )
            .first,
      );
      expect(pause.opacity, 1);
      await _unmount(tester);
    });

    testWidgets('재생 중: progress 가 줄 구간 비율로 전진 → 경계를 넘으면 다음 줄(l6)이 현재 줄', (
      tester,
    ) async {
      _screenSize(tester);
      final timeline = buildTranscriptTimeline(
        labTranscript.lines,
        labTranscript.player,
      );
      final r5 = timeline.ranges[4];
      await tester.pumpWidget(_host(const TranscriptV3Screen()));

      await tester.pump();
      expect(
        tester.widget<PlayerBar>(find.byType(PlayerBar)).playback.seconds,
        labTranscript.player.progress * labTranscript.player.durationSeconds,
      );
      await _advance(tester, const Duration(seconds: 1));
      expect(_karaokeText(tester), _l5.text);
      expect(
        _karaoke(tester).shownProgress,
        closeTo(_figmaFade + 1 / (r5.end - r5.start), 1e-3),
      );

      await _advance(tester, const Duration(seconds: 7));
      expect(find.byType(KaraokeText), findsOneWidget);
      expect(_karaokeText(tester), _l6.text);
      expect(_karaoke(tester).shownProgress, lessThan(0.01));
      await _unmount(tester);
    });

    testWidgets('일시정지 → 현재 줄·progress 유지', (tester) async {
      _screenSize(tester);
      await tester.pumpWidget(_host(const TranscriptV3Screen()));
      await _advance(tester, const Duration(milliseconds: 500));
      await tester.tap(find.byKey(PlayerBarKeys.button));
      await tester.pump();
      final before = _karaoke(tester).shownProgress;
      await _advance(tester, const Duration(seconds: 2));
      expect(_karaokeText(tester), _l5.text);
      expect(_karaoke(tester).shownProgress, before);
      await _unmount(tester);
    });

    testWidgets('줄 탭 → 그 줄 시작으로 탐색 (l1 · 카드 안 l7)', (tester) async {
      _screenSize(tester);
      final timeline = buildTranscriptTimeline(
        labTranscript.lines,
        labTranscript.player,
      );
      await tester.pumpWidget(_host(const TranscriptV3Screen()));
      await _advance(tester, const Duration(seconds: 1));

      await tester.tap(_lineText(_l1.text));

      await _advance(tester, const Duration(seconds: 1));
      expect(_karaokeText(tester), _l1.text);
      final r1 = timeline.ranges[0];
      expect(
        _karaoke(tester).shownProgress,
        closeTo(1 / (r1.end - r1.start), 0.01),
      );
      expect(
        tester.widget<CameoText>(find.byKey(PlayerBarKeys.currentTime)).text,
        '00:01',
      );

      await tester.tap(_lineText(_l7.text));
      await _advance(tester, const Duration(seconds: 1));
      expect(_karaokeText(tester), _l7.text);
      expect(
        find.descendant(
          of: find.byType(HighlightCard),
          matching: find.byType(KaraokeText),
        ),
        findsOneWidget,
      );
      final r7 = timeline.ranges[6];
      expect(
        _karaoke(tester).shownProgress,
        closeTo(1 / (r7.end - r7.start), 0.01),
      );
      await _unmount(tester);
    });

    for (final paused in [false, true]) {
      for (final target in [3, 4]) {
        testWidgets('뒤로 탐색 스프링이 줄 시작을 지나쳐도 current 는 탭한 줄 그대로 '
            '(l${target + 1}${paused ? ', 일시정지' : ''})', (tester) async {
          _screenSize(tester);
          final timeline = buildTranscriptTimeline(
            labTranscript.lines,
            labTranscript.player,
          );
          final line = labTranscript.lines[target];
          final range = timeline.ranges[target];
          await tester.pumpWidget(_host(const TranscriptV3Screen()));

          await _advance(tester, const Duration(seconds: 6));
          if (paused) {
            await tester.tap(find.byKey(PlayerBarKeys.button));
            await tester.pump();
          }
          final displayBefore = tester
              .state<KaraokeTextState>(find.byType(KaraokeText))
              .shownProgress;
          expect(displayBefore, greaterThan(0.9));

          await tester.tap(_lineText(line.text).first);
          await tester.pump();

          expect(_karaokeText(tester), line.text);
          expect(
            _karaoke(tester).shownProgress,
            target == 4 ? greaterThan(0.9) : closeTo(0, 1e-9),
          );

          for (var i = 0; i < 60; i++) {
            await tester.pump(const Duration(milliseconds: 16));
            expect(
              _karaokeText(tester),
              line.text,
              reason: 'frame $i: 앞 줄이 current 로 깜빡임',
            );
            if (target != 4) {
              expect(
                _karaoke(tester).shownProgress,
                lessThan(0.05),
                reason: 'frame $i: 새 줄이 채워졌다 되돌아감',
              );
            }
          }

          final settled = _karaoke(tester).shownProgress;
          expect(
            settled,
            paused
                ? closeTo(0, 1e-3)
                : closeTo(0.96 / (range.end - range.start), 0.01),
          );
          await _unmount(tester);
        });
      }
    }
  });

  group('내비', () {
    testWidgets('하트 토글 → heart-filled', (tester) async {
      _screenSize(tester);
      await tester.pumpWidget(_host(const TranscriptV3Screen()));
      expect(_icon(CameoIconName.heartFilled), findsNothing);
      await tester.tap(_icon(CameoIconName.heart));
      await _advance(tester, const Duration(milliseconds: 300));
      expect(_icon(CameoIconName.heartFilled), findsOneWidget);
      expect(find.bySemanticsLabel('좋아요, 켜짐'), findsOneWidget);
      await _unmount(tester);
    });
  });

  group('등장 (motion.stagger, 푸시 전환 뒤)', () {
    T outer<T extends Widget>(WidgetTester tester, Element e) =>
        tester.widget<T>(
          find
              .descendant(of: find.byWidget(e.widget), matching: find.byType(T))
              .first,
        );
    List<double> opacities(WidgetTester tester) => [
      for (final e in find.byType(StaggerIn).evaluate())
        outer<Opacity>(tester, e).opacity,
    ];
    List<double> rises(WidgetTester tester) => [
      for (final e in find.byType(StaggerIn).evaluate())
        outer<Transform>(tester, e).transform.getTranslation().y,
    ];

    testWidgets('전환 중에는 숨김 → 전환이 끝나면 줄 3 + 카드가 순서대로 페이드+상승', (tester) async {
      _screenSize(tester);
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        _host(
          Navigator(
            key: nav,
            onGenerateRoute: (_) =>
                CameoPageRoute<void>(builder: (_) => const SizedBox.expand()),
          ),
        ),
      );
      nav.currentState!.push(
        CameoPageRoute<void>(builder: (_) => const TranscriptV3Screen()),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(StaggerIn), findsNWidgets(4));
      expect(opacities(tester), everyElement(0));
      expect(rises(tester), everyElement(CameoMotion.staggerRise));

      await _advance(tester, const Duration(milliseconds: 400));
      await _advance(tester, const Duration(milliseconds: 60));
      final early = opacities(tester);
      expect(early.first, greaterThan(0));

      for (var i = 1; i < early.length; i++) {
        expect(early[i], lessThanOrEqualTo(early[i - 1]));
      }
      expect(early.last, lessThan(early.first));

      await _advance(tester, const Duration(seconds: 2));
      expect(opacities(tester), everyElement(1));
      expect(rises(tester), everyElement(0));
      await _unmount(tester);
    });

    testWidgets('모션 감소: 상승 없이 페이드만', (tester) async {
      _screenSize(tester);
      await tester.pumpWidget(
        _host(const TranscriptV3Screen(), disableAnimations: true),
      );
      await tester.pump(const Duration(milliseconds: 16));
      expect(rises(tester), everyElement(0));
      expect(opacities(tester).first, inExclusiveRange(0, 1));
      await _advance(tester, const Duration(seconds: 1));
      expect(opacities(tester), everyElement(1));
      await _unmount(tester);
    });
  });
  group('데모 스크립트 (?demo=1 · interaction-spec §5)', () {
    PlaybackController playback(WidgetTester tester) =>
        tester.widget<PlayerBar>(find.byType(PlayerBar)).playback;
    double iconOpacity(WidgetTester tester, CameoIconName name) => tester
        .widget<Opacity>(
          find.ancestor(of: _icon(name), matching: find.byType(Opacity)).first,
        )
        .opacity;

    final timeline = buildTranscriptTimeline(
      labTranscript.lines,
      labTranscript.player,
    );
    final marker = labTranscript.player.markers[TranscriptDemo.marker];
    final duration = labTranscript.player.durationSeconds.toDouble();
    final markerSec = marker.start * duration;
    const before = Duration(milliseconds: 100);
    const after = Duration(milliseconds: 50);

    testWidgets(
      '타임라인: 1500 일시정지 · 3000 마커 1 탐색 · 4500 재생 · 6500 대화 줄 1 탭(탐색)',
      (tester) async {
        _screenSize(tester);
        await tester.pumpWidget(_host(const TranscriptV3Screen(demo: true)));
        var elapsed = Duration.zero;

        Future<void> to(Duration t) async {
          await _advance(tester, t - elapsed);
          elapsed = t;
        }

        await to(TranscriptDemo.pause - before);
        expect(playback(tester).playing, isTrue);
        expect(_karaokeText(tester), _l5.text);

        await to(TranscriptDemo.pause + after);
        expect(playback(tester).playing, isFalse);
        final pausedAt = playback(tester).seconds;
        await to(TranscriptDemo.seekMarker - before);
        expect(playback(tester).seconds, pausedAt);
        expect(
          iconOpacity(tester, CameoIconName.playerPlayFilled),
          closeTo(1, 1e-3),
        );
        expect(
          iconOpacity(tester, CameoIconName.playerPauseFilled),
          closeTo(0, 1e-3),
        );
        expect(_karaokeText(tester), _l5.text);

        final shownBefore = playback(tester).position.value;
        await to(TranscriptDemo.seekMarker + after);
        expect(playback(tester).seconds, closeTo(markerSec, 1e-9));
        final markerLine = lineIndexAt(timeline.ranges, markerSec);
        expect(markerLine, 6, reason: '228.6초는 l7 구간 212.5–340.5초 안');
        expect(_karaokeText(tester), _l7.text);
        expect(
          find.descendant(
            of: find.byType(HighlightCard),
            matching: find.byType(KaraokeText),
          ),
          findsOneWidget,
        );
        final shownMid = playback(tester).position.value;
        expect(shownMid, greaterThan(shownBefore));
        expect(shownMid, lessThan(marker.start - 0.01), reason: '스프링 진행 중');
        final r7 = timeline.ranges[6];
        final markerProgress = (markerSec - r7.start) / (r7.end - r7.start);
        expect(
          _karaoke(tester).shownProgress,
          closeTo(markerProgress, 1e-6),
          reason: '스프링 도중에도 탐색 위치',
        );
        await to(TranscriptDemo.play - before);
        expect(playback(tester).position.value, closeTo(marker.start, 1e-6));
        expect(playback(tester).playing, isFalse);
        expect(_karaoke(tester).shownProgress, closeTo(markerProgress, 1e-6));

        await to(TranscriptDemo.play + const Duration(seconds: 1));
        expect(playback(tester).playing, isTrue);
        expect(playback(tester).seconds, closeTo(markerSec + 1, 0.1));
        expect(
          iconOpacity(tester, CameoIconName.playerPauseFilled),
          closeTo(1, 1e-3),
        );
        expect(_karaokeText(tester), _l7.text);

        await to(TranscriptDemo.tapLine + after);
        expect(_karaokeText(tester), _l1.text);
        expect(
          playback(tester).position.value,
          greaterThan(0.1),
          reason: '스프링 도중',
        );
        final r1Mid = timeline.ranges[0];
        expect(
          _karaoke(tester).shownProgress,
          closeTo(playback(tester).seconds / (r1Mid.end - r1Mid.start), 1e-6),
        );

        expect(
          playback(tester).seconds,
          closeTo(after.inMicroseconds / Duration.microsecondsPerSecond, 0.06),
        );
        await to(TranscriptDemo.tapLine + const Duration(seconds: 1));
        expect(playback(tester).playing, isTrue);
        expect(_karaokeText(tester), _l1.text);
        final r1 = timeline.ranges[0];
        expect(
          _karaoke(tester).shownProgress,
          closeTo(playback(tester).seconds / (r1.end - r1.start), 1e-3),
        );
        expect(playback(tester).seconds, closeTo(1, 0.1));
        await _unmount(tester);
      },
    );

    testWidgets('기본(demo 없음) — 스크립트를 실행하지 않는다', (tester) async {
      _screenSize(tester);
      await tester.pumpWidget(_host(const TranscriptV3Screen()));
      final start = playback(tester).seconds;
      await _advance(tester, TranscriptDemo.tapLine + after);
      expect(playback(tester).playing, isTrue);
      expect(
        playback(tester).seconds,
        closeTo(
          start + (TranscriptDemo.tapLine + after).inMilliseconds / 1000,
          0.1,
        ),
      );
      await _unmount(tester);
    });

    testWidgets('모션 감소 — 마커 탐색은 스프링 없이 즉시', (tester) async {
      _screenSize(tester);
      await tester.pumpWidget(
        _host(const TranscriptV3Screen(demo: true), disableAnimations: true),
      );
      await _advance(tester, TranscriptDemo.seekMarker + after);
      expect(playback(tester).playing, isFalse);
      expect(playback(tester).position.value, closeTo(marker.start, 1e-9));
      expect(_karaokeText(tester), _l7.text);
      await _unmount(tester);
    });

    testWidgets('도중에 화면이 사라지면 남은 데모 타이머를 해제한다', (tester) async {
      _screenSize(tester);
      await tester.pumpWidget(_host(const TranscriptV3Screen(demo: true)));
      await _advance(tester, TranscriptDemo.pause + after);
      await _unmount(tester);

      await tester.pump(TranscriptDemo.tapLine);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      '라우트 /transcript?theme=dark&v=3&demo=1 → TranscriptV3Screen(theme: dark, demo: true) (v5 기본 라우트의 Lab 전용 v3)',
      (tester) async {
        _screenSize(tester);

        final location = CameoRoutes.withDemo(
          transcriptV3Location(TranscriptTheme.dark),
        );
        expect(location, '/transcript?theme=dark&v=3&demo=1');
        await tester.pumpWidget(
          WidgetsApp(
            color: CameoColors.backgroundCanvasBase,
            textStyle: CameoTextStyles.bodyLg,
            initialRoute: location,
            onGenerateInitialRoutes: (name) => [
              onGenerateCameoRoute(RouteSettings(name: name)),
            ],
            onGenerateRoute: onGenerateCameoRoute,
          ),
        );
        final screen = tester.widget<TranscriptV3Screen>(
          find.byType(TranscriptV3Screen),
        );
        expect(screen.theme, TranscriptTheme.dark);
        expect(screen.demo, isTrue);
        await _advance(tester, TranscriptDemo.pause + after);
        expect(playback(tester).playing, isFalse);
        await _unmount(tester);
      },
    );
  });
}
