// Transcript quote card and its combined screen-reader label.

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../content/lab.g.dart';
import '../design_system/design_system.dart';
import 'karaoke_text.dart';

String quoteCardLabel(QuoteCardContent card) =>
    [card.label, for (final l in card.lines) l.text].join(', ');

class QuoteCard extends StatelessWidget {
  const QuoteCard({
    super.key,
    required this.card,
    this.progress,
    this.progressValue,
    this.animated = true,
    this.onPress,
    this.accessibilityLabel,
  });

  final QuoteCardContent card;

  final double? progress;

  final ValueListenable<double>? progressValue;

  final bool animated;

  final ValueChanged<QuoteCardContent>? onPress;

  final String? accessibilityLabel;

  @override
  Widget build(BuildContext context) {
    final onPress = this.onPress;
    final palette = CameoTheme.colorsOf(context);
    final surface = Stack(
      fit: StackFit.passthrough,
      children: [
        BlurSurface(
          tint: palette.quoteCardFill,
          radius: CameoLayout.quoteCardRadius,
          padding: const EdgeInsets.all(CameoLayout.quoteCardPadding),

          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: CameoLayout.quoteCardGap,
            children: [
              Align(
                alignment: card.labelAlign == LabAlign.right
                    ? AlignmentDirectional.centerEnd
                    : AlignmentDirectional.centerStart,
                child: CameoText(
                  card.label,
                  style: CameoTextStyles.bodySm,
                  color: palette.quoteCardLabel,
                  maxLines: 1,
                ),
              ),
              for (final line in card.lines)
                if (line.gradient case final gradient?)
                  KaraokeText(
                    line.text,
                    key: ValueKey(line.nodeId),
                    style: CameoTextStyles.quote,
                    karaoke: palette.gradients.karaokeQuote,
                    align: line.align,
                    progress: progress ?? gradient.solidUntil,
                    progressValue: progressValue,
                    animated: animated,
                  )
                else
                  // 2015:1957
                  KeepAllText(
                    line.text,
                    key: ValueKey(line.nodeId),
                    style: CameoTextStyles.quote,
                    color: palette.quoteCardLine,
                    textAlign: line.align == LabAlign.right
                        ? TextAlign.right
                        : TextAlign.left,
                  ),
            ],
          ),
        ),

        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: ShapeDecoration(
                shape: RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.circular(
                    CameoLayout.quoteCardRadius,
                  ),
                  side: BorderSide(
                    color: palette.quoteCardBorder,
                    width: CameoLayout.quoteCardBorderWidth,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
    return SizedBox(
      width: double.infinity,

      child: onPress == null
          ? surface
          : PressScale(
              onPress: () => onPress(card),
              accessibilityLabel: accessibilityLabel ?? quoteCardLabel(card),
              child: surface,
            ),
    );
  }
}
