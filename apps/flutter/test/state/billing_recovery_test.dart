// Regression coverage for billing recovery. Preserve behavior, layout, and interaction
// expectations.

import 'dart:async';
import 'dart:convert';
import 'package:cameo/content/app.g.dart';
import 'package:cameo/state/album_store.dart';
import 'package:cameo/state/captured_photo.dart';
import 'package:cameo/state/payment_service.dart';
import 'package:cameo/state/session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Payments implements PaymentService {
  final requests = <PaymentRequest>[];
  PaymentResult result = PaymentResult.completed;
  Completer<PaymentResult>? pending;
  @override
  Future<PaymentResult> purchase(PaymentRequest request) {
    requests.add(request);
    return pending?.future ?? Future.value(result);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  SessionController member(AlbumStore album, Payments payments) {
    final controller = SessionController(
      initial: devSessionOf(DevSessionKind.member),
      paymentService: payments,
    );
    controller.bindAlbum(album);
    addTearDown(controller.dispose);
    addTearDown(album.dispose);
    return controller;
  }

  Future<String> archive(SessionController controller) async {
    final id = controller.session.partner!.id;
    expect(await controller.breakUp(expectedPartnerId: id), isTrue);
    await controller.pendingWrites;
    controller.completeVerification(appContent.demo.phone);
    expect(controller.session.status, SessionStatus.member);
    expect(controller.session.partner, isNull);
    return controller.recoveryFor(id)!.id;
  }

  test('USD prices and calendar month period', () {
    expect(formatUsd(paymentAmountCents(PaymentKind.monthly)), r'$4.99');
    expect(formatUsd(paymentAmountCents(PaymentKind.recovery)), r'$29.90');
    expect(nextBillingMonth(DateTime(2028, 1, 31)), DateTime(2028, 2, 29));
    expect(nextBillingMonth(DateTime(2026, 12, 31)), DateTime(2027, 1, 31));
  });

  test(
    'breakup survives logout and process restart; payment restores exact album state',
    () async {
      final payments = Payments();
      final album = AlbumStore();
      final controller = member(album, payments);
      final photos = album.sections.first.photos;
      album.toggleLike(photos[1].id);
      album.deletePhotos([photos[2].id]);
      album.addCapture(
        CapturedPhoto.placeholder().asVideo(const Duration(seconds: 7)),
      );
      final expected = album.snapshot().toJson();
      final partnerId = controller.session.partner!.id;
      expect(await controller.breakUp(expectedPartnerId: partnerId), isTrue);
      await controller.pendingWrites;
      expect(controller.session, Session.guest);
      expect(album.sections, isEmpty);

      final reloadedAlbum = AlbumStore();
      final reloaded = SessionController(paymentService: payments)
        ..bindAlbum(reloadedAlbum);
      addTearDown(reloaded.dispose);
      addTearDown(reloadedAlbum.dispose);
      await reloaded.load();
      expect(reloaded.session, Session.guest);
      reloaded.completeVerification(appContent.demo.phone);
      expect(reloaded.session.status, SessionStatus.member);
      expect(reloaded.session.partner, isNull);
      expect(reloadedAlbum.sections, isEmpty);
      await expectLater(
        reloaded.connectPartner('240820'),
        throwsA(isA<RecoveryRequired>()),
      );
      expect(reloaded.session.partner, isNull);
      final record = reloaded.recoveryFor(partnerId)!;
      expect(
        await reloaded.checkout(PaymentKind.recovery, archiveId: record.id),
        PaymentResult.completed,
      );
      expect(payments.requests.single.amountCents, 2990);
      expect(payments.requests.single.currency, 'USD');
      expect(reloaded.session.partner!.id, partnerId);
      expect(reloaded.recoveryFor(partnerId), isNull);
      expect(reloadedAlbum.snapshot().toJson(), expected);
      await reloaded.pendingWrites;
    },
  );

  test(
    'monthly subscription does not waive recovery; every new breakup needs a new purchase',
    () async {
      final payments = Payments();
      final controller = member(AlbumStore(), payments);
      expect(
        await controller.checkout(PaymentKind.monthly),
        PaymentResult.completed,
      );
      expect(controller.monthlyActive, isTrue);
      final first = await archive(controller);
      expect(controller.monthlyActive, isTrue);
      await expectLater(
        controller.connectPartner('240820'),
        throwsA(isA<RecoveryRequired>()),
      );
      expect(
        await controller.checkout(PaymentKind.monthly, archiveId: first),
        PaymentResult.failed,
      );
      expect(
        await controller.checkout(PaymentKind.recovery, archiveId: first),
        PaymentResult.completed,
      );
      expect(
        await controller.checkout(PaymentKind.recovery, archiveId: first),
        PaymentResult.failed,
      );
      final second = await archive(controller);
      expect(second, isNot(first));
      expect(
        await controller.checkout(PaymentKind.recovery, archiveId: second),
        PaymentResult.completed,
      );
      expect(payments.requests.map((r) => r.amountCents), [499, 2990, 2990]);
      await controller.pendingWrites;
    },
  );

  test(
    'failed or cancelled payment keeps records archived and partner disconnected',
    () async {
      final payments = Payments();
      final album = AlbumStore();
      final controller = member(album, payments);
      final id = await archive(controller);
      for (final outcome in [PaymentResult.failed, PaymentResult.cancelled]) {
        payments.result = outcome;
        expect(
          await controller.checkout(PaymentKind.recovery, archiveId: id),
          outcome,
        );
        expect(controller.session.partner, isNull);
        expect(controller.recoveryById(id), isNotNull);
        expect(album.sections, isEmpty);
      }
      payments.result = PaymentResult.completed;
      expect(
        await controller.checkout(PaymentKind.recovery, archiveId: id),
        PaymentResult.completed,
      );
      await controller.pendingWrites;
    },
  );

  test(
    'another account cannot pay for or recover the previous account archive',
    () async {
      final payments = Payments();
      final controller = member(AlbumStore(), payments);
      final id = await archive(controller);
      controller.signOut();
      controller.completeVerification('01000000000');
      controller.setName('다른 계정');
      controller.skipPartner();
      controller.completeOnboarding();
      expect(controller.recoveryById(id), isNull);
      expect(
        await controller.checkout(PaymentKind.recovery, archiveId: id),
        PaymentResult.failed,
      );
      expect(payments.requests, isEmpty);
      await controller.connectPartner('240820');
      expect(controller.session.partner, isNotNull);
      await controller.pendingWrites;
    },
  );

  test(
    'pending payment rejects duplicate submissions and late completion after logout',
    () async {
      final payments = Payments()..pending = Completer<PaymentResult>();
      final controller = member(AlbumStore(), payments);
      final checkout = controller.checkout(PaymentKind.monthly);
      expect(
        await controller.checkout(PaymentKind.monthly),
        PaymentResult.failed,
      );
      expect(payments.requests, hasLength(1));
      controller.signOut();
      payments.pending!.complete(PaymentResult.completed);
      expect(await checkout, PaymentResult.cancelled);
      controller.completeVerification(appContent.demo.phone);
      expect(controller.monthlyActive, isFalse);
      await controller.pendingWrites;
    },
  );

  test(
    'another partner starts empty; rotating the former partner code still requires recovery',
    () async {
      final album = AlbumStore();
      final payments = Payments();
      final controller = SessionController(
        initial: devSessionOf(DevSessionKind.member),
        paymentService: payments,
        partnerLookup: (code) => code == '111111'
            ? Partner(
                id: 'another-partner',
                name: '다른 상대',
                avatar: Partner.mock().avatar,
              )
            : Partner.mock(),
      )..bindAlbum(album);
      addTearDown(controller.dispose);
      addTearDown(album.dispose);
      final id = await archive(controller);
      await expectLater(
        controller.connectPartner('654321'),
        throwsA(isA<RecoveryRequired>()),
      );
      await controller.connectPartner('111111');
      expect(controller.session.partner!.id, 'another-partner');
      expect(album.sections, isEmpty);
      expect(controller.recoveryById(id), isNotNull);
      expect(
        await controller.checkout(PaymentKind.recovery, archiveId: id),
        PaymentResult.failed,
      );
      expect(payments.requests, isEmpty);
      await controller.pendingWrites;
    },
  );

  test(
    'an interrupted session write cannot reopen an already archived relationship',
    () async {
      final payments = Payments();
      final controller = member(AlbumStore(), payments);
      final oldSession = controller.session;
      await controller.breakUp(expectedPartnerId: oldSession.partner!.id);
      await controller.pendingWrites;
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(
        kSessionStorageKey,
        jsonEncode(oldSession.toJson()),
      );
      final restored = SessionController(paymentService: payments)
        ..bindAlbum(AlbumStore());
      addTearDown(restored.dispose);
      await restored.load();
      expect(restored.session, Session.guest);
      restored.completeVerification(oldSession.phone!);
      expect(restored.session.partner, isNull);
      await expectLater(
        restored.connectPartner('240820'),
        throwsA(isA<RecoveryRequired>()),
      );
      await restored.pendingWrites;
    },
  );
}
