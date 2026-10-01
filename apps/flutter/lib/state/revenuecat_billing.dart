import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:purchases_flutter/purchases_flutter.dart' as rc;
import 'package:shared_preferences/shared_preferences.dart';
import '../api/cameo_api.dart';
import 'purchase_account.dart';
import 'payment_service.dart' show PaymentKind, paymentAmountCents;

class RevenueCatConfig {
  const RevenueCatConfig({
    required this.apiKey,
    required this.entitlementId,
    this.offeringId = '',
    this.monthlyProductId = '',
    this.recoveryProductId = '',
    this.sandboxOnly = true,
  });
  factory RevenueCatConfig.fromEnvironment() => const RevenueCatConfig(
    apiKey: String.fromEnvironment('CAMEO_RC_SDK_KEY'),
    entitlementId: String.fromEnvironment('CAMEO_RC_ENTITLEMENT_ID'),
    offeringId: String.fromEnvironment('CAMEO_RC_OFFERING_ID'),
    monthlyProductId: String.fromEnvironment('CAMEO_RC_MONTHLY_PRODUCT_ID'),
    recoveryProductId: String.fromEnvironment('CAMEO_RC_RECOVERY_PRODUCT_ID'),
    sandboxOnly: bool.fromEnvironment(
      'CAMEO_RC_SANDBOX_ONLY',
      defaultValue: true,
    ),
  );
  final String apiKey,
      entitlementId,
      offeringId,
      monthlyProductId,
      recoveryProductId;
  final bool sandboxOnly;
  bool get testStore => apiKey.startsWith('test_');
  bool get configured => apiKey.isNotEmpty && entitlementId.isNotEmpty;
  String? get configurationError {
    if (!configured) return 'billing_unconfigured';
    if (!(testStore ||
        apiKey.startsWith('appl_') ||
        apiKey.startsWith('goog_'))) {
      return 'billing_unconfigured';
    }
    if (testStore && kReleaseMode) return 'billing_test_release';
    // Test Store guarantees that this build cannot start a real-money checkout.
    if (sandboxOnly && !testStore) return 'billing_test_store_required';
    return null;
  }
}

enum CheckoutOutcome { completed, cancelled, pending, failed }

/// RevenueCat supplies receipts; the authenticated backend grants shared access
/// and consumes recovery credits. SDK operations preserve the checkout owner.
class RevenueCatBilling extends ChangeNotifier {
  RevenueCatBilling(this.config, {required this.account});
  final PurchaseAccount account;
  final RevenueCatConfig config;
  String? _ownerId, _sdkOwner;
  int _epoch = 0;
  bool _disposed = false, _listening = false, _refreshQueued = false;
  bool loading = false, purchasing = false, pending = false;
  bool recoveryPending = false;
  String? error;
  rc.StoreProduct? monthlyProduct;
  rc.StoreProduct? recoveryProduct;
  rc.CustomerInfo? _info;
  String? _syncedReceipt;
  Future<void> _operations = Future.value();
  Timer? _expiryRefresh;
  bool get ready =>
      _ownerId != null &&
      _sdkOwner == _ownerId &&
      !loading &&
      config.configurationError == null;
  bool get busy => loading || purchasing;
  String? get managementUrl => _info?.managementURL;
  rc.EntitlementInfo? get entitlement =>
      _info?.entitlements.active[config.entitlementId];
  bool get active =>
      _ownerId != null &&
      account.userId == _ownerId &&
      account.premium?.active == true;
  bool get serverReady => account.premium != null;
  bool get freeAccess => active && account.premium?.source == 'none';
  bool get storeSubscriptionActive {
    final value = entitlement;
    return _ownerId != null &&
        _ownerId == _sdkOwner &&
        value != null &&
        value.isActive &&
        value.productIdentifier ==
            (config.monthlyProductId.isNotEmpty
                ? config.monthlyProductId
                : monthlyProduct?.identifier) &&
        value.verification != rc.VerificationResult.failed &&
        (!config.sandboxOnly || value.isSandbox);
  }

  bool _current(int epoch) => !_disposed && epoch == _epoch;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<T> _serial<T>(Future<T> Function() run) {
    final task = _operations.then((_) => run());
    _operations = task.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return task;
  }

