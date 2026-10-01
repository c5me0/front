// Settings copy and responsive block geometry shared by the screen and its layout
// tests.

import 'dart:math' as math;

import '../../components/onboarding_v6_layout.dart';
import '../../content/app.g.dart';
import '../../design_system/design_system.dart';
import '../../state/session.dart';

String settingsPhoneLine(String? digits, String prefix, String sample) {
  final phone = digits?.trim() ?? '';
  if (phone.startsWith('+')) return phone;
  final formatted = formatPhoneIntl(digits ?? '', prefix, sample);
  return formatted.isEmpty ? sample : formatted;
}

String settingsName(String? name, String fallback) {
  final value = name?.trim() ?? '';
  return value.isEmpty ? fallback : value;
}

enum SettingsSheetKind { logout, disconnect }

typedef SettingsSheetCopy = ({
  String title,
  String body,
  String confirm,
  String cancel,
});

SettingsSheetCopy settingsSheetCopy(
  SettingsSheetKind kind,
  String? partnerName,
) {
  final v6 = appContent.v6.settings;
  if (kind == SettingsSheetKind.logout) {
    final s = v6.logoutSheet;
    return (title: s.title, body: s.body, confirm: s.confirm, cancel: s.cancel);
  }
  final s = v6.disconnectSheet;
  return (
    title: fillTemplate(s.title, {'partner': partnerName?.trim() ?? ''}),
    body: s.body,
    confirm: s.confirm,
    cancel: s.cancel,
  );
}

String photoSheetVariantLabel(PhotoSheetVariant variant) =>
    variant == PhotoSheetVariant.multi
    ? appContent.v6.settings.sheetMulti
    : appContent.v6.settings.sheetInstant;

PhotoSheetVariant nextPhotoSheetVariant(PhotoSheetVariant variant) =>
    variant == PhotoSheetVariant.multi
    ? PhotoSheetVariant.instant
    : PhotoSheetVariant.multi;

typedef SettingsV6Block = ({String id, double top, double bottom});

/// RN `settingsV6Blocks`.
List<SettingsV6Block> settingsV6Blocks(
  double safeTop, {
  required bool partner,
  required int devRows,
  required int accountRows,
  bool billing = false,
}) {
  const label =
      CameoLayout.settingsV6SectionLabelHeight +
      CameoLayout.settingsV6SectionLabelGap;
  final blocks = <SettingsV6Block>[];
  var y =
      math.max(safeTop, CameoLayout.screenV6StatusBarHeight) +
      CameoLayout.settingsV6TitleRowHeight +
      CameoLayout.settingsV6ContentPadding;
  void push(String id, double h) {
    blocks.add((id: id, top: y, bottom: y + h));
    y += h + CameoLayout.settingsV6ContentGap;
  }

  push('profile', CameoLayout.settingsV6ProfileHeight);
  push(
    'partner',
    label +
        (partner
            ? CameoLayout.settingsV6PartnerHeight
            : CameoLayout.settingsV6ActionRowHeight),
  );
  push('notifications', label + 2 * CameoLayout.settingsV6ToggleRowHeight);
  if (billing) push('billing', label + CameoLayout.settingsV6ChevronRowHeight);
  push('developer', label + devRows * CameoLayout.settingsV6ChevronRowHeight);
  push('account', accountRows * CameoLayout.settingsV6ActionRowHeight);
  return blocks;
}
