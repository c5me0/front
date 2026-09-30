// Palette and typography scope for light and dark surfaces. Nested themes resolve
// component colors without changing application navigation.

import 'package:flutter/widgets.dart';

import 'tokens.g.dart';

///

class CameoTheme extends InheritedWidget {
  const CameoTheme({super.key, required this.mode, required super.child});

  final CameoColorMode mode;

  CameoPalette get palette => CameoPalette.of(mode);

  static CameoColorMode modeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CameoTheme>()?.mode ??
      CameoColorMode.light;

  /// RN `useTheme()` (colors · colorOf · linearGradientCss · karaokeOf · shadowStyle).
  static CameoPalette colorsOf(BuildContext context) =>
      CameoPalette.of(modeOf(context));

  @override
  bool updateShouldNotify(CameoTheme oldWidget) => mode != oldWidget.mode;
}
