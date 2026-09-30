import 'package:cameo/api/api_config.dart';
import 'package:cameo/api/api_models.dart';
import 'package:cameo/api/cameo_api.dart';
import 'package:cameo/api/credential_store.dart';
import 'package:cameo/components/auth_scaffold.dart';
import 'package:cameo/components/confirm_sheet.dart';
import 'package:cameo/components/keypad.dart';
import 'package:cameo/components/ios_switch.dart';
import 'package:cameo/components/tab_bar_v6.dart';
import 'package:cameo/main.dart' as app;
import 'package:cameo/screens/partner/partner_screen.dart';
import 'package:cameo/screens/permissions/permissions_screen.dart';
import 'package:cameo/screens/phone/phone_screen.dart';
import 'package:cameo/screens/profile/profile_screen.dart';
import 'package:cameo/screens/settings/settings_screen.dart';
import 'package:cameo/screens/verify/verify_screen.dart';
import 'package:cameo/screens/welcome/welcome_screen.dart';
import 'package:cameo/state/album_store.dart';
import 'package:cameo/state/session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Companion and observer clients keep credentials in memory. The application
/// itself uses its production Keychain/Keystore implementation.
class _MemoryCredentials implements CredentialStore {
  ApiCredential? value;

  @override
  Future<ApiCredential?> read() async => value;
  @override
  Future<void> write(ApiCredential value) async => this.value = value;
  @override
  Future<void> clear() async => value = null;
}

Future<void> _waitFor(WidgetTester tester, Finder finder) async {
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 200));
  }
  expect(finder, findsOneWidget);
  await tester.pump(const Duration(milliseconds: 700));
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await _waitFor(tester, finder.hitTestable());
  await tester.tap(finder);
  await tester.pump();
}

Future<void> _digits(WidgetTester tester, String value) async {
  for (final digit in value.split('')) {
    await tester.tap(find.byKey(Keypad.keyKey(digit)));
    await tester.pump(const Duration(milliseconds: 90));
  }
}

Future<void> _signIn(WidgetTester tester, String phone, String code) async {
  await _waitFor(tester, find.byKey(WelcomeScreen.ctaKey));
  await _tap(tester, find.byKey(WelcomeScreen.ctaKey));
  await _waitFor(tester, find.byKey(PhoneScreen.ctaKey));
  await _digits(tester, phone);
  await _tap(tester, find.byKey(PhoneScreen.ctaKey));
  await _waitFor(tester, find.byKey(VerifyScreen.codeKey));
  await _digits(tester, code);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;
  final config = ApiConfig.fromEnvironment();
  const localHosts = {'localhost', '127.0.0.1', '::1', '10.0.2.2'};
  const otp = String.fromEnvironment('CAMEO_TEST_OTP', defaultValue: '000000');

  testWidgets(
    'live phone authentication, pairing, settings, revocation, and returning login',
    (tester) async {
      expect(
        config,
        isNotNull,
        reason: 'Set CAMEO_API_BASE_URL to a local backend',
      );
      expect(localHosts, contains(config!.baseUri.host));
      final seed = DateTime.now().microsecondsSinceEpoch % 99999998;
      final phone = '010${seed.toString().padLeft(8, '0')}';
      final partnerPhone = '010${(seed + 1).toString().padLeft(8, '0')}';
      final partner = CameoApi(
        config: config,
        credentials: _MemoryCredentials(),
      );
      final observerStore = _MemoryCredentials();
      final observer = CameoApi(config: config, credentials: observerStore);
      addTearDown(partner.close);
      addTearDown(observer.close);

      await partner.requestPhoneCode(partnerPhone);
      final partnerAuth = await partner.verifyPhone(partnerPhone, otp);
      await partner.acceptCredential(partnerAuth.credential);
      final partnerUser = await partner.updateMe(displayName: 'Cameo partner');

      // Revoke a previous test session before starting the native application.
      final existing = CameoApi(
        config: config,
        credentials: SecureCredentialStore(config.baseUri),
      );
      await existing.loadCredential();
      await existing.signOut();
      existing.close();

      app.main();
      await tester.pump();
      await _signIn(tester, phone, otp);
      await _waitFor(tester, find.byKey(ProfileScreen.inputKey));
      await tester.enterText(find.byKey(ProfileScreen.inputKey), 'Cameo local');
      await _tap(tester, find.byKey(ProfileScreen.ctaKey));
      await _waitFor(tester, find.byKey(PartnerScreen.codeKey));

      final session = SessionScope.read(
        tester.element(find.byType(PartnerScreen)),
      );
      expect(session.usesBackend, isTrue);
      expect(session.session.name, 'Cameo local');
      expect(session.pairingCode, matches(RegExp(r'^\d{6}$')));
      await _digits(tester, partnerUser.pairingCode);
      await _waitFor(tester, find.byType(PermissionsScreen));
      expect(session.session.partner?.id, partnerUser.id);
      final linkedPartner = await partner.me();
      expect(linkedPartner.partner?.displayName, 'Cameo local');
      expect((await partner.couple()).partner.id, linkedPartner.partner!.id);

      await _tap(tester, find.byKey(AuthScaffold.trailingKey));
      await _waitFor(tester, find.byKey(TabBarV6.tabKey(2)));
      expect(session.session.status, SessionStatus.member);
      expect(
        AlbumScope.read(
          tester.element(find.byKey(TabBarV6.tabKey(2))),
        ).sections,
        isEmpty,
      );
      await _tap(tester, find.byKey(TabBarV6.tabKey(2)));
      await _waitFor(tester, find.byKey(SettingsScreen.rootKey));

      // Read the application's actual secure store through an independent client
      // so server persistence and server-side revocation are both observable.
      final stored = await SecureCredentialStore(config.baseUri).read();
      expect(stored, isNotNull);
      await observer.acceptCredential(stored!);
      expect((await observer.me()).displayName, 'Cameo local');
      expect((await observer.couple()).partner.id, partnerUser.id);

      await _tap(
        tester,
        find.descendant(
          of: find.byKey(SettingsScreen.prefKey(SessionPref.callAlerts)),
          matching: find.byType(IosSwitch),
        ),
      );
      final preferenceDeadline = DateTime.now().add(
        const Duration(seconds: 15),
      );
      while (session.session.prefs.callAlerts &&
          DateTime.now().isBefore(preferenceDeadline)) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(session.session.prefs.callAlerts, isFalse);
      expect((await observer.me()).callAlert, isFalse);

      await tester.ensureVisible(find.byKey(SettingsScreen.logoutKey));
      await tester.pump(const Duration(milliseconds: 400));
      await _tap(tester, find.byKey(SettingsScreen.logoutKey));
      await _waitFor(tester, find.byKey(ConfirmSheet.confirmKey));
      await _tap(tester, find.byKey(ConfirmSheet.confirmKey));
      await _waitFor(tester, find.byKey(WelcomeScreen.ctaKey));
      expect(await SecureCredentialStore(config.baseUri).read(), isNull);
      await expectLater(
        observer.me(),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)),
      );

      // Returning sign-in must restore the persisted name, partner, and preferences.
      await _signIn(tester, phone, otp);
      await _waitFor(tester, find.byKey(TabBarV6.tabKey(2)));
      expect(session.session.status, SessionStatus.member);
      expect(session.session.name, 'Cameo local');
      expect(session.session.partner?.id, partnerUser.id);
      expect(session.session.prefs.callAlerts, isFalse);
      expect(tester.takeException(), isNull);
      await partner.signOut();
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
