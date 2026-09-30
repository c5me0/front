// Pure responsive geometry for authentication, onboarding, and settings. Derive widths
// from available space and preserve the reference aspect ratios and safe-area rules.

import 'dart:math' as math;

import '../design_system/design_system.dart';

double authV6NavTop(double safeTop) =>
    math.max(safeTop, CameoLayout.authV6NavTop);

double authV6HeaderTop(double safeTop) =>
    authV6NavTop(safeTop) + CameoLayout.authV6NavHeight;

double authV6HomeInset(double safeBottom) =>
    math.max(safeBottom, CameoLayout.screenV6HomeIndicatorHeight);

double keypadV6Height(double safeBottom) =>
    CameoLayout.keypadV6RowCount * CameoLayout.keypadV6RowHeight +
    (CameoLayout.keypadV6RowCount - 1) * CameoLayout.keypadV6RowGap +
    math.max(safeBottom, CameoLayout.keypadV6BottomInset);

double keypadV6CellWidth(double width) => math.max(
  0,
  (width - 2 * CameoLayout.keypadV6PaddingX) / CameoLayout.keypadV6Columns,
);

const String keypadDeleteKey = 'delete';

const List<List<String?>> keypadV6Rows = [
  ['1', '2', '3'],
  ['4', '5', '6'],
  ['7', '8', '9'],
  [null, '0', keypadDeleteKey],
];

({double x, double y, double width, double height}) keypadV6KeyFrame(
  int row,
  int col,
  double width,
) {
  final w = keypadV6CellWidth(width);
  return (
    x: CameoLayout.keypadV6PaddingX + col * w,
    y: row * (CameoLayout.keypadV6RowHeight + CameoLayout.keypadV6RowGap),
    width: w,
    height: CameoLayout.keypadV6RowHeight,
  );
}

/// RN `authV6FooterBottom`.
double authV6FooterBottom(double safeBottom, {required bool hasKeypad}) =>
    (hasKeypad ? keypadV6Height(safeBottom) : authV6HomeInset(safeBottom)) +
    CameoLayout.authV6CtaGapAbove;

double keyboardFooterLiftV6(double keyboardHeight, double safeBottom) =>
    math.max(0, keyboardHeight - authV6HomeInset(safeBottom));

int get codeBoxV6SlotCount => CameoLayout.codeBoxV6SlotCount.round();

double codeBoxSlotWidth(double boxWidth, [int? count]) {
  final n = count ?? codeBoxV6SlotCount;
  if (n <= 0) return 0;
  return math.max(
    0,
    (boxWidth -
            2 * CameoLayout.codeBoxV6BorderWidth -
            2 * CameoLayout.codeBoxV6Padding -
            (n - 1) * CameoLayout.codeBoxV6Gap) /
        n,
  );
}

double codeBoxSlotX(int index, double boxWidth, [int? count]) =>
    CameoLayout.codeBoxV6BorderWidth +
    CameoLayout.codeBoxV6Padding +
    index * (codeBoxSlotWidth(boxWidth, count) + CameoLayout.codeBoxV6Gap);

Duration codeBoxClearDelay(int index, int lengthBefore, Duration interval) =>
    interval * math.max(0, lengthBefore - 1 - index);

Duration codeBoxCheckDelay(int index, Duration stagger) =>
    stagger * math.max(0, index);

const List<List<double>> _welcomeColumns = [
  CameoLayout.welcomeV6TilesColumn1,
  CameoLayout.welcomeV6TilesColumn2,
  CameoLayout.welcomeV6TilesColumn3,
];

int get welcomeColumnCount => _welcomeColumns.length;

double welcomeTileWidth(double width) => math.max(
  0,
  (width +
          2 * CameoLayout.welcomeV6TilesBleedX -
          2 * CameoLayout.welcomeV6TilesGap) /
      3,
);

double welcomeColumnLeft(int column, double width) =>
    -CameoLayout.welcomeV6TilesBleedX +
    column * (welcomeTileWidth(width) + CameoLayout.welcomeV6TilesGap);

