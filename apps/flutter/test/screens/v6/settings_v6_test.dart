// Regression coverage for settings v6. Preserve behavior, layout, and interaction
// expectations.

import 'package:cameo/components/confirm_sheet.dart';
import 'package:cameo/components/ios_switch.dart';
import 'package:cameo/components/settings_v6.dart';
import 'package:cameo/components/solid_button.dart';
import 'package:cameo/content/app.g.dart';
import 'package:cameo/content/lab.g.dart';
import 'package:cameo/design_system/design_system.dart';
import 'package:cameo/navigation/navigation.dart';
import 'package:cameo/screens/settings/settings_model.dart';
import 'package:cameo/screens/settings/settings_screen.dart';
import 'package:cameo/screens/settings/breakup_screen.dart';
import 'package:cameo/screens/welcome/welcome_screen.dart';
import 'package:cameo/state/session.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'onboarding_harness.dart';

Rect _block(WidgetTester tester, Key key) => tester.getRect(find.byKey(key));

void main() {
  setUp(FlowDemo.resetForTesting);
  tearDown(FlowDemo.resetForTesting);

  test(
    'settingsV6Blocks: Figma (개발 2 · 연결 해제 1) = 122 – 202 · 226 – 328 · 352 – 498 · 522 – 656 · 680 – 734',
    () {
      final figma = settingsV6Blocks(
        62,
        partner: true,
        devRows: 2,
        accountRows: 1,
      );
      expect(
        [for (final b in figma) (b.top, b.bottom)],
        [
          (122.0, 202.0),
          (226.0, 328.0),
          (352.0, 498.0),
          (522.0, 656.0),
          (680.0, 734.0),
        ],
      );
      final none = settingsV6Blocks(
        62,
        partner: false,
        devRows: 3,
        accountRows: 1,
      );
      expect(none[1].bottom, 226 + 26 + 54);
      expect(
        settingsPhoneLine('01012345678', '+82', '+82 10 3929 8983'),
        '+82 10 1234 5678',
      );
      expect(
        settingsPhoneLine(null, '+82', '+82 10 3929 8983'),
        '+82 10 3929 8983',
      );
      expect(settingsName('  ', '이주영'), '이주영');
      final logout = settingsSheetCopy(SettingsSheetKind.logout, null);
      expect(logout.title, appContent.v6.settings.logoutSheet.title);
      final disconnect = settingsSheetCopy(
        SettingsSheetKind.disconnect,
        ' Yurim ',
      );
      expect(disconnect.title, 'Yurim 님과 연결을 해제할까요?');
      expect(
        photoSheetVariantLabel(PhotoSheetVariant.multi),
        appContent.v6.settings.sheetMulti,
      );
      expect(
        nextPhotoSheetVariant(PhotoSheetVariant.instant),
        PhotoSheetVariant.multi,
      );
    },
  );

  testWidgets('배치 @402: v6 카드에 멤버십 섹션 추가 · 카드 색 · 탭바 톤 canvas', (tester) async {
    final session = await pumpCameoAppV6(tester, '/settings?session=member');
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(_block(tester, SettingsScreen.titleKey).top, closeTo(62, kTol));
    final expected = settingsV6Blocks(
      62,
      partner: true,
      devRows: 3,
      accountRows: 2,
      billing: true,
    );
    final keys = [
      SettingsScreen.profileKey,
      SettingsScreen.partnerKey,
      SettingsScreen.notificationsKey,
      SettingsScreen.billingKey,
      SettingsScreen.developerKey,
      SettingsScreen.accountKey,
    ];
    for (var i = 0; i < keys.length; i++) {
      final r = _block(tester, keys[i]);
      expect(r.left, 16, reason: expected[i].id);
      expect(r.width, 370, reason: expected[i].id);
      expect(r.top, closeTo(expected[i].top, kTol), reason: expected[i].id);
      expect(
        r.bottom,
        closeTo(expected[i].bottom, kTol),
        reason: expected[i].id,
      );
    }
    expect(expected[5].bottom, 946);

    expect(find.text(appContent.demo.name), findsOneWidget);
    expect(
      find.text(
        settingsPhoneLine(
          appContent.demo.phone,
          labV6.phone.prefix,
          labV6.settings.me.phone,
        ),
      ),
      findsOneWidget,
    );
    expect(find.text(labV6.settings.partner.status), findsOneWidget);
    final root = tester.widget<ColoredBox>(find.byKey(SettingsScreen.rootKey));
    expect(root.color, CameoColors.backgroundCanvasNeutralStrong);
    expect(
      tester.widget<TabBarV6>(find.byType(TabBarV6)).tone,
      TabBarV6Tone.canvas,
    );
    expect(tester.widget<TabBarV6>(find.byType(TabBarV6)).selected, 2);
    expect(session.session.status, SessionStatus.member);
    await disposeApp(tester);
  });

  testWidgets('알림 스위치 ↔ NotificationPrefs · 사진 시트 방식 A ↔ B (값 크로스페이드)', (
    tester,
  ) async {
    final session = await pumpCameoAppV6(tester, '/settings?session=member');
    Finder switchOf(SessionPref p) => find.descendant(
      of: find.byKey(SettingsScreen.prefKey(p)),
      matching: find.byType(IosSwitch),
    );
    expect(
      tester.widget<IosSwitch>(switchOf(SessionPref.callAlerts)).value,
      isTrue,
    );
    await tester.tap(switchOf(SessionPref.callAlerts));
    await tester.pump();
    expect(session.session.prefs.callAlerts, isFalse);
    expect(session.session.prefs.highlightAlerts, isTrue);
    await tester.tap(switchOf(SessionPref.highlightAlerts));
    await tester.pump();
    expect(session.session.prefs.highlightAlerts, isFalse);
    await settleApp(tester);
    await scrollIntoCenter(tester, find.byKey(SettingsScreen.sheetVariantKey));
    final before = session.session.prefs.photoSheetVariant;
    await tester.tap(find.byKey(SettingsScreen.sheetVariantKey));
    await tester.pump();
    expect(
      session.session.prefs.photoSheetVariant,
      nextPhotoSheetVariant(before),
    );
    await settleApp(tester);
    expect(
      find.text(
        photoSheetVariantLabel(session.session.prefs.photoSheetVariant),
      ),
      findsOneWidget,
    );
    await disposeApp(tester);
  });

  testWidgets('헤어지기 → 첫 확인 화면 · 취소하면 설정과 상대를 유지', (tester) async {
    final session = await pumpCameoAppV6(tester, '/settings?session=member');
    await scrollIntoCenter(tester, find.byKey(SettingsScreen.disconnectKey));
    await tester.tap(find.byKey(SettingsScreen.disconnectKey));
    await settleApp(tester);
    expect(find.byType(BreakupScreen), findsOneWidget);
    expect(find.text('1 / 3'), findsOneWidget);
    await tester.tap(find.byKey(BreakupScreen.cancelKey));
    await settleApp(tester);
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(appTabs(tester)!.selectedTab, 2);
    expect(session.session.partner, isNotNull);
    expect(find.byKey(SettingsScreen.partnerCardKey), findsOneWidget);
    await disposeApp(tester);
  });

  testWidgets('상대 없음 (partner=none): \'상대 연결하기\' 행 → /connect', (tester) async {
    await pumpCameoAppV6(tester, '/settings?session=member&partner=none');
    expect(find.byKey(SettingsScreen.disconnectKey), findsNothing);
    final row = tester.widget<SettingsRowV6>(
      find.byKey(SettingsScreen.connectKey),
    );
    expect(row.label, appContent.v6.settings.connectPartner);
    await tester.tap(find.byKey(SettingsScreen.connectKey));
    await settleApp(tester);
    expect(find.byType(SettingsScreen, skipOffstage: false), findsOneWidget);
    expect(
      find.text(labV6.partner.title),
      findsOneWidget,
      reason: '/connect = 연결 화면 (설정 모드 — 나중에 없음)',
    );
    await disposeApp(tester);
  });

  testWidgets(
    '흐름 데모 settings.logout: 시트가 다 올라오면 settle · 열린 동안 거부 · sheet.confirm → 시작',
    (tester) async {
      final session = await pumpCameoAppV6(tester, '/settings?session=member');
      final before = FlowDemo.settleCount(FlowDemoAction.settingsLogout);
      expect(FlowDemo.run(FlowDemoAction.sheetConfirm), isFalse);
      expect(FlowDemo.run(FlowDemoAction.settingsLogout), isTrue);
      expect(FlowDemo.run(FlowDemoAction.settingsLogout), isFalse);
      await tester.pump();
      expect(FlowDemo.run(FlowDemoAction.sheetConfirm), isFalse);
      await settleApp(tester);
      expect(FlowDemo.settleCount(FlowDemoAction.settingsLogout), before + 1);
      expect(
        find.text(appContent.v6.settings.logoutSheet.title),
        findsOneWidget,
      );
      for (final key in [ConfirmSheet.confirmKey, ConfirmSheet.cancelKey]) {
        final button = tester.widget<SolidButton>(find.byKey(key));
        expect(button.size, SolidButtonSize.md);
        expect(button.stretch, isTrue);
        expect(tester.getSize(find.byKey(key)).height, 46);
      }
      expect(FlowDemo.run(FlowDemoAction.sheetConfirm), isTrue);
      await tester.pump();
      expect(session.session.status, SessionStatus.signedOut);
      await settleApp(tester);
      expect(find.byType(WelcomeScreen), findsOneWidget);
      await disposeApp(tester);
    },
  );
}
