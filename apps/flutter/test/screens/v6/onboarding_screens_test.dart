// Regression coverage for onboarding screens. Preserve behavior, layout, and
// interaction expectations.

import 'package:cameo/components/auth_scaffold.dart';
import 'package:cameo/components/code_box.dart';
import 'package:cameo/components/connect_done_v6.dart';
import 'package:cameo/components/keypad.dart';
import 'package:cameo/components/my_code_card.dart';
import 'package:cameo/components/permission_card.dart';
import 'package:cameo/components/phone_number_field.dart';
import 'package:cameo/components/sms_banner.dart';
import 'package:cameo/components/solid_cta.dart';
import 'package:cameo/components/text_field_v6.dart';
import 'package:cameo/components/toast.dart';
import 'package:cameo/content/app.g.dart';
import 'package:cameo/content/lab.g.dart';
import 'package:cameo/design_system/design_system.dart';
import 'package:cameo/navigation/navigation.dart';
import 'package:cameo/screens/partner/partner_screen.dart';
import 'package:cameo/screens/permissions/permissions_screen.dart';
import 'package:cameo/screens/phone/phone_screen.dart';
import 'package:cameo/screens/profile/profile_screen.dart';
import 'package:cameo/screens/verify/verify_screen.dart';
import 'package:cameo/screens/welcome/welcome_screen.dart';
import 'package:cameo/state/session.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'onboarding_harness.dart';

Future<void> _type(WidgetTester tester, String digits) async {
  for (final d in digits.split('')) {
    await tester.tap(find.byKey(Keypad.keyKey(d)));
    await tester.pump(kFrame);
  }
}

SolidCta _cta(WidgetTester tester, Key key) =>
    tester.widget<SolidCta>(find.byKey(key));

String _code(WidgetTester tester) =>
    tester.widget<CodeBox>(find.byType(CodeBox)).value;

CodeBoxState _box(WidgetTester tester) =>
    tester.widget<CodeBox>(find.byType(CodeBox)).state;

String _timer(WidgetTester tester) =>
    tester.widget<CameoText>(find.byKey(VerifyScreen.timerKey)).text;

double _opacityOf(WidgetTester tester, Finder child) => tester
    .widget<AnimatedOpacity>(
      find.ancestor(of: child, matching: find.byType(AnimatedOpacity)).first,
    )
    .opacity;

