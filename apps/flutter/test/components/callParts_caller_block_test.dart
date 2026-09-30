// ignore_for_file: file_names
// Regression coverage for callParts caller block. Preserve behavior, layout, and
// interaction expectations.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cameo/components/caller_block.dart';
import 'package:cameo/content/lab.g.dart';
import 'package:cameo/design_system/design_system.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const Size _screen = Size(393, 852);

const double _eps = 0.001;

void _screenSize(WidgetTester tester) {
  tester.view.physicalSize = _screen;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget _host(Widget block, {required double topAreaBottom}) {
  return MediaQuery(
    data: const MediaQueryData(size: _screen),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox.fromSize(
        size: _screen,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: callerBlockTop(topAreaBottom),
              child: block,
            ),
          ],
        ),
      ),
    ),
  );
}

Finder get _block => find.byType(CallerBlock);

Finder _lineBox(String text) =>
    find.ancestor(of: find.text(text), matching: find.byType(SizedBox)).first;

String _timerText(WidgetTester tester) =>
    tester.widget<CameoText>(find.byType(CameoText).at(1)).text;

const double _inkRatio = 4;

LineMetrics _strutMetrics(String text, TextStyle style) => (TextPainter(
  text: TextSpan(text: text, style: style),
  textDirection: TextDirection.ltr,
  strutStyle: cameoStrutOf(style),
)..layout()).computeLineMetrics().first;

double _cssBaseline(TextStyle style) {
  final m = _strutMetrics('0', style);
  return style.fontSize! * style.height! / 2 + (m.ascent - m.descent) / 2;
}

Future<double> _inkBottom(
  WidgetTester tester,
  GlobalKey boundary,
  double x, {
  double top = 0,
  double bottom = double.infinity,
}) async {
  final image = tester
      .renderObject<RenderRepaintBoundary>(find.byKey(boundary))
      .toImageSync(pixelRatio: _inkRatio);
  final bytes = (await tester.runAsync(
    () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
  ))!;
  final col = (x * _inkRatio).round();
  final to = bottom.isFinite
      ? math.min(image.height, (bottom * _inkRatio).ceil())
      : image.height;
  var ink = double.nan;
  for (var y = (top * _inkRatio).floor(); y < to; y++) {
    final coverage = bytes.getUint8((y * image.width + col) * 4 + 3) / 255;
    if (coverage > 0.02) ink = y + coverage;
  }
  image.dispose();
  return ink / _inkRatio;
}

Future<double> _glyphInkBelowBaseline(
  WidgetTester tester,
  String glyph,
  TextStyle style,
) async {
  final m = _strutMetrics(glyph, style);
  final baseline = _cssBaseline(style).ceilToDouble();
  final lineHeight = 2 * baseline - (m.ascent - m.descent);
  final ref = style.copyWith(height: lineHeight / style.fontSize!);
  final key = GlobalKey();
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: RepaintBoundary(
          key: key,
          child: CameoText(
            glyph,
            style: ref,
            color: CameoColors.foregroundNeutralInverseBase,
          ),
        ),
      ),
    ),
  );
  final width = tester.getSize(find.byKey(key)).width;
  return await _inkBottom(tester, key, width / 2) - baseline;
}

double _glyphCenterX(String text, TextStyle style, Rect box, int glyph) {
  final b =
      (TextPainter(
            text: TextSpan(text: text, style: style),
            textAlign: TextAlign.center,
            textDirection: TextDirection.ltr,
            strutStyle: cameoStrutOf(style),
          )..layout(minWidth: box.width, maxWidth: box.width))
          .getBoxesForSelection(
            TextSelection(baseOffset: glyph, extentOffset: glyph + 1),
          )
          .first;
  return box.left + (b.left + b.right) / 2;
}

