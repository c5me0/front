import 'dart:async';
import 'dart:convert';
import 'package:cameo/api/api_config.dart';
import 'package:cameo/api/api_models.dart';
import 'package:cameo/api/cameo_api.dart';
import 'package:cameo/api/credential_store.dart';
import 'package:cameo/state/album_store.dart';
import 'package:cameo/state/session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MemoryCredentials implements CredentialStore {
  ApiCredential? value;
  Completer<void>? pendingWrite;
  @override
  Future<ApiCredential?> read() async => value;
  @override
  Future<void> write(ApiCredential credential) async {
    if (pendingWrite != null) await pendingWrite!.future;
    value = credential;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

JsonObject user({
  String? name = 'Test user',
  bool callAlert = true,
  bool paired = false,
}) => {
  'id': 'user-a',
  'phone': '+821012345678',
  'display_name': name,
  'pairing_code': '123456',
  'call_alert': callAlert,
  'highlight_alert': true,
  'partner': paired ? {'id': 'user-b', 'display_name': 'Partner'} : null,
  'created_at': '2026-09-30T00:00:00Z',
};
JsonObject signIn({String? name = 'Test user'}) => {
  'token': 'test-bearer',
  'expires_at': '2027-01-01T00:00:00Z',
  'is_new': name == null,
  'user': user(name: name),
};

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'expired credentials finish startup as signed out and malformed models fail explicitly',
    () async {
      final store = MemoryCredentials()
        ..value = ApiCredential(token: 'expired', expiresAt: DateTime(2020));
      final api = CameoApi(
        config: ApiConfig('http://localhost:18080'),
        credentials: store,
        client: MockClient(
          (_) async => http.Response('{"code":"unauthenticated"}', 401),
        ),
      );
      final controller = SessionController(api: api);
      addTearDown(controller.dispose);
      await controller.load();
      expect(controller.isLoaded, isTrue);
      expect(controller.session, Session.guest);
      expect(store.value, isNull);
      final malformed = CameoApi(
        config: ApiConfig('http://localhost:18080'),
        credentials: MemoryCredentials(),
        client: MockClient((_) async => http.Response('{"token":123}', 200)),
      );
      addTearDown(malformed.close);
      await expectLater(
        malformed.verifyPhone('01012345678', '000000'),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'invalid_response'),
        ),
      );
    },
  );

  test('endpoint validation and Korean phone conversion', () {
    expect(
      ApiConfig('http://localhost:18080').baseUri.toString(),
      'http://localhost:18080/',
    );
    expect(ApiConfig('http://10.0.2.2:18080').baseUri.host, '10.0.2.2');
    expect(() => ApiConfig('http://api.example.com'), throwsArgumentError);
    expect(() => ApiConfig('https://token@example.com'), throwsArgumentError);
    expect(() => ApiConfig('https://api.example.com/v1'), throwsArgumentError);
    expect(koreanPhoneToE164('010-1234-5678'), '+821012345678');
    expect(koreanPhoneToE164('+821012345678'), '+821012345678');
    expect(() => koreanPhoneToE164('123'), throwsFormatException);
  });

  test(
    'OTP requests use public snake_case bodies; profile calls use Bearer and preserve false',
    () async {
      final requests = <http.Request>[];
      final store = MemoryCredentials();
      final api = CameoApi(
        config: ApiConfig('http://localhost:18080'),
        credentials: store,
        client: MockClient((request) async {
          requests.add(request);
          return switch (request.url.path) {
            '/v1/auth/phone/start' ||
            '/v1/auth/signout' => http.Response('', 204),
            '/v1/auth/phone/verify' => http.Response(jsonEncode(signIn()), 200),
            _ => http.Response(jsonEncode(user(callAlert: false)), 200),
          };
        }),
      );
      addTearDown(api.close);
      await api.requestPhoneCode('01012345678');
      final auth = await api.verifyPhone('01012345678', '000000');
      expect(store.value, isNull);
      await api.acceptCredential(auth.credential);
      final changed = await api.updateMe(callAlert: false);
      expect(changed.callAlert, isFalse);
      expect(jsonDecode(requests[0].body), {'phone': '+821012345678'});
      expect(jsonDecode(requests[1].body), {
        'phone': '+821012345678',
        'code': '000000',
      });
      expect(requests[0].headers.containsKey('Authorization'), isFalse);
      expect(requests[1].headers.containsKey('Authorization'), isFalse);
      expect(requests[2].headers['Authorization'], 'Bearer test-bearer');
      expect(jsonDecode(requests[2].body), {'call_alert': false});
      expect(requests.every((r) => !r.followRedirects), isTrue);
      await api.signOut();
      expect(store.value, isNull);
      expect(api.hasCredential, isFalse);
    },
  );

  test('backend error metadata, timeout, and 401 invalidation', () async {
    final store = MemoryCredentials()
      ..value = ApiCredential(token: 'test', expiresAt: DateTime(2027));
    var status = 429;
    final api = CameoApi(
      config: ApiConfig('http://localhost:18080'),
      credentials: store,
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'code': status == 429 ? 'rate_limit' : 'unauthenticated',
            'message': 'failure',
          }),
          status,
          headers: {'Request-ID': 'request-123', 'Retry-After': '60'},
        ),
      ),
    );
    addTearDown(api.close);
    await api.loadCredential();
    await expectLater(
      api.me(),
      throwsA(
        isA<ApiException>()
            .having((e) => e.code, 'code', 'rate_limit')
            .having((e) => e.requestId, 'request id', 'request-123')
            .having((e) => e.retryAfterSeconds, 'retry after', 60),
      ),
    );
    status = 401;
    await expectLater(
      api.me(),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)),
    );
    expect(store.value, isNull);
    final timed = CameoApi(
      config: ApiConfig('http://localhost:18080'),
      credentials: MemoryCredentials(),
      timeout: const Duration(milliseconds: 1),
      client: MockClient((_) => Completer<http.Response>().future),
    );
    addTearDown(timed.close);
    await expectLater(
      timed.requestPhoneCode('01012345678'),
      throwsA(
        isA<ApiException>().having((e) => e.code, 'code', 'network_timeout'),
      ),
    );
  });

  test('logout wins over a delayed secure credential write', () async {
    final store = MemoryCredentials()..pendingWrite = Completer<void>();
    final api = CameoApi(
      config: ApiConfig('http://localhost:18080'),
      credentials: store,
    );
    addTearDown(api.close);
    final writing = api.acceptCredential(
      ApiCredential(token: 'old', expiresAt: DateTime(2027)),
    );
    final check = expectLater(writing, throwsA(isA<ApiException>()));
    await Future<void>.delayed(Duration.zero);
    final clearing = api.forgetCredential();
    store.pendingWrite!.complete();
    await check;
    await clearing;
    expect(store.value, isNull);
    expect(api.hasCredential, isFalse);
  });

  test(
    'backend session signs in, updates profile, pairs, and revokes; no demo records or plaintext token',
    () async {
      final requests = <http.Request>[];
      final store = MemoryCredentials();
      String? name;
      var paired = false;
      final api = CameoApi(
        config: ApiConfig('http://localhost:18080'),
        credentials: store,
        client: MockClient((request) async {
          requests.add(request);
          if (request.url.path == '/v1/auth/phone/start' ||
              request.url.path == '/v1/auth/signout') {
            return http.Response('', 204);
          }
          if (request.url.path == '/v1/auth/phone/verify') {
            return http.Response(jsonEncode(signIn(name: null)), 200);
          }
          if (request.url.path == '/v1/couple') {
            paired = true;
            return http.Response(
              jsonEncode({
                'id': 'couple-1',
                'partner': {
                  'id': 'user-b',
                  'display_name': 'Partner',
                  'phone': '+821000000000',
                },
                'connected_at': '2026-09-30T00:00:00Z',
              }),
              201,
            );
          }
          if (request.method == 'PATCH') {
            name = jsonDecode(request.body)['display_name'] as String? ?? name;
          }
          return http.Response(
            jsonEncode(user(name: name, paired: paired)),
            200,
          );
        }),
      );
      final album = AlbumStore();
      final controller = SessionController(api: api)..bindAlbum(album);
      addTearDown(controller.dispose);
      addTearDown(album.dispose);
      await controller.load();
      expect(controller.session, Session.guest);
      expect(album.sections, isEmpty);
      await controller.requestCode('01012345678');
      expect(await controller.verifyCode('000000'), isTrue);
      controller.completeVerification('01012345678');
      expect(controller.session.status, SessionStatus.onboarding);
      await controller.setName(' Test user ');
      expect(controller.session.name, 'Test user');
      expect(controller.pairingCode, '123456');
      final partner = await controller.connectPartner('654321');
      expect(partner.id, 'user-b');
      expect(partner.avatar, isEmpty);
      expect(controller.partnerPhone, '+821000000000');
      controller.completeOnboarding();
      expect(controller.session.status, SessionStatus.member);
      expect(await controller.breakUp(expectedPartnerId: partner.id), isFalse);
      expect(
        await controller.checkout(PaymentKind.monthly),
        PaymentResult.failed,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getKeys().where(
          (key) => (prefs.get(key)?.toString() ?? '').contains('test-bearer'),
        ),
        isEmpty,
      );
      await controller.signOutFromServer();
      expect(controller.session, Session.guest);
      expect(store.value, isNull);
      expect(requests.last.url.path, '/v1/auth/signout');
    },
  );

  test(
    'configured backend errors do not succeed through demo fallbacks',
    () async {
      final store = MemoryCredentials()
        ..value = ApiCredential(token: 'test', expiresAt: DateTime(2027));
      var fail = false;
      final api = CameoApi(
        config: ApiConfig('http://localhost:18080'),
        credentials: store,
        client: MockClient(
          (_) async => fail
              ? http.Response(
                  '{"code":"internal_error","message":"failed"}',
                  500,
                )
              : http.Response(jsonEncode(user()), 200),
        ),
      );
      final controller = SessionController(api: api);
      addTearDown(controller.dispose);
      await controller.load();
      expect(controller.session.status, SessionStatus.member);
      fail = true;
      await expectLater(
        controller.requestCode('01012345678'),
        throwsA(isA<ApiException>()),
      );
      await expectLater(
        controller.connectPartner('654321'),
        throwsA(isA<ApiException>()),
      );
      expect(controller.session.partner, isNull);
      await controller.setPref(SessionPref.callAlerts, false);
      expect(controller.session.prefs.callAlerts, isTrue);
      expect(controller.backendError, 'internal_error');
      await expectLater(
        controller.signOutFromServer(),
        throwsA(isA<ApiException>()),
      );
      expect(controller.session.status, SessionStatus.member);
    },
  );
}