void main() {
  setUp(FlowDemo.resetForTesting);
  tearDown(FlowDemo.resetForTesting);

  group('시작 /welcome (2295:16882)', () {
    testWidgets(
      '캔버스 #e9e9ec · 텍스트 블록 62 – 770 가운데 (워드마크 368 · 태그라인 440) · nav 770 – 874 · CTA 786 – 840',
      (tester) async {
        await pumpCameoAppV6(tester, '/welcome?session=guest');
        expect(
          rectOf(tester, find.byKey(WelcomeScreen.textBlockKey)),
          const Rect.fromLTWH(0, 62, 402, 708),
        );
        expect(
          rectOf(tester, find.byKey(WelcomeScreen.wordmarkKey)).top,
          closeTo(368, kTol),
        );
        expect(
          rectOf(tester, find.byKey(WelcomeScreen.taglineKey)).top,
          closeTo(440, kTol),
        );
        expect(
          rectOf(tester, find.byKey(WelcomeScreen.navKey)),
          const Rect.fromLTWH(0, 770, 402, 104),
        );
        expect(
          rectOf(tester, find.byKey(WelcomeScreen.ctaKey)),
          const Rect.fromLTWH(16, 786, 370, 54),
        );
        final wordmark = tester.widget<CameoText>(
          find.byKey(WelcomeScreen.wordmarkKey),
        );
        expect(wordmark.text, labV6.welcome.wordmark);
        expect(wordmark.style, CameoTextStyles.wordmark);
        final canvas = tester.widget<ColoredBox>(
          find
              .descendant(
                of: find.byType(WelcomeScreen),
                matching: find.byType(ColoredBox),
              )
              .first,
        );
        expect(canvas.color, CameoColors.backgroundCanvasNeutralStrong);
        await disposeApp(tester);
      },
    );

    testWidgets('CTA → 전화번호 · welcome.start = 같은 길 (맨 위가 아니면 거부)', (
      tester,
    ) async {
      await pumpCameoAppV6(tester, '/welcome?session=guest');
      expect(FlowDemo.run(FlowDemoAction.welcomeStart), isTrue);
      await settleApp(tester);
      expect(find.byType(PhoneScreen), findsOneWidget);
      expect(FlowDemo.run(FlowDemoAction.welcomeStart), isFalse);
      CameoNav.pop(tester.element(find.byType(PhoneScreen)));
      await settleApp(tester);
      await tester.tap(find.byKey(WelcomeScreen.ctaKey));
      await settleApp(tester);
      expect(find.byType(PhoneScreen), findsOneWidget);
      await disposeApp(tester);
    });
  });

  group('전화번호 /phone (2256:4478 §A)', () {
    testWidgets(
      '배치: 뒤로 (16, 62) 46 · 제목 134 · 부제 176 · 필드 (16, 222) 370 × 58 · CTA 522 – 576 · 키패드 592',
      (tester) async {
        await pumpCameoAppV6(tester, '/phone?session=guest');
        expect(
          rectOf(tester, find.byKey(AuthScaffold.backKey)),
          const Rect.fromLTWH(16, 62, 46, 46),
        );
        expect(
          rectOf(tester, find.byKey(AuthScaffold.titleKey)).top,
          closeTo(134, kTol),
        );
        expect(
          rectOf(tester, find.byKey(AuthScaffold.subtitleKey)).top,
          closeTo(176, kTol),
        );
        expect(
          rectOf(tester, find.byType(TextFieldV6)),
          const Rect.fromLTWH(16, 222, 370, 58),
        );
        expect(
          rectOf(tester, find.byKey(PhoneScreen.ctaKey)),
          const Rect.fromLTWH(16, 522, 370, 54),
        );
        expect(
          rectOf(tester, find.byKey(AuthScaffold.keypadKey)),
          const Rect.fromLTWH(0, 592, 402, 282),
        );
        expect(find.byKey(AuthScaffold.trailingKey), findsNothing);
        expect(_cta(tester, PhoneScreen.ctaKey).enabled, isFalse);
        await disposeApp(tester);
      },
    );

    testWidgets(
      '입력: 최대 11 · 유효 → CTA 활성 (스프링) · 전송 = 키패드 비활성 → 900 ms → 인증 · 돌아오면 풀림',
      (tester) async {
        await pumpCameoAppV6(tester, '/phone?session=guest');
        await _type(tester, '010123456789');
        expect(
          tester.widget<PhoneNumberField>(find.byType(PhoneNumberField)).value,
          '01012345678',
        );
        expect(_cta(tester, PhoneScreen.ctaKey).enabled, isTrue);
        await settleApp(tester);
        await tester.tap(find.byKey(PhoneScreen.ctaKey));
        await tester.pump();
        expect(_cta(tester, PhoneScreen.ctaKey).busy, isTrue);
        expect(tester.widget<Keypad>(find.byType(Keypad)).disabled, isTrue);
        expect(FlowDemo.run(FlowDemoAction.phoneSubmit), isFalse);
        await tester.pump(CameoMotion.authMockSend);
        await tester.pump();
        await settleApp(tester);
        expect(
          tester.widget<VerifyScreen>(find.byType(VerifyScreen)).phone,
          '01012345678',
        );
        CameoNav.pop(tester.element(find.byType(VerifyScreen)));
        await tester.pump();
        await settleApp(tester);
        expect(_cta(tester, PhoneScreen.ctaKey).busy, isFalse);
        await disposeApp(tester);
      },
    );

    testWidgets(
      '흐름 데모 phone.type: 키패드 pressKey (keyIntervalMs) → 마지막 누름에 settle · phone.submit',
      (tester) async {
        await pumpCameoAppV6(tester, '/phone?session=guest');
        final before = FlowDemo.settleCount(FlowDemoAction.phoneType);
        final target = appContent.demo.phone;
        expect(FlowDemo.run(FlowDemoAction.phoneType), isTrue);
        expect(FlowDemo.run(FlowDemoAction.phoneType), isFalse);
        await tester.pump();
        for (var i = 1; i < target.length; i++) {
          await tester.pump(
            Duration(milliseconds: appContent.demo.keyIntervalMs),
          );
        }
        expect(FlowDemo.settleCount(FlowDemoAction.phoneType), before + 1);
        expect(
          tester.widget<PhoneNumberField>(find.byType(PhoneNumberField)).value,
          target,
        );
        await settleApp(tester);
        expect(FlowDemo.run(FlowDemoAction.phoneSubmit), isTrue);
        await tester.pump(CameoMotion.authMockSend);
        await settleApp(tester);
        expect(find.byType(VerifyScreen), findsOneWidget);
        await disposeApp(tester);
      },
    );
  });

  group('인증번호 /verify (2256:6336 · 6507)', () {
    const route = '/verify?session=guest&phone=01012345678';

    testWidgets(
      '부제 = 타이머 03:00 → 02:59 · 코드 상자 (16, 222) · 재전송 gray 522 · 배너 1200 ms 뒤',
      (tester) async {
        await pumpCameoAppV6(tester, route, settle: false);
        await tester.pump(kFrame);
        await tester.pump(kFrame);
        expect(_timer(tester), '03:00');
        expect(
          tester.widget<SmsBanner>(find.byType(SmsBanner)).visible,
          isFalse,
        );
        expect(FlowDemo.run(FlowDemoAction.verifyAutofill), isFalse);
        await pumpFrames(tester, const Duration(milliseconds: 1008));
        expect(_timer(tester), '02:59');
        expect(
          rectOf(tester, find.byType(CodeBox)),
          const Rect.fromLTWH(16, 222, 370, 58),
        );
        expect(
          rectOf(tester, find.byKey(VerifyScreen.resendKey)),
          const Rect.fromLTWH(16, 522, 370, 54),
        );
        await pumpFrames(tester, const Duration(milliseconds: 300));
        expect(
          tester.widget<SmsBanner>(find.byType(SmsBanner)).visible,
          isTrue,
        );
        await disposeApp(tester);
      },
    );

    testWidgets(
      '배너 = 자동 채움 (70 ms) → 호흡 → 성공 체크 · 타이머 멈춤 → 450 ms 뒤 이름 (세션 onboarding)',
      (tester) async {
        final session = await pumpCameoAppV6(tester, route);
        await tester.pump(const Duration(milliseconds: 1300));
        expect(FlowDemo.run(FlowDemoAction.verifyAutofill), isTrue);
        await tester.pump();
        expect(_code(tester), appContent.verify.mockCode.substring(0, 1));
        await tester.pump(CameoMotion.codeInputAutofillInterval * 5);
        await tester.pump();
        await tester.pump();
        expect(_code(tester), appContent.verify.mockCode);
        expect(_box(tester), CodeBoxState.verifying);
        expect(tester.widget<Keypad>(find.byType(Keypad)).disabled, isTrue);
        expect(tester.widget<Keypad>(find.byType(Keypad)).dimmed, isFalse);
        await tester.pump(CameoMotion.authMockVerify);
        await tester.pump();
        expect(_box(tester), CodeBoxState.success);
        final frozen = _timer(tester);
        expect(session.session.status, SessionStatus.signedOut);
        await tester.pump(CameoMotion.authSuccessHold);
        await tester.pump();
        expect(session.session.status, SessionStatus.onboarding);
        expect(_timer(tester), frozen);
        await settleApp(tester);
        expect(find.byType(ProfileScreen), findsOneWidget);
        await disposeApp(tester);
      },
    );

    testWidgets(
      '틀림: 흔들림 · 부제 타이머 → 오류 문구 크로스페이드 (system/red) → 600 ms 뒤 비움 · 다음 키에 오류 숨김 · 재전송 = 03:00',
      (tester) async {
        await pumpCameoAppV6(tester, route);
        await _type(tester, '000000');
        await tester.pump();
        await tester.pump(CameoMotion.authMockVerify);
        await tester.pump();
        expect(_box(tester), CodeBoxState.error);
        await tester.pump(CameoMotion.durationBase);
        expect(_opacityOf(tester, find.byKey(VerifyScreen.errorKey)), 1);
        expect(_opacityOf(tester, find.byKey(VerifyScreen.timerKey)), 0);
        final error = tester.widget<CameoText>(
          find.byKey(VerifyScreen.errorKey),
        );
        expect(error.text, appContent.v6.verify.error);
        expect(error.color, CameoColors.systemRed);
        await tester.pump(CameoMotion.shakeHold);
        await tester.pump();
        expect(_code(tester), '');
        expect(_box(tester), CodeBoxState.active);
        await _type(tester, '1');
        await tester.pump(CameoMotion.durationBase);
        expect(_opacityOf(tester, find.byKey(VerifyScreen.timerKey)), 1);
        await tester.pump(const Duration(seconds: 3));
        expect(_timer(tester), isNot('03:00'));
        await tester.tap(find.byKey(VerifyScreen.resendKey));
        await tester.pump();
        expect(_timer(tester), '03:00');
        await disposeApp(tester);
      },
    );

    testWidgets('?state=success: 체크 상자 · 타이머 03:00 고정 · 배너 없음 · 이동 없음', (
      tester,
    ) async {
      final session = await pumpCameoAppV6(
        tester,
        '/verify?session=guest&phone=01012345678&state=success',
      );
      expect(_box(tester), CodeBoxState.success);
      expect(_code(tester), appContent.verify.mockCode);
      await tester.pump(const Duration(seconds: 3));
      await settleApp(tester);
      expect(_timer(tester), '03:00');
      expect(find.byType(SmsBanner), findsNothing);
      expect(session.session.status, SessionStatus.signedOut);
      expect(find.byType(VerifyScreen), findsOneWidget);
      await disposeApp(tester);
    });
  });

  group('이름 /profile (2256:6631)', () {
    testWidgets(
      '필드 (16, 222) 370 × 54 · 테두리 없음 · CTA 770 → 키보드 332 위 16 (472 – 526) · 뒤로 = 로그아웃 → 시작',
      (tester) async {
        final session = await pumpCameoAppV6(
          tester,
          '/profile?session=onboarding',
        );
        expect(
          rectOf(tester, find.byKey(ProfileScreen.fieldKey)),
          const Rect.fromLTWH(16, 222, 370, 54),
        );
        expect(find.byKey(TextFieldV6.borderKey), findsNothing);
        expect(
          tester
              .widget<EditableText>(find.byKey(ProfileScreen.inputKey))
              .keyboardAppearance,
          Brightness.light,
        );
        expect(
          rectOf(tester, find.byKey(ProfileScreen.ctaKey)),
          const Rect.fromLTWH(16, 770, 370, 54),
        );
        tester.view.viewInsets = const FakeViewPadding(bottom: 332);
        await tester.pump();
        expect(
          rectOf(tester, find.byKey(ProfileScreen.ctaKey)),
          const Rect.fromLTWH(16, 472, 370, 54),
        );
        tester.view.resetViewInsets();
        await tester.pump();
        expect(find.byKey(AuthScaffold.backKey), findsOneWidget);
        await tester.tap(find.byKey(AuthScaffold.backKey));
        await tester.pump();
        expect(session.session.status, SessionStatus.signedOut);
        await settleApp(tester);
        expect(find.byType(WelcomeScreen), findsOneWidget);
        await disposeApp(tester);
      },
    );

    testWidgets(
      'profile.type (typeIntervalMs · settle) → CTA 활성 · profile.submit → 이름 저장 · 연결',
      (tester) async {
        final session = await pumpCameoAppV6(
          tester,
          '/profile?session=onboarding',
        );
        expect(_cta(tester, ProfileScreen.ctaKey).enabled, isFalse);
        expect(FlowDemo.run(FlowDemoAction.profileSubmit), isFalse);
        final before = FlowDemo.settleCount(FlowDemoAction.profileType);
        expect(FlowDemo.run(FlowDemoAction.profileType), isTrue);
        final chars = appContent.demo.name.characters.length;
        for (var i = 1; i < chars; i++) {
          await tester.pump(
            Duration(milliseconds: appContent.demo.typeIntervalMs),
          );
        }
        await tester.pump();
        expect(FlowDemo.settleCount(FlowDemoAction.profileType), before + 1);
        expect(_cta(tester, ProfileScreen.ctaKey).enabled, isTrue);
        expect(FlowDemo.run(FlowDemoAction.profileSubmit), isTrue);
        await settleApp(tester);
        expect(session.session.name, appContent.demo.name);
        expect(find.byType(PartnerScreen), findsOneWidget);
        await disposeApp(tester);
      },
    );
  });

  group('연결 /partner (2256:7842 · 8075)', () {
    const route = '/partner?session=onboarding';

    testWidgets(
      '배치: 코드 상자 222 · 내 코드 (16, 504) 370 × 76 · 키패드 592 · CTA 없음 · 나중에 (F5) → 권한',
      (tester) async {
        final session = await pumpCameoAppV6(tester, route);
        expect(
          rectOf(tester, find.byType(CodeBox)),
          const Rect.fromLTWH(16, 222, 370, 58),
        );
        expect(
          rectOf(tester, find.byKey(MyCodeCard.cardKey)),
          const Rect.fromLTWH(16, 504, 370, 76),
        );
        expect(find.byType(SolidCta), findsNothing);
        final trailing = rectOf(tester, find.byKey(AuthScaffold.trailingKey));
        expect(trailing.right, closeTo(386, kTol));
        await tester.tap(find.byKey(AuthScaffold.trailingKey));
        await settleApp(tester);
        expect(session.session.partnerSkipped, isTrue);
        expect(find.byType(PermissionsScreen), findsOneWidget);
        await disposeApp(tester);
      },
    );

    testWidgets('복사: 클립보드 735102 + ToastV6 elevated \'코드를 복사했어요\' (카드 블록 위)', (
      tester,
    ) async {
      final copied = mockPlatformChannel(tester);
      await pumpCameoAppV6(tester, route);
      await tester.tap(find.byKey(MyCodeCard.cardKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(copied, [labV6.partner.myCode]);
      expect(find.text(appContent.v6.partner.copied), findsOneWidget);
      final toast = rectOf(tester, find.byKey(PartnerScreen.toastKey));
      expect(toast.bottom, closeTo(874 - 282 - 100, kTol));
      await disposeApp(tester);
    });

    testWidgets(
      'partner.type → 호흡 → 성공 체크 (450) → 연결 완료 → 1600 ms 뒤 권한 · 돌아오면 입력으로 초기화',
      (tester) async {
        final session = await pumpCameoAppV6(tester, route);
        expect(FlowDemo.run(FlowDemoAction.partnerType), isTrue);
        await tester.pump();
        for (var i = 1; i < 6; i++) {
          await tester.pump(
            Duration(milliseconds: appContent.demo.keyIntervalMs),
          );
        }
        await tester.pump();
        await tester.pump();
        expect(_box(tester), CodeBoxState.verifying);
        await tester.pump(CameoMotion.authMockConnect);
        await tester.pump();
        expect(_box(tester), CodeBoxState.success);
        expect(session.session.partner, isNotNull);
        expect(
          tester.widget<ConnectDoneV6>(find.byType(ConnectDoneV6)).visible,
          isFalse,
        );
        await tester.pump(CameoMotion.authSuccessHold);
        await tester.pump();
        expect(
          tester.widget<ConnectDoneV6>(find.byType(ConnectDoneV6)).visible,
          isTrue,
        );
        await tester.pump(CameoMotion.celebrationHold);
        await settleApp(tester);
        expect(find.byType(PermissionsScreen), findsOneWidget);
        CameoNav.pop(tester.element(find.byType(PermissionsScreen)));
        await tester.pump();
        await settleApp(tester);
        expect(_box(tester), CodeBoxState.active);
        expect(_code(tester), '');
        expect(
          tester.widget<ConnectDoneV6>(find.byType(ConnectDoneV6)).visible,
          isFalse,
        );
        await disposeApp(tester);
      },
    );

    testWidgets('?state=done: 연결 완료 전체 화면 · 자동 이동 없음 · 문구 = 상대 이름', (
      tester,
    ) async {
      await pumpCameoAppV6(tester, '/partner?session=onboarding&state=done');
      await tester.pump(const Duration(seconds: 3));
      await settleApp(tester);
      expect(
        tester.widget<ConnectDoneV6>(find.byType(ConnectDoneV6)).visible,
        isTrue,
      );
      expect(find.byType(PermissionsScreen), findsNothing);
      expect(
        rectOf(tester, find.byKey(ConnectDoneV6.meKey)),
        const Rect.fromLTWH(113.5, 374, 100, 100),
      );
      await disposeApp(tester);
    });
  });

  group('권한 /permissions (2256:8243)', () {
    testWidgets(
      '카드 (16, 222 · 306 · 390) 370 × 76 · CTA 770 – 824 · 일괄 허용 → 하나씩 초록 → 시작하기 → 700 ms 뒤 앱',
      (tester) async {
        final perms = FakeSystemPermissions();
        final session = await pumpCameoAppV6(
          tester,
          '/permissions?session=onboarding',
          permissions: perms,
        );
        final kinds = PermissionKind.values;
        for (var i = 0; i < kinds.length; i++) {
          expect(
            rectOf(tester, find.byKey(PermissionsScreen.cardKey(kinds[i]))),
            Rect.fromLTWH(16, 222 + i * 84.0, 370, 76),
          );
        }
        expect(
          rectOf(tester, find.byKey(PermissionsScreen.ctaKey)),
          const Rect.fromLTWH(16, 770, 370, 54),
        );
        PermissionCardStatus status(PermissionKind k) => tester
            .widget<PermissionCard>(find.byKey(PermissionsScreen.cardKey(k)))
            .status;
        expect(FlowDemo.run(FlowDemoAction.permissionsAllow), isTrue);
        await tester.pump();
        expect(status(PermissionKind.microphone), PermissionCardStatus.granted);
        expect(status(PermissionKind.camera), PermissionCardStatus.pending);
        await tester.pump(CameoMotion.permissionGap);
        await tester.pump();
        expect(status(PermissionKind.camera), PermissionCardStatus.granted);
        await tester.pump(CameoMotion.permissionGap);
        await tester.pump();
        expect(
          status(PermissionKind.notifications),
          PermissionCardStatus.granted,
        );
        expect(perms.requests, kinds);
        expect(
          _cta(tester, PermissionsScreen.ctaKey).label,
          appContent.v6.permissions.ctaDone,
        );
        expect(session.session.status, SessionStatus.onboarding);
        await tester.pump(CameoMotion.authEnterAppDelay);
        await tester.pump();
        expect(session.session.status, SessionStatus.member);
        await settleApp(tester);
        await disposeApp(tester);
      },
    );

    testWidgets('나중에 → 요청 없이 앱 · 이미 결정된 권한은 첫 프레임부터 결과', (tester) async {
      final perms = FakeSystemPermissions();
      final session = await pumpCameoAppV6(
        tester,
        '/permissions?session=onboarding',
        permissions: perms,
      );
      session.setPermission(PermissionKind.camera, PermissionState.denied);
      await tester.pump();
      expect(
        tester
            .widget<PermissionCard>(
              find.byKey(PermissionsScreen.cardKey(PermissionKind.camera)),
            )
            .status,
        PermissionCardStatus.denied,
      );
      await tester.tap(find.byKey(AuthScaffold.trailingKey));
      await tester.pump();
      expect(perms.requests, isEmpty);
      expect(session.session.status, SessionStatus.member);
      await settleApp(tester);
      await disposeApp(tester);
    });

    test('요청 계획: 미결정만 · 첫 요청 뒤부터 gap 250', () {
      final plan = permissionRequestPlan(
        PermissionKind.values,
        (k) => k == PermissionKind.microphone
            ? PermissionState.granted
            : PermissionState.undetermined,
      );
      expect(plan.map((p) => p.kind), [
        PermissionKind.camera,
        PermissionKind.notifications,
      ]);
      expect(plan.map((p) => p.delay), [
        Duration.zero,
        CameoMotion.permissionGap,
      ]);
      expect(
        permissionCardStatusOf(
          PermissionKind.camera,
          PermissionState.undetermined,
          PermissionKind.camera,
        ),
        PermissionCardStatus.requesting,
      );
    });
  });

  test('전화번호 입력 규칙 · 타이머 형식', () {
    expect(appendDigit('0101234567', '8'), '01012345678');
    expect(appendDigit('01012345678', '9'), '01012345678');
    expect(deleteDigit('010'), '01');
    expect(deleteDigit(''), '');
    expect(formatVerifyTimer(180), '03:00');
    expect(formatVerifyTimer(178), '02:58');
    expect(formatVerifyTimer(-3), '00:00');
    expect(ToastVariant.values, isNotEmpty);
  });
}
