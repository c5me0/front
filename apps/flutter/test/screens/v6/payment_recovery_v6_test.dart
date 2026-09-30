import 'package:cameo/components/account_flow_scaffold.dart';
import 'package:cameo/components/confirm_sheet.dart';
import 'package:cameo/components/keypad.dart';
import 'package:cameo/components/solid_button.dart';
import 'package:cameo/content/app.g.dart';
import 'package:cameo/design_system/design_system.dart';
import 'package:cameo/navigation/navigation.dart';
import 'package:cameo/screens/home_timeline/home_timeline_screen.dart';
import 'package:cameo/screens/partner/partner_screen.dart';
import 'package:cameo/screens/payment/payment_screen.dart';
import 'package:cameo/screens/phone/phone_screen.dart';
import 'package:cameo/screens/settings/breakup_screen.dart';
import 'package:cameo/screens/settings/settings_screen.dart';
import 'package:cameo/screens/verify/verify_screen.dart';
import 'package:cameo/screens/welcome/welcome_screen.dart';
import 'package:cameo/state/session.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'onboarding_harness.dart';

Future<void> typeDigits(WidgetTester tester, String digits) async {
  for (final digit in digits.split('')) {
    await tester.tap(find.byKey(Keypad.keyKey(digit)));
    await tester.pump(kFrame);
  }
}

Future<void> waitFor(WidgetTester tester, Type type) async {
  for (var i = 0; i < 400 && find.byType(type).evaluate().isEmpty; i++) {
    await tester.pump(kFrame);
  }
  await settleApp(tester);
  expect(find.byType(type), findsOneWidget);
}

