// Regression coverage for transcript quote card. Preserve behavior, layout, and
// interaction expectations.

import 'package:cameo/components/karaoke_text.dart';
import 'package:cameo/components/quote_card.dart';
import 'package:cameo/content/lab.g.dart';
import 'package:cameo/design_system/design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const double _cardWidth = 381;
const double _tol = 0.001;

final double _quoteLine =
    (CameoTextStyles.quote.fontSize! * CameoTextStyles.quote.height!)
        .roundToDouble();
final double _label =
    (CameoTextStyles.bodySm.fontSize! * CameoTextStyles.bodySm.height!)
        .roundToDouble();

final QuoteCardContent _figma = labAlbumGangneung.quoteCard;

QuoteCardContent _figmaShaped() => QuoteCardContent(
  nodeId: _figma.nodeId,
  label: _figma.label,
  labelAlign: _figma.labelAlign,
  lines: [
    for (final l in _figma.lines)
      QuoteLineContent(
        nodeId: l.nodeId,
        text: '가나다',
        align: l.align,
        gradient: l.gradient,
      ),
  ],
);

Widget _harness(Widget child) {
  return MediaQuery(
    data: const MediaQueryData(size: Size(393, 852)),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: _cardWidth, child: child),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'Figma 치수 (2015:1954): 381×156 · 라벨 (16,16) h14 · 줄 (16,42) (16,97) w349 h43',
    (tester) async {
      await tester.pumpWidget(_harness(QuoteCard(card: _figmaShaped())));

      final card = tester.getSize(find.byType(QuoteCard));
      expect(card.width, _cardWidth);
      // 16 + 14 + 12 + 43 + 12 + 43 + 16 = 156 = layout.quoteCard.height (Figma metadata)
      expect(
        card.height,
        closeTo(16 + _label + 12 + 2 * _quoteLine + 12 + 16, _tol),
      );
      expect(card.height, closeTo(CameoLayout.quoteCardHeight, _tol));

      final label = tester.getRect(find.byType(CameoText));
      expect(label.topLeft, const Offset(16, 16));
      expect(label.height, closeTo(_label, _tol));

      final line1 = tester.getRect(find.byType(KaraokeText));
      expect(line1.left, 16);
      expect(
        line1.top,
        closeTo(16 + _label + 12, _tol),
      ); // 42 (metadata 2015:1956 y 42)
      expect(line1.width, 349);
      expect(line1.height, closeTo(_quoteLine, _tol));

      final line2 = tester.getRect(
        find.byWidgetPredicate(
          (w) => w is KeepAllText && w.color == CameoColors.quoteCardLine,
        ),
      );
      expect(line2.left, 16);
      expect(
        line2.top,
        closeTo(line1.bottom + 12, _tol),
      ); // 97 (metadata 2015:1957 y 97)
      expect(line2.top, closeTo(97, _tol));
      expect(line2.width, 349);
    },
  );

  testWidgets(
    '콘텐츠: 라벨 왼쪽 · 1줄 KaraokeText(karaokeQuote 46.635%) 왼쪽 · 2줄 오른쪽 quote-card/line',
    (tester) async {
      await tester.pumpWidget(_harness(QuoteCard(card: _figma)));
      final label = tester.widget<CameoText>(find.byType(CameoText));
      expect(label.text, '중요 내용 #1');
      expect(label.style, CameoTextStyles.bodySm);
      expect(label.color, CameoColors.quoteCardLabel);
      expect(tester.getRect(find.byType(CameoText)).left, 16);

      final k = tester.widget<KaraokeText>(find.byType(KaraokeText));
      expect(k.text, '나 내일 수능이라 컴싸 꼭 필요해!');
      expect(k.karaoke, CameoGradients.karaokeQuote);
      expect(k.align, LabAlign.left);
      expect(k.style, CameoTextStyles.quote);
      expect(
        tester.state<KaraokeTextState>(find.byType(KaraokeText)).shownProgress,
        0.46635,
      );

      final line2 = tester.widget<KeepAllText>(
        find.byWidgetPredicate(
          (w) => w is KeepAllText && w.color == CameoColors.quoteCardLine,
        ),
      );
      expect(line2.text, '아 알겠어 꼭 챙겨갈게!');
      expect(line2.textAlign, TextAlign.right);
      expect(line2.style, CameoTextStyles.quote);
    },
  );

  testWidgets(
    '채움·테두리: quote-card/fill (테두리 없음 → 레이아웃 제외) + 오버레이 1.5 quote-card/border r16',
    (tester) async {
      await tester.pumpWidget(_harness(QuoteCard(card: _figma)));
      final surface = tester.widget<BlurSurface>(find.byType(BlurSurface));
      expect(surface.tint, CameoColors.quoteCardFill);
      expect(surface.border, isNull);
      expect(surface.radius, CameoLayout.quoteCardRadius);

      final overlay = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((d) => d.decoration)
          .whereType<ShapeDecoration>()
          .firstWhere((d) => d.color == null);
      final shape = overlay.shape as RoundedSuperellipseBorder;
      expect(shape.side.color, CameoColors.quoteCardBorder);
      expect(shape.side.width, CameoLayout.quoteCardBorderWidth);
      expect(
        shape.borderRadius,
        BorderRadius.circular(CameoLayout.quoteCardRadius),
      );

      final overlayRect = tester.getRect(
        find.byWidgetPredicate(
          (w) => w is DecoratedBox && w.decoration == overlay,
        ),
      );
      expect(overlayRect, tester.getRect(find.byType(BlurSurface)));
    },
  );

  testWidgets('onPress 없음 → PressScale 없음, 치수 동일', (tester) async {
    await tester.pumpWidget(_harness(QuoteCard(card: _figmaShaped())));
    expect(find.byType(PressScale), findsNothing);
    final plain = tester.getSize(find.byType(QuoteCard));
    await tester.pumpWidget(
      _harness(QuoteCard(card: _figmaShaped(), onPress: (_) {})),
    );
    expect(find.byType(PressScale), findsOneWidget);
    expect(tester.getSize(find.byType(QuoteCard)), plain);
  });

  testWidgets('탭 → onPress(card) · 한국어 라벨', (tester) async {
    final handle = tester.ensureSemantics();
    QuoteCardContent? tapped;
    await tester.pumpWidget(
      _harness(QuoteCard(card: _figma, onPress: (c) => tapped = c)),
    );
    await tester.tap(find.byType(QuoteCard));
    await tester.pumpAndSettle();
    expect(tapped, same(_figma));
    expect(
      find.bySemanticsLabel(
        RegExp('^중요 내용 #1, 나 내일 수능이라 컴싸 꼭 필요해!, 아 알겠어 꼭 챙겨갈게!'),
      ),
      findsOneWidget,
    );
    handle.dispose();
  });
}