double welcomeColumnTop(int column) {
  final offsets = CameoLayout.welcomeV6TilesColumnOffsets;
  return CameoLayout.welcomeV6TilesStartY +
      (column >= 0 && column < offsets.length ? offsets[column] : 0);
}

List<double> welcomeTileHeights(int column, double width) {
  final scale = welcomeTileWidth(width) / CameoLayout.welcomeV6TilesWidth;
  if (column < 0 || column >= _welcomeColumns.length) return const [];
  return [for (final h in _welcomeColumns[column]) h * scale];
}

double welcomeLoopLength(int column, double width) {
  final hs = welcomeTileHeights(column, width);
  return hs.fold<double>(0, (a, h) => a + h) +
      hs.length * CameoLayout.welcomeV6TilesGap;
}

/// RN `welcomeTileCount`.
int welcomeTileCount(int column, double width, double height) {
  final hs = welcomeTileHeights(column, width);
  if (hs.isEmpty) return 0;
  final need =
      welcomeLoopLength(column, width) + height - welcomeColumnTop(column);
  var y = 0.0;
  var n = 0;
  while (y < need) {
    y += hs[n % hs.length] + CameoLayout.welcomeV6TilesGap;
    n += 1;
  }
  return n;
}

int welcomeDirection(int column) => column % 2 == 1 ? -1 : 1;

double welcomeColumnTranslate(
  double elapsedMs,
  int direction,
  double loopLength,
  double speed,
) {
  if (loopLength <= 0) return 0;
  final s = direction * speed * elapsedMs / 1000;
  final m = ((s % loopLength) + loopLength) % loopLength;
  return m == 0 ? 0 : -m;
}

double welcomeNavHeight(double safeBottom) =>
    CameoLayout.welcomeV6BottomNavPaddingTop +
    CameoLayout.solidButtonV6LgHeight +
    authV6HomeInset(safeBottom);

({double top, double bottom}) welcomeTextBlock(
  double safeTop,
  double safeBottom,
) => (
  top: math.max(safeTop, CameoLayout.screenV6StatusBarHeight),
  bottom: welcomeNavHeight(safeBottom),
);

double connectDoneGroupTop(
  double safeTop,
  double screenHeight,
  double safeBottom,
) {
  final top = math.max(safeTop, CameoLayout.screenV6StatusBarHeight);
  final bottom = screenHeight - authV6HomeInset(safeBottom);
  return (top + bottom - CameoLayout.connectDoneV6GroupHeight) / 2;
}

double connectDoneAvatarX(int side, double p) =>
    side *
    ((CameoLayout.connectDoneV6AvatarSize -
                CameoLayout.connectDoneV6AvatarOverlap) /
            2 +
        CameoLayout.connectDoneV6AvatarTravel * (1 - p));

({double left, double width}) iosSwitchKnobFrame(
  double p,
  double q,
  double pressStretch,
) {
  final width =
      CameoLayout.settingsV6SwitchKnobWidth * (1 + (pressStretch - 1) * q);
  final left =
      CameoLayout.settingsV6SwitchInset +
      (CameoLayout.settingsV6SwitchWidth -
              2 * CameoLayout.settingsV6SwitchInset -
              width) *
          p;
  return (left: left, width: width);
}

List<int> _intlGroups(String sample) =>
    sample.split(' ').skip(1).map((g) => g.length).toList();

String formatPhoneIntl(String digits, String prefix, String sample) {
  final d = digits.replaceAll(RegExp(r'\D'), '').replaceFirst(RegExp('^0'), '');
  if (d.isEmpty) return '';
  final groups = _intlGroups(sample);
  final parts = <String>[];
  var i = 0;
  for (var g = 0; g < groups.length && i < d.length; g++) {
    final end = g == groups.length - 1
        ? d.length
        : math.min(d.length, i + groups[g]);
    parts.add(d.substring(i, end));
    i = end;
  }
  if (i < d.length) parts.add(d.substring(i));
  return [prefix, ...parts].join(' ');
}
