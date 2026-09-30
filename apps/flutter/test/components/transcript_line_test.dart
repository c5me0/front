// Regression coverage for transcript line. Preserve behavior, layout, and interaction
// expectations.

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

final _l1 = labTranscript.lines.firstWhere((l) => l.id == 'l1');
final _l2 = labTranscript.lines.firstWhere((l) => l.id == 'l2');

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
  testWidgets('왼쪽 한 줄 (2042:3245): 393×48, 텍스트 (16, 8) h32', (tester) async {
    await tester.pumpWidget(
      _harness(TranscriptLine(text: _l1.text, side: _l1.side)),
    );
    final row = tester.getSize(find.byType(TranscriptLine));
    expect(row.width, _screenWidth);
    expect(_line, 32);
    expect(row.height, closeTo(8 + _line + 8, _tol));
    final text = tester.getRect(find.byType(KeepAllText));
    expect(text.left, CameoLayout.transcriptLinePaddingX);
    expect(text.top, CameoLayout.transcriptLinePaddingY);
    expect(text.height, closeTo(_line, _tol));
    expect(
      text.width,
      lessThanOrEqualTo(_screenWidth - 2 * CameoLayout.transcriptLinePaddingX),
    );
  });

  testWidgets('오른쪽 한 줄 (2042:3256): 텍스트 오른쪽 끝 x = 377', (tester) async {
    await tester.pumpWidget(
      _harness(TranscriptLine(text: _l2.text, side: _l2.side)),
    );
    final text = tester.getRect(find.byType(KeepAllText));
    expect(
      text.right,
      closeTo(_screenWidth - CameoLayout.transcriptLinePaddingX, _tol),
    ); // 377
    expect(text.top, CameoLayout.transcriptLinePaddingY);
    expect(
      tester.widget<KeepAllText>(find.byType(KeepAllText)).textAlign,
      TextAlign.right,
    );
  });

  testWidgets('강제 줄바꿈 두 줄 (2042:3247): 80 = 8 + 2 × 32 + 8 (Figma 306 → 386)', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(const TranscriptLine(text: '가나\n다라')));
    expect(
      tester.getSize(find.byType(TranscriptLine)).height,
      closeTo(8 + 2 * _line + 8, _tol),
    );
  });

  testWidgets('최대 폭 = 행 폭 − 32 (361) 에서 줄바꿈', (tester) async {
    await tester.pumpWidget(
      _harness(const TranscriptLine(text: '가나다라마 바사아자차 카타파하가 나다라마바 사아자차카')),
    );
    final text = tester.getRect(find.byType(KeepAllText));
    expect(text.width, lessThanOrEqualTo(361));
    expect(text.height, closeTo(2 * _line, _tol));
  });

  testWidgets(
    '색 역할: light foreground/neutral/subtle · dark transcript/dark-line',
    (tester) async {
      await tester.pumpWidget(_harness(TranscriptLine(text: _l1.text)));
      expect(
        tester.widget<KeepAllText>(find.byType(KeepAllText)).color,
        CameoColors.foregroundNeutralSubtle,
      );
      expect(
        tester.widget<KeepAllText>(find.byType(KeepAllText)).style,
        CameoTextStyles.transcriptLine,
      );
      await tester.pumpWidget(
        _harness(TranscriptLine(text: _l1.text, tone: TranscriptTone.dark)),
      );
      expect(
        tester.widget<KeepAllText>(find.byType(KeepAllText)).color,
        CameoColors.transcriptDarkLine,
      );

      await tester.pumpWidget(
        CameoTheme(
          mode: CameoColorMode.dark,
          child: _harness(
            TranscriptLine(text: _l1.text, tone: TranscriptTone.darkToken),
          ),
        ),
      );
      expect(
        tester.widget<KeepAllText>(find.byType(KeepAllText)).color,
        CameoColorsDark.foregroundNeutralMuted,
      );

      await tester.pumpWidget(
        CameoTheme(
          mode: CameoColorMode.dark,
          child: _harness(
            TranscriptText(
              text: _l1.text,
              tone: TranscriptTone.darkToken,
              color: CameoColorsDark.foregroundNeutralSubtle,
            ),
          ),
        ),
      );
      expect(
        tester.widget<KeepAllText>(find.byType(KeepAllText)).color,
        CameoColorsDark.foregroundNeutralSubtle,
      );
    },
  );

  testWidgets(
    'current → KaraokeText (light karaokeLight · dark karaokeDark · darkToken karaokeDarkToken)',
    (tester) async {
      await tester.pumpWidget(
        _harness(TranscriptLine(text: _l1.text, current: true)),
      );
      expect(
        tester.widget<KaraokeText>(find.byType(KaraokeText)).karaoke,
        CameoGradients.karaokeLight,
      );
      await tester.pumpWidget(
        _harness(
          TranscriptLine(
            text: _l1.text,
            current: true,
            tone: TranscriptTone.dark,
          ),
        ),
      );
      expect(
        tester.widget<KaraokeText>(find.byType(KaraokeText)).karaoke,
        CameoGradients.karaokeDark,
      );
      await tester.pumpWidget(
        CameoTheme(
          mode: CameoColorMode.dark,
          child: _harness(
            TranscriptLine(
              text: _l1.text,
              current: true,
              tone: TranscriptTone.darkToken,
            ),
          ),
        ),
      );
      expect(
        tester.widget<KaraokeText>(find.byType(KaraokeText)).karaoke,
        CameoGradientsDark.karaokeDarkToken,
      );

      expect(
        tester.getSize(find.byType(TranscriptLine)).height,
        closeTo(8 + _line + 8, _tol),
      );
    },
  );

  testWidgets('onPress 없음 → PressScale·버튼 시맨틱 없음, 크기 동일', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_harness(TranscriptLine(text: _l1.text)));
    expect(find.byType(PressScale), findsNothing);
    expect(
      tester.getSemantics(find.bySemanticsLabel(_l1.text)),
      containsSemantics(isButton: false),
    );
    final plain = tester.getSize(find.byType(TranscriptLine));
    await tester.pumpWidget(
      _harness(TranscriptLine(text: _l1.text, onPress: () {})),
    );
    expect(find.byType(PressScale), findsOneWidget);
    expect(tester.getSize(find.byType(TranscriptLine)), plain);
    handle.dispose();
  });

  testWidgets('탭 → onPress · 한국어 스크린 리더 라벨', (tester) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(
      _harness(TranscriptLine(text: _l1.text, onPress: () => taps++)),
    );
    await tester.tap(find.byType(TranscriptLine));
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(
      find.bySemanticsLabel(RegExp('^주영아 토요일에 성수 갈까\\?, 이 위치로 이동')),
      findsOneWidget,
    );
    expect(transcriptLineLabel('저번에\n새로 생긴 카페?'), '저번에 새로 생긴 카페?, 이 위치로 이동');
    handle.dispose();
  });
}
