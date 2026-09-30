// Regression coverage for transcript karaoke text. Preserve behavior, layout, and
// interaction expectations.

import 'package:cameo/components/karaoke_text.dart';
import 'package:cameo/content/lab.g.dart';
import 'package:cameo/design_system/design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const double _lineWidth = 339;

const double _tol = 0.001;

final double _line =
    (CameoTextStyles.transcriptLine.fontSize! *
            CameoTextStyles.transcriptLine.height!)
        .roundToDouble();

Widget _harness(
  Widget child, {
  double width = _lineWidth,
  bool disableAnimations = false,
  bool tight = true,
}) {
  return MediaQuery(
    data: MediaQueryData(
      size: const Size(393, 852),
      disableAnimations: disableAnimations,
    ),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          child: tight
              ? child
              : Align(alignment: Alignment.topLeft, child: child),
        ),
      ),
    ),
  );
}

KaraokeTextState _state(WidgetTester tester) =>
    tester.state<KaraokeTextState>(find.byType(KaraokeText));

List<Rect> _layers(WidgetTester tester) => tester
    .widgetList<KeepAllText>(find.byType(KeepAllText))
    .map((w) => tester.getRect(find.byWidget(w)))
    .toList();

void main() {
  group('karaokeFadeRange — RN 과 같은 수식', () {
    test(
      'progress = fadeStart → Figma 스냅샷 (2042:3252 · 2042:3141: 60.577% → 100%)',
      () {
        for (final k in [
          CameoGradients.karaokeLight,
          CameoGradients.karaokeDark,
        ]) {
          final r = karaokeFadeRange(k.fadeStart, k);
          expect(r.solidUntil, 0.60577);
          expect(r.clearFrom, closeTo(1.0, 1e-9));
        }
      },
    );
    test('karaokeQuote (2015:1956: 46.635% → 100%)', () {
      const k = CameoGradients.karaokeQuote;
      final r = karaokeFadeRange(k.fadeStart, k);
      expect(r.solidUntil, 0.46635);
      expect(r.clearFrom, closeTo(1.0, 1e-9));
    });
    test('페이드 길이는 progress 와 무관하게 fadeEnd − fadeStart', () {
      const k = CameoGradients.karaokeLight;
      for (final p in [0.0, 0.25, 1.0]) {
        final r = karaokeFadeRange(p, k);
        expect(
          r.clearFrom - r.solidUntil,
          closeTo(k.fadeEnd - k.fadeStart, 1e-9),
        );
      }
    });
  });

  group('keepAllSpan — 한국어 어절 단위 줄바꿈', () {
    const style = CameoTextStyles.transcriptLine;
    TextPainter paint(InlineSpan s, [double max = double.infinity]) =>
        TextPainter(text: s, textDirection: TextDirection.ltr)
          ..layout(maxWidth: max);

    test('WORD JOINER 를 넣어도 폭은 원문과 같다 (letterSpacing 보정)', () {
      const text = '오 그럼 1시에 서울숲역 4번 출구에서 봐!';

      final plain = paint(cameoTextSpan(text, style));
      final keepAll = paint(
        TextSpan(
          style: style,
          children: [keepAllSpan(text, style: style)],
        ),
      );
      expect(keepAll.width, closeTo(plain.width, _tol));
    });

    test(
      'SF run(공백·숫자·기호)에만 SF 트래킹, 한글 run 은 토큰 자간 그대로',
      () {
        const text = '오 그럼 1시에 서울숲역 4번 출구에서 봐!';
        final tracking = CameoTextStyles.systemTracking[style.fontSize] ?? 0;
        final runs = <TextSpan>[];
        keepAllSpan(text, style: style).visitChildren((s) {
          if (s is TextSpan && s.text != null) runs.add(s);
          return true;
        });
        final systemChars = RegExp(r'[ 0-9!]');
        for (final r in runs) {
          if (r.text == '\u2060') {
            expect(r.style!.letterSpacing, 0);
          } else if (systemChars.hasMatch(r.text!)) {
            expect(r.text, matches(RegExp(r'^[ 0-9!]+$')));
            expect(
              r.style!.letterSpacing,
              closeTo(style.letterSpacing! + tracking, 1e-9),
            );
          } else {
            expect(r.style, isNull, reason: r.text);
          }
        }
      },
      skip: CameoTextStyles.systemTracking.isEmpty,
    );

    test('어절 중간이 아니라 공백에서 줄을 바꾼다', () {
      const text = '가나다 라마바사';

      final glyph = style.fontSize! + style.letterSpacing!;
      final p = paint(
        TextSpan(
          style: style,
          children: [keepAllSpan(text, style: style)],
        ),
        glyph * 6,
      );
      final lines = p.computeLineMetrics();
      expect(lines, hasLength(2));

      expect(lines[0].width, closeTo(glyph * 3, _tol));
      expect(lines[1].width, closeTo(glyph * 4, _tol));
    });
  });

  group('KaraokeText 레이아웃', () {
    testWidgets('fill: 마스크 박스 = 줄 폭 339, base·ink 두 겹이 같은 박스', (tester) async {
      await tester.pumpWidget(
        _harness(
          const KaraokeText(
            '오 그럼',
            style: CameoTextStyles.transcriptLine,
            karaoke: CameoGradients.karaokeLight,
            align: LabAlign.right,
          ),
        ),
      );
      expect(tester.getSize(find.byType(KaraokeText)).width, _lineWidth);
      expect(tester.getSize(find.byType(ShaderMask)).width, _lineWidth);
      final layers = _layers(tester);
      expect(layers, hasLength(2));
      expect(layers[0], layers[1]);
      expect(layers[0].height, closeTo(_line, _tol));
      final mask = tester.widget<ShaderMask>(find.byType(ShaderMask));
      expect(mask.blendMode, BlendMode.dstIn);

      final texts = tester
          .widgetList<KeepAllText>(find.byType(KeepAllText))
          .toList();
      expect(texts[0].color, CameoGradients.karaokeLight.base);
      expect(texts[1].color, CameoGradients.karaokeLight.ink);
      expect(texts.every((t) => t.textAlign == TextAlign.right), isTrue);
    });

    testWidgets('hug: 느슨한 제약이면 박스 = 가장 긴 줄, 두 겹 동일', (tester) async {
      await tester.pumpWidget(
        _harness(
          const KaraokeText(
            '가나\n다',
            style: CameoTextStyles.transcriptLine,
            karaoke: CameoGradients.karaokeDark,
          ),
          tight: false,
        ),
      );
      final glyph =
          CameoTextStyles.transcriptLine.fontSize! +
          CameoTextStyles.transcriptLine.letterSpacing!;
      final size = tester.getSize(find.byType(KaraokeText));
      expect(size.width, closeTo(glyph * 2, _tol));
      expect(size.height, closeTo(_line * 2, _tol));
      final layers = _layers(tester);
      expect(layers[0], layers[1]);
    });

    testWidgets('여러 줄 · 오른쪽 정렬: 두 겹이 같은 줄바꿈', (tester) async {
      await tester.pumpWidget(
        _harness(
          const KaraokeText(
            '가나다 라마바 사아자 차카타 파하 가나다 라마바 사아자',
            style: CameoTextStyles.transcriptLine,
            karaoke: CameoGradients.karaokeLight,
            align: LabAlign.right,
          ),
        ),
      );
      final layers = _layers(tester);
      expect(layers[0], layers[1]);
      expect(layers[0].width, _lineWidth);
      expect(layers[0].height, closeTo(_line * 2, _tol));
    });

    testWidgets('스크린 리더에는 한 번만 읽힌다 (ink 겹 제외)', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _harness(
          const KaraokeText(
            '오 그럼 1시에',
            style: CameoTextStyles.transcriptLine,
            karaoke: CameoGradients.karaokeLight,
          ),
        ),
      );
      expect(find.bySemanticsLabel('오 그럼 1시에'), findsOneWidget);
      handle.dispose();
    });
  });

  group('KaraokeText 모션 (CameoMotion.scrubberSeekSpring)', () {
    Widget karaoke(double? progress, {bool animated = true}) => KaraokeText(
      '오 그럼',
      style: CameoTextStyles.transcriptLine,
      karaoke: CameoGradients.karaokeLight,
      progress: progress,
      animated: animated,
    );

    testWidgets('기본 progress = 스펙 fadeStart (Figma 0.60577)', (tester) async {
      await tester.pumpWidget(_harness(karaoke(null)));
      expect(_state(tester).shownProgress, 0.60577);
    });

    testWidgets('progress 변경 → 스프링으로 이동 후 정착', (tester) async {
      await tester.pumpWidget(_harness(karaoke(0.2)));
      await tester.pumpWidget(_harness(karaoke(0.8)));
      await tester.pump(const Duration(milliseconds: 16));
      final mid = _state(tester).shownProgress;
      expect(mid, greaterThan(0.2));
      expect(mid, lessThan(0.8));
      await tester.pumpAndSettle();
      expect(
        _state(tester).shownProgress,
        closeTo(0.8, CameoMotion.restThresholdDisplacement),
      );
    });

    testWidgets('도중 재목표 → 진행 속도를 이어받는다 (RN withSpring 과 같음)', (tester) async {
      await tester.pumpWidget(_harness(karaoke(0.2)));
      await tester.pumpWidget(_harness(karaoke(0.8)));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      final before = _state(tester).shownProgress;
      expect(before, greaterThan(0.2));
      await tester.pumpWidget(_harness(karaoke(0.2)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 4));

      expect(_state(tester).shownProgress, greaterThan(before));
      await tester.pumpAndSettle();
      expect(
        _state(tester).shownProgress,
        closeTo(0.2, CameoMotion.restThresholdDisplacement),
      );
    });

    testWidgets('animated 만 바뀌면 움직이지 않는다 (목표값이 바뀔 때만 — RN 과 같음)', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(karaoke(0.4)));
      await tester.pumpWidget(_harness(karaoke(0.4, animated: false)));
      expect(_state(tester).shownProgress, 0.4);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('모션 감소 → 즉시 이동', (tester) async {
      await tester.pumpWidget(_harness(karaoke(0.2), disableAnimations: true));
      await tester.pumpWidget(_harness(karaoke(0.8), disableAnimations: true));
      expect(_state(tester).shownProgress, 0.8);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('animated: false → 즉시 이동', (tester) async {
      await tester.pumpWidget(_harness(karaoke(0.2, animated: false)));
      await tester.pumpWidget(_harness(karaoke(0.8, animated: false)));
      expect(_state(tester).shownProgress, 0.8);
    });

    testWidgets('progressValue → 스프링 없이 그대로 따른다', (tester) async {
      final value = ValueNotifier<double>(0.3);
      await tester.pumpWidget(
        _harness(
          KaraokeText(
            '오 그럼',
            style: CameoTextStyles.transcriptLine,
            karaoke: CameoGradients.karaokeLight,
            progressValue: value,
          ),
        ),
      );
      expect(_state(tester).shownProgress, 0.3);
      value.value = 0.9;
      await tester.pump();
      expect(_state(tester).shownProgress, 0.9);
      expect(tester.hasRunningAnimations, isFalse);
      value.dispose();
    });
  });
}