  Future<void> identify() async {
    final userId = account.userId;
    if (_disposed ||
        (_ownerId == userId &&
            (_sdkOwner == userId ||
                loading ||
                purchasing ||
                config.configurationError != null))) {
      return;
    }
    _ownerId = userId;
    final epoch = ++_epoch;
    _expiryRefresh?.cancel();
    _info = null;
    _syncedReceipt = null;
    monthlyProduct = null;
    recoveryProduct = null;
    error = config.configurationError;
    pending = false;
    recoveryPending = false;
    loading = userId != null && error == null;
    _notify();
    await _serial(() async {
      if (!_current(epoch)) return;
      try {
        if (userId == null) {
          // Keep the native SDK identified. The next authenticated account uses
          // logIn directly, avoiding anonymous aliases and receipt transfers.
          _sdkOwner = null;
          return;
        }
        if (config.configurationError != null) return;
        if (!await rc.Purchases.isConfigured) {
          await rc.Purchases.setLogLevel(rc.LogLevel.warn);
          await rc.Purchases.configure(
            rc.PurchasesConfiguration(config.apiKey)
              ..appUserID = userId
              ..entitlementVerificationMode =
                  rc.EntitlementVerificationMode.informational,
          );
        } else if (await rc.Purchases.appUserID != userId) {
          await rc.Purchases.logIn(userId);
        }
        if (!_current(epoch)) return;
        _sdkOwner = userId;
        final preferences = await SharedPreferences.getInstance();
        if (!_current(epoch)) return;
        recoveryPending = preferences.containsKey(_recoveryKey(userId));
        if (!_listening) {
          rc.Purchases.addCustomerInfoUpdateListener(_customerChanged);
          _listening = true;
        }
        await _load(epoch);
      } on PlatformException catch (problem) {
        if (_current(epoch)) error = _errorCode(problem);
      } on ApiException catch (problem) {
        if (_current(epoch)) error = problem.code;
      } catch (_) {
        if (_current(epoch)) error = 'billing_unavailable';
      } finally {
        if (_current(epoch)) {
          loading = false;
          _notify();
        }
      }
    });
  }

  Future<void> _load(int epoch, {bool forceSync = false}) async {
    final info = await rc.Purchases.getCustomerInfo();
    rc.StoreProduct? monthly;
    if (config.monthlyProductId.isNotEmpty) {
      final products = await rc.Purchases.getProducts([
        config.monthlyProductId,
      ], productCategory: rc.ProductCategory.subscription);
      monthly = products
          .where((p) => p.identifier == config.monthlyProductId)
          .firstOrNull;
    } else {
      final offerings = await rc.Purchases.getOfferings();
      final offering = config.offeringId.isEmpty
          ? offerings.current
          : offerings.all[config.offeringId];
      final packages =
          offering?.availablePackages
              .where((p) => p.packageType == rc.PackageType.monthly)
              .toList() ??
          [];
      if (packages.length == 1) monthly = packages.single.storeProduct;
    }
    if (!_current(epoch)) return;
    rc.StoreProduct? recovery;
    if (config.recoveryProductId.isNotEmpty) {
      final products = await rc.Purchases.getProducts([
        config.recoveryProductId,
      ], productCategory: rc.ProductCategory.nonSubscription);
      recovery = products
          .where((p) => p.identifier == config.recoveryProductId)
          .firstOrNull;
    }
    if (!_current(epoch)) return;
    monthlyProduct =
        monthly != null &&
            monthly.currencyCode == 'USD' &&
            monthly.subscriptionPeriod == 'P1M'
        ? monthly
        : null;
    recoveryProduct =
        recovery != null &&
            recovery.currencyCode == 'USD' &&
            recovery.subscriptionPeriod == null &&
            (recovery.price * 100).round() ==
                paymentAmountCents(PaymentKind.recovery)
        ? recovery
        : null;
    _accept(info);
    if (monthlyProduct == null) error ??= 'billing_product_unavailable';
    await _syncAccount(epoch, force: forceSync);
  }

  String? get _receiptState {
    final info = _info;
    if (info == null) return null;
    final subscription = info.entitlements.all[config.entitlementId];
    final recoveries =
        info.nonSubscriptionTransactions
            .where(
              (transaction) =>
                  transaction.productIdentifier == config.recoveryProductId,
            )
            .map((transaction) => transaction.transactionIdentifier)
            .toSet()
            .toList()
          ..sort();
    return jsonEncode([
      subscription?.isActive,
      subscription?.productIdentifier,
      subscription?.expirationDate,
      subscription?.isSandbox,
      recoveries,
    ]);
  }

