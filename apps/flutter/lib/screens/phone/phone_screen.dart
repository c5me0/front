// Phone-number entry and verification-code request. Keep input validation separate from
// displayed formatting.

import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../components/auth_scaffold.dart';
import '../../components/keypad.dart';
import '../../components/phone_number_field.dart';
import '../../components/solid_cta.dart';
import '../../content/app.g.dart';
import '../../content/lab.g.dart';
import '../../navigation/navigation.dart';
import '../../state/session.dart';

String appendDigit(String digits, String digit, [int? maxDigits]) =>
    digits.length >= (maxDigits ?? appContent.phone.maxDigits)
    ? digits
    : digits + digit;

String deleteDigit(String digits) =>
    digits.isEmpty ? digits : digits.substring(0, digits.length - 1);

class PhoneScreen extends StatefulWidget {
  const PhoneScreen({super.key});

  static const Key ctaKey = ValueKey('phone.cta');
  static const Key fieldKey = ValueKey('phone.field');

  @override
  State<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends State<PhoneScreen> {
  String _digits = '';
  bool _sending = false;

  final KeypadController _keypad = KeypadController();

  Timer? _typing;

  final List<VoidCallback> _unregisterFlow = [];

  bool get _valid => isValidPhone(_digits);

  @override
  void initState() {
    super.initState();
    _unregisterFlow
      ..add(FlowDemo.register(FlowDemoAction.phoneType, _typeDemo))
      ..add(FlowDemo.register(FlowDemoAction.phoneSubmit, _submitFromDemo));
  }

  @override
  void dispose() {
    for (final unregister in _unregisterFlow) {
      unregister();
    }
    _typing?.cancel();
    super.dispose();
  }

  void _onKey(String digit) {
    if (_sending) return;
    setState(() => _digits = appendDigit(_digits, digit));
  }

  void _onDelete() {
    if (_sending || _digits.isEmpty) return;
    setState(() => _digits = deleteDigit(_digits));
  }

  Future<void> _submit() async {
    if (!_valid || _sending || !CameoNav.isTop(context)) return;
    _typing?.cancel();
    _typing = null;
    final session = SessionScope.read(context);
    final phone = _digits;
    setState(() => _sending = true);
    await session.requestCode(phone);
    if (!mounted) return;
    if (!CameoNav.isTop(context)) {
      setState(() => _sending = false);
      return;
    }
    await CameoNav.openVerify(context, phone);
    if (mounted) setState(() => _sending = false);
  }

  bool _submitFromDemo() {
    if (!mounted || !_valid || _sending || !CameoNav.isTop(context)) {
      return false;
    }
    _submit();
    return true;
  }

  bool _typeDemo() {
    if (!mounted || _typing != null || _sending || !CameoNav.isTop(context)) {
      return false;
    }
    if (!_keypad.isAttached) return false;
    final target = appContent.demo.phone;
    if (_digits.isNotEmpty) setState(() => _digits = '');
    var i = 0;
    void typeNext() {
      if (!mounted) return;
      _keypad.pressKey(target[i]);
      i++;
      if (i >= target.length) {
        _typing?.cancel();
        _typing = null;
        FlowDemo.settle(FlowDemoAction.phoneType);
      }
    }

    _typing = Timer.periodic(
      Duration(milliseconds: appContent.demo.keyIntervalMs),
      (_) => typeNext(),
    );
    typeNext();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final c = labV6.phone;
    return AuthScaffold(
      title: c.title,
      subtitle: c.subtitle,
      onBack: () => CameoNav.pop(context),
      footer: SolidCta(
        key: PhoneScreen.ctaKey,
        label: c.cta,
        enabled: _valid,
        busy: _sending,
        onPress: _submit,
      ),
      keypad: Keypad(
        onKey: _onKey,
        onDelete: _onDelete,
        disabled: _sending,
        controller: _keypad,
      ),
      child: PhoneNumberField(key: PhoneScreen.fieldKey, value: _digits),
    );
  }
}
