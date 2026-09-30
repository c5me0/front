// Describe the underlying surface tone to Liquid Glass. Bright canvases, photos, and
// dark camera surfaces use distinct tint compensation.

import 'package:flutter/widgets.dart';

import 'cameo_theme.dart';
import 'tokens.g.dart';

enum GlassBackdropTone {
  defaultTone,
  dark,
  light;

  static GlassBackdropTone fromToken(String value) => switch (value) {
    'dark' => GlassBackdropTone.dark,
    'default' => GlassBackdropTone.defaultTone,
    'light' => GlassBackdropTone.light,
    _ => throw ArgumentError.value(
      value,
      'value',
      "'default' | 'dark' | 'light'",
    ),
  };
}

class GlassBackdrop extends InheritedWidget {
  const GlassBackdrop({super.key, required this.tone, required super.child});

  final GlassBackdropTone tone;

  /// RN `useGlassBackdrop()`.
  static GlassBackdropTone of(BuildContext context) {
    final explicit = context
        .dependOnInheritedWidgetOfExactType<GlassBackdrop>()
        ?.tone;
    if (explicit != null) return explicit;
    return CameoTheme.modeOf(context) == CameoColorMode.dark
        ? GlassBackdropTone.dark
        : GlassBackdropTone.defaultTone;
  }

  @override
  bool updateShouldNotify(GlassBackdrop oldWidget) => tone != oldWidget.tone;
}
