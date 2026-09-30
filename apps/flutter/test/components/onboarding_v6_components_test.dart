// Regression coverage for onboarding v6 components. Preserve behavior, layout, and
// interaction expectations.

import 'package:cameo/components/auth_scaffold.dart';
import 'package:cameo/components/avatar_v6.dart';
import 'package:cameo/components/code_box.dart';
import 'package:cameo/components/connect_done_v6.dart';
import 'package:cameo/components/ios_switch.dart';
import 'package:cameo/components/keypad.dart';
import 'package:cameo/components/my_code_card.dart';
import 'package:cameo/components/onboarding_v6_layout.dart';
import 'package:cameo/components/permission_card.dart';
import 'package:cameo/components/phone_number_field.dart';
import 'package:cameo/components/settings_v6.dart';
import 'package:cameo/components/solid_button.dart';
import 'package:cameo/components/solid_cta.dart';
import 'package:cameo/components/text_field_v6.dart';
import 'package:cameo/components/welcome_tiles.dart';
import 'package:cameo/content/lab.g.dart';
import 'package:cameo/design_system/design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../screens/v6/onboarding_harness.dart';

const double _tol = 0.01;

Widget _content(Widget child) => Padding(
  padding: const EdgeInsets.only(left: 16, top: 222),
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(width: 370, child: child),
  ),
);

Future<void> _pumpFor(WidgetTester tester, Duration d) async {
  var t = Duration.zero;
  while (t < d) {
    await tester.pump(kFrame);
    t += kFrame;
  }
}

