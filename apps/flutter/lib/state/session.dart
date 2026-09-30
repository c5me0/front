// Session and account persistence with generation guards for delayed work. Keep account
// archives after sign-out, commit before disconnecting, and restore a former partner
// only after successful recovery checkout.

//

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../content/app.g.dart';
import '../design_system/design_system.dart';
import 'account_history.dart';
import 'album_store.dart';
import 'payment_service.dart';

export 'account_history.dart' show RelationshipArchive, RecoveryRequired;
export 'payment_service.dart' show PaymentKind, PaymentResult;

const String kSessionStorageKey = 'cameo.session.v1';
const String kAccountHistoryStorageKey = 'cameo.accounts.v1';

enum SessionStatus { signedOut, onboarding, member }

enum PermissionKind { microphone, camera, notifications }

enum PermissionState { undetermined, granted, denied }

enum OnboardingStep { profile, partner, permissions }

enum SessionPref { callAlerts, highlightAlerts }

enum PhotoSheetVariant {
  instant('instant'),
  multi('multi');

  const PhotoSheetVariant(this.param);

  final String param;

  static const PhotoSheetVariant fallback = PhotoSheetVariant.instant;

  static PhotoSheetVariant? tryParse(String? value) {
    for (final v in values) {
      if (v.param == value) return v;
    }
    return null;
  }
}

enum DevSessionKind {
  guest('guest'),
  onboarding('onboarding'),
  member('member');

  const DevSessionKind(this.param);

  final String param;

  static DevSessionKind? tryParse(String? value) {
    for (final k in values) {
      if (k.param == value) return k;
    }
    return null;
  }
}

@immutable
class Partner {
  const Partner({
    this.id = 'demo-partner-yurim',
    required this.name,
    required this.avatar,
  });

  /// content partner.partner ('Yurim' · tabbar-avatar.png — D4)
  factory Partner.mock() => Partner(
    name: appContent.partner.partner.name,
    avatar: appContent.partner.partner.avatar,
  );

