// Text-only album section header for dates without a hero photo.

import 'package:flutter/widgets.dart';

import '../content/lab.g.dart';
import '../design_system/design_system.dart';
import 'meta_row.dart';

class TextHeader extends StatelessWidget {
  const TextHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.stats,
  });

  final String title;

  final String subtitle;

  final AlbumStatsContent stats;

  @override
  Widget build(BuildContext context) {
    // 2042:2857 col · justify-end · items-start · clip
    return ClipRect(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          CameoLayout.textHeaderPaddingX,
          CameoLayout.textHeaderPaddingTop,
          CameoLayout.textHeaderPaddingX,
          CameoLayout.textHeaderPaddingBottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: CameoText(
                title,
                style: CameoTextStyles.headingLg,
                color: CameoTheme.colorsOf(context).foregroundNeutralBase,
                maxLines: 1,
              ),
            ),
            const SizedBox(height: CameoLayout.textHeaderGap),
            MetaRow(label: subtitle, stats: stats, tone: LabTone.light),
          ],
        ),
      ),
    );
  }
}
