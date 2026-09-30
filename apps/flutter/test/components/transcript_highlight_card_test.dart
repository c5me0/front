// Regression coverage for transcript highlight card. Preserve behavior, layout, and
// interaction expectations.

import 'package:cameo/components/highlight_card.dart';
import 'package:cameo/components/karaoke_text.dart';
import 'package:cameo/components/transcript_line.dart';
import 'package:cameo/content/lab.g.dart';
import 'package:cameo/design_system/design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const double _screenWidth = 393;
const double _tol = 0.001;

final double _line =
    (CameoTextStyles.transcriptLine.fontSize! *
            CameoTextStyles.transcriptLine.height!)
        .roundToDouble();

final List<TranscriptLineContent> _figmaLines = labTranscript.lines
    .where((l) => l.inHighlight)
    .toList();

List<TranscriptLineContent> _figmaShaped() => [
  for (final (i, l) in _figmaLines.indexed)
    TranscriptLineContent(
      id: l.id,
      nodeIds: l.nodeIds,
      text: i == 0 ? '가나\n다라' : '가나다',
      side: l.side,
      inHighlight: l.inHighlight,
      current: l.current,
      gradient: l.gradient,
    ),
];

Widget _harness(Widget child, {CameoColorMode mode = CameoColorMode.light}) {
  return MediaQuery(
    data: const MediaQueryData(size: Size(_screenWidth, 852)),
    child: CameoTheme(
      mode: mode,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: _screenWidth, child: child),
        ),
      ),
    ),
  );
}

ShapeDecoration _cardDecoration(WidgetTester tester) =>
    tester
            .widget<DecoratedBox>(
              find
                  .descendant(
                    of: find.byType(BlurSurface),
                    matching: find.byType(DecoratedBox),
                  )
                  .first,
            )
            .decoration
        as ShapeDecoration;

