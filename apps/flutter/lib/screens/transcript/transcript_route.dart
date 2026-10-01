// Select the light v6 transcript by default; legacy tone variants remain development-
// only routes.

import 'package:flutter/widgets.dart';

import '../../navigation/cameo_location.dart';
import '../../navigation/cameo_routes.dart';
import '../../navigation/route_params.dart';
import '../../navigation/status_bar.dart';
import 'transcript_screen.dart';
import 'live_transcript_screen.dart';

enum TranscriptVersion {
  v6,
  v3;

  static const String param = 'v';
  static const String v3Value = '3';

  static TranscriptVersion tryParse(String? raw) => raw == v3Value ? v3 : v6;

  static TranscriptVersion of(CameoLocation location) =>
      tryParse(location.param(param));
}

String transcriptV3Location(TranscriptTheme theme) => CameoLocation(
  CameoRoutes.transcriptPath,
  {'theme': theme.param, TranscriptVersion.param: TranscriptVersion.v3Value},
).toString();

CameoStatusBarStyle transcriptStatusBarFor(CameoLocation location) =>
    switch (TranscriptVersion.of(location)) {
      TranscriptVersion.v6 => CameoStatusBarStyle.darkContent,
      TranscriptVersion.v3 => CameoStatusBarStyle.lightContent,
    };

Widget transcriptScreenFor(CameoLocation location, {bool backend = false}) {
  if (backend && !CameoRoutes.demoOf(location) && TranscriptVersion.of(location) != TranscriptVersion.v3) {
    return LiveTranscriptScreen(callId: location.param('id'));
  }
  final theme = CameoRoutes.transcriptThemeOf(location);
  final demo = CameoRoutes.demoOf(location);
  return switch (TranscriptVersion.of(location)) {
    TranscriptVersion.v3 => TranscriptV3Screen(
      key: ValueKey('v3:${theme.param}${demo ? ':demo' : ''}'),
      theme: theme,
      demo: demo,
    ),
    TranscriptVersion.v6 => TranscriptScreen(
      key: ValueKey(demo ? 'v6:demo' : 'v6'),
      theme: theme,
      demo: demo,
    ),
  };
}