  Future<void> _syncAccount(int epoch, {bool force = false}) async {
    if (!_current(epoch) || account.userId != _ownerId) {
      throw const ApiException('request_cancelled');
    }
    // Only changed receipts and explicit purchase/restore actions need the
    // rate-limited reconciliation endpoint. Normal navigation reads server state.
    final receipt = _receiptState;
    if (force || receipt != _syncedReceipt) {
      await account.syncPurchases();
      if (!_current(epoch)) return;
      _syncedReceipt = receipt;
    } else {
      await account.refreshPurchaseStatus();
    }
    if (!_current(epoch)) return;
    await account.refreshCouple();
    if (!_current(epoch)) return;
    if (active) pending = false;
  }

  String _recoveryKey(String owner) =>
      'cameo.recovery.v1.${base64Url.encode(utf8.encode('${config.apiKey}:$owner'))}';

  Future<void> _rememberRecovery(
    String owner,
    String coupleId,
    String transactionId,
  ) async {
    if (_ownerId == owner) recoveryPending = true;
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(
      _recoveryKey(owner),
      jsonEncode({
        'couple_id': coupleId,
        'transaction_id': transactionId,
        'product_id': config.recoveryProductId,
      }),
    );
    if (!saved) throw const ApiException('storage_unavailable');
  }

  Future<void> _forgetRecovery(String owner) async {
    final preferences = await SharedPreferences.getInstance();
    if (!await preferences.remove(_recoveryKey(owner))) {
      throw const ApiException('storage_unavailable');
    }
    if (_ownerId == owner) recoveryPending = false;
  }

  /// Sync before charging and again before delivery. A successful SDK purchase
  /// remains pending until the backend restores the requested current couple.
  Future<CheckoutOutcome> recover(String expectedCoupleId) async {
    if (!ready || purchasing || !serverReady) return CheckoutOutcome.failed;
    final epoch = _epoch, owner = _ownerId!;
    purchasing = true;
    error = null;
    _notify();
    return _serial(() async {
      try {
        await _syncAccount(epoch, force: recoveryPending);
        if (!_current(epoch)) return CheckoutOutcome.cancelled;
        final couple = account.remoteCouple;
        if (couple?.id != expectedCoupleId) {
          throw const ApiException('recovery_context_changed');
        }
        if (!couple!.canRestore) {
          await _forgetRecovery(owner);
          return CheckoutOutcome.completed;
        }
        if (!active) throw const ApiException('purchase:required', status: 402);
        if (account.restoreCredits == 0 && !freeAccess) {
          if (recoveryPending) {
            throw const ApiException('billing_server_pending');
          }
          final product = recoveryProduct;
          if (product == null) {
            throw const ApiException('billing_product_unavailable');
          }
          if (await rc.Purchases.appUserID != owner || !_current(epoch)) {
            throw const ApiException('request_cancelled');
          }
          final result = await rc.Purchases.purchase(
            rc.PurchaseParams.storeProduct(product),
          );
          // Preserve the original owner's receipt even when sign-out raced with
          // the native store dialog; it must never turn into a second charge.
          if (result.storeTransaction.productIdentifier != product.identifier ||
              result.storeTransaction.transactionIdentifier.isEmpty) {
            throw const ApiException('billing_verification_failed');
          }
          await _rememberRecovery(
            owner,
            expectedCoupleId,
            result.storeTransaction.transactionIdentifier,
          );
          if (!_current(epoch)) return CheckoutOutcome.cancelled;
          _accept(result.customerInfo);
          if (error == 'billing_verification_failed') {
            return CheckoutOutcome.pending;
          }
          await _syncAccount(epoch, force: true);
          if (!_current(epoch)) return CheckoutOutcome.cancelled;
          if (account.restoreCredits == 0) {
            throw const ApiException('billing_server_pending');
          }
        }
        if (account.remoteCouple?.id != expectedCoupleId) {
          throw const ApiException('recovery_context_changed');
        }
        await account.restoreCouple(expectedCoupleId);
        if (!_current(epoch)) return CheckoutOutcome.cancelled;
        await _forgetRecovery(owner);
        return CheckoutOutcome.completed;
      } on PlatformException catch (problem) {
        if (!_current(epoch)) return CheckoutOutcome.cancelled;
        final code = rc.PurchasesErrorHelper.getErrorCode(problem);
        if (code == rc.PurchasesErrorCode.purchaseCancelledError) {
          return CheckoutOutcome.cancelled;
        }
        if (code == rc.PurchasesErrorCode.paymentPendingError) {
          try {
            await _rememberRecovery(owner, expectedCoupleId, '');
          } catch (_) {
            // Keep the in-memory guard even if local storage is unavailable.
            // The next attempt always reconciles server credits before charging.
          }
        }
        error = _errorCode(problem);
        return recoveryPending
            ? CheckoutOutcome.pending
            : CheckoutOutcome.failed;
      } on ApiException catch (problem) {
        if (!_current(epoch)) return CheckoutOutcome.cancelled;
        error = recoveryPending && problem.status == 429
            ? 'billing_server_pending'
            : problem.code == 'purchase:required' &&
                  problem.meta['required'] == 'restore'
            ? 'recovery_credit_required'
            : problem.code;
        return recoveryPending
            ? CheckoutOutcome.pending
            : CheckoutOutcome.failed;
      } catch (_) {
        if (_current(epoch)) error = 'billing_unavailable';
        return recoveryPending
            ? CheckoutOutcome.pending
            : CheckoutOutcome.failed;
      } finally {
        purchasing = false;
        if (_current(epoch)) _notify();
      }
    });
  }

