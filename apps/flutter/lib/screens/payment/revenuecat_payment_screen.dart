import 'package:flutter/widgets.dart';
import 'package:purchases_flutter/purchases_flutter.dart' show StoreProduct;
import 'package:url_launcher/url_launcher.dart';

import '../../api/api_error_text.dart';
import '../../components/account_flow_scaffold.dart';
import '../../components/confirm_sheet.dart';
import '../../components/settings_v6.dart';
import '../../components/storage_usage.dart';
import '../../components/solid_button.dart';
import '../../content/app.g.dart';
import '../../design_system/design_system.dart';
import '../../navigation/cameo_nav.dart';
import '../../state/revenuecat_billing.dart';
import '../../state/session.dart';

class RevenueCatPaymentScreen extends StatefulWidget {
  const RevenueCatPaymentScreen({super.key, this.archiveId});
  // Live recovery routes carry the current server couple ID.
  final String? archiveId;
  @override
  State<RevenueCatPaymentScreen> createState() =>
      _RevenueCatPaymentScreenState();
}

class _RevenueCatPaymentScreenState extends State<RevenueCatPaymentScreen> {
  bool _confirm = false, _recovered = false;
  String? _notice;
  void _back() {
    if (!BillingScope.of(context).purchasing) CameoNav.pop(context);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) BillingScope.of(context).refresh();
    });
  }

  Future<void> _manage(String url) async {
    final uri = Uri.tryParse(url);
    try {
      if (uri == null ||
          uri.scheme != 'https' ||
          uri.userInfo.isNotEmpty ||
          !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (mounted) {
          setState(
            () => _notice = AppContent.of(context).v6.backend.billingError,
          );
        }
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _notice = AppContent.of(context).v6.backend.billingError,
        );
      }
    }
  }

  Future<void> _purchase(
    RevenueCatBilling billing, {
    required bool recovery,
  }) async {
    setState(() {
      _confirm = false;
      _notice = null;
    });
    final result = recovery
        ? await billing.recover(widget.archiveId!)
        : await billing.purchaseMonthly();
    if (!mounted) return;
    setState(() {
      _recovered = recovery && result == CheckoutOutcome.completed;
      _notice = result == CheckoutOutcome.cancelled
          ? AppContent.of(context).v6.billing.cancelled
          : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final billing = BillingScope.of(context),
        session = SessionScope.of(context);
    final copy = AppContent.of(context).v6.billing,
        messages = AppContent.of(context).v6.backend;
    final c = CameoTheme.colorsOf(context);
    final recovery = widget.archiveId != null;
    final couple = session.remoteCouple;
    final matchingCouple = couple?.id == widget.archiveId;
    final restored =
        recovery &&
        matchingCouple &&
        (_recovered || couple?.restoredAt != null);
    final hasRecords = recovery && matchingCouple && couple?.canRestore == true;
    final recovering = recovery;
    final useCredit = recovering && session.restoreCredits > 0;
    final product = recovering
        ? billing.recoveryProduct
        : billing.monthlyProduct;
    final amount = product?.priceString ?? '';
    final partner = session.session.partner?.name ?? messages.partnerName;
    final pending = recovering ? billing.recoveryPending : billing.pending;
    final canPurchase =
        billing.ready &&
        !billing.busy &&
        billing.serverReady &&
        (recovery ? hasRecords : !billing.active) &&
        (recovering
            ? (useCredit || pending || product != null)
            : (!pending && product != null)) &&
        (billing.error == null || (recovering && pending));
    final confirmation = fillTemplate(
      recovering
          ? (useCredit || pending
                ? messages.recoveryCreditConfirm
                : messages.recoveryConfirm)
          : copy.monthlyConfirm,
      {'partner': partner, 'amount': amount},
    );
    final primaryLabel = billing.busy
        ? copy.processing
        : restored
        ? copy.recoveryDone
        : recovery && !hasRecords
        ? copy.unavailableTitle
        : recovering && pending
        ? messages.recoveryResume
        : recovering && useCredit
        ? messages.useRecoveryCredit
        : !recovery && billing.active
        ? copy.active
        : pending
        ? copy.processing
        : product == null
        ? messages.billingPreparing
        : fillTemplate(recovering ? copy.payLabel : copy.subscribeLabel, {
            'amount': amount,
          });
    return PopScope(
      canPop: !billing.purchasing,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AccountFlowScaffold(
            title: recovery ? copy.recoveryTitle : copy.title,
            onBack: _back,
            busy: billing.purchasing,
            footer: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: CameoSpace.s12,
              children: [
                CameoText(
                  recovering ? copy.recoveryPeriod : copy.previewNote,
                  style: CameoTextStyles.bodySm,
                  color: c.foregroundNeutralMuted,
                  textAlign: TextAlign.center,
                ),
                if (_notice != null)
                  CameoText(
                    _notice!,
                    style: CameoTextStyles.bodyMd,
                    color: c.foregroundNeutralMuted,
                  ),
                SolidButton(
                  key: ValueKey(
                    recovering ? 'billing.recovery' : 'billing.purchase',
                  ),
                  stretch: true,
                  label: primaryLabel,
                  disabled: !restored && !canPurchase,
                  onPress: () {
                    if (restored) {
                      CameoNav.pop(context);
                    } else if (recovering && pending) {
                      _purchase(billing, recovery: true);
                    } else {
                      setState(() => _confirm = true);
                    }
                  },
                ),
                if (!recovery)
                  SolidButton(
                    key: const ValueKey('billing.restore'),
                    stretch: true,
                    size: SolidButtonSize.md,
                    variant: SolidButtonVariant.gray,
                    label: messages.restorePurchases,
                    disabled: !billing.ready || billing.busy,
                    onPress: () async {
                      setState(() => _notice = null);
                      await billing.restore();
                    },
                  ),
                if (billing.error != null || pending)
                  SolidButton(
                    key: const ValueKey('billing.retry'),
                    stretch: true,
                    size: SolidButtonSize.md,
                    variant: SolidButtonVariant.gray,
                    label: messages.retry,
                    disabled: billing.busy,
                    onPress: billing.refresh,
                  ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: CameoSpace.s24,
              children: [
                CameoText(
                  copy.brand,
                  style: CameoTextStyles.bodyMd,
                  color: c.foregroundNeutralMuted,
                ),
                if (billing.managementUrl case final url? when !recovery)
                  SolidButton(
                    stretch: true,
                    size: SolidButtonSize.md,
                    variant: SolidButtonVariant.gray,
                    label: messages.manageSubscription,
                    disabled: billing.busy,
                    onPress: () => _manage(url),
                  ),
                CameoText(
                  restored
                      ? copy.recoverySuccessTitle
                      : recovery
                      ? (hasRecords
                            ? copy.recoveryTitle
                            : copy.unavailableTitle)
                      : billing.active
                      ? copy.active
                      : copy.headline,
                  style: CameoTextStyles.headingLg,
                  color: c.foregroundNeutralBase,
                ),
                CameoText(
                  restored
                      ? messages.recoverySuccess
                      : recovery
                      ? (hasRecords
                            ? fillTemplate(copy.recoverySubtitle, {
                                'partner': partner,
                              })
                            : copy.unavailableBody)
                      : session.storage?.source == 'partner'
                      ? messages.partnerPremium
                      : billing.active
                      ? copy.activeBody
                      : copy.subtitle,
                  style: CameoTextStyles.bodyLg,
                  color: c.foregroundNeutralMuted,
                ),
                if (hasRecords) ...[
                  CameoText(
                    '${fillTemplate(copy.photoCount, {'count': couple!.restorable.photos})} · '
                    '${fillTemplate(copy.callCount, {'count': couple.restorable.calls})}',
                    key: const ValueKey('billing.recoveryCounts'),
                    style: CameoTextStyles.bodyLgStrong,
                    color: c.foregroundNeutralBase,
                  ),
                  CameoText(
                    messages.recoveryNote,
                    style: CameoTextStyles.bodyMd,
                    color: c.foregroundNeutralMuted,
                  ),
                ],
                if (!recovery) ...[
                  SettingsCard(
                    children: [StorageUsage(storage: session.storage)],
                  ),
                  CameoText(
                    AppContent.of(context).v6.storage.freeDetail,
                    style: CameoTextStyles.bodyMd,
                    color: c.foregroundNeutralMuted,
                  ),
                  CameoText(
                    AppContent.of(context).v6.storage.keepAccess,
                    style: CameoTextStyles.bodySm,
                    color: c.foregroundNeutralMuted,
                  ),
                ],
                if (product != null &&
                    !restored &&
                    (!recovery || hasRecords) &&
                    !useCredit)
                  _ProductCard(product: product, recovery: recovering),
                if (useCredit && hasRecords)
                  CameoText(
                    messages.recoveryCreditNote,
                    style: CameoTextStyles.bodyMd,
                    color: c.foregroundNeutralMuted,
                  ),
                if (billing.error != null)
                  Semantics(
                    liveRegion: true,
                    child: CameoText(
                      apiErrorCodeText(
                        billing.error!,
                        copy: AppContent.of(context),
                      ),
                      key: const ValueKey('billing.error'),
                      style: CameoTextStyles.bodyMd,
                      color: c.systemRed,
                    ),
                  ),
                if (recovery &&
                    billing.error == 'storage:quota_exceeded' &&
                    session.shouldOfferStorageUpgrade)
                  SolidButton(
                    stretch: true,
                    label: AppContent.of(context).v6.storage.upgrade,
                    onPress: () => CameoNav.openPayment(context),
                  ),
                if (pending)
                  CameoText(
                    messages.billingPending,
                    style: CameoTextStyles.bodyMd,
                    color: c.foregroundNeutralMuted,
                  ),
              ],
            ),
          ),
          Positioned.fill(
            child: ConfirmSheet(
              visible: _confirm,
              title: copy.confirmTitle,
              body: confirmation,
              confirmLabel: primaryLabel,
              cancelLabel: copy.cancel,
              actionSize: SolidButtonSize.md,
              onConfirm: canPurchase
                  ? () => _purchase(billing, recovery: recovering)
                  : null,
              onCancel: () => setState(() => _confirm = false),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, required this.recovery});
  final StoreProduct product;
  final bool recovery;

  @override
  Widget build(BuildContext context) {
    final c = CameoTheme.colorsOf(context),
        copy = AppContent.of(context).v6.billing;
    return SettingsCard(
      children: [
        Padding(
          padding: const EdgeInsets.all(CameoSpace.s24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: CameoSpace.s16,
            children: [
              CameoText(
                recovery ? copy.recoveryTitle : copy.monthlyLabel,
                style: CameoTextStyles.bodyLgStrong,
                color: c.foregroundNeutralBase,
              ),
              Wrap(
                spacing: CameoSpace.s8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  CameoText(
                    product.priceString,
                    key: const ValueKey('billing.price'),
                    style: CameoTextStyles.wordmark,
                    color: c.foregroundNeutralBase,
                  ),
                  CameoText(
                    '${product.currencyCode} ${recovery ? copy.recoveryPeriod : copy.monthlyPeriod}',
                    style: CameoTextStyles.bodyLg,
                    color: c.foregroundNeutralMuted,
                  ),
                ],
              ),
              CameoText(
                recovery ? copy.recoveryDetail : copy.monthlyDetail,
                style: CameoTextStyles.bodyMd,
                color: c.foregroundNeutralMuted,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
