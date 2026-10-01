import 'dart:async';
import 'dart:convert';
import 'dart:io' show WebSocket;
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'api_models.dart';
import 'credential_store.dart';
import 'media_models.dart';

class ApiException implements Exception {
  const ApiException(
    this.code, {
    this.status,
    this.requestId,
    this.retryAfterSeconds,
    this.meta = const {},
  });
  final String code;
  final int? status;
  final String? requestId;
  final int? retryAfterSeconds;
  final JsonObject meta;
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
        meta: data is Map && data['meta'] is Map
            ? jsonObject(data['meta'])
            : const {},
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
  Future<ApiUser> syncPurchases() =>
      _decode(request('POST', '/v1/me/purchases/sync'), ApiUser.fromJson);
  Future<void> disconnectCouple() async => request('DELETE', '/v1/couple');
  Future<ApiRestorable> restoreCouple() =>
      _decode(request('POST', '/v1/couple/restore'), ApiRestorable.fromJson);
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

  String _listPath(
    String resource,
    String? cursor,
    int limit,
    bool favorite, [
    String? callId,
  ]) => Uri(
    path: '/v1/$resource',
    queryParameters: {
      'limit': '$limit',
      if (cursor != null) 'cursor': cursor,
      if (favorite) 'favorite': 'true',
      if (callId != null) 'call_id': callId,
    },
  ).toString();

  Future<ApiPage<ApiPhoto>> photos({
    String? cursor,
    int limit = 25,
    bool favorite = false,
    String? callId,
  }) => _decode(
    request('GET', _listPath('photos', cursor, limit, favorite, callId)),
    (json) => ApiPage.fromJson(json, ApiPhoto.fromJson),
  );
  Future<ApiPhoto> photo(String id) => _decode(
    request('GET', '/v1/photos/${Uri.encodeComponent(id)}'),
    ApiPhoto.fromJson,
  );
  Future<ApiUpload> reservePhoto({
    required String contentType,
    required int sizeBytes,
    required int thumbnailSizeBytes,
    required int width,
    required int height,
    DateTime? takenAt,
  }) => _decode(
    request(
      'POST',
      '/v1/photos/upload-url',
      body: {
        'content_type': contentType,
        'size_bytes': sizeBytes,
        'thumbnail_size_bytes': thumbnailSizeBytes,
        'width': width,
        'height': height,
        if (takenAt != null) 'taken_at': takenAt.toUtc().toIso8601String(),
      },
    ),
    ApiUpload.fromJson,
  );
  Future<ApiPhoto> completePhoto(String id) => _decode(
    request('POST', '/v1/photos/${Uri.encodeComponent(id)}/complete'),
    ApiPhoto.fromJson,
  );
  Future<void> favoritePhoto(String id, bool value) async {
    await request(
      value ? 'PUT' : 'DELETE',
      '/v1/photos/${Uri.encodeComponent(id)}/favorite',
    );
  }

  Future<void> deletePhoto(String id) async =>
      request('DELETE', '/v1/photos/${Uri.encodeComponent(id)}');

  Future<ApiPage<ApiCall>> calls({
    String? cursor,
    int limit = 25,
    bool favorite = false,
  }) => _decode(
    request('GET', _listPath('calls', cursor, limit, favorite)),
    (json) => ApiPage.fromJson(json, ApiCall.fromJson),
  );
  Future<ApiCreatedCall> createCall() =>
      _decode(request('POST', '/v1/calls'), ApiCreatedCall.fromJson);
  Future<ApiCallDetail> call(String id) => _decode(
    request('GET', '/v1/calls/${Uri.encodeComponent(id)}'),
    ApiCallDetail.fromJson,
  );
  Future<void> endCall(String id) async =>
      request('POST', '/v1/calls/${Uri.encodeComponent(id)}/end');
  Future<void> declineCall(String id) async =>
      request('POST', '/v1/calls/${Uri.encodeComponent(id)}/decline');
  Future<void> deleteCall(String id) async =>
      request('DELETE', '/v1/calls/${Uri.encodeComponent(id)}');
  Future<void> favoriteCall(String id, bool value) async => request(
    value ? 'PUT' : 'DELETE',
    '/v1/calls/${Uri.encodeComponent(id)}/favorite',
  );
  Future<ApiHighlight> highlight(String id, double seconds) => _decode(
    request(
      'POST',
      '/v1/calls/${Uri.encodeComponent(id)}/highlights',
      body: {'offset_seconds': seconds},
    ),
    ApiHighlight.fromJson,
  );
  Future<ApiPhoto> shareCallPhoto(String id, String photoId) => _decode(
    request(
      'POST',
      '/v1/calls/${Uri.encodeComponent(id)}/photos',
      body: {'photo_id': photoId},
    ),
    ApiPhoto.fromJson,
  );
  Future<void> registerDevice(String token, String platform) async => request(
    'POST',
    '/v1/devices',
    body: {'token': token, 'platform': platform},
  );
  Future<void> unregisterDevice(String token) async =>
      request('DELETE', '/v1/devices/${Uri.encodeComponent(token)}');

  /// Object storage receives the presigned URL only, never the API bearer token.
  Future<void> uploadObject(
    String url,
    Uint8List bytes,
    String contentType,
  ) async {
    final generation = _generation;
    final uri = mediaUri(url);
    try {
      final upload = http.Request('PUT', uri)
        ..followRedirects = false
        ..headers['Content-Type'] = contentType
        ..bodyBytes = bytes;
      final response = await _client
          .send(upload)
          .timeout(const Duration(minutes: 2));
      await response.stream.drain<void>().timeout(timeout);
      if (generation != _generation) {
        throw const ApiException('request_cancelled');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException('upload_failed', status: response.statusCode);
      }
    } on TimeoutException {
      throw const ApiException('network_timeout');
    } on http.ClientException {
      throw const ApiException('network_unavailable');
    }
  }

  Future<WebSocket> openSignal(String id) async {
    final token = _credential?.token;
    if (token == null) throw const ApiException('unauthenticated', status: 401);
    final generation = _generation;
    final uri = config.baseUri
        .resolve('/v1/calls/${Uri.encodeComponent(id)}/signal')
        .replace(scheme: config.baseUri.scheme == 'https' ? 'wss' : 'ws');
    final socket = await WebSocket.connect(
      uri.toString(),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(timeout);
    if (generation != _generation) {
      await socket.close();
      throw const ApiException('request_cancelled');
    }
    return socket;
  }

  void close() {
    _generation++;
    _client.close();
  }
}

Uri mediaUri(String value) {
  final uri = Uri.parse(value);
  const local = {'localhost', '127.0.0.1', '::1', '10.0.2.2'};
  if (uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      !(uri.scheme == 'https' ||
          (uri.scheme == 'http' && local.contains(uri.host)))) {
    throw const ApiException('invalid_response');
  }
  return uri;
}
