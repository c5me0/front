// Payment request/result boundary and explicit demo adapter. No real payment SDK is
// invoked. Calendar-month expiry clamps to the last valid day.

import '../content/app.g.dart';
import '../design_system/design_system.dart';

enum PaymentKind { monthly, recovery }

enum PaymentResult { completed, cancelled, failed }

class PaymentRequest {
  const PaymentRequest({
    required this.kind,
    required this.ownerPhone,
    required this.amountCents,
    required this.currency,
    required this.reference,
  });
  final PaymentKind kind;
  final String ownerPhone;
  final int amountCents;
  final String currency;
  final String reference;
}

abstract interface class PaymentService {
  Future<PaymentResult> purchase(PaymentRequest request);
}

class DemoPaymentService implements PaymentService {
  const DemoPaymentService();
  @override
  Future<PaymentResult> purchase(PaymentRequest request) async {
    await Future<void>.delayed(CameoMotion.authMockVerify);
    return PaymentResult.completed;
  }
}

int paymentAmountCents(PaymentKind kind) => switch (kind) {
  PaymentKind.monthly => appContent.v6.billing.monthlyPriceCents,
  PaymentKind.recovery => appContent.v6.billing.recoveryPriceCents,
};

String formatUsd(int cents) => '\$${(cents / 100).toStringAsFixed(2)}';

DateTime nextBillingMonth(DateTime date) {
  final lastDay = DateTime(date.year, date.month + 2, 0).day;
  return DateTime(
    date.year,
    date.month + 1,
    date.day > lastDay ? lastDay : date.day,
    date.hour,
    date.minute,
    date.second,
    date.millisecond,
    date.microsecond,
  );
}