void main() {
  group('onboarding_v6_layout (RN onboardingV6Layout.ts 와 같은 값)', () {
    test(
      '인증 틀 §A @402 · 인셋 62/34: 내비 62 · header 118 · 키패드 282 (top 592) · CTA 522 / 770',
      () {
        expect(authV6NavTop(62), 62);
        expect(authV6NavTop(40), 62);
        expect(authV6HeaderTop(62), 118);
        expect(keypadV6Height(34), 282);
        expect(874 - keypadV6Height(34), 592);
        expect(keypadV6CellWidth(402), closeTo(123.333333, 1e-6));
        expect(keypadV6CellWidth(393), closeTo(120.333333, 1e-6));
        final withKeypad = authV6FooterBottom(34, hasKeypad: true);
        expect(874 - withKeypad - 54, closeTo(522, _tol));
        final withoutKeypad = authV6FooterBottom(34, hasKeypad: false);
        expect(874 - withoutKeypad - 54, closeTo(770, _tol));

        expect(keyboardFooterLiftV6(336, 34), 302);
        expect(keyboardFooterLiftV6(0, 34), 0);
      },
    );

    test('키패드 F4: 빈칸 · 0 · ⌫ · 키 프레임', () {
      expect(keypadV6Rows.last, [null, '0', keypadDeleteKey]);
      expect(keypadV6Rows.expand((r) => r).whereType<String>().length, 11);
      final zero = keypadV6KeyFrame(3, 1, 402);
      expect(zero.x, closeTo(139.333333, 1e-6));
      expect(zero.y, 186);
      expect(zero.height, 62);
    });

    test('코드 상자 슬롯 @370: 49.67 · x 32 … 320.33 · 비움 지연 · 체크 지연', () {
      expect(codeBoxSlotWidth(370), closeTo(49.666667, 1e-6));
      expect(codeBoxSlotWidth(361), closeTo(48.166667, 1e-6));
      expect(16 + codeBoxSlotX(0, 370), 32);
      expect(16 + codeBoxSlotX(5, 370), closeTo(320.333333, 1e-6));
      const i70 = Duration(milliseconds: 70);
      expect(codeBoxClearDelay(5, 6, i70), Duration.zero);
      expect(codeBoxClearDelay(0, 6, i70), const Duration(milliseconds: 350));
      expect(codeBoxClearDelay(2, 3, i70), Duration.zero);
      expect(
        codeBoxCheckDelay(5, CameoMotion.codeBoxV6CheckStagger),
        const Duration(milliseconds: 300),
      );
    });

    test(
      '시작 타일 @402: 132 · 열 x −5 / 135 / 275 · top −40 / −6 / −28 · 한 바퀴 972 · 흐름',
      () {
        expect(welcomeTileWidth(402), 132);
        expect(
          [for (var c = 0; c < 3; c++) welcomeColumnLeft(c, 402)],
          [-5, 135, 275],
        );
        expect(
          [for (var c = 0; c < 3; c++) welcomeColumnTop(c)],
          [-40, -6, -28],
        );
        expect(welcomeTileHeights(0, 402), [99, 176, 176, 165, 132, 176]);
        expect(welcomeLoopLength(0, 402), 972);
        expect([for (var c = 0; c < 3; c++) welcomeDirection(c)], [1, -1, 1]);
        expect(welcomeColumnTranslate(0, 1, 972, 18), 0);
        expect(welcomeColumnTranslate(1000, 1, 972, 18), closeTo(-18, 1e-9));
        expect(welcomeColumnTranslate(1000, -1, 972, 18), closeTo(-954, 1e-9));

        final n = welcomeTileCount(0, 402, 874);
        var covered = 0.0;
        final hs = welcomeTileHeights(0, 402);
        for (var k = 0; k < n; k++) {
          covered += hs[k % hs.length] + 8;
        }
        expect(covered, greaterThanOrEqualTo(972 + 874 + 40));

        expect(welcomeTileWidth(393), 129);
        expect(welcomeTileHeights(0, 393).first, closeTo(99 * 129 / 132, 1e-9));
        expect(welcomeNavHeight(34), 104);
        final block = welcomeTextBlock(62, 34);
        expect((block.top, block.bottom), (62, 104));
      },
    );

    test('연결 완료 @402: 묶음 top 374 · 아바타 가운데 ∓37.5 (정지) · ∓157.5 (시작)', () {
      expect(connectDoneGroupTop(62, 874, 34), 374);
      expect(connectDoneAvatarX(-1, 1), -37.5);
      expect(connectDoneAvatarX(1, 1), 37.5);
      expect(connectDoneAvatarX(1, 0), 157.5);
      expect(201 + connectDoneAvatarX(-1, 1) - 50, 113.5);
      expect(201 + connectDoneAvatarX(1, 1) - 50, 188.5);
    });

    test('iOS 스위치 손잡이: 꺼짐 2 · 켜짐 24 · 누름 늘어남 (켜짐 = 오른쪽 가장자리 고정)', () {
      expect(iosSwitchKnobFrame(0, 0, 1.2), (left: 2.0, width: 38.0));
      expect(iosSwitchKnobFrame(1, 0, 1.2), (left: 24.0, width: 38.0));
      final pressedOn = iosSwitchKnobFrame(1, 1, 1.2);
      expect(pressedOn.width, closeTo(45.6, 1e-9));
      expect(pressedOn.left + pressedOn.width, closeTo(62, 1e-9));
      expect(iosSwitchKnobFrame(0, 1, 1.2).left, 2);
    });

    test('전화번호 표시 +82 (설정 카드)', () {
      const sample = '+82 10 3929 8983';
      expect(formatPhoneIntl('01012345678', '+82', sample), '+82 10 1234 5678');
      expect(formatPhoneIntl('010-3929-8983', '+82', sample), sample);
      expect(formatPhoneIntl('0101', '+82', sample), '+82 10 1');
      expect(formatPhoneIntl('', '+82', sample), '');
      expect(spokenDigits('735102'), '7 3 5 1 0 2');
      expect(formatPhone('01012345678'), '010-1234-5678');
      expect(isValidPhone('01012345678'), isTrue);
      expect(isValidPhone('02012345678'), isFalse);
    });
  });

  group('Keypad v6', () {
    testWidgets(
      '배치 @402: 칸 123.33 × 62 · 빈칸 · 0 · ⌫ · 높이 282 · 숫자 headingMd · ⌫ 30 subtle',
      (tester) async {
        setIPhone17Pro(tester);
        await tester.pumpWidget(
          v6Frame(
            const Stack(
              children: [
                Positioned(left: 0, right: 0, bottom: 0, child: Keypad()),
              ],
            ),
          ),
        );
        final one = tester.getRect(find.byKey(Keypad.keyKey('1')));
        expect(one.left, closeTo(16, _tol));
        expect(one.top, closeTo(592, _tol));
        expect(one.width, closeTo(123.333, 0.01));
        expect(one.height, 62);
        final zero = tester.getRect(find.byKey(Keypad.keyKey('0')));
        expect(zero.left, closeTo(139.333, 0.01));
        expect(zero.top, closeTo(592 + 3 * 62, _tol));
        final del = tester.getRect(find.byKey(Keypad.keyKey(keypadDeleteKey)));
        expect(del.left, closeTo(262.667, 0.01));

        var keys = 0;
        for (final row in keypadV6Rows) {
          for (final k in row) {
            if (k != null) {
              expect(find.byKey(Keypad.keyKey(k)), findsOneWidget);
              keys++;
            }
          }
        }
        expect(keys, 11);
        final digit = tester.widget<CameoText>(
          find.descendant(
            of: find.byKey(Keypad.labelKey('5')),
            matching: find.byType(CameoText),
          ),
        );
        expect(digit.style, CameoTextStyles.headingMd);
        final back = tester.widget<CameoIcon>(
          find.descendant(
            of: find.byKey(Keypad.labelKey(keypadDeleteKey)),
            matching: find.byType(CameoIcon),
          ),
        );
        expect(back.size, 30);
        expect(back.color, CameoColors.foregroundNeutralSubtle);
      },
    );

    testWidgets('누르는 순간 입력 (포인터 down) · 하이라이트 · 놓으면 돌아온다 · 비활성 무시 · dimmed', (
      tester,
    ) async {
      setIPhone17Pro(tester);
      final keys = <String>[];
      var deletes = 0;
      Widget pad({bool disabled = false, bool? dimmed}) => v6Frame(
        Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Keypad(
                onKey: keys.add,
                onDelete: () => deletes++,
                disabled: disabled,
                dimmed: dimmed,
              ),
            ),
          ],
        ),
      );
      await tester.pumpWidget(pad());
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(Keypad.keyKey('7'))),
      );
      await tester.pump();
      expect(keys, ['7'], reason: '놓기 전에 입력');
      await tester.pump(const Duration(milliseconds: 60));
      final highlight = tester.widget<Opacity>(
        find.byKey(Keypad.highlightKey('7')),
      );
      expect(highlight.opacity, greaterThan(0.5));
      await gesture.up();
      await _pumpFor(tester, const Duration(milliseconds: 800));
      expect(
        tester.widget<Opacity>(find.byKey(Keypad.highlightKey('7'))).opacity,
        closeTo(0, 0.02),
      );
      await tester.tap(find.byKey(Keypad.keyKey(keypadDeleteKey)));
      expect(deletes, 1);

      await tester.pumpWidget(pad(disabled: true));
      await tester.tap(find.byKey(Keypad.keyKey('3')));
      expect(keys, ['7']);
      CameoText label(String k) => tester.widget<CameoText>(
        find.descendant(
          of: find.byKey(Keypad.labelKey(k)),
          matching: find.byType(CameoText),
        ),
      );
      expect(label('3').color, CameoColors.foregroundNeutralSubtle);

      await tester.pumpWidget(pad(disabled: true, dimmed: false));
      expect(label('3').color, CameoColors.foregroundNeutralBase);
    });

    testWidgets(
      'KeypadController.pressKey: 같은 핸들러 + 누름 모션 → durationFast 뒤 놓음 · 모르는 키 false',
      (tester) async {
        final keys = <String>[];
        final controller = KeypadController();
        await tester.pumpWidget(
          v6Frame(Keypad(onKey: keys.add, controller: controller)),
        );
        expect(controller.isAttached, isTrue);
        expect(controller.pressKey('4'), isTrue);
        expect(keys, ['4']);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(
          tester.widget<Opacity>(find.byKey(Keypad.highlightKey('4'))).opacity,
          greaterThan(0.3),
        );
        expect(controller.pressKey('x'), isFalse);
        await _pumpFor(tester, const Duration(milliseconds: 900));
        expect(
          tester.widget<Opacity>(find.byKey(Keypad.highlightKey('4'))).opacity,
          closeTo(0, 0.02),
        );
        await tester.pumpWidget(const SizedBox());
        expect(controller.isAttached, isFalse);
      },
    );
  });

  group('CodeBox v6', () {
    testWidgets(
      '한 상자 (16, 222) 370 × 58 · 슬롯 49.67 (x 32 · 320.33) · placeholder "0" headingSm subtle · 테두리 2 검정',
      (tester) async {
        setIPhone17Pro(tester);
        await tester.pumpWidget(v6Frame(_content(const CodeBox(value: ''))));
        final box = tester.getRect(find.byKey(CodeBox.boxKey));
        expect(box, const Rect.fromLTWH(16, 222, 370, 58));
        final s0 = tester.getRect(find.byKey(CodeBox.slotKey(0)));
        final s5 = tester.getRect(find.byKey(CodeBox.slotKey(5)));
        expect(s0.left, closeTo(32, _tol));
        expect(s0.width, closeTo(49.667, 0.01));
        expect(s5.left, closeTo(320.333, 0.01));
        final placeholder = tester.widget<CameoText>(
          find.descendant(
            of: find.byKey(CodeBox.placeholderKey(0)),
            matching: find.byType(CameoText),
          ),
        );
        expect(placeholder.text, labV6.verify.codePlaceholder);
        expect(placeholder.style, CameoTextStyles.headingSm);
        expect(placeholder.color, CameoColors.foregroundNeutralSubtle);
        final border =
            tester
                    .widget<DecoratedBox>(
                      find.descendant(
                        of: find.byKey(CodeBox.borderKey),
                        matching: find.byType(DecoratedBox),
                      ),
                    )
                    .decoration
                as ShapeDecoration;
        final side = (border.shape as RoundedSuperellipseBorder).side;
        expect(side.width, 2);
        expect(side.color, CameoColors.staticBlackBase);
      },
    );

    testWidgets('입력: placeholder 사라짐 · 6자리에 onComplete 한 번 · 비우면 뒤에서부터 70 ms', (
      tester,
    ) async {
      final done = <String>[];
      Widget box(String v) =>
          v6Frame(_content(CodeBox(value: v, onComplete: done.add)));
      await tester.pumpWidget(box(''));
      await tester.pumpWidget(box('12'));
      await _pumpFor(tester, const Duration(milliseconds: 300));
      final state = tester.state<CodeBoxWidgetState>(find.byType(CodeBox));
      expect(state.placeholderOpacityOf(0), closeTo(0, 0.01));
      expect(state.placeholderOpacityOf(2), closeTo(1, 0.01));
      await tester.pumpWidget(box('123456'));
      await tester.pump();
      await tester.pump();
      expect(done, ['123456']);
      await tester.pumpWidget(box('123456'));
      await tester.pump();
      expect(done, ['123456']);

      await tester.pumpWidget(box(''));
      await tester.pump(const Duration(milliseconds: 200));
      expect(state.placeholderOpacityOf(5), greaterThan(0.5));
      expect(state.placeholderOpacityOf(0), 0);
      await _pumpFor(tester, const Duration(milliseconds: 700));
      expect(state.placeholderOpacityOf(0), closeTo(1, 0.01));
    });

    testWidgets(
      'success: 테두리 초록 · 체크 26 이 60 ms 스태거로 0 → 1.25 넘침 → 1 · 숫자 사라짐',
      (tester) async {
        Widget box(CodeBoxState s) =>
            v6Frame(_content(CodeBox(value: '482019', state: s)));
        await tester.pumpWidget(box(CodeBoxState.verifying));
        await tester.pump(const Duration(milliseconds: 300));
        final state = tester.state<CodeBoxWidgetState>(find.byType(CodeBox));
        expect(state.breatheScale, lessThan(1));
        await tester.pumpWidget(box(CodeBoxState.success));
        await tester.pump(const Duration(milliseconds: 30));
        expect(state.checkScaleOf(0), greaterThan(0));
        expect(state.checkScaleOf(5), 0, reason: '슬롯 5 = 300 ms 뒤');
        var peak = 0.0;
        for (var i = 0; i < 40; i++) {
          await tester.pump(kFrame);
          if (state.checkScaleOf(0) > peak) peak = state.checkScaleOf(0);
        }
        expect(peak, closeTo(CameoMotion.codeBoxV6CheckOvershootScale, 0.03));
        await _pumpFor(tester, const Duration(seconds: 1));
        for (var i = 0; i < 6; i++) {
          expect(state.checkScaleOf(i), closeTo(1, 0.01));
          expect(state.checkOpacityOf(i), closeTo(1, 0.01));
        }
        expect(state.successProgress, closeTo(1, 0.01));
        final icon = tester.widget<CameoIcon>(
          find.descendant(
            of: find.byKey(CodeBox.checkKey(0)),
            matching: find.byType(CameoIcon),
          ),
        );
        expect(icon.size, 26);
        expect(icon.color, CameoColors.systemGreen);
        expect(state.breatheScale, closeTo(1, 0.005));
      },
    );

    testWidgets('error: 흔들림 첫 극값 +10 · 테두리 빨강 (cameo)', (tester) async {
      Widget box(CodeBoxState s) =>
          v6Frame(_content(CodeBox(value: '111111', state: s)));
      await tester.pumpWidget(box(CodeBoxState.active));
      await tester.pumpWidget(box(CodeBoxState.error));
      final state = tester.state<CodeBoxWidgetState>(find.byType(CodeBox));
      var peak = 0.0;
      for (var i = 0; i < 30; i++) {
        await tester.pump(kFrame);
        if (state.shakeOffset > peak) peak = state.shakeOffset;
      }
      expect(peak, closeTo(CameoMotion.shakeDistance, 0.6));
      await _pumpFor(tester, const Duration(seconds: 1));
      expect(state.errorProgress, closeTo(1, 0.01));
      expect(state.shakeOffset.abs(), lessThan(0.1));
    });

    testWidgets('?state=success 로 처음부터: 초록 테두리 즉시 · 체크 팝은 한 번 재생', (
      tester,
    ) async {
      await tester.pumpWidget(
        v6Frame(
          _content(const CodeBox(value: '482019', state: CodeBoxState.success)),
        ),
      );
      final state = tester.state<CodeBoxWidgetState>(find.byType(CodeBox));
      expect(state.successProgress, 1);
      await _pumpFor(tester, const Duration(seconds: 1));
      expect(state.checkScaleOf(5), closeTo(1, 0.01));
    });
  });

  group('TextFieldV6 · PhoneNumberField', () {
    testWidgets(
      'phone 58 · r14 · 테두리 2 (포커스) · "+82" x 34 · placeholder · name 54 · 테두리 없음',
      (tester) async {
        setIPhone17Pro(tester);
        await tester.pumpWidget(
          v6Frame(_content(const PhoneNumberField(value: ''))),
        );
        final field = tester.getRect(find.byType(TextFieldV6));
        expect(field, const Rect.fromLTWH(16, 222, 370, 58));
        expect(
          tester.getTopLeft(find.byKey(PhoneNumberField.prefixKey)).dx,
          closeTo(34, _tol),
        );
        expect(find.byKey(PhoneNumberField.placeholderKey), findsOneWidget);
        expect(
          tester.getTopLeft(find.byKey(PhoneNumberField.placeholderKey)).dx,
          closeTo(
            tester.getTopRight(find.byKey(PhoneNumberField.prefixKey)).dx +
                8 +
                4,
            _tol,
          ),
          reason: '+82 · gap 8 · 슬롯 px 4',
        );
        expect(
          tester
              .widget<Opacity>(
                find.descendant(
                  of: find.byKey(TextFieldV6.borderKey),
                  matching: find.byType(Opacity),
                ),
              )
              .opacity,
          1,
        );
        await tester.pumpWidget(
          v6Frame(_content(const PhoneNumberField(value: '0101234'))),
        );
        await _pumpFor(tester, const Duration(milliseconds: 400));
        expect(find.byKey(PhoneNumberField.placeholderKey), findsNothing);
        expect(
          tester
              .widget<Semantics>(
                find
                    .ancestor(
                      of: find.byType(TextFieldV6),
                      matching: find.byType(Semantics),
                    )
                    .first,
              )
              .properties
              .value,
          '+82 010-1234',
        );
        await tester.pumpWidget(
          v6Frame(
            _content(
              const TextFieldV6(
                variant: TextFieldV6Variant.name,
                focused: true,
              ),
            ),
          ),
        );
        expect(tester.getSize(find.byType(TextFieldV6)), const Size(370, 54));
        expect(find.byKey(TextFieldV6.borderKey), findsNothing);
      },
    );
  });

  group('AuthScaffold v6 (§A)', () {
    Widget scaffold({bool keypad = true, bool accessory = false}) => v6Frame(
      AuthScaffold(
        title: labV6.phone.title,
        subtitle: labV6.phone.subtitle,
        onBack: () {},
        trailingLabel: '나중에',
        onTrailing: () {},
        footer: SolidButton(
          key: const ValueKey('cta'),
          label: labV6.phone.cta,
          stretch: true,
        ),
        keypad: keypad ? const Keypad() : null,
        accessory: accessory
            ? MyCodeCard(code: labV6.partner.myCode, onCopy: () {})
            : null,
        entrance: false,
        child: const PhoneNumberField(value: ''),
      ),
    );

    testWidgets(
      '내비 (16, 62) 46 · 나중에 오른쪽 386 · 제목 134 · 부제 176 · 본문 222 · CTA 522 – 576 · 키패드 592',
      (tester) async {
        setIPhone17Pro(tester);
        await tester.pumpWidget(scaffold());
        expect(
          tester.getRect(find.byKey(AuthScaffold.backKey)),
          const Rect.fromLTWH(16, 62, 46, 46),
        );
        final trailing = tester.getRect(find.byKey(AuthScaffold.trailingKey));
        expect(trailing.right, closeTo(386, _tol));
        expect(trailing.top, 62);
        expect(trailing.height, 46);
        expect(
          tester.getTopLeft(find.byKey(AuthScaffold.titleKey)).dy,
          closeTo(134, _tol),
        );
        expect(
          tester.getTopLeft(find.byKey(AuthScaffold.subtitleKey)).dy,
          closeTo(176, _tol),
        );
        final subtitle = tester.widget<CameoText>(
          find.descendant(
            of: find.byKey(AuthScaffold.subtitleKey),
            matching: find.byType(CameoText),
          ),
        );
        expect(subtitle.style, CameoTextStyles.bodyMd);
        expect(
          tester.getRect(find.byType(TextFieldV6)),
          const Rect.fromLTWH(16, 222, 370, 58),
        );
        expect(
          tester.getRect(find.byKey(const ValueKey('cta'))),
          const Rect.fromLTWH(16, 522, 370, 54),
        );
        expect(tester.getTopLeft(find.byType(Keypad)).dy, closeTo(592, _tol));

        final canvas = tester.widget<ColoredBox>(
          find
              .descendant(
                of: find.byType(AuthScaffold),
                matching: find.byType(ColoredBox),
              )
              .first,
        );
        expect(canvas.color, CameoColors.backgroundCanvasNeutralBase);
      },
    );

    testWidgets('키패드 없음: CTA 770 – 824 · 키패드 위 블록 (연결 내 코드) 504 – 580', (
      tester,
    ) async {
      setIPhone17Pro(tester);
      await tester.pumpWidget(scaffold(keypad: false));
      expect(
        tester.getRect(find.byKey(const ValueKey('cta'))),
        const Rect.fromLTWH(16, 770, 370, 54),
      );
      await tester.pumpWidget(scaffold(accessory: true));
      expect(
        tester.getRect(find.byKey(MyCodeCard.cardKey)),
        const Rect.fromLTWH(16, 504, 370, 76),
      );
    });

    testWidgets(
      '등장: 제목 0 → 부제 120 → 본문 240 → CTA 360 (페이드 + 상승) · 내비 · 키패드는 제자리',
      (tester) async {
        setIPhone17Pro(tester);
        await tester.pumpWidget(
          v6Frame(
            AuthScaffold(
              title: 't',
              subtitle: 's',
              onBack: () {},
              footer: SolidButton(label: 'c', stretch: true),
              keypad: const Keypad(),
              child: const SizedBox(height: 10),
            ),
          ),
        );
        await tester.pump();
        double p(Key key) => tester
            .state<AuthEntranceState>(
              find
                  .ancestor(
                    of: find.byKey(key),
                    matching: find.byType(AuthEntrance),
                  )
                  .first,
            )
            .progress;
        await _pumpFor(tester, const Duration(milliseconds: 96));
        expect(p(AuthScaffold.titleKey), greaterThan(0));
        expect(p(AuthScaffold.subtitleKey), 0);
        await _pumpFor(tester, const Duration(milliseconds: 96)); // 192
        expect(p(AuthScaffold.subtitleKey), greaterThan(0));
        expect(p(AuthScaffold.bodyKey), 0);
        await _pumpFor(tester, const Duration(milliseconds: 96)); // 288
        expect(p(AuthScaffold.bodyKey), greaterThan(0));
        expect(
          find.ancestor(
            of: find.byType(Keypad),
            matching: find.byType(AuthEntrance),
          ),
          findsNothing,
        );
        expect(
          find.ancestor(
            of: find.byKey(AuthScaffold.backKey),
            matching: find.byType(AuthEntrance),
          ),
          findsNothing,
        );
        await _pumpFor(tester, const Duration(seconds: 1));
        expect(p(AuthScaffold.bodyKey), closeTo(1, 0.01));
      },
    );
  });

  group('MyCodeCard · AvatarPair · ConnectDoneV6', () {
    testWidgets(
      '내 코드 카드 76 · r14 · 채움 fill/neutral/base · 코드 bodyLgStrong tnum · copy 22 · 누름 = onCopy',
      (tester) async {
        var copies = 0;
        await tester.pumpWidget(
          v6Frame(
            _content(
              SizedBox(
                width: 370,
                child: MyCodeCard(
                  code: labV6.partner.myCode,
                  onCopy: () => copies++,
                ),
              ),
            ),
          ),
        );
        expect(
          tester.getSize(find.byKey(MyCodeCard.cardKey)),
          const Size(370, 76),
        );
        final copy = tester.getRect(find.byKey(MyCodeCard.copyKey));
        expect(copy.size, const Size(22, 22));
        expect(copy.right, closeTo(16 + 370 - 18, _tol));
        final code = tester.widget<CameoText>(find.byKey(MyCodeCard.codeKey));
        expect(code.text, '735102');
        expect(code.style.fontFeatures, isNotEmpty);
        await tester.tap(find.byKey(MyCodeCard.cardKey));
        await tester.pump();
        expect(copies, 1);
      },
    );

    testWidgets('아바타 쌍 175 × 100 · 겹침 25 · 상대 사진이 위', (tester) async {
      await tester.pumpWidget(
        v6Frame(
          const Center(
            child: AvatarPair(
              myName: '이주영',
              partnerImage: LabImages.albumSungsuCover,
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(AvatarPair)), const Size(175, 100));
      final me = tester.getRect(find.byKey(AvatarPair.meKey));
      final partner = tester.getRect(find.byKey(AvatarPair.partnerKey));
      expect(partner.left - me.left, 75);
      expect(find.text('이'), findsOneWidget);
      expect(avatarInitialV6(' yurim '), 'Y');
      expect(avatarInitialV6(''), '');
    });

    testWidgets(
      '연결 완료: 캔버스 페이드 · 아바타 모임 (113.5 · 188.5 @ 374) · 겹칠 때 버스트 → 200 ms 뒤 문구 · 1600 ms 에 onDone',
      (tester) async {
        setIPhone17Pro(tester);
        var done = 0;
        await tester.pumpWidget(
          v6Frame(
            ConnectDoneV6(
              visible: true,
              myName: '이주영',
              partnerName: 'Yurim',
              onDone: () => done++,
            ),
          ),
        );
        final state = tester.state<ConnectDoneV6State>(
          find.byType(ConnectDoneV6),
        );
        expect(state.burstTrigger, 0);
        var metAt = -1;
        for (var f = 1; f <= 60; f++) {
          await tester.pump(kFrame);
          if (metAt < 0 && state.burstTrigger == 1) metAt = f;
        }
        expect(metAt, greaterThan(0), reason: '겹침 순간 버스트');
        expect(state.textProgress, greaterThan(0));

        await _pumpFor(tester, const Duration(milliseconds: 480));
        expect(
          tester.getRect(find.byKey(ConnectDoneV6.meKey)),
          const Rect.fromLTWH(113.5, 374, 100, 100),
        );
        expect(
          tester.getRect(find.byKey(ConnectDoneV6.partnerKey)).left,
          closeTo(188.5, _tol),
        );
        expect(
          tester.getTopLeft(find.byKey(ConnectDoneV6.messageKey)).dy,
          closeTo(498, 0.5),
        );
        final message = tester.widget<CameoText>(
          find.byKey(ConnectDoneV6.messageKey),
        );
        expect(message.text, '성공적으로 Yurim님과 연결됐어요!');
        expect(message.style, CameoTextStyles.headingMdStrong);
        expect(done, 0);
        await tester.pump(const Duration(milliseconds: 200));
        expect(done, 1);
        expect(state.canvasOpacity, 1);

        await tester.pumpWidget(
          v6Frame(
            const ConnectDoneV6(
              visible: false,
              myName: '이주영',
              partnerName: 'Yurim',
            ),
          ),
        );
        await _pumpFor(tester, const Duration(milliseconds: 300));
        expect(find.byKey(ConnectDoneV6.messageKey), findsNothing);
      },
    );
  });

  group('PermissionCard', () {
    Widget card(PermissionCardStatus s) => v6Frame(
      _content(
        SizedBox(
          width: 370,
          child: PermissionCard(
            icon: CameoIconName.microphone,
            title: '마이크',
            description: '통화를 녹음하고 기록으로 정리해요.',
            status: s,
          ),
        ),
      ),
    );

    testWidgets(
      'pending 370 × 76 · 링 20 · → granted: 초록 · 링 0 · 팝 1.02 · requesting 회전',
      (tester) async {
        await tester.pumpWidget(card(PermissionCardStatus.pending));
        expect(
          tester.getSize(find.byKey(PermissionCard.cardKey)),
          const Size(370, 76),
        );
        final ring = tester.getRect(find.byKey(PermissionCard.ringKey));
        expect(ring.size, const Size(20, 20));
        expect(ring.right, closeTo(16 + 370 - 18, _tol));
        await tester.pumpWidget(card(PermissionCardStatus.requesting));
        final state = tester.state<PermissionCardState>(
          find.byType(PermissionCard),
        );
        expect(state.spinning, isTrue);
        await tester.pumpWidget(card(PermissionCardStatus.granted));
        var peak = 1.0;
        for (var i = 0; i < 30; i++) {
          await tester.pump(kFrame);
          if (state.cardScale > peak) peak = state.cardScale;
        }
        expect(peak, closeTo(CameoMotion.permissionV6GrantPopScale, 0.004));
        await _pumpFor(tester, const Duration(seconds: 1));
        expect(state.grantProgress, closeTo(1, 0.01));
        expect(state.ringScale, closeTo(0, 0.01));
        final fill =
            tester
                    .widget<DecoratedBox>(
                      find.descendant(
                        of: find.byKey(PermissionCard.cardKey),
                        matching: find.byType(DecoratedBox),
                      ),
                    )
                    .decoration
                as ShapeDecoration;
        expect(fill.color, CameoColors.systemGreen);
      },
    );

    testWidgets('처음부터 granted = 모션 없이 초록 · denied = 설명 크로스페이드', (tester) async {
      await tester.pumpWidget(card(PermissionCardStatus.granted));
      final state = tester.state<PermissionCardState>(
        find.byType(PermissionCard),
      );
      expect(state.grantProgress, 1);
      expect(state.ringScale, 0);
      await tester.pumpWidget(card(PermissionCardStatus.pending));
      await tester.pumpWidget(card(PermissionCardStatus.denied));
      await _pumpFor(tester, const Duration(milliseconds: 400));
      expect(
        tester.widget<Opacity>(find.byKey(PermissionCard.deniedKey)).opacity,
        1,
      );
    });
  });

  group('IosSwitch · 설정 행 · SolidCta · WelcomeTiles', () {
    testWidgets(
      '스위치 64 × 28 · 켜짐 손잡이 24 · Accents/Green · 탭 → onValueChange(!value)',
      (tester) async {
        bool? next;
        await tester.pumpWidget(
          v6Frame(
            Center(
              child: IosSwitch(
                value: true,
                onValueChange: (v) => next = v,
                semanticLabel: '통화 알림',
              ),
            ),
          ),
        );
        final track = tester.getRect(find.byKey(IosSwitch.trackKey));
        expect(track.size, const Size(64, 28));
        final knob = tester.getRect(find.byKey(IosSwitch.knobKey));
        expect(knob.left - track.left, 24);
        expect(knob.size, const Size(38, 24));
        await tester.tap(find.byKey(IosSwitch.trackKey));
        await tester.pump();
        expect(next, isFalse);
      },
    );

    testWidgets('설정 행: 스위치 60 · chevron 54 · 행동 54 · 프로필 80 · 상대 76 + 연결됨 초록', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        v6Frame(
          Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 370,
              child: Column(
                children: [
                  SettingsRowV6(
                    key: const ValueKey('a'),
                    label: '통화 알림',
                    trailing: SettingsRowV6Trailing.toggle(
                      value: true,
                      onValueChange: (_) {},
                    ),
                  ),
                  SettingsRowV6(
                    key: const ValueKey('b'),
                    label: 'Lab',
                    trailing: const SettingsRowV6Trailing.chevron(),
                    onPress: () => taps++,
                  ),
                  const SettingsRowV6(
                    key: ValueKey('c'),
                    label: '연결 해제',
                    icon: CameoIconName.linkOff,
                    tone: SettingsRowV6Tone.destructive,
                  ),
                  const SettingsPersonRow(
                    key: ValueKey('d'),
                    kind: SettingsPersonKind.me,
                    name: '이주영',
                    phone: '+82 10 3929 8983',
                  ),
                  const SettingsPersonRow(
                    key: ValueKey('e'),
                    kind: SettingsPersonKind.partner,
                    name: '이유림',
                    phone: '+82 10 3929 8983',
                    status: '연결됨',
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      double h(String k) => tester.getSize(find.byKey(ValueKey(k))).height;
      expect([h('a'), h('b'), h('c'), h('d'), h('e')], [60, 54, 54, 80, 76]);
      expect(
        tester.getSize(find.byKey(SettingsRowV6.chevronKey)),
        const Size(22, 22),
      );
      final status = tester.widget<CameoText>(
        find.byKey(SettingsPersonRow.statusKey),
      );
      expect(status.color, CameoColors.systemGreen);
      final avatars = find.byKey(SettingsPersonRow.avatarKey);
      expect(tester.getSize(avatars.first), const Size(48, 48));
      expect(tester.getSize(avatars.last), const Size(44, 44));
      await tester.tap(find.byKey(const ValueKey('b')));
      expect(taps, 1);
    });

    testWidgets('SolidCta: 비활성 0.3 ↔ 활성 1 을 스프링으로 · 비활성 · busy = 누름 없음', (
      tester,
    ) async {
      var presses = 0;
      Widget cta({bool enabled = true, bool busy = false}) => v6Frame(
        _content(
          SizedBox(
            width: 370,
            child: SolidCta(
              label: '다음',
              enabled: enabled,
              busy: busy,
              onPress: () => presses++,
            ),
          ),
        ),
      );
      await tester.pumpWidget(cta(enabled: false));
      final state = tester.state<SolidCtaState>(find.byType(SolidCta));
      expect(state.opacity, 0.3);
      await tester.tap(find.byType(SolidCta));
      expect(presses, 0);
      await tester.pumpWidget(cta());
      await tester.pump(const Duration(milliseconds: 50));
      expect(state.opacity, inExclusiveRange(0.3, 1.0));
      await _pumpFor(tester, const Duration(seconds: 1));
      expect(state.opacity, closeTo(1, 0.01));
      await tester.tap(find.byType(SolidCta));
      expect(presses, 1);
      await tester.pumpWidget(cta(busy: true));
      await tester.tap(find.byType(SolidCta));
      expect(presses, 1);
    });

    testWidgets(
      '시작 타일: t = 0 Figma 배치 (열 0 첫 타일 (−5, −40) 132 × 99) · 흐름 18 dp/s · 가운데 열 반대',
      (tester) async {
        setIPhone17Pro(tester);
        await tester.pumpWidget(v6Frame(const WelcomeTiles()));
        expect(
          tester.getRect(find.byKey(WelcomeTiles.tileKey(0, 0))),
          const Rect.fromLTWH(-5, -40, 132, 99),
        );
        expect(
          tester.getRect(find.byKey(WelcomeTiles.tileKey(1, 0))),
          const Rect.fromLTWH(135, -6, 132, 165),
        );
        expect(
          tester.getRect(find.byKey(WelcomeTiles.tileKey(2, 1))).top,
          closeTo(-28 + 132 + 8, _tol),
        );
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        final state = tester.state<WelcomeTilesState>(
          find.byType(WelcomeTiles),
        );
        final dy = welcomeColumnTranslate(state.elapsedMs, 1, 972, 18);
        expect(dy, lessThan(-10));
        expect(
          tester.getRect(find.byKey(WelcomeTiles.tileKey(0, 0))).top,
          closeTo(-40 + dy, 0.01),
        );
        final col1 = tester.getRect(find.byKey(WelcomeTiles.tileKey(1, 0))).top;
        expect(col1, isNot(closeTo(-6, 0.01)), reason: '가운데 열도 흐른다');
        await tester.pumpWidget(const SizedBox());
      },
    );
  });
}
