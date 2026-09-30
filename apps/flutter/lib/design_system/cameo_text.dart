// Shared text rendering and fallback font metrics. Apply the specified strut so Korean
// fallback glyphs do not change the line-box height.

import 'package:flutter/widgets.dart';

import 'cameo_theme.dart';
import 'tokens.g.dart';

StrutStyle cameoStrutOf(TextStyle style) =>
    StrutStyle.fromTextStyle(style, forceStrutHeight: true);

bool cameoIsHangul(int rune) =>
    (rune >= 0xAC00 && rune <= 0xD7A3) ||
    (rune >= 0x1100 && rune <= 0x11FF) ||
    (rune >= 0x3130 && rune <= 0x318F) ||
    (rune >= 0xA960 && rune <= 0xA97F) ||
    (rune >= 0xD7B0 && rune <= 0xD7FF);

bool _drawnBySystemFont(int rune) =>
    !cameoIsHangul(rune) &&
    !(rune >= 0x2E80 && rune <= 0x9FFF) &&
    !(rune >= 0xF900 && rune <= 0xFAFF) &&
    !(rune >= 0xFE30 && rune <= 0xFE4F) &&
    !(rune >= 0xFF00 && rune <= 0xFFEF) &&
    rune <= 0xFFFF;

double cameoSystemTrackingOf(TextStyle style) {
  final table = CameoTextStyles.systemTracking;
  if (table.isEmpty) return 0;
  final size = style.fontSize;
  assert(
    size != null && table.containsKey(size),
    'CameoTextStyles.systemTracking 에 $size pt 가 없다 — CameoTextStyles 의 토큰 크기만 쓴다',
  );
  return table[size] ?? 0;
}

List<TextSpan> cameoTrackedRuns(String text, TextStyle style) {
  final tracking = cameoSystemTrackingOf(style);
  if (tracking == 0 || text.isEmpty) return [TextSpan(text: text)];
  final tracked = TextStyle(
    letterSpacing: (style.letterSpacing ?? 0) + tracking,
  );
  final runs = <TextSpan>[];
  final run = StringBuffer();
  bool? runIsSystem;
  for (final g in text.characters) {
    final system = _drawnBySystemFont(g.runes.first);
    if (runIsSystem != null && system != runIsSystem) {
      runs.add(
        TextSpan(text: run.toString(), style: runIsSystem ? tracked : null),
      );
      run.clear();
    }
    run.write(g);
    runIsSystem = system;
  }
  runs.add(
    TextSpan(text: run.toString(), style: runIsSystem! ? tracked : null),
  );
  return runs;
}

TextSpan cameoTextSpan(String text, TextStyle style) {
  final runs = cameoTrackedRuns(text, style);
  if (runs.length == 1) {
    final spacing = runs.single.style?.letterSpacing;
    return TextSpan(
      text: text,
      style: spacing == null ? style : style.copyWith(letterSpacing: spacing),
    );
  }
  return TextSpan(style: style, children: runs);
}

class CameoText extends StatelessWidget {
  const CameoText(
    this.text, {
    super.key,
    required this.style,
    this.color,
    this.maxLines,
    this.textAlign,
  });

  final String text;
  final TextStyle style;
  final Color? color;
  final int? maxLines;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final colored = style.copyWith(
      color: color ?? CameoTheme.colorsOf(context).foregroundNeutralBase,
    );
    return Text.rich(
      cameoTextSpan(text, colored),
      style: colored,
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
      textAlign: textAlign,
      strutStyle: cameoStrutOf(style),

      textHeightBehavior: const TextHeightBehavior(
        leadingDistribution: TextLeadingDistribution.even,
      ),
    );
  }
}
