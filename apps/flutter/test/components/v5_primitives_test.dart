// Regression coverage for v5 primitives. Preserve behavior, layout, and interaction
// expectations.

import 'package:cameo/components/call_list_card.dart';
import 'package:cameo/components/controls.dart';
import 'package:cameo/components/toast.dart';
import 'package:cameo/components/toast_v6.dart';
import 'package:cameo/content/lab.g.dart';
import 'package:cameo/design_system/design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const Size _screen = Size(393, 852);

void _iPhone16(WidgetTester tester) {
  tester.view
    ..physicalSize = _screen
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  CameoColorMode mode = CameoColorMode.dark,
  bool positioned = false,
}) async {
  _iPhone16(tester);
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(size: _screen),
        child: CameoTheme(
          mode: mode,
          child: Stack(
            children: [
              if (positioned)
                child
              else
                Positioned(left: 16, top: 78, child: child),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  final dark = CameoPalette.of(CameoColorMode.dark);

  group('SelectControl · HeartControl (2166:5659)', () {
    testWidgets(
      '체크 20: 꺼짐 = 1 px static/white/base 링 · 켜짐 = 흰 원판 + check 14 static/black/base (bouncy 스케일)',
      (tester) async {
        await _pump(tester, const SelectControl(selected: false));
        expect(tester.getSize(find.byType(SelectControl)), const Size(20, 20));
        expect(find.byKey(SelectControl.ringKey), findsOneWidget);
        expect(find.byKey(SelectControl.discKey), findsNothing);
        final ring =
            tester
                    .widget<DecoratedBox>(find.byKey(SelectControl.ringKey))
                    .decoration
                as BoxDecoration;
        expect((ring.border! as Border).top.width, 1);
        expect((ring.border! as Border).top.color, dark.staticWhiteBase);
        await _pump(tester, const SelectControl(selected: true));
        await tester.pump(const Duration(milliseconds: 40));
        final mid = tester.widget<Transform>(
          find
              .ancestor(
                of: find.byKey(SelectControl.discKey),
                matching: find.byType(Transform),
              )
              .first,
        );
        expect(mid.transform.entry(0, 0), inExclusiveRange(0, 1.3));
        await tester.pumpAndSettle();
        expect(find.byKey(SelectControl.ringKey), findsNothing);
        final check = tester.widget<CameoIcon>(
          find.descendant(
            of: find.byKey(SelectControl.discKey),
            matching: find.byType(CameoIcon),
          ),
        );
        expect(check.name, CameoIconName.check);
        expect(check.size, 14);
        expect(check.color, dark.staticBlackBase);
        expect(tester.getSize(find.byType(CameoIcon)), const Size(14, 14));
      },
    );

    testWidgets('하트 22: 꺼짐 outline · 켜짐 heart-filled + 하트 모양 그림자 (0, 8) · 누름', (
      tester,
    ) async {
      var pressed = 0;
      await _pump(
        tester,
        HeartControl(active: false, onPress: () => pressed++),
      );
      expect(tester.getSize(find.byType(HeartControl)), const Size(22, 22));
      expect(find.byKey(HeartControl.shadowKey), findsNothing);
      await tester.tap(find.byType(HeartControl));
      await tester.pumpAndSettle();
      expect(pressed, 1);
      await _pump(tester, const HeartControl(active: true));
      await tester.pumpAndSettle();
      expect(find.byKey(HeartControl.shadowKey), findsOneWidget);
      expect(
        tester
            .widget<Transform>(find.byKey(HeartControl.shadowKey))
            .transform
            .getTranslation()
            .y,
        8,
      );
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is CameoIcon &&
              w.name == CameoIconName.heartFilled &&
              w.color == dark.staticWhiteBase,
        ),
        findsOneWidget,
      );
    });
  });

  group('v5 계약 추가 (RN 과 같은 props)', () {
    testWidgets('SelectControl showRing false = 꺼진 칸에 아무것도 없다 (앨범 선택 모드)', (
      tester,
    ) async {
      await _pump(
        tester,
        const SelectControl(selected: false, showRing: false),
      );
      expect(find.byKey(SelectControl.ringKey), findsNothing);
      expect(find.byKey(SelectControl.discKey), findsNothing);
    });

    testWidgets(
      'ToastController 토스트마다 변형 (show(…, variant: v6Elevated)) — 호스트 변형이 없으면 그 모양 · 다음 show 는 호스트 변형',
      (tester) async {
        final toast = ToastController();
        addTearDown(toast.dispose);
        await _pump(
          tester,
          Positioned(
            left: 0,
            right: 0,
            bottom: 104,
            child: ToastHost(controller: toast),
          ),
          positioned: true,
        );
        toast.showContent(
          labInCallV5.toasts.highlight,
          variant: ToastVariant.v6Elevated,
        );
        await tester.pumpAndSettle();
        expect(find.byType(ToastV6Pill), findsOneWidget);
        toast.show('v4', CameoIconName.borderNone);
        await tester.pump();
        expect(find.byType(ToastV6Pill), findsNothing);
        await tester.pump(CameoMotion.toastVisible);
        await tester.pumpAndSettle();
      },
    );

    testWidgets('CallListCard: Medium span = bodySmStrong', (tester) async {
      await _pump(
        tester,
        const Positioned(
          left: 8,
          top: 100,
          width: 377,
          child: CallListCard(
            direction: CallDirection.outgoing,
            title: 't',
            subtitle: [
              LabTextSpan('12시 20분', LabTextWeight.medium),
              LabTextSpan(' ∙ 발신', LabTextWeight.regular),
            ],
          ),
        ),
        positioned: true,
      );
      final rich = tester.widget<Text>(
        find
            .descendant(
              of: find.byType(CallListCard),
              matching: find.byType(Text),
            )
            .last,
      );
      final spans = (rich.textSpan! as TextSpan).children!.cast<TextSpan>();
      expect(
        spans.first.style!.fontWeight,
        CameoTextStyles.bodySmStrong.fontWeight,
      );
      expect(spans.last.style!.fontWeight, CameoTextStyles.bodySm.fontWeight);
    });
  });
}
