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
  });
  final String id;
  final String phone;
  final String? displayName;
  final String pairingCode;
  final bool callAlert;
  final bool highlightAlert;
  final ApiPartner? partner;
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
  );
}

class ApiCouple {
  const ApiCouple({
    required this.id,
    required this.partner,
    required this.connectedAt,
  });
  final String id;
  final ApiPartner partner;
  final DateTime connectedAt;
  factory ApiCouple.fromJson(JsonObject json) => ApiCouple(
    id: json['id'] as String,
    partner: ApiPartner.fromJson(jsonObject(json['partner'])),
    connectedAt: DateTime.parse(json['connected_at'] as String),
  );
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

String koreanPhoneToE164(String phone) {
  final digits = phone.replaceAll(RegExp(r'[\s()-]'), '');
  if (RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(digits)) return digits;
  if (RegExp(r'^01\d{9}$').hasMatch(digits)) return '+82${digits.substring(1)}';
  throw const FormatException('Invalid phone number');
}

String localPhoneDisplay(String phone) =>
    phone.startsWith('+82') ? '0${phone.substring(3)}' : phone;