  void _accept(rc.CustomerInfo info) {
    _expiryRefresh?.cancel();
    if (info.entitlements.verification == rc.VerificationResult.failed) {
      error = 'billing_verification_failed';
      _info = null;
      return;
    }
    _info = info;
    error = null;
    final expiry = DateTime.tryParse(entitlement?.expirationDate ?? '');
    if (expiry != null && expiry.isAfter(DateTime.now())) {
      _expiryRefresh = Timer(
        expiry.difference(DateTime.now()) + const Duration(seconds: 1),
        () => unawaited(refresh()),
      );
    }
  }

  void _customerChanged(rc.CustomerInfo _) {
    // Re-read under the current identity instead of publishing an event that may
    // belong to an account that just signed out.
    if (_disposed || loading || purchasing || _refreshQueued || !ready) return;
    _refreshQueued = true;
    unawaited(refresh().whenComplete(() => _refreshQueued = false));
  }

  Future<void> refresh() async {
    if (_ownerId == null || busy || config.configurationError != null) return;
    if (_sdkOwner != _ownerId) {
      await identify();
      return;
    }
    final epoch = _epoch;
    final forceSync = pending || recoveryPending;
    loading = true;
    _notify();
    await _serial(() async {
      try {
        if (!_current(epoch) || await rc.Purchases.appUserID != _ownerId) {
          return;
        }
        await rc.Purchases.invalidateCustomerInfoCache();
        await _load(epoch, forceSync: forceSync);
      } on PlatformException catch (problem) {
        if (_current(epoch)) error = _errorCode(problem);
      } on ApiException catch (problem) {
        if (_current(epoch)) error = problem.code;
      } catch (_) {
        if (_current(epoch)) error = 'billing_unavailable';
      } finally {
        if (_current(epoch)) {
          loading = false;
          _notify();
        }
      }
    });
  }

