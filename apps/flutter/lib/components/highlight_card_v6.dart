// Light v6 transcript highlight card. Read geometry and typography from transcriptV6
// tokens.

import 'package:flutter/widgets.dart';

import '../content/lab.g.dart';
import '../design_system/design_system.dart';
import 'transcript_v6_line.dart';

typedef HighlightCardV6Line = ({
  String id,
  String text,
  LabAlign side,
  bool current,
});

class HighlightCardV6 extends StatelessWidget {
  const HighlightCardV6({super.key, required this.lines, this.onLinePress});

  final List<HighlightCardV6Line> lines;

  final ValueChanged<HighlightCardV6Line>? onLinePress;

  static const Key cardKey = ValueKey('highlightCardV6.card');

  @override
  Widget build(BuildContext context) {
    final roles = transcriptV6Roles(CameoTheme.colorsOf(context));
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        CameoLayout.transcriptV6CardWrapperPaddingX,
        CameoLayout.transcriptV6CardWrapperPaddingTop,
        CameoLayout.transcriptV6CardWrapperPaddingX,
        CameoLayout.transcriptV6CardWrapperPaddingBottom,
      ),
      child: DecoratedBox(
        key: cardKey,
        decoration: ShapeDecoration(
          color: roles.card,
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(
              CameoLayout.transcriptV6CardRadius,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: CameoLayout.transcriptV6CardPaddingX,
            vertical: CameoLayout.transcriptV6CardPaddingY,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: CameoLayout.transcriptV6CardGap,
            children: [for (final line in lines) _line(line)],
          ),
        ),
      ),
    );
  }

  Widget _line(HighlightCardV6Line line) {
    final text = TranscriptTextV6(
      key: TranscriptTextV6.keyFor(line.id),
      text: line.text,
      side: line.side,
      current: line.current,
    );
    final onLinePress = this.onLinePress;
    if (onLinePress == null) return text;
    return PressScale(
      onPress: () => onLinePress(line),
      accessibilityLabel: transcriptLineLabel(line.text),
      child: text,
    );
  }
}
