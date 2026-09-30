// Regression coverage for glass pressable. Preserve behavior, layout, and interaction
// expectations.

import 'package:cameo/design_system/design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {bool reduceMotion = false}) => MediaQuery(
  data: MediaQueryData(disableAnimations: reduceMotion),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: Center(child: child),
  ),
);

Widget _button({VoidCallback? onPress}) => GlassPressable(
  onPress: onPress,
  child: const SizedBox.square(dimension: CameoLayout.navBarCircleButtonSize),
);

double _scaleX(WidgetTester tester) => tester
    .widget<Transform>(
      find
          .descendant(
            of: find.byType(GlassPressable),
            matching: find.byType(Transform),
          )
          .first,
    )
    .transform
    .entry(0, 0);

void main() {
  group('GlassPressable', () {
    testWidgets('두 손가락으로 눌러도 onPress 는 한 번 (RN Pan = 제스처 하나)', (tester) async {
      var pressed = 0;
      await tester.pumpWidget(_host(_button(onPress: () => pressed++)));
      final center = tester.getCenter(find.byType(GlassPressable));
      final a = await tester.startGesture(center, pointer: 1);
      final b = await tester.startGesture(
        center + const Offset(4, 0),
        pointer: 2,
      );
      await a.up();
      await b.up();
      await tester.pumpAndSettle();
      expect(pressed, 1);

      await tester.tap(find.byType(GlassPressable));
      await tester.pumpAndSettle();
      expect(pressed, 2);
    });

    testWidgets('누름은 press 스프링으로 부풀고 놓으면 chewy 로 1 에 돌아온다', (tester) async {
      await tester.pumpWidget(_host(_button(onPress: () {})));
      final g = await tester.startGesture(
        tester.getCenter(find.byType(GlassPressable)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.hasRunningAnimations, isTrue);
      expect(_scaleX(tester), greaterThan(1));
      expect(_scaleX(tester), lessThan(CameoMotion.glassPressScale));
      await g.up();
      await tester.pumpAndSettle();
      expect(_scaleX(tester), 1);
    });

    testWidgets('모션 감소: 누름·복귀가 스프링 없이 즉시 (RN ReduceMotion.System)', (
      tester,
    ) async {
      var pressed = 0;
      await tester.pumpWidget(
        _host(_button(onPress: () => pressed++), reduceMotion: true),
      );
      final g = await tester.startGesture(
        tester.getCenter(find.byType(GlassPressable)),
      );
      await tester.pump();
      expect(_scaleX(tester), CameoMotion.glassPressScale);
      expect(tester.hasRunningAnimations, isFalse);
      await g.up();
      await tester.pump();
      expect(_scaleX(tester), 1);
      expect(tester.hasRunningAnimations, isFalse);
      expect(pressed, 1);
    });
  });
}