  Future<CheckoutOutcome> purchaseMonthly() async {
    final product = monthlyProduct;
    if (!ready || purchasing || product == null || pending || error != null) {
      return CheckoutOutcome.failed;
    }
    if (active) return CheckoutOutcome.completed;
    final epoch = _epoch, owner = _ownerId;
    purchasing = true;
    error = null;
    _notify();
    return _serial(() async {
      try {
        if (!_current(epoch) || await rc.Purchases.appUserID != owner) {
          return CheckoutOutcome.cancelled;
        }
        // A partner may have subscribed since this screen was opened. Check the
        // shared server entitlement before opening another checkout.
        await _syncAccount(epoch);
        if (!_current(epoch)) return CheckoutOutcome.cancelled;
        if (active) return CheckoutOutcome.completed;
        final currentInfo = await rc.Purchases.getCustomerInfo();
        if (!_current(epoch)) return CheckoutOutcome.cancelled;
        _accept(currentInfo);
        if (error == 'billing_verification_failed') {
          return CheckoutOutcome.failed;
        }
        if (storeSubscriptionActive) {
          await _syncAccount(epoch, force: true);
          if (!_current(epoch)) return CheckoutOutcome.cancelled;
          if (active) return CheckoutOutcome.completed;
          pending = true;
          error = 'billing_server_pending';
          return CheckoutOutcome.pending;
        }
        final result = await rc.Purchases.purchase(
          rc.PurchaseParams.storeProduct(product),
        );
        if (!_current(epoch)) return CheckoutOutcome.cancelled;
        if (result.storeTransaction.productIdentifier != product.identifier) {
          error = 'billing_verification_failed';
          return CheckoutOutcome.failed;
        }
        _accept(result.customerInfo);
        if (error == 'billing_verification_failed') {
          pending = true;
          return CheckoutOutcome.pending;
        }
        await _syncAccount(epoch, force: true);
        if (!_current(epoch)) return CheckoutOutcome.cancelled;
        if (active) return CheckoutOutcome.completed;
        pending = true;
        error ??= 'billing_server_pending';
        return CheckoutOutcome.pending;
      } on ApiException catch (problem) {
        if (!_current(epoch)) return CheckoutOutcome.cancelled;
        pending = storeSubscriptionActive;
        error = pending && problem.status == 429
            ? 'billing_server_pending'
            : problem.code;
        return pending ? CheckoutOutcome.pending : CheckoutOutcome.failed;
      } on PlatformException catch (problem) {
        if (!_current(epoch)) return CheckoutOutcome.cancelled;
        final code = rc.PurchasesErrorHelper.getErrorCode(problem);
        if (code == rc.PurchasesErrorCode.purchaseCancelledError) {
          return CheckoutOutcome.cancelled;
        }
        error = _errorCode(problem);
        if (code == rc.PurchasesErrorCode.paymentPendingError) {
          pending = true;
          return CheckoutOutcome.pending;
        }
        return CheckoutOutcome.failed;
      } catch (_) {
        if (_current(epoch)) error = 'billing_unavailable';
        return CheckoutOutcome.failed;
      } finally {
        purchasing = false;
        if (_current(epoch)) _notify();
      }
    });
  }

  Future<CheckoutOutcome> restore() async {
    if (!ready || purchasing) return CheckoutOutcome.failed;
    final epoch = _epoch, owner = _ownerId;
    purchasing = true;
    error = null;
    _notify();
    return _serial(() async {
      try {
        if (!_current(epoch) || await rc.Purchases.appUserID != owner) {
          return CheckoutOutcome.cancelled;
        }
        final info = await rc.Purchases.restorePurchases();
        if (!_current(epoch)) return CheckoutOutcome.cancelled;
        _accept(info);
        await _syncAccount(epoch, force: true);
        if (!_current(epoch)) return CheckoutOutcome.cancelled;
        if (active) return CheckoutOutcome.completed;
        error ??= 'billing_nothing_to_restore';
        return CheckoutOutcome.failed;
      } on PlatformException catch (problem) {
        if (_current(epoch)) error = _errorCode(problem);
        return CheckoutOutcome.failed;
      } on ApiException catch (problem) {
        if (_current(epoch)) error = problem.code;
        return CheckoutOutcome.failed;
      } catch (_) {
        if (_current(epoch)) error = 'billing_unavailable';
        return CheckoutOutcome.failed;
      } finally {
        purchasing = false;
        if (_current(epoch)) _notify();
      }
    });
  }

  String _errorCode(PlatformException problem) =>
      switch (rc.PurchasesErrorHelper.getErrorCode(problem)) {
        rc.PurchasesErrorCode.networkError => 'network_unavailable',
        rc.PurchasesErrorCode.paymentPendingError => 'billing_pending',
        rc.PurchasesErrorCode.productNotAvailableForPurchaseError ||
        rc.PurchasesErrorCode.configurationError =>
          'billing_product_unavailable',
        _ => 'billing_unavailable',
      };

  @override
  void dispose() {
    _disposed = true;
    _expiryRefresh?.cancel();
    _epoch++;
    if (_listening) {
      rc.Purchases.removeCustomerInfoUpdateListener(_customerChanged);
    }
    super.dispose();
  }
}

class BillingScope extends InheritedNotifier<RevenueCatBilling> {
  const BillingScope({
    super.key,
    required RevenueCatBilling billing,
    required super.child,
  }) : super(notifier: billing);
  static RevenueCatBilling of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BillingScope>()!.notifier!;
}
