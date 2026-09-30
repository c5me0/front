// Formatted phone-number display with animated digits. Keep the underlying value
// numeric and derive separators independently of input.

import 'package:flutter/widgets.dart';

import '../content/app.g.dart';
import '../content/lab.g.dart';
import '../design_system/design_system.dart';
import 'digit_entry.dart';
import 'text_field_v6.dart';

///  '' → '' · '010' → '010' · '0101' → '010-1' · '0101234' → '010-1234' · '01012345' → '010-1234-5' · '01012345678' → '010-1234-5678'
String formatPhone(String digits) {
  final d = digits.replaceAll(RegExp(r'[^0-9]'), '');
  final s = d.length > appContent.phone.maxDigits
      ? d.substring(0, appContent.phone.maxDigits)
      : d;
  if (s.length <= 3) return s;
  if (s.length <= 7) return '${s.substring(0, 3)}-${s.substring(3)}';
  return '${s.substring(0, 3)}-${s.substring(3, 7)}-${s.substring(7)}';
}

bool isValidPhone(String digits) =>
    RegExp(r'^[0-9]+$').hasMatch(digits) &&
    digits.length == appContent.phone.maxDigits &&
    digits.startsWith(appContent.phone.validPrefix);

String spokenDigits(String code) =>
    code.replaceAll(RegExp(r'[^0-9]'), '').split('').join(' ');

class _Glyph {
  _Glyph(this.id, this.char, {required this.animateIn});

  final int id;
  final String char;
  final bool animateIn;
  bool exiting = false;
}

///

class PhoneNumberField extends StatefulWidget {
  const PhoneNumberField({
    super.key,
    required this.value,
    this.focused = true,
    this.placeholder,
    this.prefix,
    this.accessibilityLabel = '전화번호',
  });

  final String value;

  final bool focused;

  /// null → labV6.phone.placeholder ('010-0000-0000')
  final String? placeholder;

  /// null → labV6.phone.prefix ('+82')
  final String? prefix;

  final String accessibilityLabel;

  static const Key numberKey = ValueKey('phoneNumberField.number');
  static const Key placeholderKey = ValueKey('phoneNumberField.placeholder');
  static const Key prefixKey = ValueKey('phoneNumberField.prefix');

  @override
  State<PhoneNumberField> createState() => _PhoneNumberFieldState();
}

class _PhoneNumberFieldState extends State<PhoneNumberField> {
  final List<_Glyph> _glyphs = [];
  int _nextId = 0;
  late String _formatted = formatPhone(widget.value);

  @override
  void initState() {
    super.initState();
    for (final ch in _formatted.split('')) {
      _glyphs.add(_Glyph(_nextId++, ch, animateIn: false));
    }
  }

  @override
  void didUpdateWidget(PhoneNumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = formatPhone(widget.value);
    if (next == _formatted) return;
    var prefix = 0;
    while (prefix < next.length &&
        prefix < _formatted.length &&
        next[prefix] == _formatted[prefix]) {
      prefix++;
    }
    final live = _glyphs.where((g) => !g.exiting).toList();
    for (final g in live.skip(prefix)) {
      g.exiting = true;
    }
    for (final ch in next.substring(prefix).split('')) {
      _glyphs.add(_Glyph(_nextId++, ch, animateIn: true));
    }
    _formatted = next;
  }

  void _remove(int id) {
    if (!mounted) return;
    setState(() => _glyphs.removeWhere((g) => g.id == id));
  }

  @override
  Widget build(BuildContext context) {
    final c = CameoTheme.colorsOf(context);
    final prefix = widget.prefix ?? labV6.phone.prefix;
    final placeholder = widget.placeholder ?? labV6.phone.placeholder;
    final empty = _formatted.isEmpty;
    final number = Row(
      key: PhoneNumberField.numberKey,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final g in _glyphs)
          EntryGlyph(
            key: ValueKey('phoneNumberField.glyph.${g.id}'),
            text: g.char,
            style: CameoTextStyles.bodyLg,
            color: c.foregroundNeutralBase,
            kind: g.char == '-'
                ? EntryGlyphKind.separator
                : EntryGlyphKind.digit,
            animateIn: g.animateIn,
            exiting: g.exiting,
            collapseOnExit: true,
            onExited: () => _remove(g.id),
          ),
      ],
    );
    return Semantics(
      textField: true,
      focused: widget.focused,
      label: widget.accessibilityLabel,
      value: '$prefix ${empty ? placeholder : _formatted}',
      excludeSemantics: true,
      child: TextFieldV6(
        variant: TextFieldV6Variant.phone,
        focused: widget.focused,
        children: [
          CameoText(
            prefix,
            key: PhoneNumberField.prefixKey,
            style: CameoTextStyles.bodyLg,
            color: c.foregroundNeutralBase,
            maxLines: 1,
          ),
          TextFieldV6Slot(
            child: ClipRect(
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  if (empty)
                    CameoText(
                      placeholder,
                      key: PhoneNumberField.placeholderKey,
                      style: CameoTextStyles.bodyLg,
                      color: c.foregroundNeutralSubtle,
                      maxLines: 1,
                    ),

                  SizedBox(
                    key: const ValueKey('phoneNumberField.numberBox'),
                    height: CameoLayout.textFieldV6PhoneHeight,
                    child: OverflowBox(
                      alignment: Alignment.centerLeft,
                      minWidth: 0,
                      maxWidth: double.infinity,
                      child: number,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
