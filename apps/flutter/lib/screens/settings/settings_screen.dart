// Settings sections, monthly billing entry, and three-step relationship separation.
// Logout uses matching medium confirmation buttons.

//

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../components/confirm_sheet.dart';
import '../../components/settings_v6.dart';
import '../../components/solid_button.dart';
import '../../content/app.g.dart';
import '../../content/lab.g.dart';
import '../../design_system/design_system.dart';
import '../../navigation/navigation.dart';
import '../../state/notification_prefs.dart';
import '../../state/session.dart';
import 'settings_model.dart';
import 'language_screen.dart';
import '../../state/app_language.dart';
import '../../api/api_error_text.dart';

final GlassBackdropTone _backdrop = GlassBackdropTone.fromToken(
  CameoEffects.liquidGlassBackdropSettingsV6,
);

CameoIconName _iconOf(String key) => CameoIconName.values.firstWhere(
  (n) => n.key == key,
  orElse: () => CameoIconName.borderNone,
);

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  static const Key rootKey = ValueKey('settings.v6');
  static const Key scrollKey = ValueKey('settings.scroll');
  static const Key titleKey = ValueKey('settings.title');
  static const Key profileKey = ValueKey('settings.profile');
  static const Key partnerKey = ValueKey('settings.partner');
  static const Key partnerCardKey = ValueKey('settings.partner.card');
  static const Key connectKey = ValueKey('settings.connect');
  static const Key notificationsKey = ValueKey('settings.notifications');
  static Key prefKey(SessionPref pref) =>
      ValueKey('settings.pref.${pref.name}');
  static const Key developerKey = ValueKey('settings.developer');
  static const Key billingKey = ValueKey('settings.billing');
  static const Key paymentKey = ValueKey('settings.payment');
  static const Key labKey = ValueKey('settings.lab');
  static const Key flowDemoKey = ValueKey('settings.flowDemo');
  static const Key sheetVariantKey = ValueKey('settings.photoSheetVariant');
  static const Key accountKey = ValueKey('settings.account');
  static const Key disconnectKey = ValueKey('settings.disconnect');
  static const Key logoutKey = ValueKey('settings.logout');
  static const Key sheetKey = ValueKey('settings.sheet');

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final OverlayPortalController _sheetPortal = OverlayPortalController();
  final ConfirmSheetController _sheet = ConfirmSheetController();
  final List<VoidCallback> _unregisterFlow = [];

  bool _sheetOpen = false;
  bool _loggingOut = false;
  String? _serverError;

  bool _sheetShown = false;

  bool _tickersOn = true;

  Session? _member;

  @override
  void initState() {
    super.initState();
    _unregisterFlow
      ..add(FlowDemo.register(FlowDemoAction.settingsLogout, _openLogout))
      ..add(FlowDemo.register(FlowDemoAction.sheetConfirm, _confirmFromDemo));
  }

  @override
  void dispose() {
    for (final unregister in _unregisterFlow) {
      unregister();
    }
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _tickersOn = TickerMode.of(context);
    if (!_tickersOn) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _tickersOn || _sheetOpen) return;
        if (_sheetPortal.isShowing) _sheetPortal.hide();
      });
    }
  }

  bool _openLogout() {
    if (!mounted || _sheetOpen || !CameoNav.isTop(context)) return false;
    if (!_sheetPortal.isShowing) _sheetPortal.show();
    setState(() {
      _sheetOpen = true;
      _sheetShown = false;
    });
    return true;
  }

  bool _openDisconnect() {
    if (!mounted || _sheetOpen || !CameoNav.isTop(context)) return false;
    CameoNav.openBreakup(context);
    return true;
  }

  void _closeSheet() {
    if (!mounted || !_sheetOpen) return;
    setState(() {
      _sheetOpen = false;
      _sheetShown = false;
    });
  }

  Future<void> _confirm() async {
    if (!mounted || !_sheetOpen || _loggingOut) return;
    final session = SessionScope.read(context);
    _loggingOut = true;
    try {
      await session.signOutFromServer();
      if (mounted) _closeSheet();
    } catch (error) {
      if (mounted) {
        _closeSheet();
        setState(
          () =>
              _serverError = apiErrorText(error, copy: AppContent.of(context)),
        );
      }
    } finally {
      _loggingOut = false;
    }
  }

  void _onSheetShown() {
    if (!mounted || !_sheetOpen) return;
    _sheetShown = true;
    FlowDemo.settle(FlowDemoAction.settingsLogout);
  }

  bool _confirmFromDemo() {
    if (!mounted || !_sheetOpen || !_sheetShown) return false;
    return _sheet.confirm();
  }

  @override
  Widget build(BuildContext context) {
    TabBarTone.report(context, TabBarV6Tone.canvas);
    return OverlayPortal(
      controller: _sheetPortal,
      overlayChildBuilder: _buildSheet,
      child: GlassBackdrop(
        tone: _backdrop,
        child: Builder(builder: _buildScreen),
      ),
    );
  }

  Widget _buildScreen(BuildContext context) {
    final c = CameoTheme.colorsOf(context);
    final controller = SessionScope.of(context);
    final live = controller.session;
    if (live.status == SessionStatus.member) _member = live;
    final session = _member ?? live;
    final prefs = NotificationPrefs.of(context);
    final content = LabV6.of(context).settings;
    final v6 = AppContent.of(context).v6.settings;
    final partner = session.partner;
    final sheetVariant = session.prefs.photoSheetVariant;
    final safeTop = MediaQuery.paddingOf(context).top;

    final partnerRow = partner != null
        ? SettingsPersonRow(
            key: SettingsScreen.partnerCardKey,
            kind: SettingsPersonKind.partner,
            name: settingsName(partner.name, content.partner.name),
            phone: controller.usesBackend
                ? controller.partnerPhone
                : content.partner.phone,
            status: content.partner.status,
          )
        : SettingsRowV6(
            key: SettingsScreen.connectKey,
            label: v6.connectPartner,
            icon: _iconOf(v6.connectPartnerIcon),
            onPress: () => CameoNav.openConnect(context),
          );

    return ColoredBox(
      key: SettingsScreen.rootKey,

      color: c.backgroundCanvasNeutralStrong,
      child: SingleChildScrollView(
        key: SettingsScreen.scrollKey,
        // RN alwaysBounceVertical
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: EdgeInsets.only(
          top: safeTop < CameoLayout.screenV6StatusBarHeight
              ? CameoLayout.screenV6StatusBarHeight
              : safeTop,

          bottom: CameoLayout.settingsV6BottomInset,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: CameoLayout.settingsV6TitleRowHeight,
              child: Padding(
                padding: const EdgeInsets.only(
                  left: CameoLayout.settingsV6TitleRowPaddingX,
                  right: CameoLayout.settingsV6TitleRowPaddingX,
                  bottom: CameoLayout.settingsV6TitleRowPaddingBottom,
                ),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Semantics(
                    header: true,
                    child: CameoText(
                      content.title,
                      key: SettingsScreen.titleKey,
                      style: CameoTextStyles.headingLg,
                      color: c.foregroundNeutralBase,
                      maxLines: 1,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(
                CameoLayout.settingsV6ContentPadding,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: CameoLayout.settingsV6ContentGap,
                children: [
                  if (_serverError != null || controller.backendError != null)
                    Semantics(
                      liveRegion: true,
                      child: CameoText(
                        _serverError ??
                            apiErrorCodeText(
                              controller.backendError!,
                              copy: AppContent.of(context),
                            ),
                        style: CameoTextStyles.bodyMd,
                        color: c.systemRed,
                      ),
                    ),
                  KeyedSubtree(
                    key: SettingsScreen.profileKey,
                    child: SettingsCard(
                      children: [
                        SettingsPersonRow(
                          kind: SettingsPersonKind.me,
                          name: settingsName(session.name, content.me.name),
                          phone: settingsPhoneLine(
                            session.phone,
                            LabV6.of(context).phone.prefix,
                            content.me.phone,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SettingsSectionV6(
                    key: SettingsScreen.partnerKey,
                    title: content.partnerSection,
                    children: [
                      _SpringHeight(
                        height: partner != null
                            ? CameoLayout.settingsV6PartnerHeight
                            : CameoLayout.settingsV6ActionRowHeight,
                        child: AnimatedSwitcher(
                          duration: CameoMotion.durationBase,
                          switchInCurve: CameoMotion.easingStandard,
                          switchOutCurve: CameoMotion.easingStandard,
                          layoutBuilder: (current, previous) => Stack(
                            alignment: Alignment.topCenter,
                            children: [...previous, ?current],
                          ),
                          child: partnerRow,
                        ),
                      ),
                    ],
                  ),
                  SettingsSectionV6(
                    key: SettingsScreen.notificationsKey,
                    title: content.notificationsSection,
                    children: [
                      SettingsRowV6(
                        key: SettingsScreen.prefKey(SessionPref.callAlerts),
                        label: content.callAlerts,
                        trailing: SettingsRowV6Trailing.toggle(
                          value: prefs.callAlerts,
                          onValueChange: prefs.setCallAlerts,
                        ),
                      ),
                      SettingsRowV6(
                        key: SettingsScreen.prefKey(
                          SessionPref.highlightAlerts,
                        ),
                        label: content.highlightAlerts,
                        trailing: SettingsRowV6Trailing.toggle(
                          value: prefs.highlightAlerts,
                          onValueChange: prefs.setHighlightAlerts,
                        ),
                      ),
                    ],
                  ),
                  SettingsSectionV6(
                    key: SettingsScreen.billingKey,
                    title: AppContent.of(context).v6.billing.section,
                    children: [
                      SettingsRowV6(
                        key: SettingsScreen.paymentKey,
                        label: AppContent.of(context).v6.billing.settingsLabel,
                        trailing: const SettingsRowV6Trailing.chevron(),
                        onPress: () => CameoNav.openPayment(context),
                      ),
                      if (controller.remoteCouple case final couple?
                          when couple.canRestore)
                        SettingsRowV6(
                          key: const ValueKey('settings.recovery'),
                          label: AppContent.of(
                            context,
                          ).v6.billing.recoveryTitle,
                          trailing: const SettingsRowV6Trailing.chevron(),
                          onPress: () => CameoNav.openPayment(
                            context,
                            archiveId: couple.id,
                          ),
                        ),
                    ],
                  ),
                  SettingsSectionV6(
                    key: const ValueKey('settings.languageSection'),
                    title: v6.languageSection,
                    children: [
                      SettingsRowV6(
                        key: const ValueKey('settings.language'),
                        label: v6.language,
                        trailing: SettingsRowV6Trailing.value(
                          AppLanguageScope.maybeOf(context)?.language.label ??
                              AppLanguage.korean.label,
                        ),
                        onPress: () => CameoNav.pushPage(
                          context,
                          (_) => const LanguageScreen(),
                        ),
                      ),
                    ],
                  ),
                  if (!controller.usesBackend)
                    SettingsSectionV6(
                      key: SettingsScreen.developerKey,
                      title: content.developerSection,
                      children: [
                        SettingsRowV6(
                          key: SettingsScreen.labKey,
                          label: content.lab,
                          trailing: const SettingsRowV6Trailing.chevron(),
                          onPress: () => CameoNav.openLab(context),
                        ),
                        SettingsRowV6(
                          key: SettingsScreen.flowDemoKey,
                          label: content.flowDemo,
                          trailing: const SettingsRowV6Trailing.chevron(),
                          onPress: () => FlowDemo.restart(context),
                        ),

                        SettingsRowV6(
                          key: SettingsScreen.sheetVariantKey,
                          label: v6.developerSheetMode,
                          trailing: SettingsRowV6Trailing.value(
                            photoSheetVariantLabel(
                              sheetVariant,
                              content: AppContent.of(context),
                            ),
                          ),
                          onPress: () => controller.setPhotoSheetVariant(
                            nextPhotoSheetVariant(sheetVariant),
                          ),
                        ),
                      ],
                    ),
                  SettingsSectionV6(
                    key: SettingsScreen.accountKey,
                    children: [
                      _SpringCollapse(
                        visible: partner != null,
                        child: SettingsRowV6(
                          key: SettingsScreen.disconnectKey,
                          label: AppContent.of(
                            context,
                          ).v6.breakup.settingsLabel,
                          icon: _iconOf(content.disconnect.icon),
                          tone: SettingsRowV6Tone.destructive,
                          onPress: _openDisconnect,
                        ),
                      ),
                      SettingsRowV6(
                        key: SettingsScreen.logoutKey,
                        label: v6.logout,
                        icon: _iconOf(v6.logoutIcon),
                        onPress: _openLogout,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSheet(BuildContext context) {
    final copy = settingsSheetCopy(
      SettingsSheetKind.logout,
      null,
      content: AppContent.of(context),
    );
    return KeyedSubtree(
      key: SettingsScreen.sheetKey,
      child: ConfirmSheet(
        visible: _sheetOpen,
        title: copy.title,
        body: copy.body,
        confirmLabel: copy.confirm,
        cancelLabel: copy.cancel,
        destructive: true,
        actionSize: SolidButtonSize.md,
        controller: _sheet,
        onShown: _onSheetShown,
        onConfirm: _confirm,
        onCancel: _closeSheet,
      ),
    );
  }
}

class _SpringHeight extends StatefulWidget {
  const _SpringHeight({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  State<_SpringHeight> createState() => _SpringHeightState();
}

class _SpringHeightState extends State<_SpringHeight>
    with SingleTickerProviderStateMixin {
  late final AnimationController _h = AnimationController.unbounded(
    vsync: this,
    value: widget.height,
  );

  @override
  void initState() {
    super.initState();
    _h;
  }

  @override
  void didUpdateWidget(_SpringHeight oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.height == widget.height) return;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _h.value = widget.height;
    } else {
      _h.springTo(widget.height, CameoSprings.smooth, velocity: _h.velocity);
    }
  }

  @override
  void dispose() {
    _h.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _h,
    child: widget.child,
    builder: (context, child) => SizedBox(
      height: _h.value < 0 ? 0 : _h.value,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topCenter,
          minHeight: 0,
          maxHeight: double.infinity,
          child: child,
        ),
      ),
    ),
  );
}

class _SpringCollapse extends StatefulWidget {
  const _SpringCollapse({required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  State<_SpringCollapse> createState() => _SpringCollapseState();
}

class _SpringCollapseState extends State<_SpringCollapse>
    with TickerProviderStateMixin {
  late final AnimationController _size = AnimationController.unbounded(
    vsync: this,
    value: widget.visible ? 1 : 0,
  );
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: CameoMotion.durationBase,
    value: widget.visible ? 1 : 0,
  );

  @override
  void initState() {
    super.initState();
    _size;
    _fade;
  }

  @override
  void didUpdateWidget(_SpringCollapse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visible == widget.visible) return;
    final target = widget.visible ? 1.0 : 0.0;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _size.value = target;
    } else {
      _size.springTo(target, CameoSprings.smooth, velocity: _size.velocity);
    }
    _fade.animateTo(target, curve: CameoMotion.easingStandard);
  }

  @override
  void dispose() {
    _size.dispose();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([_size, _fade]),
    child: widget.child,
    builder: (context, child) {
      final s = _size.value.clamp(0.0, 1.0);
      if (s == 0 && !widget.visible) return const SizedBox.shrink();
      return IgnorePointer(
        ignoring: !widget.visible,
        child: ExcludeSemantics(
          excluding: !widget.visible,
          child: ClipRect(
            child: Align(
              alignment: Alignment.topCenter,
              heightFactor: s,
              child: Opacity(opacity: _fade.value, child: child),
            ),
          ),
        ),
      );
    },
  );
}
