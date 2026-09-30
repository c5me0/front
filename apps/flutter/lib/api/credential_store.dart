import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_models.dart';

abstract interface class CredentialStore {
  Future<ApiCredential?> read();
  Future<void> write(ApiCredential value);
  Future<void> clear();
}

/// Bearer credentials are isolated by API origin and never stored in preferences.
class SecureCredentialStore implements CredentialStore {
  SecureCredentialStore(Uri origin, {FlutterSecureStorage? storage})
    : _key = 'cameo.api.${base64Url.encode(utf8.encode(origin.origin))}',
      _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );
  final String _key;
  final FlutterSecureStorage _storage;

  @override
  Future<ApiCredential?> read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return null;
    try {
      return ApiCredential.fromJson(jsonObject(jsonDecode(raw)));
    } on FormatException {
      await clear();
      return null;
    } on TypeError {
      await clear();
      return null;
    }
  }

  @override
  Future<void> write(ApiCredential value) =>
      _storage.write(key: _key, value: jsonEncode(value.toJson()));
  @override
  Future<void> clear() => _storage.delete(key: _key);
}