void main() {
  testWidgets(
    'Figma 치수 (2042:3249 / 2042:3250): 래퍼 393×290 · 카드 (8,8) 377×274 · 줄 x27 w339',
    (tester) async {
      await tester.pumpWidget(_harness(HighlightCard(lines: _figmaShaped())));

      final wrapper = tester.getSize(find.byType(HighlightCard));
      expect(wrapper.width, _screenWidth);
      // 8 + (1 + 16 + 6 × 32 + 4 × 12 + 16 + 1) + 8 = 290
      expect(wrapper.height, closeTo(8 + 274 + 8, _tol));

      final card = tester.getRect(find.byType(BlurSurface));
      expect(card.left, CameoLayout.highlightCardWrapperPadding);
      expect(card.top, CameoLayout.highlightCardWrapperPadding);
      expect(card.width, 377);

      expect(card.height, closeTo(274, _tol));
      expect(card.height, closeTo(2 * 1 + 2 * 16 + 6 * _line + 4 * 12, _tol));

      final texts = find.byType(TranscriptText);
      expect(texts, findsNWidgets(5));
      final first = tester.getRect(texts.at(0));
      expect(first.left, 8 + 1 + 18); // 27
      expect(first.top, 8 + 1 + 16); // 25
      expect(first.width, 339);
      expect(first.height, closeTo(2 * _line, _tol));
      // gap 12
      for (var i = 1; i < 5; i++) {
        final prev = tester.getRect(texts.at(i - 1));
        final cur = tester.getRect(texts.at(i));
        expect(
          cur.top - prev.bottom,
          closeTo(CameoLayout.highlightCardGap, _tol),
        );
        expect(cur.width, 339);
        expect(cur.left, 27);
      }
    },
  );

  testWidgets('콘텐츠 5줄: 현재 줄(l5)만 KaraokeText · 오른쪽 줄 textAlign right', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(HighlightCard(lines: _figmaLines)));
    expect(find.byType(KaraokeText), findsOneWidget);
    final karaoke = tester.widget<KaraokeText>(find.byType(KaraokeText));
    expect(karaoke.text, '오 그럼 1시에 서울숲역 4번 출구에서 봐!');
    expect(karaoke.align, LabAlign.right);
    expect(karaoke.karaoke, CameoGradients.karaokeLight);

    expect(
      tester.state<KaraokeTextState>(find.byType(KaraokeText)).shownProgress,
      0.60577,
    );

    expect(tester.getSize(find.byType(KaraokeText)).width, 339);

    final plain = tester
        .widgetList<KeepAllText>(find.byType(KeepAllText))
        .where(
          (t) =>
              t.color == CameoColors.foregroundNeutralSubtle &&
              t.text != karaoke.text,
        );
    expect(plain.map((t) => t.textAlign).toList(), [
      TextAlign.left, // l4
      TextAlign.left, // l6
      TextAlign.right, // l7
      TextAlign.left, // l8
    ]);
  });

  testWidgets(
    '역할: light background/neutral/subtle + stroke/neutral/base · r26 · border 1',
    (tester) async {
      await tester.pumpWidget(_harness(HighlightCard(lines: _figmaLines)));
      final d = _cardDecoration(tester);
      expect(d.color, CameoColors.backgroundNeutralSubtle);
      final shape = d.shape as RoundedSuperellipseBorder;
      expect(shape.side.color, CameoColors.strokeNeutralBase);
      expect(shape.side.width, CameoLayout.highlightCardBorderWidth);
      expect(
        shape.borderRadius,
        BorderRadius.circular(CameoLayout.highlightCardRadius),
      );
      final blur = tester.widget<BlurSurface>(find.byType(BlurSurface));
      expect(blur.blur, CameoBlur.backgroundBlur);
    },
  );

  testWidgets(
    '역할: dark(16-12) transcript/dark-card + dark-card-border · 줄 transcript/dark-line · karaokeDark · 블러 σ10',
    (tester) async {
      await tester.pumpWidget(
        _harness(HighlightCard(lines: _figmaLines, tone: TranscriptTone.dark)),
      );
      final d = _cardDecoration(tester);
      expect(d.color, CameoColors.transcriptDarkCard);
      expect(
        (d.shape as RoundedSuperellipseBorder).side.color,
        CameoColors.transcriptDarkCardBorder,
      );
      expect(
        tester.widget<KaraokeText>(find.byType(KaraokeText)).karaoke,
        CameoGradients.karaokeDark,
      );
      expect(
        tester
            .widgetList<KeepAllText>(find.byType(KeepAllText))
            .where((t) => t.color == CameoColors.transcriptDarkLine),
        hasLength(5 - 1 + 1),
      );
      // 16-12 v3: background-blur r5 → r20 (CHANGES §2.2)
      final blur = tester.widget<BlurSurface>(find.byType(BlurSurface));
      expect(blur.blur, CameoBlur.backgroundBlurStrong);
      expect(CameoBlur.backgroundBlurStrong.sigma, 10);
    },
  );

  testWidgets(
    'darkToken(16-13 v3, 2042:3250) 치수: 래퍼 393×288 · 카드 (8,8) 377×272 테두리 없음 · 줄 x26 w341 · y 16/92/136/180/224',
    (tester) async {
      await tester.pumpWidget(
        _harness(
          HighlightCard(lines: _figmaShaped(), tone: TranscriptTone.darkToken),
          mode: CameoColorMode.dark,
        ),
      );
      final wrapper = tester.getSize(find.byType(HighlightCard));
      expect(wrapper.width, _screenWidth);
      expect(
        wrapper.height,
        closeTo(CameoLayout.highlightCardV3WrapperHeight, _tol),
      );
      final card = tester.getRect(find.byType(BlurSurface));
      expect(card.left, CameoLayout.highlightCardV3WrapperPadding);
      expect(card.top, CameoLayout.highlightCardV3WrapperPadding);
      expect(card.width, CameoLayout.highlightCardV3Width);
      expect(card.height, closeTo(CameoLayout.highlightCardV3Height, _tol));
      expect(card.height, closeTo(2 * 16 + 6 * _line + 4 * 12, _tol));

      final texts = find.byType(TranscriptText);
      expect(texts, findsNWidgets(5));
      const figmaTops = [16.0, 92.0, 136.0, 180.0, 224.0];
      for (var i = 0; i < 5; i++) {
        final r = tester.getRect(texts.at(i));
        expect(r.left - card.left, CameoLayout.highlightCardV3PaddingX);
        expect(r.width, CameoLayout.highlightCardV3TextWidth);
        expect(
          r.top - card.top,
          closeTo(figmaTops[i], _tol),
          reason: 'line $i',
        );
      }
    },
  );

  testWidgets(
    '역할: darkToken(16-13 v3) background/neutral/base · 테두리 없음 · 줄 foreground/neutral/subtle · karaokeDarkToken · 블러 σ10 (dark 모드)',
    (tester) async {
      await tester.pumpWidget(
        _harness(
          HighlightCard(lines: _figmaLines, tone: TranscriptTone.darkToken),
          mode: CameoColorMode.dark,
        ),
      );
      final d = _cardDecoration(tester);
      expect(d.color, CameoColorsDark.backgroundNeutralBase);
      final shape = d.shape as RoundedSuperellipseBorder;
      expect(shape.side, BorderSide.none);
      final blur = tester.widget<BlurSurface>(find.byType(BlurSurface));
      expect(blur.blur, CameoBlur.backgroundBlurStrong);
      expect(blur.border, isNull);
      expect(blur.borderWidth, CameoLayout.highlightCardV3BorderWidth);
      final karaoke = tester.widget<KaraokeText>(find.byType(KaraokeText));
      expect(karaoke.karaoke, CameoGradientsDark.karaokeDarkToken);

      expect(karaoke.karaoke.ink, CameoColorsDark.foregroundNeutralBase);
      expect(karaoke.karaoke.base, CameoColorsDark.foregroundNeutralSubtle);

      expect(
        tester
            .widgetList<KeepAllText>(find.byType(KeepAllText))
            .where((t) => t.color == CameoColorsDark.foregroundNeutralSubtle),
        hasLength(5 - 1 + 1),
      );
      expect(highlightCardRoles(CameoPalette.dark, TranscriptTone.darkToken), (
        fill: CameoColorsDark.backgroundNeutralBase,
        border: null,
        line: CameoColorsDark.foregroundNeutralSubtle,
      ));
    },
  );

  testWidgets('progress 지정 → 현재 줄에만 전달', (tester) async {
    await tester.pumpWidget(
      _harness(HighlightCard(lines: _figmaLines, progress: 0.3)),
    );
    expect(
      tester.state<KaraokeTextState>(find.byType(KaraokeText)).shownProgress,
      0.3,
    );
  });

  testWidgets('onLinePress 없음 → 줄에 PressScale 없음 · 있으면 줄마다, 치수 동일', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(HighlightCard(lines: _figmaShaped())));
    expect(find.byType(PressScale), findsNothing);
    final plain = tester.getSize(find.byType(HighlightCard));
    await tester.pumpWidget(
      _harness(HighlightCard(lines: _figmaShaped(), onLinePress: (_) {})),
    );
    expect(find.byType(PressScale), findsNWidgets(5));
    expect(tester.getSize(find.byType(HighlightCard)), plain);
  });

  testWidgets('줄 탭 → onLinePress(line) · 한국어 라벨', (tester) async {
    final handle = tester.ensureSemantics();
    TranscriptLineContent? tapped;
    await tester.pumpWidget(
      _harness(
        HighlightCard(lines: _figmaLines, onLinePress: (l) => tapped = l),
      ),
    );
    await tester.tap(find.byType(TranscriptText).at(2));
    await tester.pumpAndSettle();
    expect(tapped?.id, 'l6');
    expect(
      find.bySemanticsLabel(RegExp('^저녁은 어디서 먹지, 이 위치로 이동')),
      findsOneWidget,
    );
    handle.dispose();
  });
}