  final String name;
  final String avatar;
  final String id;

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'avatar': avatar};

  static Partner? fromJson(Object? json) {
    if (json is! Map) return null;
    final name = json['name'];
    final avatar = json['avatar'];
    if (name is! String || avatar is! String) return null;
    return Partner(
      id: json['id'] is String ? json['id'] as String : 'demo-partner-yurim',
      name: name,
      avatar: avatar,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Partner &&
      other.id == id &&
      other.name == name &&
      other.avatar == avatar;

  @override
  int get hashCode => Object.hash(id, name, avatar);

  @override
  String toString() => 'Partner($name)';
}

/// RN `prefs: { callAlerts, highlightAlerts, photoSheetVariant }`.
@immutable
class SessionPrefs {
  const SessionPrefs({
    this.callAlerts = true,
    this.highlightAlerts = true,
    this.photoSheetVariant = PhotoSheetVariant.fallback,
  });

  final bool callAlerts;
  final bool highlightAlerts;

  final PhotoSheetVariant photoSheetVariant;

  bool valueOf(SessionPref key) => switch (key) {
    SessionPref.callAlerts => callAlerts,
    SessionPref.highlightAlerts => highlightAlerts,
  };

  SessionPrefs copyWith(SessionPref key, bool value) => SessionPrefs(
    callAlerts: key == SessionPref.callAlerts ? value : callAlerts,
    highlightAlerts: key == SessionPref.highlightAlerts
        ? value
        : highlightAlerts,
    photoSheetVariant: photoSheetVariant,
  );

  SessionPrefs withPhotoSheetVariant(PhotoSheetVariant variant) => SessionPrefs(
    callAlerts: callAlerts,
    highlightAlerts: highlightAlerts,
    photoSheetVariant: variant,
  );

  Map<String, Object?> toJson() => {
    'callAlerts': callAlerts,
    'highlightAlerts': highlightAlerts,
    'photoSheetVariant': photoSheetVariant.param,
  };

  static SessionPrefs fromJson(Object? json) {
    if (json is! Map) return const SessionPrefs();
    final call = json['callAlerts'];
    final highlight = json['highlightAlerts'];
    return SessionPrefs(
      callAlerts: call is bool ? call : true,
      highlightAlerts: highlight is bool ? highlight : true,
      photoSheetVariant:
          PhotoSheetVariant.tryParse(json['photoSheetVariant'] as String?) ??
          PhotoSheetVariant.fallback,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SessionPrefs &&
      other.callAlerts == callAlerts &&
      other.highlightAlerts == highlightAlerts &&
      other.photoSheetVariant == photoSheetVariant;

  @override
  int get hashCode =>
      Object.hash(callAlerts, highlightAlerts, photoSheetVariant);
}

const Object _keep = Object();

const Map<PermissionKind, PermissionState> _undeterminedPermissions = {
  PermissionKind.microphone: PermissionState.undetermined,
  PermissionKind.camera: PermissionState.undetermined,
  PermissionKind.notifications: PermissionState.undetermined,
};

@immutable
class Session {
  const Session({
    this.status = SessionStatus.signedOut,
    this.phone,
    this.name,
    this.partner,
    this.partnerSkipped = false,
    this.permissions = _undeterminedPermissions,
    this.prefs = const SessionPrefs(),
  });

  static const Session guest = Session();

  final SessionStatus status;

  final String? phone;

  final String? name;

  final Partner? partner;

  final bool partnerSkipped;

  final Map<PermissionKind, PermissionState> permissions;

  final SessionPrefs prefs;

  PermissionState permissionOf(PermissionKind kind) =>
      permissions[kind] ?? PermissionState.undetermined;

  Session copyWith({
    SessionStatus? status,
    Object? phone = _keep,
    Object? name = _keep,
    Object? partner = _keep,
    bool? partnerSkipped,
    Map<PermissionKind, PermissionState>? permissions,
    SessionPrefs? prefs,
  }) {
    return Session(
      status: status ?? this.status,
      phone: identical(phone, _keep) ? this.phone : phone as String?,
      name: identical(name, _keep) ? this.name : name as String?,
      partner: identical(partner, _keep) ? this.partner : partner as Partner?,
      partnerSkipped: partnerSkipped ?? this.partnerSkipped,
      permissions: permissions == null
          ? this.permissions
          : Map.unmodifiable(permissions),
      prefs: prefs ?? this.prefs,
    );
  }

  Map<String, Object?> toJson() => {
    'status': status.name,
    'phone': phone,
    'name': name,
    'partner': partner?.toJson(),
    'partnerSkipped': partnerSkipped,
    'permissions': {
      for (final kind in PermissionKind.values)
        kind.name: permissionOf(kind).name,
    },
    'prefs': prefs.toJson(),
  };

  static Session fromJson(Object? json) {
    if (json is! Map) return guest;
    T? byName<T extends Enum>(List<T> values, Object? name) {
      for (final v in values) {
        if (v.name == name) return v;
      }
      return null;
    }

    final rawPermissions = json['permissions'];
    final permissions = <PermissionKind, PermissionState>{
      for (final kind in PermissionKind.values)
        kind:
            byName(
              PermissionState.values,
              rawPermissions is Map ? rawPermissions[kind.name] : null,
            ) ??
            PermissionState.undetermined,
    };
    final phone = json['phone'];
    final name = json['name'];
    final skipped = json['partnerSkipped'];
    return Session(
      status:
          byName(SessionStatus.values, json['status']) ??
          SessionStatus.signedOut,
      phone: phone is String ? phone : null,
      name: name is String ? name : null,
      partner: Partner.fromJson(json['partner']),
      partnerSkipped: skipped is bool && skipped,
      permissions: Map.unmodifiable(permissions),
      prefs: SessionPrefs.fromJson(json['prefs']),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Session &&
      other.status == status &&
      other.phone == phone &&
      other.name == name &&
      other.partner == partner &&
      other.partnerSkipped == partnerSkipped &&
      mapEquals(other.permissions, permissions) &&
      other.prefs == prefs;

  @override
  int get hashCode => Object.hash(
    status,
    phone,
    name,
    partner,
    partnerSkipped,
    Object.hashAllUnordered(
      permissions.entries.map((e) => Object.hash(e.key, e.value)),
    ),
    prefs,
  );

  @override
  String toString() =>
      'Session(${status.name}, phone: $phone, name: $name, partner: $partner, '
      'skipped: $partnerSkipped)';
}

OnboardingStep onboardingStepOf(Session session) {
  final name = session.name;
  if (name == null || name.trim().isEmpty) return OnboardingStep.profile;
  if (session.partner == null && !session.partnerSkipped) {
    return OnboardingStep.partner;
  }
  return OnboardingStep.permissions;
}

Session devSessionOf(DevSessionKind kind, {bool partnerNone = false}) {
  switch (kind) {
    case DevSessionKind.guest:
      return Session.guest;
    case DevSessionKind.onboarding:
      return Session(
        status: SessionStatus.onboarding,
        phone: appContent.demo.phone,
      );
    case DevSessionKind.member:
      return Session(
        status: SessionStatus.member,
        phone: appContent.demo.phone,
        name: appContent.demo.name,
        partner: partnerNone ? null : Partner.mock(),
        partnerSkipped: partnerNone,
        permissions: const {
          PermissionKind.microphone: PermissionState.granted,
          PermissionKind.camera: PermissionState.granted,
          PermissionKind.notifications: PermissionState.granted,
        },
      );
  }
}

///

class SessionController extends ChangeNotifier {
  SessionController({
    Session? initial,
    PaymentService paymentService = const DemoPaymentService(),
    Partner Function(String code)? partnerLookup,
    DateTime Function()? now,
  }) : _session = initial ?? Session.guest,
       _paymentService = paymentService,
       _partnerLookup = partnerLookup,
       _now = now ?? DateTime.now {
    if (initial != null) _loaded = true;
  }

  Session _session;
  bool _loaded = false;
  bool _disposed = false;
  bool _historyReadFailed = false;
  bool _flowDemoSession = false;
  bool _transaction = false;
  int _archiveCounter = 0;
  final PaymentService _paymentService;
  final Partner Function(String code)? _partnerLookup;
  final DateTime Function() _now;
  Map<String, AccountRecord> _accounts = {};
  AlbumStore? _album;

  void bindAlbum(AlbumStore album) => _album = album;

  AccountRecord? get _account =>
      _flowDemoSession ? null : _accounts[_session.phone];
  bool get monthlyActive => _account?.monthlyUntil?.isAfter(_now()) ?? false;

  RelationshipArchive? recoveryFor(String partnerId) =>
      _account?.archives[partnerId];

  RelationshipArchive? recoveryById(String id) {
    for (final archive
        in _account?.archives.values ?? <RelationshipArchive>[]) {
      if (archive.id == id) return archive;
    }
    return null;
  }

  int _generation = 0;

  Future<void> _writes = Future<void>.value();

  Session get session => _session;

  bool get isLoaded => _loaded;

  @visibleForTesting
  Future<void> get pendingWrites => _writes;

  Future<void> load({DevSessionKind? dev, bool partnerNone = false}) async {
    if (_loaded) {
      if (dev != null) applyDevSession(dev, partnerNone: partnerNone);
      return;
    }
    Session loaded = Session.guest;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(kSessionStorageKey);
      if (raw != null) loaded = Session.fromJson(jsonDecode(raw));
      final history = prefs.getString(kAccountHistoryStorageKey);
      if (history != null) {
        try {
          final data = jsonDecode(history) as Map<String, dynamic>;
          _accounts = {
            for (final entry in data.entries)
              entry.key: AccountRecord.fromJson(
                entry.value as Map<String, dynamic>,
              ),
          };
        } catch (error) {
          _historyReadFailed = true;
          debugPrint(
            '[cameo] account history: cannot read saved records ($error)',
          );
        }
      }
    } catch (error) {
      debugPrint('[cameo] session: 저장값을 읽지 못했다 → guest ($error)');
    }
    if (_disposed) return;

    final account = _accounts[loaded.phone];
    if (dev == null &&
        loaded.status == SessionStatus.member &&
        account != null) {
      final oldPartner = loaded.partner;
      loaded = oldPartner != null && account.archives.containsKey(oldPartner.id)
          ? Session.guest
          : Session.fromJson(
              account.profile,
            ).copyWith(status: SessionStatus.member);
    }
    _session = loaded;
    _loaded = true;
    if (dev != null) {
      applyDevSession(dev, partnerNone: partnerNone);
    } else {
      _restoreAccountAlbum(loaded);
      notifyListeners();
    }
  }

  Future<void> requestCode(String phone) =>
      Future<void>.delayed(CameoMotion.authMockSend);

  Future<bool> verifyCode(String code) async {
    await Future<void>.delayed(CameoMotion.authMockVerify);
    return code == appContent.verify.mockCode;
  }

  void completeVerification(String phone, {bool forceOnboarding = false}) {
    _generation++;
    _flowDemoSession = forceOnboarding;
    final account = forceOnboarding ? null : _accounts[phone];
    if (account != null) {
      var returning = Session.fromJson(account.profile).copyWith(phone: phone);
      if (returning.partner != null &&
          account.archives.containsKey(returning.partner!.id)) {
        returning = returning.copyWith(partner: null);
      }
      _restoreAccountAlbum(returning);
      _set(returning.copyWith(status: SessionStatus.member));
      return;
    }
    _set(
      Session(
        status: SessionStatus.onboarding,
        phone: phone,
        prefs: _session.prefs,
      ),
    );
  }

  void setName(String name) => _set(_session.copyWith(name: name.trim()));

  Future<Partner> connectPartner(String code) async {
    final generation = _generation;
    await Future<void>.delayed(CameoMotion.authMockConnect);
    final partner = _partnerLookup?.call(code) ?? Partner.mock();
    if (generation == _generation) {
      if (_historyReadFailed) throw StateError('Account history unavailable');
      if (_session.partner != null && _session.partner!.id != partner.id) {
        throw StateError('Disconnect the current partner before reconnecting');
      }
      final archive = recoveryFor(partner.id);
      if (archive != null) throw RecoveryRequired(archive);

      if (_account?.archives.isNotEmpty ?? false) _album?.reset(empty: true);
      _set(_session.copyWith(partner: partner, partnerSkipped: false));
    }
    return partner;
  }

  void skipPartner() => _set(_session.copyWith(partnerSkipped: true));

  void setPermission(PermissionKind kind, PermissionState state) {
    _set(
      _session.copyWith(permissions: {..._session.permissions, kind: state}),
    );
  }

  void completeOnboarding() =>
      _set(_session.copyWith(status: SessionStatus.member));

  void setPref(SessionPref key, bool value) =>
      _set(_session.copyWith(prefs: _session.prefs.copyWith(key, value)));

  void setPhotoSheetVariant(PhotoSheetVariant variant) => _set(
    _session.copyWith(prefs: _session.prefs.withPhotoSheetVariant(variant)),
  );

  void disconnectPartner() {
    if (_session.status != SessionStatus.member || _session.partner == null) {
      return;
    }
    _generation++;
    _set(_session.copyWith(partner: null));
  }

  void signOut() {
    _rememberAccount(_session);
    _generation++;
    _set(Session.guest);
  }

  void _restoreAccountAlbum(Session session) {
    final album = _album;
    final account = _accounts[session.phone];
    if (album == null || account == null) return;
    if (session.partner == null) {
      album.reset(empty: true);
    } else if (account.album case final snapshot?) {
      album.restoreSnapshot(snapshot);
    }
  }

  void _rememberAccount(Session session) {
    final phone = session.phone;
    if (phone == null ||
        session.status != SessionStatus.member ||
        _historyReadFailed ||
        _flowDemoSession) {
      return;
    }
    final old = _accounts[phone] ?? AccountRecord(profile: session.toJson());
    _accounts[phone] = old.copyWith(
      profile: session.toJson(),
      album: session.partner == null ? null : _album?.snapshot(),
      clearAlbum: session.partner == null,
    );
  }

  String _encodeAccounts(Map<String, AccountRecord> accounts) => jsonEncode({
    for (final entry in accounts.entries) entry.key: entry.value.toJson(),
  });

  Future<bool> _commitAccounts(
    Map<String, AccountRecord> next,
    int generation,
  ) {
    final completer = Completer<bool>();
    _writes = _writes.then((_) async {
      if (_disposed || generation != _generation) {
        completer.complete(false);
        return;
      }
      try {
        final prefs = await SharedPreferences.getInstance();
        if (_disposed || generation != _generation) {
          completer.complete(false);
          return;
        }
        final saved = await prefs.setString(
          kAccountHistoryStorageKey,
          _encodeAccounts(next),
        );
        if (!saved) throw StateError('Account history write failed');
        if (_disposed || generation != _generation) {
          await prefs.setString(
            kAccountHistoryStorageKey,
            _encodeAccounts(_accounts),
          );
          completer.complete(false);
          return;
        }
        _accounts = next;
        completer.complete(true);
      } catch (error, stack) {
        completer.completeError(error, stack);
      }
    });
    return completer.future;
  }

  Future<bool> breakUp({required String expectedPartnerId}) async {
    final phone = _session.phone;
    final partner = _session.partner;
    final album = _album;
    if (_transaction ||
        _flowDemoSession ||
        _historyReadFailed ||
        phone == null ||
        partner == null ||
        partner.id != expectedPartnerId ||
        album == null ||
        _session.status != SessionStatus.member) {
      return false;
    }
    _transaction = true;
    final generation = _generation;
    try {
      final archive = RelationshipArchive(
        id: '$phone:${partner.id}:${_now().microsecondsSinceEpoch}:${++_archiveCounter}',
        partnerId: partner.id,
        partnerName: partner.name,
        partnerAvatar: partner.avatar,
        album: album.snapshot(),
      );
      final unpaired = _session.copyWith(partner: null, partnerSkipped: true);
      final current = _account ?? AccountRecord(profile: _session.toJson());
      final next = current.copyWith(
        profile: unpaired.toJson(),
        clearAlbum: true,
        archives: {...current.archives, partner.id: archive},
      );
      if (!await _commitAccounts({..._accounts, phone: next}, generation)) {
        return false;
      }
      _session = unpaired;
      album.reset(empty: true);
      signOut();
      return true;
    } finally {
      _transaction = false;
    }
  }

  Future<PaymentResult> checkout(PaymentKind kind, {String? archiveId}) async {
    if (kind == PaymentKind.monthly && archiveId != null) {
      return PaymentResult.failed;
    }
    final phone = _session.phone;
    final archive = archiveId == null ? null : recoveryById(archiveId);
    if (_transaction ||
        _flowDemoSession ||
        _historyReadFailed ||
        phone == null ||
        _session.status != SessionStatus.member ||
        (kind == PaymentKind.recovery &&
            (archive == null || _session.partner != null))) {
      return PaymentResult.failed;
    }
    if (kind == PaymentKind.monthly && monthlyActive) {
      return PaymentResult.completed;
    }
    _transaction = true;
    final generation = _generation;
    try {
      final result = await _paymentService.purchase(
        PaymentRequest(
          kind: kind,
          ownerPhone: phone,
          amountCents: paymentAmountCents(kind),
          currency: appContent.v6.billing.currency,
          reference:
              archive?.id ?? 'monthly:$phone:${_now().microsecondsSinceEpoch}',
        ),
      );
      if (_disposed || generation != _generation) {
        return PaymentResult.cancelled;
      }
      if (result != PaymentResult.completed) return result;
      final current = _account ?? AccountRecord(profile: _session.toJson());
      var nextSession = _session;
      final AccountRecord next;
      if (kind == PaymentKind.recovery) {
        if (recoveryById(archiveId!) != archive) return PaymentResult.cancelled;
        final restored = archive!;
        nextSession = _session.copyWith(
          partner: Partner(
            id: restored.partnerId,
            name: restored.partnerName,
            avatar: restored.partnerAvatar,
          ),
          partnerSkipped: false,
        );
        final remaining = Map<String, RelationshipArchive>.of(current.archives)
          ..remove(restored.partnerId);
        next = current.copyWith(
          profile: nextSession.toJson(),
          album: restored.album,
          archives: remaining,
        );
      } else {
        next = current.copyWith(
          monthlyUntil: nextBillingMonth(_now()),
          album: _album?.snapshot(),
        );
      }
      if (!await _commitAccounts({..._accounts, phone: next}, generation)) {
        return PaymentResult.cancelled;
      }
      if (kind == PaymentKind.recovery && archive != null) {
        _album?.restoreSnapshot(archive.album);
      }
      _set(nextSession, force: true);
      return PaymentResult.completed;
    } catch (error) {
      debugPrint('[cameo] checkout failed ($error)');
      return PaymentResult.failed;
    } finally {
      _transaction = false;
    }
  }

  void applyDevSession(DevSessionKind kind, {bool partnerNone = false}) {
    _generation++;
    _flowDemoSession = false;
    _set(devSessionOf(kind, partnerNone: partnerNone), force: true);
  }

  void _set(Session next, {bool force = false}) {
    if (_disposed) return;
    if (!force && next == _session) return;
    _session = next;
    _rememberAccount(next);
    notifyListeners();
    _persist(next);
  }

  void _persist(Session value) {
    final raw = jsonEncode(value.toJson());
    final history = _historyReadFailed || _flowDemoSession
        ? null
        : _encodeAccounts(_accounts);
    _writes = _writes.then((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(kSessionStorageKey, raw);
        if (history != null) {
          await prefs.setString(kAccountHistoryStorageKey, history);
        }
      } catch (error) {
        debugPrint('[cameo] session: 저장하지 못했다 ($error)');
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _album = null;
    super.dispose();
  }
}

class SessionScope extends InheritedNotifier<SessionController> {
  const SessionScope({
    super.key,
    required SessionController controller,
    required super.child,
  }) : super(notifier: controller);

  static SessionController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SessionScope>();
    assert(scope != null, 'SessionScope 가 없다 — CameoApp 아래에서 쓴다');
    return scope!.notifier!;
  }

  static SessionController read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<SessionScope>();
    assert(scope != null, 'SessionScope 가 없다 — CameoApp 아래에서 쓴다');
    return scope!.notifier!;
  }

  static SessionController? maybeRead(BuildContext context) =>
      context.getInheritedWidgetOfExactType<SessionScope>()?.notifier;
}
