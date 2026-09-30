// Transcript highlight card surfaces and text roles for the supported transcript tones.

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../content/lab.g.dart';
import '../design_system/design_system.dart';
import 'transcript_line.dart';

({Color fill, Color? border, Color line}) highlightCardRoles(
  CameoPalette c,
  TranscriptTone tone,
) => switch (tone) {
  TranscriptTone.light => (
    fill: c.backgroundNeutralSubtle,
    border: c.strokeNeutralBase,
    line: transcriptLineColor(c, TranscriptTone.light),
  ),
  TranscriptTone.dark => (
    fill: c.transcriptDarkCard,
    border: c.transcriptDarkCardBorder,
    line: transcriptLineColor(c, TranscriptTone.dark),
  ),
  TranscriptTone.darkToken => (
    fill: c.backgroundNeutralBase,
    border: null,
    line: c.foregroundNeutralSubtle,
  ),
};

typedef _CardSpec = ({
  double wrapperPadding,
  double paddingX,
  double paddingY,
  double gap,
  double radius,
  double borderWidth,
  CameoBlur blur,
});

///  - dark      highlightCard   · backgroundBlurStrong σ10 (16-12 v3: r5 → r20, CHANGES §2.2)

_CardSpec _cardSpec(TranscriptTone tone) => switch (tone) {
  TranscriptTone.light || TranscriptTone.dark => (
    wrapperPadding: CameoLayout.highlightCardWrapperPadding,
    paddingX: CameoLayout.highlightCardPaddingX,
    paddingY: CameoLayout.highlightCardPaddingY,
    gap: CameoLayout.highlightCardGap,
    radius: CameoLayout.highlightCardRadius,
    borderWidth: CameoLayout.highlightCardBorderWidth,
    blur: tone == TranscriptTone.light
        ? CameoBlur.backgroundBlur
        : CameoBlur.backgroundBlurStrong,
  ),
  TranscriptTone.darkToken => (
    wrapperPadding: CameoLayout.highlightCardV3WrapperPadding,
    paddingX: CameoLayout.highlightCardV3PaddingX,
    paddingY: CameoLayout.highlightCardV3PaddingY,
    gap: CameoLayout.highlightCardV3Gap,
    radius: CameoLayout.highlightCardV3Radius,
    borderWidth: CameoLayout.highlightCardV3BorderWidth,
    blur: CameoBlur.backgroundBlurStrong,
  ),
};

class HighlightCard extends StatelessWidget {
  const HighlightCard({
    super.key,
    required this.lines,
    this.tone = TranscriptTone.light,
    this.progress,
    this.progressValue,
    this.animated = true,
    this.onLinePress,
  });

  final List<TranscriptLineContent> lines;

  final TranscriptTone tone;

  final double? progress;

  final ValueListenable<double>? progressValue;

  final bool animated;

  final ValueChanged<TranscriptLineContent>? onLinePress;

  Widget _line(
    TranscriptLineContent line,
    Color color,
    ValueChanged<TranscriptLineContent>? onLinePress,
  ) {
    final text = TranscriptText(
      key: onLinePress == null ? ValueKey(line.id) : null,
      text: line.text,
      side: line.side,
      tone: tone,
      color: color,
      current: line.current,
      progress: line.current ? (progress ?? line.gradient?.solidUntil) : null,
      progressValue: line.current ? progressValue : null,
      animated: animated,
    );
    if (onLinePress == null) return text;
    return PressScale(
      key: ValueKey(line.id),
      onPress: () => onLinePress(line),
      accessibilityLabel: transcriptLineLabel(line.text),
      child: text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final roles = highlightCardRoles(CameoTheme.colorsOf(context), tone);
    final spec = _cardSpec(tone);
    final onLinePress = this.onLinePress;
    return SizedBox(
      width: double.infinity,
      // 2042:3249 col · items-start · p8
      child: Padding(
        padding: EdgeInsets.all(spec.wrapperPadding),
        child: BlurSurface(
          blur: spec.blur,
          tint: roles.fill,
          border: roles.border,
          borderWidth: spec.borderWidth,
          radius: spec.radius,
          padding: EdgeInsets.symmetric(
            horizontal: spec.paddingX,
            vertical: spec.paddingY,
          ),

          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: spec.gap,
            children: [
              for (final line in lines) _line(line, roles.line, onLinePress),
            ],
          ),
        ),
      ),
    );
  }
}
