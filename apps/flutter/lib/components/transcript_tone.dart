// Palette roles shared by transcript titles, lines, and highlight cards.

import '../content/lab.g.dart';

enum TranscriptTone {
  light,
  dark,
  darkToken;

  static TranscriptTone fromLab(LabTone tone) => switch (tone) {
    LabTone.light => TranscriptTone.light,
    LabTone.dark => TranscriptTone.dark,
  };
}
