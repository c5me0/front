// Album metadata row using separate foreground roles for photo-backed and plain
// sections.

import 'package:flutter/widgets.dart';
import '../content/app.g.dart';

import '../content/lab.g.dart';
import '../design_system/design_system.dart';

typedef MetaRowRoles = ({Color text, Color icon, Color dot});

MetaRowRoles metaRowRoles(CameoPalette c, LabTone tone) => switch (tone) {
  LabTone.dark => (
    text: c.foregroundNeutralInverseMuted,
    icon: c.foregroundNeutralInverseMuted,
    dot: c.staticWhite,
  ),
  LabTone.light => (
    text: c.foregroundNeutralMuted,
    icon: c.foregroundNeutralMuted,
    dot: c.backgroundNeutralInverse,
  ),
};

String metaRowAccessibilityLabel(
  String label,
  AlbumStatsContent stats, {
  AppContent copy = appContent,
}) => fillTemplate(copy.v6.accessibility.albumStats, {
  'label': label,
  'photos': stats.photos,
  'calls': stats.calls,
});

class MetaRow extends StatelessWidget {
  const MetaRow({
    super.key,
    required this.label,
    required this.stats,
    this.tone = LabTone.dark,
  });

  final String label;

  final AlbumStatsContent stats;

  final LabTone tone;

  @override
  Widget build(BuildContext context) {
    final roles = metaRowRoles(CameoTheme.colorsOf(context), tone);
    Widget count(CameoIconName icon, String value) => Row(
      // 2042:2796 / 2800 row · gap 6 · items-center · hug
      mainAxisSize: MainAxisSize.min,
      children: [
        CameoIcon(
          icon,
          size: CameoLayout.metaRowCountIconSize,
          color: roles.icon,
        ),
        const SizedBox(width: CameoLayout.metaRowCountGap),
        CameoText(
          value,
          style: CameoTextStyles.bodyMd,
          color: roles.text,
          maxLines: 1,
        ),
      ],
    );

    return Semantics(
      container: true,
      label: metaRowAccessibilityLabel(
        label,
        stats,
        copy: AppContent.of(context),
      ),
      excludeSemantics: true,
      // 2042:2794 row · gap 8 · items-center · justify-center
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 2042:2795 flex-[1_0_0]
          Expanded(
            child: CameoText(
              label,
              style: CameoTextStyles.bodyMd,
              color: roles.text,
            ),
          ),
          const SizedBox(width: CameoLayout.metaRowGap),
          count(CameoIconName.photo, stats.photos),
          const SizedBox(width: CameoLayout.metaRowGap),
          // 2042:2799 2x2 · radius 999
          SizedBox.square(
            dimension: CameoLayout.metaRowDotSize,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: roles.dot,
                borderRadius: BorderRadius.circular(
                  CameoLayout.metaRowDotRadius,
                ),
              ),
            ),
          ),
          const SizedBox(width: CameoLayout.metaRowGap),
          count(CameoIconName.phone, stats.calls),
        ],
      ),
    );
  }
}
