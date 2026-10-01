import 'package:phone_numbers_parser/phone_numbers_parser.dart';

export 'package:phone_numbers_parser/phone_numbers_parser.dart' show IsoCode;

/// The selected region determines national-prefix handling, including countries
/// that retain a leading zero. API calls receive only canonical E.164 numbers.
PhoneNumber? parseNationalPhone(String input, IsoCode region) {
  if (!RegExp(r'^\+?[0-9\s().-]+$').hasMatch(input)) return null;
  try {
    final phone = PhoneNumber.parse(input, callerCountry: region);
    if (!phone.isValid() || phone.international.length > 16) return null;
    return phone;
  } catch (_) {
    return null;
  }
}

String callingCode(IsoCode region) =>
    PhoneNumber(isoCode: region, nsn: '').countryCode;

String formatNationalPhone(String digits, IsoCode region) {
  if (digits.isEmpty) return '';
  try {
    return PhoneNumber.parse(
      digits,
      callerCountry: region,
    ).formatNsn(format: NsnFormat.national);
  } catch (_) {
    return digits;
  }
}
