// Select system status-bar glyph brightness for the active screen. The app does not
// draw a replacement status bar.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

enum CameoStatusBarStyle {
  lightContent(SystemUiOverlayStyle.light),
  darkContent(SystemUiOverlayStyle.dark);

  const CameoStatusBarStyle(this.overlay);

  final SystemUiOverlayStyle overlay;

  static CameoStatusBarStyle forBackground({required bool dark}) =>
      dark ? lightContent : darkContent;
}

///

class CameoStatusBar extends StatelessWidget {
  const CameoStatusBar({super.key, required this.style, required this.child});

  final CameoStatusBarStyle style;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: style.overlay,
      child: child,
    );
  }
}