void main() {
  group('parseCallTime / formatCallTime', () {
    test('mm:ss ↔ 초', () {
      expect(parseCallTime('00:04'), 4);
      expect(parseCallTime('01:30'), 90);
      expect(parseCallTime('1:02:03'), 3723);
      expect(parseCallTime('ab:cd'), 0);
      expect(formatCallTime(4), '00:04');
      expect(formatCallTime(65), '01:05');
      expect(formatCallTime(3723), '62:03');
      expect(formatCallTime(-3), '00:00');
    });
  });

  group('CallerBlock regular (2042:2493)', () {
    testWidgets('393 x 131.6 @ top 118 (= 62 + 56), 이름 361 x 89.6 · 타이머 26', (
      tester,
    ) async {
      _screenSize(tester);
      await tester.pumpWidget(
        _host(
          CallerBlock(name: labInCall.name, startTime: labInCall.timer),
          topAreaBottom: CameoLayout.screenTopAreaHeight,
        ),
      );

      final r = tester.getRect(_block);
      expect(r.left, 0);
      expect(r.width, CameoLayout.screenWidth);
      expect(r.top, 118);
      expect(r.height, closeTo(CameoLayout.callerBlockHeight, _eps));

      expect(
        r.bottom,
        closeTo(_screen.height - CameoLayout.callerBlockFigmaBottom, 0.41),
      );

      final name = tester.getRect(_lineBox('Yurim'));
      expect(name.left, 16);
      expect(name.width, 361);
      expect(name.top, 118 + 8);
      expect(name.height, closeTo(89.6, _eps));

      final timer = tester.getRect(_lineBox('00:04'));
      expect(timer.width, 361);
      expect(timer.top, closeTo(name.bottom, _eps));
      expect(timer.height, closeTo(26, _eps));
      expect(r.bottom - timer.bottom, closeTo(8, _eps));

      final nameStyle = tester.widget<CameoText>(find.byType(CameoText).at(0));
      final timerStyle = tester.widget<CameoText>(find.byType(CameoText).at(1));
      expect(nameStyle.style, CameoTextStyles.display);
      expect(timerStyle.style, CameoTextStyles.headingSm);
      expect(nameStyle.color, CameoColors.foregroundNeutralInverseBase);
      expect(timerStyle.color, CameoColors.foregroundNeutralInverseBase);
      expect(nameStyle.textAlign, TextAlign.center);
    });

    testWidgets(
      '글자 기준선 = RN/CSS 규칙 (줄 위 + L/2 + (ascent − descent)/2) — SkParagraph 정수 반올림 보정',
      (tester) async {
        _screenSize(tester);
        const timerStyle = CameoTextStyles.headingSm;
        const nameStyle = CameoTextStyles.display;

        final zeroBelow = await _glyphInkBelowBaseline(tester, '0', timerStyle);
        final uBelow = await _glyphInkBelowBaseline(tester, 'u', nameStyle);

        final boundary = GlobalKey();
        await tester.pumpWidget(
          _host(
            RepaintBoundary(
              key: boundary,
              child: CallerBlock(
                name: labInCall.name,
                startTime: labInCall.timer,
                running: false,
              ),
            ),
            topAreaBottom: CameoLayout.screenTopAreaHeight,
          ),
        );
        final origin = tester.getTopLeft(find.byKey(boundary));
        Rect local(Finder f) => tester.getRect(f).shift(-origin);

        final timerBox = local(_lineBox('00:04'));
        expect(
          await _inkBottom(
            tester,
            boundary,
            _glyphCenterX('00:04', timerStyle, timerBox, 0),
            top: timerBox.top,
            bottom: timerBox.bottom,
          ),
          closeTo(timerBox.top + _cssBaseline(timerStyle) + zeroBelow, 0.15),
        );

        final nameBox = local(_lineBox('Yurim'));
        expect(
          await _inkBottom(
            tester,
            boundary,
            _glyphCenterX('Yurim', nameStyle, nameBox, 1),
            top: nameBox.top,
            bottom: nameBox.bottom,
          ),
          closeTo(nameBox.top + _cssBaseline(nameStyle) + uBelow, 0.15),
        );
      },
    );

    testWidgets('타이머: 00:04 에서 1초마다 증가, running=false 면 정지', (tester) async {
      _screenSize(tester);
      Widget build({required bool running}) => _host(
        CallerBlock(
          name: labInCall.name,
          startTime: labInCall.timer,
          running: running,
        ),
        topAreaBottom: CameoLayout.screenTopAreaHeight,
      );
      await tester.pumpWidget(build(running: true));
      expect(_timerText(tester), '00:04');

      await tester.pump(const Duration(milliseconds: 999));
      expect(_timerText(tester), '00:04');
      await tester.pump(const Duration(milliseconds: 1));
      expect(_timerText(tester), '00:05');
      await tester.pump(const Duration(seconds: 56));
      expect(_timerText(tester), '01:01');

      await tester.pumpWidget(build(running: false));
      await tester.pump(const Duration(seconds: 5));
      expect(_timerText(tester), '01:01');

      await tester.pumpWidget(build(running: true));
      await tester.pump(const Duration(seconds: 2));
      expect(_timerText(tester), '01:03');
    });

    testWidgets('접근성 라벨 (한국어) = 이름 + 통화 시간', (tester) async {
      _screenSize(tester);
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          CallerBlock(name: labInCall.name, startTime: labInCall.timer),
          topAreaBottom: CameoLayout.screenTopAreaHeight,
        ),
      );
      expect(find.bySemanticsLabel('Yurim, 통화 시간 00:04'), findsOneWidget);
      handle.dispose();
    });
  });

  group('CallerBlock v1 (2004:1814)', () {
    testWidgets('393 x 127.6 @ top 128 (= 62 + navBarV1 66), 타이머 bodyLg 22', (
      tester,
    ) async {
      _screenSize(tester);
      await tester.pumpWidget(
        _host(
          CallerBlock(
            name: labInCall.name,
            startTime: labInCall.timer,
            variant: CallerBlockVariant.v1,
          ),
          topAreaBottom:
              CameoLayout.screenStatusBarHeight + CameoLayout.navBarV1Height,
        ),
      );

      final r = tester.getRect(_block);
      expect(r.width, CameoLayout.screenWidth);
      expect(r.top, 128);
      expect(r.height, closeTo(CameoLayout.callerBlockV1Height, _eps));
      // Figma: bottom 596 → 852 − 596 = 256 (128.4 … 256)
      expect(
        r.bottom,
        closeTo(_screen.height - CameoLayout.callerBlockV1FigmaBottom, 0.41),
      );
      expect(tester.getSize(_lineBox('00:04')).height, closeTo(22, _eps));
      expect(tester.getSize(_lineBox('Yurim')).height, closeTo(89.6, _eps));
      expect(
        tester.widget<CameoText>(find.byType(CameoText).at(1)).style,
        CameoTextStyles.bodyLg,
      );
    });
  });
}
