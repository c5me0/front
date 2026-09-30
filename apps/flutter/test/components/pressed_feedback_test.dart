import 'package:cameo/components/scrim_button.dart';
import 'package:cameo/components/scrim_pill.dart';
import 'package:cameo/components/solid_button.dart';
import 'package:cameo/components/tab_bar_v6.dart';
import 'package:cameo/design_system/design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> host(
  WidgetTester tester,
  Widget child, {
  bool reduced = false,
}) async {
  tester.view
    ..physicalSize = const Size(402, 874)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: MediaQueryData(
          size: const Size(402, 874),
          disableAnimations: reduced,
        ),
        child: CameoTheme(
          mode: CameoColorMode.light,
          child: Center(child: child),
        ),
      ),
    ),
  );
  await tester.pump();
}

double feedbackAlpha(WidgetTester tester, Finder owner) {
  final box = tester.widget<DecoratedBox>(
    find.descendant(of: owner, matching: find.byKey(PressFeedback.overlayKey)),
  );
  return (box.decoration as BoxDecoration).color!.a;
}

void main() {
  testWidgets(
    'removing a pressed control cancels tracking without firing its action',
    (tester) async {
      var taps = 0;
      for (final button in <Widget>[
        SolidButton(label: '다음', onPress: () => taps++),
        ScrimButton(label: '선택', onPress: () => taps++),
      ]) {
        await host(tester, button);
        final gesture = await tester.startGesture(
          tester.getCenter(find.byWidget(button)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));
        await tester.pumpWidget(const SizedBox());
        await gesture.up();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      expect(taps, 0);
    },
  );

  testWidgets(
    'solid: touch-down feedback precedes tap recognition, release activates once',
    (tester) async {
      var taps = 0;
      await host(tester, SolidButton(label: '다음', onPress: () => taps++));
      final owner = find.byType(SolidButton);
      final surface = tester.element(find.byKey(SolidButton.surfaceKey));
      expect(feedbackAlpha(tester, owner), 0);
      final gesture = await tester.startGesture(tester.getCenter(owner));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 32));
      expect(feedbackAlpha(tester, owner), greaterThan(0));
      expect(taps, 0);
      expect(
        identical(surface, tester.element(find.byKey(SolidButton.surfaceKey))),
        isTrue,
      );
      await gesture.up();
      await tester.pumpAndSettle();
      expect(taps, 1);
      expect(feedbackAlpha(tester, owner), 0);
    },
  );

  testWidgets(
    'solid: dragging cancels feedback and never activates on release',
    (tester) async {
      var taps = 0;
      await host(
        tester,
        SolidButton(
          label: '취소',
          variant: SolidButtonVariant.gray,
          onPress: () => taps++,
        ),
      );
      final owner = find.byType(SolidButton);
      final gesture = await tester.startGesture(tester.getCenter(owner));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(feedbackAlpha(tester, owner), greaterThan(0));
      await gesture.moveBy(const Offset(80, 0));
      await tester.pumpAndSettle();
      expect(feedbackAlpha(tester, owner), 0);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(taps, 0);
    },
  );

  testWidgets(
    'glass: pressed surface preserves its instance; pointer cancellation clears it',
    (tester) async {
      var taps = 0;
      await host(
        tester,
        ScrimButton(
          size: ScrimButtonSize.md,
          label: '선택',
          onPress: () => taps++,
        ),
      );
      final owner = find.byType(ScrimButton);
      final surface = tester.element(find.byKey(ScrimButton.surfaceKey));
      final gesture = await tester.startGesture(tester.getCenter(owner));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(feedbackAlpha(tester, owner), greaterThan(0));
      expect(
        identical(surface, tester.element(find.byKey(ScrimButton.surfaceKey))),
        isTrue,
      );
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(feedbackAlpha(tester, owner), 0);
      expect(taps, 0);
      expect(
        identical(surface, tester.element(find.byKey(ScrimButton.surfaceKey))),
        isTrue,
      );
    },
  );

  testWidgets('disabled controls have no pressed surface or activation', (
    tester,
  ) async {
    var taps = 0;
    for (final button in <Widget>[
      SolidButton(label: '다음', disabled: true, onPress: () => taps++),
      ScrimButton(label: '선택', disabled: true, onPress: () => taps++),
    ]) {
      await host(tester, button);
      expect(find.byType(PressFeedback), findsNothing);
      await tester.tap(find.byWidget(button), warnIfMissed: false);
      await tester.pumpAndSettle();
    }
    expect(taps, 0);
  });

  testWidgets(
    'reduced motion: pressed color remains visible without a spring',
    (tester) async {
      await host(
        tester,
        SolidButton(label: '다음', onPress: () {}),
        reduced: true,
      );
      final owner = find.byType(SolidButton);
      final gesture = await tester.startGesture(tester.getCenter(owner));
      await tester.pump();
      expect(
        feedbackAlpha(tester, owner),
        closeTo(CameoPalette.dark.backgroundFillScrimInteraction.a, 1e-6),
      );
      expect(tester.hasRunningAnimations, isFalse);
      await gesture.up();
      await tester.pump();
      expect(feedbackAlpha(tester, owner), 0);
    },
  );

  testWidgets('pill: only the touched item highlights', (tester) async {
    await host(
      tester,
      ScrimPill(
        items: [
          ScrimPillItem(
            icon: CameoIconName.heart,
            semanticLabel: '좋아요',
            onPress: () {},
          ),
          ScrimPillItem(
            icon: CameoIconName.history,
            semanticLabel: '최근 삭제',
            onPress: () {},
          ),
        ],
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(ScrimPill.itemKey(0))),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final pressables = find.byType(GlassPressable);
    expect(feedbackAlpha(tester, pressables.at(0)), greaterThan(0));
    expect(feedbackAlpha(tester, pressables.at(1)), 0);
    await gesture.cancel();
    await tester.pumpAndSettle();
  });

  testWidgets(
    'tab bar: interrupted morph retains the same glass surface and current geometry',
    (tester) async {
      Widget bar(TabBarV6Mode mode) =>
          TabBarV6(selected: 0, mode: mode, onSelect: (_) {});
      await host(tester, bar(TabBarV6Mode.full));
      final glass = tester.element(find.byKey(TabBarV6.pillKey));
      await host(tester, bar(TabBarV6Mode.mini));
      await tester.pump(const Duration(milliseconds: 80));
      final width = tester.getSize(find.byKey(TabBarV6.pillKey)).width;
      expect(width, inExclusiveRange(190, 308));
      await host(tester, bar(TabBarV6Mode.full));
      expect(
        tester.getSize(find.byKey(TabBarV6.pillKey)).width,
        closeTo(width, 1e-6),
      );
      expect(
        identical(glass, tester.element(find.byKey(TabBarV6.pillKey))),
        isTrue,
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byKey(TabBarV6.pillKey)).width, 308);
    },
  );
}
