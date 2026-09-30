// Responsive transcript title and date block using shared type metrics and padding.

import 'package:flutter/widgets.dart';

import '../design_system/design_system.dart';
import 'karaoke_text.dart' show KeepAllText;
import 'transcript_v6_line.dart' show transcriptV6Roles;

class TranscriptTitleV6 extends StatelessWidget {
  const TranscriptTitleV6({super.key, required this.title, required this.date});

  final String title;
  final String date;

  static const Key titleKey = ValueKey('transcriptTitleV6.title');
  static const Key dateKey = ValueKey('transcriptTitleV6.date');

  @override
  Widget build(BuildContext context) {
    final roles = transcriptV6Roles(CameoTheme.colorsOf(context));
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.all(
          CameoLayout.transcriptV6TitleBlockPadding,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: CameoLayout.transcriptV6TitleBlockGap,
          children: [
            Semantics(
              header: true,
              child: KeepAllText(
                title,
                key: titleKey,
                style: CameoTextStyles.headingLg,
                color: roles.title,
              ),
            ),
            KeepAllText(
              date,
              key: dateKey,
              style: CameoTextStyles.bodyMd,
              color: roles.date,
            ),
          ],
        ),
      ),
    );
  }
}
