// Verification-code input, resend timer, and success transition. Prototype flow
// playback may supply the demo code; normal verification follows the session service.

import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../components/auth_scaffold.dart';
import '../../components/code_box.dart';
import '../../components/keypad.dart';
import '../../components/sms_banner.dart';
import '../../components/solid_button.dart';
import '../../components/solid_cta.dart';
import '../../content/app.g.dart';
import '../../content/lab.g.dart';
import '../../design_system/design_system.dart';
import '../../navigation/navigation.dart';
import '../../state/session.dart';
import '../../api/api_error_text.dart';

enum _Phase { idle, autofilling, verifying, success, error }

String formatVerifyTimer(int seconds) {
  final s = seconds < 0 ? 0 : seconds;
  final m = (s ~/ 60).toString().padLeft(2, '0');
  final r = (s % 60).toString().padLeft(2, '0');
  return '$m:$r';
}

const Duration verifyTimerTick = Duration(seconds: 1);

class VerifyScreen extends StatefulWidget {
  const VerifyScreen({
    super.key,
    required this.phone,
    this.state = VerifyRouteState.input,
  });

  final String phone;

  final VerifyRouteState state;

  static const Key codeKey = ValueKey('verify.code');
  static const Key timerKey = ValueKey('verify.timer');
  static const Key errorKey = ValueKey('verify.error');
  static const Key resendKey = ValueKey('verify.resend');

