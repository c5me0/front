// Monthly membership and one-time relationship recovery checkout. Prototype payments
// are clearly labeled; cancellation or failure must not activate a membership or
// restore records.

import 'package:flutter/widgets.dart';

import '../../components/account_flow_scaffold.dart';
import '../../components/confirm_sheet.dart';
import '../../components/settings_v6.dart';
import '../../components/solid_button.dart';
import '../../content/app.g.dart';
import '../../design_system/design_system.dart';
import '../../navigation/navigation.dart';
import '../../state/payment_service.dart';
import '../../state/session.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key, this.archiveId});
  final String? archiveId;
  static const planKey = ValueKey('payment.plan');
  static const continueKey = ValueKey('payment.continue');
  static const doneKey = ValueKey('payment.done');
  static const successKey = ValueKey('payment.success');
  static const errorKey = ValueKey('payment.error');
  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _selected = false;
  bool _confirm = false;
  bool _busy = false;
  bool _success = false;
  String? _error;
  RelationshipArchive? _archive;
  bool get _recovery => widget.archiveId != null;
  PaymentKind get _kind =>
      _recovery ? PaymentKind.recovery : PaymentKind.monthly;
  String get _amount => formatUsd(paymentAmountCents(_kind));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_success && !_busy && widget.archiveId != null) {
      _archive = SessionScope.read(context).recoveryById(widget.archiveId!);
    }
  }

  void _back() {
    if (_busy) return;
    if (_success) {
      _done();
      return;
    }
    if (_confirm) {
      setState(() => _confirm = false);
    } else {
      CameoNav.pop(context);
    }
  }

  Future<void> _pay() async {
    if (_busy || !_confirm) return;
    setState(() {
      _confirm = false;
      _busy = true;
      _error = null;
    });
    final result = await SessionScope.read(
      context,
    ).checkout(_kind, archiveId: widget.archiveId);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _success = result == PaymentResult.completed;
      _error = switch (result) {
        PaymentResult.completed => null,
        PaymentResult.cancelled => appContent.v6.billing.cancelled,
        PaymentResult.failed => appContent.v6.billing.failure,
      };
    });
  }

  void _done() {
    if (!_recovery) {
      CameoNav.pop(context);
      return;
    }

    CameoNav.openLocation(context, CameoRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final copy = appContent.v6.billing;
    final c = CameoTheme.colorsOf(context);
    final session = SessionScope.of(context);
    final active = !_recovery && session.monthlyActive;
    final unavailable =
        session.usesBackend || (_recovery && _archive == null && !_success);
    final completed = _success || active;
    final partner = _archive?.partnerName ?? '';
    final title = _recovery ? copy.recoveryTitle : copy.title;
    final footer = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: CameoSpace.s12,
      children: [
        if (_error != null)
          Semantics(
            liveRegion: true,
            child: CameoText(
              _error!,
              key: PaymentScreen.errorKey,
              style: CameoTextStyles.bodyMd,
              color: c.systemRed,
            ),
          ),
        CameoText(
          copy.previewNote,
          style: CameoTextStyles.bodySm,
          color: c.foregroundNeutralMuted,
          textAlign: TextAlign.center,
        ),
        SolidButton(
          key: completed || unavailable
              ? PaymentScreen.doneKey
              : PaymentScreen.continueKey,
          stretch: true,
          label: completed
              ? (_recovery ? copy.recoveryDone : copy.done)
              : unavailable
              ? copy.cancel
              : _busy
              ? copy.processing
              : copy.continueLabel,
          disabled: _busy || (!completed && !unavailable && !_selected),
          onPress: completed
              ? _done
              : unavailable
              ? _back
              : () => setState(() => _confirm = true),
        ),
      ],
    );

    return PopScope(
      canPop: !_busy && !_confirm,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_busy && _confirm) setState(() => _confirm = false);
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          AccountFlowScaffold(
            title: title,
            onBack: _back,
            busy: _busy,
            footer: footer,
            child: completed
                ? _completion(context, active: active && !_success)
                : unavailable
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: CameoSpace.s16,
                    children: [
                      CameoText(
                        copy.unavailableTitle,
                        style: CameoTextStyles.headingLg,
                        color: c.foregroundNeutralBase,
                      ),
                      CameoText(
                        session.usesBackend
                            ? appContent.v6.backend.billingUnavailable
                            : copy.unavailableBody,
                        style: CameoTextStyles.bodyLg,
                        color: c.foregroundNeutralMuted,
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: CameoSpace.s24,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: CameoSpace.s12,
                        children: [
                          CameoText(
                            copy.brand,
                            style: CameoTextStyles.bodyMd,
                            color: c.foregroundNeutralMuted,
                          ),
                          CameoText(
                            _recovery ? copy.recoveryTitle : copy.headline,
                            style: CameoTextStyles.headingLg,
                            color: c.foregroundNeutralBase,
                          ),
                          CameoText(
                            _recovery
                                ? fillTemplate(copy.recoverySubtitle, {
                                    'partner': partner,
                                  })
                                : copy.subtitle,
                            style: CameoTextStyles.bodyLg,
                            color: c.foregroundNeutralMuted,
                          ),
                        ],
                      ),
                      Semantics(
                        selected: _selected,
                        inMutuallyExclusiveGroup: true,
                        child: PressScale(
                          key: PaymentScreen.planKey,
                          accessibilityLabel: _recovery
                              ? copy.recoveryLabel
                              : copy.selectPlan,
                          pressedColor: c.backgroundFillScrimInteraction,
                          pressedRadius: CameoRadius.lg,
                          onPress: _busy
                              ? null
                              : () => setState(() => _selected = true),
                          child: AnimatedContainer(
                            duration: MediaQuery.disableAnimationsOf(context)
                                ? Duration.zero
                                : CameoMotion.durationBase,
                            curve: CameoMotion.easingStandard,
                            padding: const EdgeInsets.all(CameoSpace.s24),
                            decoration: ShapeDecoration(
                              color: c.backgroundCanvasNeutralBase,
                              shape: RoundedSuperellipseBorder(
                                borderRadius: BorderRadius.circular(
                                  CameoRadius.lg,
                                ),
                                side: BorderSide(
                                  color: _selected
                                      ? c.foregroundNeutralBase
                                      : c.borderOutline,
                                  width: CameoBorderWidth.thick,
                                ),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              spacing: CameoSpace.s16,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: CameoText(
                                        _recovery
                                            ? copy.recoveryLabel
                                            : copy.monthlyLabel,
                                        style: CameoTextStyles.bodyLgStrong,
                                        color: c.foregroundNeutralBase,
                                      ),
                                    ),
                                    Container(
                                      width: CameoIconTokens.sizeMd,
                                      height: CameoIconTokens.sizeMd,
                                      decoration: ShapeDecoration(
                                        color: _selected
                                            ? c.foregroundNeutralBase
                                            : c.backgroundCanvasNeutralBase,
                                        shape: CircleBorder(
                                          side: BorderSide(
                                            color: _selected
                                                ? c.foregroundNeutralBase
                                                : c.borderOutline,
                                            width: CameoBorderWidth.thin,
                                          ),
                                        ),
                                      ),
                                      child: _selected
                                          ? CameoIcon(
                                              CameoIconName.check,
                                              size: CameoIconTokens.sizeXs,
                                              color: c.foregroundInvertedBase,
                                            )
                                          : null,
                                    ),
                                  ],
                                ),
                                Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: CameoSpace.s8,
                                  children: [
                                    CameoText(
                                      _amount,
                                      style: CameoTextStyles.wordmark,
                                      color: c.foregroundNeutralBase,
                                    ),
                                    CameoText(
                                      _recovery
                                          ? copy.recoveryPeriod
                                          : copy.monthlyPeriod,
                                      style: CameoTextStyles.bodyLg,
                                      color: c.foregroundNeutralMuted,
                                    ),
                                  ],
                                ),
                                CameoText(
                                  _recovery
                                      ? copy.recoveryDetail
                                      : copy.monthlyDetail,
                                  style: CameoTextStyles.bodyMd,
                                  color: c.foregroundNeutralMuted,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SettingsCard(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(CameoSpace.s16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              spacing: CameoSpace.s12,
                              children: [
                                CameoText(
                                  fillTemplate(
                                    _recovery
                                        ? copy.recoverySummary
                                        : copy.monthlySummary,
                                    {'amount': _amount},
                                  ),
                                  style: CameoTextStyles.bodyLgStrong,
                                  color: c.foregroundNeutralBase,
                                ),
                                if (_archive case final archive?)
                                  Wrap(
                                    spacing: CameoSpace.s16,
                                    runSpacing: CameoSpace.s8,
                                    children: [
                                      CameoText(
                                        fillTemplate(copy.photoCount, {
                                          'count': archive.album.photoCount,
                                        }),
                                        style: CameoTextStyles.bodyMd,
                                        color: c.foregroundNeutralMuted,
                                      ),
                                      CameoText(
                                        fillTemplate(copy.callCount, {
                                          'count': archive.album.callCount,
                                        }),
                                        style: CameoTextStyles.bodyMd,
                                        color: c.foregroundNeutralMuted,
                                      ),
                                    ],
                                  ),
                                CameoText(
                                  _recovery
                                      ? copy.recoveryNote
                                      : copy.monthlyRecoveryNote,
                                  style: CameoTextStyles.bodyMd,
                                  color: c.foregroundNeutralMuted,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      CameoText(
                        copy.priceNote,
                        style: CameoTextStyles.bodySm,
                        color: c.foregroundNeutralMuted,
                      ),
                    ],
                  ),
          ),
          Positioned.fill(
            child: ConfirmSheet(
              visible: _confirm,
              title: copy.confirmTitle,
              body: fillTemplate(
                _recovery ? copy.recoveryConfirm : copy.monthlyConfirm,
                {'amount': _amount, 'partner': partner},
              ),
              confirmLabel: fillTemplate(copy.payLabel, {'amount': _amount}),
              cancelLabel: copy.cancel,
              actionSize: SolidButtonSize.md,
              onConfirm: _pay,
              onCancel: () => setState(() => _confirm = false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _completion(BuildContext context, {required bool active}) {
    final c = CameoTheme.colorsOf(context);
    final copy = appContent.v6.billing;
    return Semantics(
      liveRegion: true,
      child: Column(
        key: PaymentScreen.successKey,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: CameoSpace.s24,
        children: [
          DecoratedBox(
            decoration: ShapeDecoration(
              color: c.backgroundCanvasNeutralBase,
              shape: const CircleBorder(),
            ),
            child: Padding(
              padding: const EdgeInsets.all(CameoSpace.s24),
              child: CameoIcon(
                CameoIconName.check,
                size: CameoSpace.s36,
                color: c.systemGreen,
              ),
            ),
          ),
          CameoText(
            active
                ? copy.active
                : _recovery
                ? copy.recoverySuccessTitle
                : copy.successTitle,
            style: CameoTextStyles.headingLg,
            color: c.foregroundNeutralBase,
          ),
          CameoText(
            active
                ? copy.activeBody
                : _recovery
                ? fillTemplate(copy.recoverySuccessBody, {
                    'partner': _archive?.partnerName ?? '',
                  })
                : copy.successBody,
            style: CameoTextStyles.bodyLg,
            color: c.foregroundNeutralMuted,
          ),
          CameoText(
            '$_amount ${copy.currency}${_recovery ? ' · ${copy.recoveryPeriod}' : ' ${copy.monthlyPeriod}'}',
            style: CameoTextStyles.headingMdStrong,
            color: c.foregroundNeutralBase,
          ),
        ],
      ),
    );
  }
}
