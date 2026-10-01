typedef JsonObject = Map<String, dynamic>;

JsonObject jsonObject(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Expected a JSON object');
  }
  return value;
}

class ApiPartner {
  const ApiPartner({required this.id, this.displayName, this.phone});
  final String id;
  final String? displayName;
  final String? phone;
  factory ApiPartner.fromJson(JsonObject json) => ApiPartner(
    id: json['id'] as String,
    displayName: json['display_name'] as String?,
    phone: json['phone'] as String?,
  );
}

class ApiUser {
  const ApiUser({
    required this.id,
    required this.phone,
    required this.pairingCode,
    required this.callAlert,
    required this.highlightAlert,
    this.displayName,
    this.partner,
    this.restoreCredits = 0,
    this.storage,
  });
  final String id;
  final String phone;
  final String? displayName;
  final String pairingCode;
  final bool callAlert;
  final bool highlightAlert;
  final ApiPartner? partner;
  final int restoreCredits;
  final ApiStorage? storage;
  factory ApiUser.fromJson(JsonObject json) => ApiUser(
    id: json['id'] as String,
    phone: json['phone'] as String,
    displayName: json['display_name'] as String?,
    pairingCode: json['pairing_code'] as String,
    callAlert: json['call_alert'] as bool,
    highlightAlert: json['highlight_alert'] as bool,
    partner: json['partner'] == null
        ? null
        : ApiPartner.fromJson(jsonObject(json['partner'])),
    restoreCredits: json['restore_credits'] as int? ?? 0,
    storage: json['storage'] == null
        ? null
        : ApiStorage.fromJson(jsonObject(json['storage'])),
  );
}

/// Server-owned shared usage, including photo thumbnails and call recordings.
class ApiStorage {
  const ApiStorage({
    required this.usedBytes,
    required this.quotaBytes,
    this.tier,
    this.source = 'none',
    this.until,
  });

  static const freeBytes = 1000000000;
  static const proBytes = 50000000000;
  final int usedBytes;
  final int? quotaBytes;
  final String? tier;
  final String source;
  final DateTime? until;
  bool paidAt(DateTime now) =>
      tier != null && source != 'none' && until?.isAfter(now) == true;
  bool get isPro => paidAt(DateTime.now());
  int? get remainingBytes => quotaBytes == null
      ? null
      : (quotaBytes! - usedBytes).clamp(0, quotaBytes!);
  bool get isFull => remainingBytes == 0;
  double get progress =>
      quotaBytes == null ? 0 : (usedBytes / quotaBytes!).clamp(0, 1);
  bool fits(int bytes) =>
      bytes >= 0 && (remainingBytes == null || bytes <= remainingBytes!);

  factory ApiStorage.fromJson(JsonObject json) {
    final used = json['used_bytes'] as int;
    final limit = json['quota_bytes'] as int?;
    final source = json['source'] as String;
    if (!json.containsKey('quota_bytes') ||
        used < 0 ||
        (limit != null && limit <= 0) ||
        !{'none', 'self', 'partner'}.contains(source)) {
      throw const FormatException('Invalid storage quota');
    }
    return ApiStorage(
      usedBytes: used,
      quotaBytes: limit,
      tier: json['tier'] as String?,
      source: source,
      until: json['until'] == null
          ? null
          : DateTime.parse(json['until'] as String),
    );
  }
}

class ApiCouple {
  const ApiCouple({
    required this.id,
    required this.partner,
    required this.connectedAt,
    this.restorable = const ApiRestorable(0, 0),
    this.restoredAt,
  });
  final String id;
  final ApiPartner partner;
  final DateTime connectedAt;
  final ApiRestorable restorable;
  final DateTime? restoredAt;
  bool get canRestore => restoredAt == null && restorable.hasRecords;
  factory ApiCouple.fromJson(JsonObject json) => ApiCouple(
    id: json['id'] as String,
    partner: ApiPartner.fromJson(jsonObject(json['partner'])),
    connectedAt: DateTime.parse(json['connected_at'] as String),
    restorable: json['restorable'] == null
        ? const ApiRestorable(0, 0)
        : ApiRestorable.fromJson(jsonObject(json['restorable'])),
    restoredAt: json['restored_at'] == null
        ? null
        : DateTime.parse(json['restored_at'] as String),
  );
}

class ApiRestorable {
  const ApiRestorable(this.calls, this.photos);
  final int calls, photos;
  bool get hasRecords => calls > 0 || photos > 0;
  factory ApiRestorable.fromJson(JsonObject json) =>
      ApiRestorable(json['calls'] as int, json['photos'] as int);
}

class ApiCredential {
  const ApiCredential({required this.token, required this.expiresAt});
  final String token;
  final DateTime expiresAt;
  JsonObject toJson() => {
    'token': token,
    'expires_at': expiresAt.toUtc().toIso8601String(),
  };
  factory ApiCredential.fromJson(JsonObject json) => ApiCredential(
    token: json['token'] as String,
    expiresAt: DateTime.parse(json['expires_at'] as String),
  );
}

class ApiSignIn {
  const ApiSignIn({
    required this.credential,
    required this.user,
    required this.isNew,
  });
  final ApiCredential credential;
  final ApiUser user;
  final bool isNew;
  factory ApiSignIn.fromJson(JsonObject json) => ApiSignIn(
    credential: ApiCredential.fromJson(json),
    user: ApiUser.fromJson(jsonObject(json['user'])),
    isNew: json['is_new'] as bool,
  );
}

String phoneToE164(String phone) {
  final digits = phone.replaceAll(RegExp(r'[\s()-]'), '');
  if (RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(digits)) return digits;
  throw const FormatException(
    'A phone number with country calling code is required',
  );
}
