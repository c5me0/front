// Regression coverage for confirm sheet. Preserve behavior, layout, and interaction
// expectations.

import 'package:cameo/components/confirm_sheet.dart';
import 'package:cameo/components/primary_button.dart';
import 'package:cameo/content/app.g.dart';
import 'package:cameo/design_system/design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

const Size _screen = Size(393, 852);
const Duration _frame = Duration(milliseconds: 16);

void _screenSize(WidgetTester tester) {
  tester.view.physicalSize = _screen;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

class _Host extends StatefulWidget {
  const _Host({this.controller, this.reduceMotion = false});
  final ConfirmSheetController? controller;
  final bool reduceMotion;
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  bool visible = false;
  final List<String> log = [];

  void open() => setState(() => visible = true);

  @override
  Widget build(BuildContext context) {
    final sheet = appContent.settings.logoutSheet;
    return MediaQuery(
      data: MediaQueryData(
        size: _screen,
        padding: const EdgeInsets.only(top: 59, bottom: 34),
        disableAnimations: widget.reduceMotion,
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: CameoTheme(
          mode: CameoColorMode.light,
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  key: const ValueKey('background'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => log.add('background'),
                ),
              ),
              Positioned.fill(
                child: ConfirmSheet(
                  visible: visible,
                  title: sheet.title,
                  body: sheet.body,
                  confirmLabel: sheet.confirm,
                  cancelLabel: sheet.cancel,
                  destructive: true,
                  controller: widget.controller,
                  onShown: () => log.add('shown'),
                  onConfirm: () {
                    log.add('confirm');
                    setState(() => visible = false);
                  },
                  onCancel: () {
                    log.add('cancel');
                    setState(() => visible = false);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

_HostState _host(WidgetTester tester) =>
    tester.state<_HostState>(find.byType(_Host));

Future<void> _open(WidgetTester tester) async {
  _host(tester).open();
  await tester.pump();
}

void _expectGlassNeverFaded(WidgetTester tester) {
  for (final e in find.byType(LiquidGlass).evaluate()) {
    e.visitAncestorElements((a) {
      final w = a.widget;
      if (w is Opacity) {
        expect(w.opacity, 1, reason: 'Liquid Glass 조상 Opacity');
      }
      if (w is FadeTransition) {
        expect(w.opacity.value, 1, reason: 'Liquid Glass 조상 FadeTransition');
      }
      return true;
    });
  }
}

void main() {
  test('시트 아래 여백 = max(safeBottom − 26, 8)', () {
    expect(confirmSheetBottom(34), 8);
    expect(confirmSheetBottom(0), 8);
    expect(confirmSheetBottom(48), 22);
  });

  testWidgets('숨김이면 아무것도 없고 터치가 통과한다', (tester) async {
    _screenSize(tester);
    await tester.pumpWidget(const _Host());
    expect(find.byKey(ConfirmSheet.sheetKey), findsNothing);
    await tester.tapAt(const Offset(200, 400));
    expect(_host(tester).log, ['background']);
  });

  testWidgets(
    '등장: 아래 밖에서 smooth 로 올라와 좌우 8 · 아래 8 · 반경 38 Liquid Glass · onShown 한 번 · 내용 배치',
    (tester) async {
      _screenSize(tester);
      await tester.pumpWidget(const _Host());
      await _open(tester);

      expect(
        tester.getRect(find.byKey(ConfirmSheet.sheetKey)).top,
        closeTo(852, 0.01),
      );
      await tester.pump(_frame);
      await tester.pump(const Duration(milliseconds: 100));
      final mid = tester.getRect(find.byKey(ConfirmSheet.sheetKey));
      expect(mid.top, lessThan(852));
      expect(_host(tester).log, isEmpty);
      await tester.pumpAndSettle();
      expect(_host(tester).log, ['shown']);
      final rect = tester.getRect(find.byKey(ConfirmSheet.sheetKey));
      expect(rect.left, 8);
      expect(rect.right, 393 - 8);
      expect(rect.bottom, closeTo(852 - 8, 0.01));
      final surface = tester.widget<GlassSurface>(
        find
            .descendant(
              of: find.byKey(ConfirmSheet.sheetKey),
              matching: find.byType(GlassSurface),
            )
            .first,
      );
      expect(surface.radius, CameoLayout.confirmSheetRadius);
      expect(surface.tint, CameoColors.glassTintPanel); // D15
      expect(find.byType(LiquidGlass), findsNWidgets(3));

      final title = tester.getRect(
        find.byWidgetPredicate((w) => w is CameoText && w.text == '로그아웃할까요?'),
      );
      expect(title.left, 8 + 24);
      expect(title.top, closeTo(rect.top + 24, 0.01));
      final confirm = tester.getRect(find.byKey(ConfirmSheet.confirmKey));
      final cancel = tester.getRect(find.byKey(ConfirmSheet.cancelKey));
      expect(confirm.width, 393 - 16 - 48);
      expect(cancel.top, confirm.bottom + 8);
      expect(cancel.bottom, closeTo(rect.bottom - 24, 0.01));
      expect(
        tester
            .widget<PrimaryButton>(find.byKey(ConfirmSheet.confirmKey))
            .variant,
        PrimaryButtonVariant.destructive,
      );
      expect(
        tester
            .widget<PrimaryButton>(find.byKey(ConfirmSheet.cancelKey))
            .variant,
        PrimaryButtonVariant.secondary,
      );
      // dim overlay/dim
      final dim = tester.widget<Opacity>(find.byKey(ConfirmSheet.dimKey));
      expect(dim.opacity, 1);
      expect(
        tester
            .widget<ColoredBox>(
              find.descendant(
                of: find.byKey(ConfirmSheet.dimKey),
                matching: find.byType(ColoredBox),
              ),
            )
            .color,
        CameoColors.overlayDim,
      );
    },
  );

  testWidgets('확인 버튼 → onConfirm → 닫힘 (반대 모션) · 취소 버튼 → onCancel', (
    tester,
  ) async {
    _screenSize(tester);
    await tester.pumpWidget(const _Host());
    await _open(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ConfirmSheet.confirmKey));
    await tester.pump();
    expect(_host(tester).log, ['shown', 'confirm']);
    await tester.pump(_frame);
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.byKey(ConfirmSheet.sheetKey), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byKey(ConfirmSheet.sheetKey), findsNothing);
    await _open(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ConfirmSheet.cancelKey));
    await tester.pumpAndSettle();
    expect(_host(tester).log, ['shown', 'confirm', 'shown', 'cancel']);
  });

  testWidgets('dim 탭 → onCancel (아래 배경은 받지 않는다)', (tester) async {
    _screenSize(tester);
    await tester.pumpWidget(const _Host());
    await _open(tester);
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(200, 200));
    await tester.pumpAndSettle();
    expect(_host(tester).log, ['shown', 'cancel']);
  });

  testWidgets('아래로 끌기: 절반 넘게 → onCancel · 조금만 → 제자리', (tester) async {
    _screenSize(tester);
    await tester.pumpWidget(const _Host());
    await _open(tester);
    await tester.pumpAndSettle();
    final rect = tester.getRect(find.byKey(ConfirmSheet.sheetKey));
    final title = find.byWidgetPredicate(
      (w) => w is CameoText && w.text == '로그아웃할까요?',
    );

    final g = await tester.startGesture(tester.getCenter(title));
    for (var i = 0; i < 6; i++) {
      await g.moveBy(const Offset(0, 5));
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(
      tester.getRect(find.byKey(ConfirmSheet.sheetKey)).top,
      greaterThan(rect.top + 10),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await g.up();
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byKey(ConfirmSheet.sheetKey)).top,
      closeTo(rect.top, 0.01),
    );
    expect(_host(tester).log, ['shown']);

    final g2 = await tester.startGesture(tester.getCenter(title));
    for (var i = 0; i < 20; i++) {
      await g2.moveBy(Offset(0, rect.height * 0.6 / 20));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(const Duration(milliseconds: 200));
    await g2.up();
    await tester.pump();
    expect(_host(tester).log, ['shown', 'cancel']);
    await tester.pumpAndSettle();
    expect(find.byKey(ConfirmSheet.sheetKey), findsNothing);
  });

  testWidgets('ConfirmSheetController.confirm = 확인 버튼과 같은 핸들러 · 숨김이면 false', (
    tester,
  ) async {
    _screenSize(tester);
    final controller = ConfirmSheetController();
    await tester.pumpWidget(_Host(controller: controller));
    expect(controller.isAttached, isTrue);
    expect(controller.confirm(), isFalse);
    await _open(tester);
    await tester.pumpAndSettle();
    expect(controller.confirm(), isTrue);
    await tester.pumpAndSettle();
    expect(_host(tester).log, ['shown', 'confirm']);
    expect(controller.confirm(), isFalse);
    await _open(tester);
    await tester.pumpAndSettle();
    expect(controller.cancel(), isTrue);
    await tester.pumpAndSettle();
    expect(_host(tester).log.last, 'cancel');
  });

  testWidgets('시트는 이동만 — 글래스에 불투명도 애니메이션 없음 (dim 만 페이드) · 매 프레임', (
    tester,
  ) async {
    _screenSize(tester);
    await tester.pumpWidget(const _Host());
    await _open(tester);
    var dimSeen = <double>{};
    for (var i = 0; i < 40; i++) {
      _expectGlassNeverFaded(tester);
      dimSeen.add(
        tester.widget<Opacity>(find.byKey(ConfirmSheet.dimKey)).opacity,
      );
      await tester.pump(_frame);
    }
    expect(dimSeen.length, greaterThan(2));
    await tester.tap(find.byKey(ConfirmSheet.cancelKey));
    await tester.pump();
    for (var i = 0; i < 30; i++) {
      _expectGlassNeverFaded(tester);
      await tester.pump(_frame);
    }
    await tester.pumpAndSettle();
  });

  testWidgets(
    '모션 감소: 시트는 즉시 제자리 (이동·페이드 없음) · dim 만 durationBase 페이드 · onShown 은 dim 뒤',
    (tester) async {
      _screenSize(tester);
      await tester.pumpWidget(const _Host(reduceMotion: true));
      await _open(tester);
      expect(
        tester.getRect(find.byKey(ConfirmSheet.sheetKey)).bottom,
        closeTo(852 - 8, 0.01),
      );
      _expectGlassNeverFaded(tester);
      await tester.pump(CameoMotion.durationBase ~/ 2);
      expect(
        tester.widget<Opacity>(find.byKey(ConfirmSheet.dimKey)).opacity,
        inExclusiveRange(0, 1),
      );
      expect(_host(tester).log, isEmpty);
      await tester.pumpAndSettle();
      expect(_host(tester).log, ['shown']);

      await tester.tap(find.byKey(ConfirmSheet.cancelKey));
      await tester.pump();
      await tester.pump();
      expect(
        tester.getRect(find.byKey(ConfirmSheet.sheetKey)).top,
        greaterThanOrEqualTo(852),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(ConfirmSheet.sheetKey), findsNothing);
    },
  );
}
