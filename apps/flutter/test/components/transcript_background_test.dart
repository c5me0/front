// Regression coverage for transcript background. Preserve behavior, layout, and
// interaction expectations.

import 'package:cameo/components/transcript_background.dart';
import 'package:cameo/content/lab.g.dart';
import 'package:cameo/design_system/design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void _useScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget _harness(Widget child) {
  return MediaQuery(
    data: const MediaQueryData(size: Size(393, 852)),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 393,
          height: 852,
          child: Stack(children: [Positioned.fill(child: child)]),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    '풀블리드 (2042:2933): 이미지 cover + transcriptDarkBackground 가 393×852 를 채운다',
    (tester) async {
      _useScreen(tester);
      await tester.pumpWidget(_harness(const TranscriptBackground()));

      expect(
        tester.getSize(find.byType(TranscriptBackground)),
        const Size(393, 852),
      );

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.fit, BoxFit.cover);
      expect(
        (image.image as AssetImage).assetName,
        LabImages.transcriptDarkBackground,
      );
      expect(LabImages.transcriptDarkBackground, labTranscript.darkBackground);
      expect(tester.getSize(find.byType(Image)), const Size(393, 852));

      final gradient = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(TranscriptBackground),
          matching: find.byType(DecoratedBox),
        ),
      );
      expect(
        (gradient.decoration as BoxDecoration).gradient,
        CameoGradients.transcriptDarkBackground,
      );
      expect(
        tester.getSize(
          find.descendant(
            of: find.byType(TranscriptBackground),
            matching: find.byType(DecoratedBox),
          ),
        ),
        const Size(393, 852),
      );

      expect(CameoGradients.transcriptDarkBackground.stops, [
        0.0,
        0.1,
        0.4,
        1.0,
      ]);
    },
  );

  testWidgets('장식 전용 — 스크린 리더·터치 제외', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_harness(const TranscriptBackground()));
    expect(
      find.descendant(
        of: find.byType(TranscriptBackground),
        matching: find.byType(ExcludeSemantics),
      ),
      findsWidgets,
    );
    expect(
      find.descendant(
        of: find.byType(TranscriptBackground),
        matching: find.byType(IgnorePointer),
      ),
      findsWidgets,
    );
    handle.dispose();
  });
}
