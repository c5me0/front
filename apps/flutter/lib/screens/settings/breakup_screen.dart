import 'package:flutter/widgets.dart';

import '../../components/account_flow_scaffold.dart';
import '../../components/auth_scaffold.dart';
import '../../components/avatar_v6.dart';
import '../../components/settings_v6.dart';
import '../../components/solid_button.dart';
import '../../content/app.g.dart';
import '../../design_system/design_system.dart';
import '../../navigation/navigation.dart';
import '../../state/payment_service.dart';
import '../../state/session.dart';

class BreakupScreen extends StatefulWidget {
  const BreakupScreen({super.key});
  static const nextKey = ValueKey('breakup.next');
  static const cancelKey = ValueKey('breakup.cancel');
  static const acknowledgeKey = ValueKey('breakup.acknowledge');
  static const stepKey = ValueKey('breakup.step');
  static const errorKey = ValueKey('breakup.error');
  @override
  State<BreakupScreen> createState() => _BreakupScreenState();
}

class _BreakupScreenState extends State<BreakupScreen> {
  int _step = 0;
  bool _acknowledged = false;
  bool _busy = false;
  bool _failed = false;
  Partner? _partner;
  bool get _last => _step == AppContent.of(context).v6.breakup.steps.length - 1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _partner ??= SessionScope.read(context).session.partner;
  }

  void _back() {
    if (_busy) return;
    if (_step == 0) {
      CameoNav.pop(context);
    } else {
      setState(() {
        _step--;
        _acknowledged = false;
        _failed = false;
      });
    }
  }

  Future<void> _next() async {
    if (_busy) return;
    if (!_last) {
      setState(() {
        _step++;
        _acknowledged = false;
      });
      return;
    }
    final partner = _partner;
    final session = SessionScope.read(context);
    if (!_acknowledged ||
        partner == null ||
        (session.usesBackend && session.premium == null)) {
      return;
    }
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      final success = await SessionScope.read(
        context,
      ).breakUp(expectedPartnerId: partner.id);
      if (mounted && !success) {
        setState(() {
          _busy = false;
          _failed = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = CameoTheme.colorsOf(context);
    final copy = AppContent.of(context).v6.breakup;
    final step = copy.steps[_step];
    final partner = _partner;
    final session = SessionScope.of(context);
    final unavailable = session.usesBackend && session.premium == null;
    final amount = formatUsd(
      AppContent.of(context).v6.billing.recoveryPriceCents,
    );
    String text(String value) =>
        fillTemplate(value, {'partner': partner?.name ?? '', 'amount': amount});
    return PopScope(
      canPop: !_busy && _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_busy) _back();
      },
      child: AccountFlowScaffold(
        title: copy.title,
        onBack: _back,
        busy: _busy,
        trailing: CameoText(
          fillTemplate(copy.stepLabel, {'step': _step + 1}),
          key: BreakupScreen.stepKey,
          style: CameoTextStyles.bodyMd,
          color: c.foregroundNeutralMuted,
        ),
        footer: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: CameoSpace.s8,
          children: [
            if (_failed)
              CameoText(
                copy.failure,
                key: BreakupScreen.errorKey,
                style: CameoTextStyles.bodyMd,
                color: c.systemRed,
              ),
            SolidButton(
              key: BreakupScreen.nextKey,
              label: _busy
                  ? copy.saving
                  : _last
                  ? copy.confirm
                  : copy.next,
              variant: _last
                  ? SolidButtonVariant.system
                  : SolidButtonVariant.defaultVariant,
              stretch: true,
              disabled:
                  unavailable ||
                  _busy ||
                  partner == null ||
                  (_last && !_acknowledged),
              onPress: _next,
            ),
            SolidButton(
              key: BreakupScreen.cancelKey,
              label: copy.cancel,
              variant: SolidButtonVariant.gray,
              stretch: true,
              disabled: _busy,
              onPress: () => CameoNav.pop(context),
            ),
          ],
        ),
        child: AuthEntrance(
          key: ValueKey(_step),
          index: 0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: CameoSpace.s24,
            children: [
              if (partner != null)
                AvatarPair(
                  myName:
                      SessionScope.read(context).session.name ??
                      AppContent.of(context).demo.name,
                  partnerImage: partner.avatar,
                ),
              Semantics(
                header: true,
                liveRegion: true,
                child: CameoText(
                  step.title,
                  style: CameoTextStyles.headingLg,
                  color: c.foregroundNeutralBase,
                ),
              ),
              CameoText(
                unavailable
                    ? AppContent.of(context).v6.backend.breakupUnavailable
                    : text(step.body),
                style: CameoTextStyles.bodyLg,
                color: c.foregroundNeutralMuted,
              ),
              SettingsCard(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(CameoSpace.s16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: CameoSpace.s12,
                      children: [
                        if (_step > 0)
                          CameoText(
                            '$amount ${AppContent.of(context).v6.billing.currency} · ${AppContent.of(context).v6.billing.recoveryPeriod}',
                            style: CameoTextStyles.headingMdStrong,
                            color: c.foregroundNeutralBase,
                          ),
                        CameoText(
                          text(step.detail),
                          style: CameoTextStyles.bodyMd,
                          color: c.foregroundNeutralMuted,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_last)
                Semantics(
                  checked: _acknowledged,
                  child: PressScale(
                    key: BreakupScreen.acknowledgeKey,
                    pressedColor: c.backgroundFillScrimInteraction,
                    pressedRadius: CameoRadius.lg,
                    onPress: _busy
                        ? null
                        : () => setState(() => _acknowledged = !_acknowledged),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: CameoSpace.s16,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: CameoIconTokens.sizeMd,
                            height: CameoIconTokens.sizeMd,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                CameoRadius.sm,
                              ),
                              color: _acknowledged
                                  ? c.foregroundNeutralBase
                                  : c.backgroundCanvasNeutralBase,
                              border: Border.all(
                                color: _acknowledged
                                    ? c.foregroundNeutralBase
                                    : c.borderOutline,
                                width: CameoBorderWidth.thick,
                              ),
                            ),
                            child: _acknowledged
                                ? CameoIcon(
                                    CameoIconName.check,
                                    size: CameoIconTokens.sizeSm,
                                    color: c.foregroundInvertedBase,
                                  )
                                : null,
                          ),
                          const SizedBox(width: CameoSpace.s12),
                          Expanded(
                            child: CameoText(
                              text(copy.acknowledge),
                              style: CameoTextStyles.bodyMd,
                              color: c.foregroundNeutralBase,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