  @override
  State<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends State<VerifyScreen> {
  late final bool _preset = widget.state == VerifyRouteState.success;
  late String _code = _preset ? appContent.verify.mockCode : '';
  late _Phase _phase = _preset ? _Phase.success : _Phase.idle;
  bool _bannerVisible = false;

  bool _errorVisible = false;
  String? _serverError;
  bool _resending = false;

  int _remaining = appContent.verify.timerSeconds;

  final KeypadController _keypad = KeypadController();
  Timer? _bannerTimer;
  Timer? _autofillTimer;
  Timer? _errorTimer;
  Timer? _countdown;
  late final VoidCallback _unregisterFlow;

  static int get _length => appContent.verify.codeLength;

  @override
  void initState() {
    super.initState();
    _unregisterFlow = FlowDemo.register(
      FlowDemoAction.verifyAutofill,
      _autofillFromDemo,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _preset) return;
      _scheduleBanner();
      _startCountdown();
    });
  }

  @override
  void dispose() {
    _unregisterFlow();
    _bannerTimer?.cancel();
    _autofillTimer?.cancel();
    _errorTimer?.cancel();
    _countdown?.cancel();
    super.dispose();
  }

  void _scheduleBanner() {
    if (SessionScope.read(context).usesBackend) return;
    _bannerTimer?.cancel();
    _bannerTimer = Timer(CameoMotion.smsBannerDelay, () {
      if (mounted) setState(() => _bannerVisible = true);
    });
  }

  void _startCountdown() {
    _countdown?.cancel();
    setState(() => _remaining = appContent.verify.timerSeconds);
    _countdown = Timer.periodic(verifyTimerTick, (t) {
      if (!mounted) return;
      setState(() => _remaining = _remaining > 0 ? _remaining - 1 : 0);
      if (_remaining == 0) t.cancel();
    });
  }

  void _onKey(String digit) {
    if (_phase != _Phase.idle || _code.length >= _length) return;
    setState(() {
      _code += digit;
      _errorVisible = false;
    });
  }

  void _onDelete() {
    if (_phase != _Phase.idle || _code.isEmpty) return;
    setState(() => _code = _code.substring(0, _code.length - 1));
  }

  bool _autofill() {
    if (!mounted || !_bannerVisible || _phase != _Phase.idle) return false;
    final code = appContent.verify.mockCode;
    var i = 1;
    setState(() {
      _bannerVisible = false;
      _errorVisible = false;
      _phase = _Phase.autofilling;
      _code = code[0];
    });
    _autofillTimer?.cancel();
    _autofillTimer = Timer.periodic(CameoMotion.codeInputAutofillInterval, (t) {
      if (!mounted) return;
      setState(() => _code += code[i]);
      i++;
      if (i >= code.length) {
        t.cancel();
        _autofillTimer = null;
      }
    });
    return true;
  }

  bool _autofillFromDemo() {
    if (!mounted || !CameoNav.isTop(context)) return false;
    return _autofill();
  }

  Future<void> _verify(String code) async {
    if (_phase == _Phase.verifying || _phase == _Phase.success) return;
    final session = SessionScope.read(context);
    setState(() => _phase = _Phase.verifying);
    bool ok;
    try {
      ok = await session.verifyCode(code, phone: widget.phone);
      _serverError = null;
    } catch (error) {
      ok = false;
      _serverError = apiErrorText(error);
    }
    if (!mounted) return;
    if (ok) {
      _countdown?.cancel();
      setState(() {
        _bannerVisible = false;
        _phase = _Phase.success;
      });
      await Future<void>.delayed(CameoMotion.authSuccessHold);
      if (!mounted) return;

      session.completeVerification(
        widget.phone,
        forceOnboarding: FlowDemo.isActive,
      );
      return;
    }

    setState(() {
      _phase = _Phase.error;
      _errorVisible = true;
    });
    _errorTimer?.cancel();
    _errorTimer = Timer(CameoMotion.shakeHold, () {
      if (!mounted) return;
      setState(() {
        _code = '';
        _phase = _Phase.idle;
      });
    });
  }

  Future<void> _resend() async {
    if (_phase != _Phase.idle || _resending) return;
    _resending = true;
    try {
      final session = SessionScope.read(context);
      if (session.usesBackend) await session.requestCode(widget.phone);
    } catch (error) {
      if (mounted) {
        setState(() {
          _serverError = apiErrorText(error);
          _errorVisible = true;
        });
      }
      return;
    } finally {
      _resending = false;
    }
    if (!mounted) return;
    setState(() {
      _bannerVisible = false;
      _errorVisible = false;
    });
    _startCountdown();
    _scheduleBanner();
  }

  CodeBoxState get _boxState => switch (_phase) {
    _Phase.idle || _Phase.autofilling => CodeBoxState.active,
    _Phase.verifying => CodeBoxState.verifying,
    _Phase.success => CodeBoxState.success,
    _Phase.error => CodeBoxState.error,
  };

  @override
  Widget build(BuildContext context) {
    final c = CameoTheme.colorsOf(context);
    final verify = labV6.verify;
    final v4 = appContent.verify;
    final code = v4.mockCode;
    return AuthScaffold(
      title: verify.title,
      subtitleWidget: Stack(
        children: [
          _Crossfade(
            key: const ValueKey('verify.timerLayer'),
            visible: !_errorVisible,
            child: CameoText(
              formatVerifyTimer(_remaining),
              key: VerifyScreen.timerKey,
              style: CameoTextStyles.bodyMd,
              color: c.foregroundNeutralMuted,
              maxLines: 1,
            ),
          ),
          Positioned.fill(
            key: const ValueKey('verify.errorLayer'),
            child: _Crossfade(
              visible: _errorVisible,
              live: true,
              child: CameoText(
                _serverError ?? appContent.v6.verify.error,
                key: VerifyScreen.errorKey,
                style: CameoTextStyles.bodyMd,
                color: c.systemRed,
                maxLines: 1,
              ),
            ),
          ),
        ],
      ),
      onBack: () => CameoNav.pop(context),
      footer: SolidCta(
        key: VerifyScreen.resendKey,
        variant: SolidButtonVariant.gray,
        label: verify.resend,
        busy: _phase != _Phase.idle,
        onPress: _resend,
      ),
      keypad: Keypad(
        onKey: _onKey,
        onDelete: _onDelete,
        disabled: _phase != _Phase.idle,
        dimmed: false,
        controller: _keypad,
      ),
      overlays: [
        if (!_preset)
          Positioned.fill(
            key: const ValueKey('verify.banner'),
            child: SmsBanner(
              visible: _bannerVisible,
              message: fillTemplate(v4.sms.body, {'code': code}),
              accessibilityLabel: fillTemplate(v4.sms.accessibilityLabel, {
                'code': code,
              }),
              onPress: _autofill,
              onDismiss: () {
                if (mounted) setState(() => _bannerVisible = false);
              },
            ),
          ),
      ],
      child: CodeBox(
        key: VerifyScreen.codeKey,
        value: _code,
        state: _boxState,
        onComplete: _preset ? null : _verify,
        accessibilityLabel: verify.title,
      ),
    );
  }
}

class _Crossfade extends StatelessWidget {
  const _Crossfade({
    super.key,
    required this.visible,
    this.live = false,
    required this.child,
  });

  final bool visible;
  final bool live;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      excluding: !visible,
      child: Semantics(
        liveRegion: live,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: CameoMotion.durationBase,
          curve: CameoMotion.easingStandard,
          child: child,
        ),
      ),
    );
  }
}
