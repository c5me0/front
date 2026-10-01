// Pairing-code entry for onboarding and settings. After reconnection the backend
// offers any archived records separately from the new shared album.

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../components/auth_scaffold.dart';
import '../../components/code_box.dart';
import '../../components/connect_done_v6.dart';
import '../../components/keypad.dart';
import '../../components/my_code_card.dart';
import '../../components/toast.dart';
import '../../components/toast_v6.dart';
import '../../content/app.g.dart';
import '../../content/lab.g.dart';
import '../../design_system/design_system.dart';
import '../../navigation/navigation.dart';
import '../../state/session.dart';
import '../../api/api_error_text.dart';

enum PartnerMode { onboarding, settings }

/// RN `Phase`.
enum _Phase { idle, connecting, success, done }

class PartnerScreen extends StatefulWidget {
  const PartnerScreen({
    super.key,
    this.mode = PartnerMode.onboarding,
    this.state = PartnerRouteState.input,
  });

  final PartnerMode mode;

  final PartnerRouteState state;

  static const Key codeKey = ValueKey('partner.code');
  static const Key myCodeKey = ValueKey('partner.myCode');
  static const Key toastKey = ValueKey('partner.toast');
  static const Key doneKey = ValueKey('partner.done');

  @override
  State<PartnerScreen> createState() => _PartnerScreenState();
}

class _PartnerScreenState extends State<PartnerScreen> {
  late final bool _preset = widget.state == PartnerRouteState.done;
  String _code = '';
  late _Phase _phase = _preset ? _Phase.done : _Phase.idle;

  Partner? _partner;

  final KeypadController _keypad = KeypadController();
  final ToastController _toast = ToastController();
  Timer? _typing;
  late final VoidCallback _unregisterFlow;

  static int get _length => appContent.verify.codeLength;

  bool get _onboarding => widget.mode == PartnerMode.onboarding;

  @override
  void initState() {
    super.initState();
    _unregisterFlow = FlowDemo.register(FlowDemoAction.partnerType, _typeDemo);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_preset && _partner == null) {
      _partner = SessionScope.read(context).session.partner ?? Partner.mock();
    }
  }

  @override
  void dispose() {
    _unregisterFlow();
    _typing?.cancel();
    _toast.dispose();
    super.dispose();
  }

  void _onKey(String digit) {
    if (_phase != _Phase.idle || _code.length >= _length) return;
    setState(() => _code += digit);
  }

  void _onDelete() {
    if (_phase != _Phase.idle || _code.isEmpty) return;
    setState(() => _code = _code.substring(0, _code.length - 1));
  }

  Future<void> _connect(String code) async {
    if (_phase != _Phase.idle) return;
    final session = SessionScope.read(context);
    setState(() => _phase = _Phase.connecting);
    final Partner partner;
    try {
      partner = await session.connectPartner(code);
    } on RecoveryRequired catch (required) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.idle;
        _code = '';
      });
      await CameoNav.openPayment(context, archiveId: required.archive.id);
      if (mounted &&
          !_onboarding &&
          session.session.partner != null &&
          CameoNav.isTop(context)) {
        CameoNav.pop(context);
      }
      return;
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.idle;
        _code = '';
      });
      _toast.show(apiErrorText(error), CameoIconName.x);
      return;
    }
    if (!mounted) return;
    setState(() {
      _partner = partner;
      _phase = _Phase.success;
    });
    await Future<void>.delayed(CameoMotion.authSuccessHold);

    if (!mounted || _phase != _Phase.success) return;
    setState(() => _phase = _Phase.done);
  }

  Future<void> _onDone() async {
    if (!mounted) return;
    final controller = SessionScope.read(context);
    if (controller.usesBackend && controller.hasRestorable) {
      await CameoNav.openPayment(
        context,
        archiveId: controller.remoteCouple!.id,
      );
      if (!mounted) return;
    }
    if (!_onboarding) {
      CameoNav.pop(context);
      return;
    }
    await CameoNav.openPermissions(context);
    if (!mounted || _phase != _Phase.done) return;
    setState(() {
      _phase = _Phase.idle;
      _code = '';
    });
  }

  void _skip() {
    if (_phase != _Phase.idle || !CameoNav.isTop(context)) return;
    SessionScope.read(context).skipPartner();
    CameoNav.openPermissions(context);
  }

  void _copy() {
    HapticFeedback.mediumImpact();
    Clipboard.setData(
      ClipboardData(text: SessionScope.read(context).pairingCode),
    );
    _toast.show(appContent.v6.partner.copied, CameoIconName.check);
  }

  bool _typeDemo() {
    if (!mounted || _typing != null || _phase != _Phase.idle) return false;
    if (!CameoNav.isTop(context) || !_keypad.isAttached) return false;
    final target = appContent.demo.partnerCode;
    if (_code.isNotEmpty) setState(() => _code = '');
    var i = 0;
    void typeNext() {
      if (!mounted) return;
      _keypad.pressKey(target[i]);
      i++;
      if (i >= target.length) {
        _typing?.cancel();
        _typing = null;
      }
    }

    _typing = Timer.periodic(
      Duration(milliseconds: appContent.demo.keyIntervalMs),
      (_) => typeNext(),
    );
    typeNext();
    return true;
  }

  CodeBoxState get _boxState => switch (_phase) {
    _Phase.idle => CodeBoxState.active,
    _Phase.connecting => CodeBoxState.verifying,
    _Phase.success || _Phase.done => CodeBoxState.success,
  };

  @override
  Widget build(BuildContext context) {
    final content = labV6.partner;
    final session = SessionScope.of(context).session;
    final partner = _partner;
    return AuthScaffold(
      title: content.title,
      subtitle: content.subtitle,
      onBack: () => CameoNav.pop(context),
      trailingLabel: _onboarding ? appContent.v6.partner.skip : null,
      onTrailing: _skip,
      keypad: Keypad(
        onKey: _onKey,
        onDelete: _onDelete,
        disabled: _phase != _Phase.idle,
        dimmed: false,
        controller: _keypad,
      ),
      accessory: MyCodeCard(
        key: PartnerScreen.myCodeKey,
        code: SessionScope.read(context).pairingCode,
        onCopy: _copy,
      ),
      overlays: [
        Positioned(
          key: PartnerScreen.toastKey,
          left: 0,
          right: 0,
          bottom:
              keypadHeightOf(context) + CameoLayout.partnerV6MyCodeBlockHeight,
          child: ToastV6Host(
            controller: _toast,
            variant: ToastV6Variant.elevated,
          ),
        ),
        Positioned.fill(
          key: PartnerScreen.doneKey,
          child: partner == null
              ? const SizedBox.shrink()
              : ConnectDoneV6(
                  visible: _phase == _Phase.done,
                  myName: session.name ?? appContent.demo.name,
                  partnerName: partner.name,
                  partnerImage: SessionScope.read(context).usesBackend
                      ? ''
                      : labV6.connected.partnerPhoto,
                  onDone: _preset ? null : _onDone,
                ),
        ),
      ],
      child: CodeBox(
        key: PartnerScreen.codeKey,
        value: _code,
        state: _boxState,
        onComplete: _connect,
        accessibilityLabel: content.title,
      ),
    );
  }
}
