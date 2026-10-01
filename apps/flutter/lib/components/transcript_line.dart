// Transcript line roles and active/inactive text styling.

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../content/app.g.dart';

import '../content/lab.g.dart';
import '../design_system/design_system.dart';
import 'karaoke_text.dart';
import 'transcript_tone.dart';

export 'transcript_tone.dart' show TranscriptTone;

Color transcriptLineColor(CameoPalette c, TranscriptTone tone) =>
    switch (tone) {
      TranscriptTone.light => c.foregroundNeutralSubtle,
      TranscriptTone.dark => c.transcriptDarkLine,
      TranscriptTone.darkToken => c.foregroundNeutralMuted,
    };

CameoKaraokeSpec transcriptKaraoke(CameoPalette c, TranscriptTone tone) =>
    switch (tone) {
      TranscriptTone.light => c.gradients.karaokeLight,
      TranscriptTone.dark => c.gradients.karaokeDark,
      TranscriptTone.darkToken => c.gradients.karaokeDarkToken,
    };

final RegExp _hardBreak = RegExp(r'\s*\n\s*');

String transcriptLineLabel(String text, {AppContent copy = appContent}) =>
    fillTemplate(copy.v6.accessibility.seekTranscript, {
      'text': text.replaceAll(_hardBreak, ' '),
    });

class TranscriptText extends StatelessWidget {
  const TranscriptText({
    super.key,
    required this.text,
    this.side = LabAlign.left,
    this.tone = TranscriptTone.light,
    this.color,
    this.karaoke,
    this.current = false,
    this.progress,
    this.progressValue,
    this.animated = true,
  });

  final String text;

  final LabAlign side;

  final TranscriptTone tone;

  final CameoKaraokeSpec? karaoke;

  final Color? color;

  final bool current;

  final double? progress;

  final ValueListenable<double>? progressValue;

  final bool animated;

  @override
  Widget build(BuildContext context) {
    final palette = CameoTheme.colorsOf(context);
    if (current) {
      return KaraokeText(
        text,
        style: CameoTextStyles.transcriptLine,
        karaoke: karaoke ?? transcriptKaraoke(palette, tone),
        align: side,
        progress: progress,
        progressValue: progressValue,
        animated: animated,
      );
    }
    return KeepAllText(
      text,
      style: CameoTextStyles.transcriptLine,
      color: color ?? transcriptLineColor(palette, tone),
      textAlign: side == LabAlign.right ? TextAlign.right : TextAlign.left,
    );
  }
}

class TranscriptLine extends StatelessWidget {
  const TranscriptLine({
    super.key,
    required this.text,
    this.side = LabAlign.left,
    this.tone = TranscriptTone.light,
    this.color,
    this.karaoke,
    this.current = false,
    this.progress,
    this.progressValue,
    this.animated = true,
    this.onPress,
    this.accessibilityLabel,
  });

  final String text;

  final LabAlign side;

  final TranscriptTone tone;

  final Color? color;

  final CameoKaraokeSpec? karaoke;

  final bool current;

  final double? progress;

  final ValueListenable<double>? progressValue;

  final bool animated;

  final VoidCallback? onPress;

  final String? accessibilityLabel;

  @override
  Widget build(BuildContext context) {
    final onPress = this.onPress;
    // 2042:3245 col · items-start|end · justify-center · px16 py8
    final row = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: CameoLayout.transcriptLinePaddingX,
        vertical: CameoLayout.transcriptLinePaddingY,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: side == LabAlign.right
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          TranscriptText(
            text: text,
            side: side,
            tone: tone,
            color: color,
            karaoke: karaoke,
            current: current,
            progress: progress,
            progressValue: progressValue,
            animated: animated,
          ),
        ],
      ),
    );
    return SizedBox(
      width: double.infinity,

      child: onPress == null
          ? row
          : PressScale(
              onPress: onPress,
              accessibilityLabel:
                  accessibilityLabel ??
                  transcriptLineLabel(text, copy: AppContent.of(context)),
              child: row,
            ),
    );
  }
}
