import 'package:cameo/components/scroll_edge_fade.dart';
import 'package:cameo/design_system/design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('높이 = safeTop + 56 + 16 (iPhone 16: 59 → 131)', () {
    expect(scrollEdgeFadeHeight(59), 131);
    expect(scrollEdgeFadeHeight(0), 72);
  });

  testWidgets('부모 폭 × height · gradient.scrollEdgeTop · 터치 통과', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var taps = 0;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 393,
          height: 852,
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => taps++,
                ),
              ),
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: ScrollEdgeFade(height: 131),
              ),
            ],
          ),
        ),
      ),
    );
    expect(
      tester.getRect(find.byType(ScrollEdgeFade)),
      const Rect.fromLTWH(0, 0, 393, 131),
    );
    final box = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(ScrollEdgeFade),
        matching: find.byType(DecoratedBox),
      ),
    );
    expect(
      (box.decoration as BoxDecoration).gradient,
      CameoGradients.scrollEdgeTop,
    );
    await tester.tapAt(const Offset(100, 50));
    expect(taps, 1);
  });
}
