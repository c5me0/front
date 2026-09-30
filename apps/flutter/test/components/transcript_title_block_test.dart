// Regression coverage for transcript title block. Preserve behavior, layout, and
// interaction expectations.

import 'package:cameo/components/karaoke_text.dart';
import 'package:cameo/components/title_block.dart';
import 'package:cameo/content/lab.g.dart';
import 'package:cameo/design_system/design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const double _screenWidth = 393;
const double _tol = 0.001;

Widget _harness(Widget child) {
  return MediaQuery(
    data: const MediaQueryData(size: Size(_screenWidth, 852)),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: _screenWidth, child: child),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'Figma 치수 (2042:3242): 393×92 · 제목 (16,16) 361×34 · 날짜 (16,58) 361×18',
    (tester) async {
      await tester.pumpWidget(
        _harness(const TitleBlock(title: '성수 대화', subtitle: '8월 20일')),
      );
      final block = tester.getSize(find.byType(TitleBlock));
      expect(block.width, _screenWidth);
      expect(
        block.height,
        closeTo(CameoLayout.titleBlockHeight, _tol),
      ); // 92 = 16 + 34 + 8 + 18 + 16

      final texts = find.byType(KeepAllText);
      final title = tester.getRect(texts.at(0));
      final date = tester.getRect(texts.at(1));
      expect(title.topLeft, const Offset(16, 16));
      expect(title.width, 361);
      expect(title.height, closeTo(34, _tol));
      expect(date.left, 16);
      expect(
        date.top,
        closeTo(16 + 34 + CameoLayout.titleBlockGap, _tol),
      ); // 58
      expect(date.width, 361);
      expect(date.height, closeTo(18, _tol));
    },
  );

  testWidgets(
    'light: 제목 headingLg foreground/neutral/base · 날짜 bodyMd foreground/neutral/muted',
    (tester) async {
      await tester.pumpWidget(
        _harness(
          TitleBlock(title: labTranscript.title, subtitle: labTranscript.date),
        ),
      );
      final texts = tester
          .widgetList<KeepAllText>(find.byType(KeepAllText))
          .toList();
      expect(texts[0].style, CameoTextStyles.headingLg);
      expect(texts[0].color, CameoColors.foregroundNeutralBase);
      expect(texts[1].style, CameoTextStyles.bodyMd);
      expect(texts[1].color, CameoColors.foregroundNeutralMuted);
    },
  );

  testWidgets('dark (16-12 2042:3124): inverse/base · inverse/muted', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        TitleBlock(
          title: labTranscript.title,
          subtitle: labTranscript.date,
          tone: TranscriptTone.dark,
        ),
      ),
    );
    final texts = tester
        .widgetList<KeepAllText>(find.byType(KeepAllText))
        .toList();
    expect(texts[0].color, CameoColors.foregroundNeutralInverseBase);
    expect(texts[1].color, CameoColors.foregroundNeutralInverseMuted);
  });

  testWidgets(
    'darkToken (16-13 v3 2042:3243/3244, dark 모드): foreground/neutral/base #f8f8fa · muted #f8f8fa99',
    (tester) async {
      await tester.pumpWidget(
        CameoTheme(
          mode: CameoColorMode.dark,
          child: _harness(
            TitleBlock(
              title: labTranscript.title,
              subtitle: labTranscript.date,
              tone: TranscriptTone.darkToken,
            ),
          ),
        ),
      );
      final texts = tester
          .widgetList<KeepAllText>(find.byType(KeepAllText))
          .toList();
      expect(texts[0].color, CameoColorsDark.foregroundNeutralBase);
      expect(texts[1].color, CameoColorsDark.foregroundNeutralMuted);
    },
  );

  testWidgets('제목은 header 시맨틱', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _harness(
        TitleBlock(title: labTranscript.title, subtitle: labTranscript.date),
      ),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel(labTranscript.title)),
      matchesSemantics(label: labTranscript.title, isHeader: true),
    );
    handle.dispose();
  });
}
