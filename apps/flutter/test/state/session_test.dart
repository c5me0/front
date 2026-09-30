// Regression coverage for session. Preserve behavior, layout, and interaction
// expectations.

import 'dart:convert';

import 'package:cameo/content/app.g.dart';
import 'package:cameo/design_system/design_system.dart';
import 'package:cameo/state/session.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Map<String, Object?>> _stored() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(kSessionStorageKey);
  return raw == null ? {} : (jsonDecode(raw) as Map).cast<String, Object?>();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('모델 · JSON', () {
    test('guest 기본값 = signedOut · 모두 비움 · 권한 undetermined · 알림 켬', () {
      const s = Session.guest;
      expect(s.status, SessionStatus.signedOut);
      expect(s.phone, isNull);
      expect(s.name, isNull);
      expect(s.partner, isNull);
      expect(s.partnerSkipped, isFalse);
      for (final kind in PermissionKind.values) {
        expect(s.permissionOf(kind), PermissionState.undetermined);
      }
      expect(s.prefs, const SessionPrefs());
      expect(s.prefs.callAlerts && s.prefs.highlightAlerts, isTrue);
    });

    test('copyWith: 안 준 값은 그대로 · null 은 지운다 · 불변', () {
      final s = Session.guest.copyWith(
        status: SessionStatus.member,
        phone: '01012345678',
        name: '주영',
        partner: Partner.mock(),
      );
      expect(s.copyWith().name, '주영');
      expect(s.copyWith(name: null).name, isNull);
      expect(s.copyWith(partner: null).partner, isNull);
      expect(s.copyWith(partner: null).phone, '01012345678');
      final permissions = s
          .copyWith(
            permissions: {PermissionKind.camera: PermissionState.granted},
          )
          .permissions;
      expect(
        () => permissions[PermissionKind.camera] = PermissionState.denied,
        throwsUnsupportedError,
      );
    });

    test('JSON 왕복 · 깨진 값은 기본값 (RN 과 같은 키)', () {
      final s = devSessionOf(
        DevSessionKind.member,
      ).copyWith(prefs: const SessionPrefs(callAlerts: false));
      final json = s.toJson();
      expect(json.keys.toSet(), {
        'status',
        'phone',
        'name',
        'partner',
        'partnerSkipped',
        'permissions',
        'prefs',
      });
      expect(json['status'], 'member');
      expect(json['permissions'], {
        'microphone': 'granted',
        'camera': 'granted',
        'notifications': 'granted',
      });
      expect(Session.fromJson(jsonDecode(jsonEncode(json))), s);
      expect(Session.fromJson('nope'), Session.guest);
      expect(Session.fromJson(null), Session.guest);
      final broken = Session.fromJson({
        'status': 'admin',
        'phone': 7,
        'partner': {'name': 'x'},
        'permissions': {'camera': 'maybe'},
        'prefs': {'callAlerts': 'yes'},
      });
      expect(broken.status, SessionStatus.signedOut);
      expect(broken.phone, isNull);
      expect(broken.partner, isNull);
      expect(
        broken.permissionOf(PermissionKind.camera),
        PermissionState.undetermined,
      );
      expect(broken.prefs.callAlerts, isTrue);
    });

    test(
      '온보딩 재개 단계 (RN onboardingStep): 이름 없음 → profile · 상대 없음 && 안 건너뜀 → partner · 그 밖 → permissions',
      () {
        const onboarding = Session(status: SessionStatus.onboarding);
        expect(onboardingStepOf(onboarding), OnboardingStep.profile);
        expect(
          onboardingStepOf(onboarding.copyWith(name: '  ')),
          OnboardingStep.profile,
        );
        final named = onboarding.copyWith(name: '주영');
        expect(onboardingStepOf(named), OnboardingStep.partner);
        expect(
          onboardingStepOf(named.copyWith(partnerSkipped: true)),
          OnboardingStep.permissions,
        );
        expect(
          onboardingStepOf(named.copyWith(partner: Partner.mock())),
          OnboardingStep.permissions,
        );
      },
    );

    test(
      '개발 세션: member = 데모 프로필 (이름 · 전화 · 상대 · 권한 전부 허용) · partner=none · onboarding = 인증만',
      () {
        final member = devSessionOf(DevSessionKind.member);
        expect(member.status, SessionStatus.member);
        expect(member.name, appContent.demo.name);
        expect(member.phone, appContent.demo.phone);
        expect(member.partner, Partner.mock());
        expect(member.partner!.name, appContent.partner.partner.name);
        expect(member.partner!.avatar, appContent.partner.partner.avatar);
        for (final kind in PermissionKind.values) {
          expect(member.permissionOf(kind), PermissionState.granted);
        }
        final none = devSessionOf(DevSessionKind.member, partnerNone: true);
        expect(none.partner, isNull);
        expect(none.status, SessionStatus.member);
        final onboarding = devSessionOf(DevSessionKind.onboarding);
        expect(onboarding.status, SessionStatus.onboarding);
        expect(onboarding.phone, appContent.demo.phone);
        expect(onboarding.name, isNull);
        expect(onboardingStepOf(onboarding), OnboardingStep.profile);
        expect(devSessionOf(DevSessionKind.guest), Session.guest);
        expect(DevSessionKind.tryParse('member'), DevSessionKind.member);
        expect(DevSessionKind.tryParse('admin'), isNull);
      },
    );
  });

  group('저장 (shared_preferences 목 · 키 cameo.session.v1)', () {
    test('처음 = guest · 바뀔 때마다 JSON 저장 · 다시 열면(새 컨트롤러) 그 상태', () async {
      final c = SessionController();
      expect(c.isLoaded, isFalse);
      await c.load();
      expect(c.isLoaded, isTrue);
      expect(c.session, Session.guest);
      c.completeVerification('01012345678');
      c.setName('  주영 ');
      c.skipPartner();
      c.setPermission(PermissionKind.microphone, PermissionState.denied);
      c.setPref(SessionPref.highlightAlerts, false);
      await c.pendingWrites;
      final stored = await _stored();
      expect(stored['status'], 'onboarding');
      expect(stored['name'], '주영');
      expect(stored['partnerSkipped'], true);

      final relaunch = SessionController();
      await relaunch.load();
      expect(relaunch.session, c.session);
      expect(
        relaunch.session.permissionOf(PermissionKind.microphone),
        PermissionState.denied,
      );
      expect(relaunch.session.prefs.highlightAlerts, isFalse);
      c.dispose();
      relaunch.dispose();
    });

    test('개발 세션 덮어쓰기: 저장값보다 우선 · 첫 알림 전에 적용 · 저장도 한다', () async {
      SharedPreferences.setMockInitialValues({
        kSessionStorageKey: jsonEncode(
          devSessionOf(DevSessionKind.member).toJson(),
        ),
      });
      final c = SessionController();
      final seen = <SessionStatus>[];
      c.addListener(() => seen.add(c.session.status));
      await c.load(dev: DevSessionKind.guest);
      expect(c.session, Session.guest);
      expect(seen, [SessionStatus.signedOut]);
      await c.pendingWrites;
      expect((await _stored())['status'], 'signedOut');

      final d = SessionController();
      await d.load(dev: DevSessionKind.member, partnerNone: true);
      expect(d.session.partner, isNull);
      expect(d.session.status, SessionStatus.member);
      await d.pendingWrites;
      expect((await _stored())['partner'], isNull);
      c.dispose();
      d.dispose();
    });

    test('깨진 저장값 → guest (앱이 뜬다)', () async {
      SharedPreferences.setMockInitialValues({kSessionStorageKey: '{nope'});
      final c = SessionController();
      await c.load();
      expect(c.session, Session.guest);
      c.dispose();
    });

    test('signOut → 모두 비움 (알림 설정 포함)', () async {
      final c = SessionController(initial: devSessionOf(DevSessionKind.member));
      c.setPref(SessionPref.callAlerts, false);
      c.signOut();
      expect(c.session, Session.guest);
      await c.pendingWrites;
      expect((await _stored())['status'], 'signedOut');
      c.dispose();
    });
  });

  group('목업 동작 (motion.auth 지연)', () {
    testWidgets(
      'requestCode = mockSendMs · verifyCode = mockVerifyMs 뒤 content mockCode 와 비교',
      (tester) async {
        final c = SessionController(initial: Session.guest);
        var sent = false;
        c.requestCode('01012345678').then((_) => sent = true);
        await tester.pump(
          CameoMotion.authMockSend - const Duration(milliseconds: 1),
        );
        expect(sent, isFalse);
        await tester.pump(const Duration(milliseconds: 1));
        expect(sent, isTrue);

        bool? ok;
        c.verifyCode(appContent.verify.mockCode).then((v) => ok = v);
        await tester.pump(
          CameoMotion.authMockVerify - const Duration(milliseconds: 1),
        );
        expect(ok, isNull);
        await tester.pump(const Duration(milliseconds: 1));
        expect(ok, isTrue);
        c.verifyCode('000000').then((v) => ok = v);
        await tester.pump(CameoMotion.authMockVerify);
        expect(ok, isFalse);

        c.completeVerification('01012345678');
        expect(c.session.status, SessionStatus.onboarding);
        expect(c.session.phone, '01012345678');
        c.completeOnboarding();
        expect(c.session.status, SessionStatus.member);
        await tester.runAsync(() => c.pendingWrites);
        c.dispose();
      },
    );

    testWidgets(
      'connectPartner = mockConnectMs 뒤 어떤 코드든 content 상대 · 기다리는 동안 로그아웃하면 붙이지 않는다',
      (tester) async {
        final c = SessionController(
          initial: devSessionOf(DevSessionKind.onboarding),
        );
        Partner? partner;
        c.connectPartner('240820').then((p) => partner = p);
        await tester.pump(
          CameoMotion.authMockConnect - const Duration(milliseconds: 1),
        );
        expect(c.session.partner, isNull);
        await tester.pump(const Duration(milliseconds: 1));
        expect(partner, Partner.mock());
        expect(c.session.partner, Partner.mock());
        expect(c.session.partnerSkipped, isFalse);

        c.applyDevSession(DevSessionKind.onboarding);
        c.connectPartner('111111');
        c.signOut();
        await tester.pump(CameoMotion.authMockConnect);
        expect(c.session.partner, isNull);
        expect(c.session.status, SessionStatus.signedOut);
        await tester.runAsync(() => c.pendingWrites);
        c.dispose();
      },
    );
  });

  group('SessionScope', () {
    testWidgets('of = 구독 (바뀌면 다시 그림) · read = 구독 안 함', (tester) async {
      final c = SessionController(initial: Session.guest);
      var ofBuilds = 0;
      var readBuilds = 0;
      await tester.pumpWidget(
        SessionScope(
          controller: c,
          child: Column(
            children: [
              Builder(
                builder: (context) {
                  ofBuilds++;
                  SessionScope.of(context);
                  return const SizedBox();
                },
              ),
              Builder(
                builder: (context) {
                  readBuilds++;
                  expect(SessionScope.read(context), same(c));
                  return const SizedBox();
                },
              ),
            ],
          ),
        ),
      );
      expect((ofBuilds, readBuilds), (1, 1));
      c.setName('주영');
      await tester.pump();
      expect((ofBuilds, readBuilds), (2, 1));
      await tester.runAsync(() => c.pendingWrites);
      c.dispose();
    });
  });
}