void main() {
  setUp(FlowDemo.resetForTesting);
  tearDown(FlowDemo.resetForTesting);

  for (final route in [CameoRoutes.payment, CameoRoutes.breakup]) {
    testWidgets(
      '$route remains usable on a small screen with larger text and reduced motion',
      (tester) async {
        await pumpCameoAppV6(tester, '$route?session=member');
        tester.view.physicalSize = const Size(320, 568);
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        await settleApp(tester);
        if (route == CameoRoutes.breakup) {
          for (var step = 0; step < 2; step++) {
            await tester.tap(find.byKey(BreakupScreen.nextKey));
            await settleApp(tester);
          }
          await tester.ensureVisible(find.byKey(BreakupScreen.acknowledgeKey));
          await tester.tap(find.byKey(BreakupScreen.acknowledgeKey));
          await tester.pump();
          expect(
            tester
                .widget<SolidButton>(find.byKey(BreakupScreen.nextKey))
                .disabled,
            isFalse,
          );
        } else {
          await tester.ensureVisible(find.byKey(PaymentScreen.planKey));
          await tester.tap(find.byKey(PaymentScreen.planKey));
          await tester.pump();
          expect(
            tester
                .widget<SolidButton>(find.byKey(PaymentScreen.continueKey))
                .disabled,
            isFalse,
          );
        }
        expect(tester.takeException(), isNull);
        await disposeApp(tester);
      },
    );
  }

  testWidgets(
    'settings → monthly USD only → cancel → test purchase → settings',
    (tester) async {
      final session = await pumpCameoAppV6(tester, '/settings?session=member');
      await scrollIntoCenter(tester, find.byKey(SettingsScreen.paymentKey));
      await tester.tap(find.byKey(SettingsScreen.paymentKey));
      await settleApp(tester);
      expect(find.byType(PaymentScreen), findsOneWidget);
      expect(find.text(r'$4.99'), findsOneWidget);
      expect(find.text('연간 구독'), findsNothing);
      expect(
        tester
            .widget<SolidButton>(find.byKey(PaymentScreen.continueKey))
            .disabled,
        isTrue,
      );
      await tester.tap(find.byKey(PaymentScreen.planKey));
      await tester.pump();
      await tester.tap(find.byKey(PaymentScreen.continueKey));
      await settleApp(tester);
      expect(find.textContaining(r'$4.99 USD / 월'), findsOneWidget);
      await tester.tap(find.byKey(ConfirmSheet.cancelKey));
      await settleApp(tester);
      expect(session.monthlyActive, isFalse);
      await tester.tap(find.byKey(PaymentScreen.continueKey));
      await settleApp(tester);
      await tester.tap(find.byKey(ConfirmSheet.confirmKey));
      await tester.pump(CameoMotion.authMockVerify);
      await settleApp(tester);
      expect(find.byKey(PaymentScreen.successKey), findsOneWidget);
      expect(session.monthlyActive, isTrue);
      await tester.tap(find.byKey(PaymentScreen.doneKey));
      await settleApp(tester);
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(appTabs(tester)!.selectedTab, CameoTabs.settings);
      await disposeApp(tester);
      await session.pendingWrites;
    },
  );

  for (var stage = 0; stage < 3; stage++) {
    testWidgets(
      'breakup cancellation at checkpoint ${stage + 1} preserves partner and album',
      (tester) async {
        final session = await pumpCameoAppV6(tester, '/breakup?session=member');
        final original = lastAlbum.snapshot().toJson();
        for (var step = 0; step < stage; step++) {
          await tester.tap(find.byKey(BreakupScreen.nextKey));
          await settleApp(tester);
        }
        expect(find.text('${stage + 1} / 3'), findsOneWidget);
        await tester.tap(find.byKey(BreakupScreen.cancelKey));
        await settleApp(tester);
        expect(find.byType(SettingsScreen), findsOneWidget);
        expect(session.session.partner, isNotNull);
        expect(lastAlbum.snapshot().toJson(), original);
        expect(session.recoveryFor(Partner.mock().id), isNull);
        await disposeApp(tester);
        await session.pendingWrites;
      },
    );
  }

  testWidgets(
    r'three checkpoints → logout → phone login → same partner → $29.90 → exact recovery',
    (tester) async {
      final session = await pumpCameoAppV6(tester, '/settings?session=member');
      final trackedPhoto = lastAlbum.sections.first.photos[1];
      lastAlbum.setLiked(trackedPhoto.id, true);
      final expected = lastAlbum.snapshot().toJson();
      await scrollIntoCenter(tester, find.byKey(SettingsScreen.disconnectKey));
      await tester.tap(find.byKey(SettingsScreen.disconnectKey));
      await settleApp(tester);
      for (var stage = 0; stage < 2; stage++) {
        expect(find.text('${stage + 1} / 3'), findsOneWidget);
        expect(session.session.partner, isNotNull);
        await tester.tap(find.byKey(BreakupScreen.nextKey));
        await settleApp(tester);
      }
      expect(find.text('3 / 3'), findsOneWidget);
      expect(
        tester.widget<SolidButton>(find.byKey(BreakupScreen.nextKey)).disabled,
        isTrue,
      );
      await tester.tap(find.byKey(BreakupScreen.acknowledgeKey));
      await tester.pump();
      await tester.tap(find.byKey(BreakupScreen.nextKey));
      await waitFor(tester, WelcomeScreen);
      expect(session.session, Session.guest);
      expect(lastAlbum.sections, isEmpty);
      await tester.tap(find.byKey(WelcomeScreen.ctaKey));
      await settleApp(tester);
      await typeDigits(tester, appContent.demo.phone);
      await tester.tap(find.byKey(PhoneScreen.ctaKey));
      await waitFor(tester, VerifyScreen);
      await typeDigits(tester, appContent.verify.mockCode);
      await waitFor(tester, HomeTimelineScreen);
      expect(session.session.status, SessionStatus.member);
      expect(session.session.partner, isNull);
      await tester.tap(find.byKey(TabBarV6.tabKey(CameoTabs.settings)));
      await settleApp(tester);
      await tester.tap(find.byKey(SettingsScreen.connectKey));
      await waitFor(tester, PartnerScreen);
      await typeDigits(tester, appContent.demo.partnerCode);
      await waitFor(tester, PaymentScreen);
      expect(find.text(r'$29.90'), findsOneWidget);
      expect(session.session.partner, isNull);
      expect(lastAlbum.sections, isEmpty);
      await tester.tap(find.byKey(PaymentScreen.planKey));
      await tester.pump();
      await tester.tap(find.byKey(PaymentScreen.continueKey));
      await settleApp(tester);
      await tester.tap(find.byKey(ConfirmSheet.cancelKey));
      await settleApp(tester);
      expect(session.session.partner, isNull);
      await tester.tap(find.byKey(PaymentScreen.continueKey));
      await settleApp(tester);
      await tester.tap(find.byKey(ConfirmSheet.confirmKey));
      await tester.pump(CameoMotion.authMockVerify);
      await settleApp(tester);
      expect(find.byKey(PaymentScreen.successKey), findsOneWidget);
      expect(session.session.partner, Partner.mock());
      expect(lastAlbum.snapshot().toJson(), expected);
      await tester.tap(find.byKey(PaymentScreen.doneKey));
      await waitFor(tester, HomeTimelineScreen);
      expect(lastAlbum.photoById(trackedPhoto.id)!.liked, isTrue);
      expect(appTabs(tester)!.selectedTab, CameoTabs.albums);
      await disposeApp(tester);
      await session.pendingWrites;
    },
  );

  testWidgets(
    'payment deep link has a settings back stack; guest cannot open it',
    (tester) async {
      await pumpCameoAppV6(tester, '/payment?session=member');
      expect(find.byType(PaymentScreen), findsOneWidget);
      await tester.tap(find.byKey(AccountFlowScaffold.backKey));
      await settleApp(tester);
      expect(find.byType(SettingsScreen), findsOneWidget);
      await disposeApp(tester);
      await pumpCameoAppV6(tester, '/payment?session=guest');
      expect(find.byType(PaymentScreen), findsNothing);
      expect(find.byType(WelcomeScreen), findsOneWidget);
      await disposeApp(tester);
    },
  );
}
