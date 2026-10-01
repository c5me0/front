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
import '../../api/api_error_text.dart';
import '../../design_system/design_system.dart';
import '../../state/session.dart';
import '../../state/international_phone.dart';
import 'country_screen.dart';

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
  IsoCode _country = IsoCode.US;
  bool _countryInitialized = false;
  bool _sending = false;
  String? _error;

  final KeypadController _keypad = KeypadController();

  Timer? _typing;

  final List<VoidCallback> _unregisterFlow = [];

  String? get _phone => parseNationalPhone(_digits, _country)?.international;
  bool get _valid => _phone != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_countryInitialized) return;
    _countryInitialized = true;
    if (!SessionScope.read(context).usesBackend) {
      _country = IsoCode.KR;
    } else {
      final region =
          WidgetsBinding.instance.platformDispatcher.locale.countryCode;
      _country =
          IsoCode.values.where((value) => value.name == region).firstOrNull ??
          IsoCode.US;
    }
  }

  Future<void> _selectCountry() async {
    if (_sending) return;
    final country = await CameoNav.pushPage<IsoCode>(
      context,
      (_) => CountryScreen(selected: _country),
    );
    if (mounted && country != null) {
      setState(() {
        _country = country;
        _error = null;
      });
    }
  }

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
    setState(() => _digits = appendDigit(_digits, digit, 15));
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
    final phone = SessionScope.read(context).usesBackend ? _phone! : _digits;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await session.requestCode(phone);
    } catch (error) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = apiErrorText(error, copy: AppContent.of(context));
        });
      }
      return;
    }
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
    final target = AppContent.of(context).demo.phone;
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
      Duration(milliseconds: AppContent.of(context).demo.keyIntervalMs),
      (_) => typeNext(),
    );
    typeNext();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final c = LabV6.of(context).phone;
    return AuthScaffold(
      title: c.title,
      subtitle: c.subtitle,
      subtitleWidget: _error == null
          ? null
          : Semantics(
              liveRegion: true,
              child: CameoText(
                _error!,
                style: CameoTextStyles.bodyMd,
                color: CameoTheme.colorsOf(context).systemRed,
              ),
            ),
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
      child: PhoneNumberField(
        key: PhoneScreen.fieldKey,
        value: _digits,
        prefix: '+${callingCode(_country)}',
        placeholder: AppContent.of(context).v6.phone.numberPlaceholder,
        formattedValue: formatNationalPhone(_digits, _country),
        countryLabel: fillTemplate(
          AppContent.of(context).v6.phone.countryLabel,
          {'country': _country.name, 'code': callingCode(_country)},
        ),
        onSelectCountry: _sending ? null : _selectCountry,
      ),
    );
  }
}
