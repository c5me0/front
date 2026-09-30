// Regression coverage for session v5. Preserve behavior, layout, and interaction
// expectations.

import 'dart:convert';

import 'package:cameo/state/session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'disconnectPartner: member 그대로 · 상대 없음 · partnerSkipped 그대로 (RN 과 같다) · 알림 · 저장',
    () async {
      final c = SessionController(initial: devSessionOf(DevSessionKind.member));
      var notified = 0;
      c.addListener(() => notified++);
      c.disconnectPartner();
      expect(c.session.status, SessionStatus.member);
      expect(c.session.partner, isNull);
      expect(c.session.partnerSkipped, isFalse);
      expect(c.session.name, isNotNull);
      expect(notified, 1);
      await c.pendingWrites;
      final prefs = await SharedPreferences.getInstance();
      final saved = Session.fromJson(
        jsonDecode(prefs.getString(kSessionStorageKey)!),
      );
      expect(saved.partner, isNull);

      c.disconnectPartner();
      expect(notified, 1);
      final guest = SessionController(initial: Session.guest);
      guest.disconnectPartner();
      expect(guest.session, Session.guest);
    },
  );

  test('disconnectPartner 는 진행 중인 connectPartner 결과를 버린다', () async {
    final c = SessionController(initial: devSessionOf(DevSessionKind.member));
    final connecting = c.connectPartner('240820');
    c.disconnectPartner();
    await connecting;
    expect(c.session.partner, isNull);
  });

  test(
    'photoSheetVariant: 기본 instant · setPhotoSheetVariant · JSON (알 수 없는 값 → instant) · 알림 설정은 그대로',
    () {
      expect(const SessionPrefs().photoSheetVariant, PhotoSheetVariant.instant);
      final c = SessionController(initial: devSessionOf(DevSessionKind.member));
      c.setPref(SessionPref.callAlerts, false);
      c.setPhotoSheetVariant(PhotoSheetVariant.multi);
      expect(c.session.prefs.photoSheetVariant, PhotoSheetVariant.multi);
      expect(c.session.prefs.callAlerts, isFalse);
      c.setPref(SessionPref.highlightAlerts, false);
      expect(c.session.prefs.photoSheetVariant, PhotoSheetVariant.multi);
      final json = c.session.toJson();
      expect((json['prefs']! as Map)['photoSheetVariant'], 'multi');
      expect(Session.fromJson(json), c.session);
      expect(
        SessionPrefs.fromJson({'photoSheetVariant': 'nope'}).photoSheetVariant,
        PhotoSheetVariant.instant,
      );
      expect(
        SessionPrefs.fromJson({}).photoSheetVariant,
        PhotoSheetVariant.instant,
      );
      expect(PhotoSheetVariant.tryParse('multi'), PhotoSheetVariant.multi);
      expect(PhotoSheetVariant.tryParse(null), isNull);

      c.signOut();
      expect(c.session.prefs.photoSheetVariant, PhotoSheetVariant.instant);
    },
  );
}
