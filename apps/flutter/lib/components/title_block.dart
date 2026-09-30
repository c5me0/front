// Transcript title and date roles for light, dark, and photo-backed variants.

import 'package:flutter/widgets.dart';

import '../design_system/design_system.dart';
import 'karaoke_text.dart';
import 'transcript_tone.dart';

export 'transcript_tone.dart' show TranscriptTone;

({Color title, Color subtitle}) titleBlockRoles(
  CameoPalette c,
  TranscriptTone tone,
) => switch (tone) {
  TranscriptTone.light || TranscriptTone.darkToken => (
    title: c.foregroundNeutralBase,
    subtitle: c.foregroundNeutralMuted,
  ),
  TranscriptTone.dark => (
    title: c.foregroundNeutralInverseBase,
    subtitle: c.foregroundNeutralInverseMuted,
  ),
};

class TitleBlock extends StatelessWidget {
  const TitleBlock({
    super.key,
    required this.title,
    required this.subtitle,
    this.tone = TranscriptTone.light,
  });

  final String title;

  final String subtitle;

  final TranscriptTone tone;

  @override
  Widget build(BuildContext context) {
    final roles = titleBlockRoles(CameoTheme.colorsOf(context), tone);
    return SizedBox(
      width: double.infinity,

      child: Padding(
        padding: const EdgeInsets.all(CameoLayout.titleBlockPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: CameoLayout.titleBlockGap,
          children: [
            Semantics(
              header: true,
              child: KeepAllText(
                title,
                style: CameoTextStyles.headingLg,
                color: roles.title,
              ),
            ),
            KeepAllText(
              subtitle,
              style: CameoTextStyles.bodyMd,
              color: roles.subtitle,
            ),
          ],
        ),
      ),
    );
  }
}
