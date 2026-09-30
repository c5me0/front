import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'api_models.dart';
import 'credential_store.dart';

class ApiException implements Exception {
  const ApiException(
    this.code, {
    this.status,
    this.requestId,
    this.retryAfterSeconds,
  });
  final String code;
  final int? status;
  final String? requestId;
  final int? retryAfterSeconds;
  @override
  String toString() =>
      'ApiException($code, status=$status, requestId=$requestId)';
}

/// Transport for the backend's /v1 contract. Mutations are never retried implicitly.
/// Tokens and response bodies are deliberately omitted from diagnostics.
class CameoApi {
  CameoApi({
    required this.config,
    required this.credentials,
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client();
  final ApiConfig config;
  final CredentialStore credentials;
  final http.Client _client;
  final Duration timeout;
  ApiCredential? _credential;
  int _generation = 0;
  Future<void> _credentialWrites = Future.value();

  bool get hasCredential => _credential != null;
  Future<void> loadCredential() async {
    final generation = _generation;
    final saved = await credentials.read();
    if (generation == _generation) _credential = saved;
  }

  Future<void> acceptCredential(ApiCredential value) {
    final generation = ++_generation;
    _credentialWrites = _credentialWrites.catchError((_) {}).then((_) async {
      if (generation != _generation) {
        throw const ApiException('request_cancelled');
      }
      await credentials.write(value);
      if (generation != _generation) {
        throw const ApiException('request_cancelled');
      }
      _credential = value;
    });
    return _credentialWrites;
  }

  Future<void> forgetCredential() {
    _generation++;
    _credential = null;
    _credentialWrites = _credentialWrites
        .catchError((_) {})
        .then((_) => credentials.clear());
    return _credentialWrites;
  }

  Future<Object?> request(
    String method,
    String path, {
    JsonObject? body,
    bool authenticated = true,
  }) async {
    final credential = _credential;
    final generation = _generation;
    if (authenticated && credential == null) {
      throw const ApiException('unauthenticated', status: 401);
    }
    final request = http.Request(method, config.baseUri.resolve(path))
      ..followRedirects = false
      ..headers['Accept'] = 'application/json';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    if (authenticated) {
      request.headers['Authorization'] = 'Bearer ${credential!.token}';
    }
    final http.Response response;
    try {
      response = await (() async {
        final streamed = await _client.send(request);
        return http.Response.fromStream(streamed);
      })().timeout(timeout);
    } on TimeoutException {
      throw const ApiException('network_timeout');
    } on http.ClientException {
      throw const ApiException('network_unavailable');
    }
    if (generation != _generation) {
      throw const ApiException('request_cancelled');
    }
    final headers = {
      for (final entry in response.headers.entries)
        entry.key.toLowerCase(): entry.value,
    };
    if (response.statusCode == 401 &&
        authenticated &&
        identical(credential, _credential)) {
      await forgetCredential();
    }
    Object? data;
    if (response.bodyBytes.isNotEmpty) {
      try {
        data = jsonDecode(utf8.decode(response.bodyBytes));
      } on FormatException {
        throw ApiException(
          'invalid_response',
          status: response.statusCode,
          requestId: headers['request-id'],
        );
      }
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        data is Map && data['code'] is String
            ? data['code'] as String
            : 'http_error',
        status: response.statusCode,
        requestId: headers['request-id'],
        retryAfterSeconds: int.tryParse(headers['retry-after'] ?? ''),
      );
    }
    return data;
  }

  Future<void> requestPhoneCode(String phone) async {
    await request(
      'POST',
      '/v1/auth/phone/start',
      authenticated: false,
      body: {'phone': koreanPhoneToE164(phone)},
    );
  }

  Future<T> _decode<T>(
    Future<Object?> response,
    T Function(JsonObject) parse,
  ) async {
    try {
      return parse(jsonObject(await response));
    } on FormatException {
      throw const ApiException('invalid_response');
    } on TypeError {
      throw const ApiException('invalid_response');
    }
  }

  Future<ApiSignIn> verifyPhone(String phone, String code) => _decode(
    request(
      'POST',
      '/v1/auth/phone/verify',
      authenticated: false,
      body: {'phone': koreanPhoneToE164(phone), 'code': code},
    ),
    ApiSignIn.fromJson,
  );
  Future<ApiUser> me() => _decode(request('GET', '/v1/me'), ApiUser.fromJson);
  Future<ApiUser> updateMe({
    String? displayName,
    bool? callAlert,
    bool? highlightAlert,
  }) => _decode(
    request(
      'PATCH',
      '/v1/me',
      body: {
        if (displayName != null) 'display_name': displayName.trim(),
        if (callAlert != null) 'call_alert': callAlert,
        if (highlightAlert != null) 'highlight_alert': highlightAlert,
      },
    ),
    ApiUser.fromJson,
  );
  Future<ApiCouple> couple() =>
      _decode(request('GET', '/v1/couple'), ApiCouple.fromJson);
  Future<ApiCouple> connect(String code) => _decode(
    request('POST', '/v1/couple', body: {'code': code}),
    ApiCouple.fromJson,
  );
  Future<String> regeneratePairingCode() => _decode(
    request('POST', '/v1/couple/code'),
    (json) => json['pairing_code'] as String,
  );
  Future<void> signOut() async {
    if (!hasCredential) return;
    try {
      await request('POST', '/v1/auth/signout');
    } on ApiException catch (error) {
      if (error.status != 401) rethrow;
    }
    await forgetCredential();
  }

  void close() {
    _generation++;
    _client.close();
  }
}
