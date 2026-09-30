// Active transcript lines interpolate ink color. The v6 presentation does not use the
// legacy karaoke gradient.

//

import 'package:flutter/widgets.dart';

import '../content/lab.g.dart';
import '../design_system/design_system.dart';
import 'karaoke_text.dart' show KeepAllText;
import 'transcript_line.dart' show transcriptLineLabel;

export 'transcript_line.dart' show transcriptLineLabel;

typedef TranscriptV6Roles = ({
  Color canvas,
  Color title,
  Color date,
  Color line,
  Color current,
  Color card,
});

TranscriptV6Roles transcriptV6Roles(CameoPalette c) => (
  canvas: c.backgroundCanvasNeutralStrong,
  title: c.foregroundNeutralBase,
  date: c.foregroundNeutralMuted,
  line: c.foregroundNeutralSubtle,
  current: c.foregroundNeutralBase,
  card: c.backgroundCanvasElevatedBase,
);

/// (RN `interpolateColor(clamp(t), [0, 1], [idle, ink])`).
Color transcriptV6InkColor(CameoPalette c, double ink) {
  final roles = transcriptV6Roles(c);
  return Color.lerp(roles.line, roles.current, ink.clamp(0.0, 1.0))!;
}

class TranscriptTextV6 extends StatefulWidget {
  const TranscriptTextV6({
    super.key,
    required this.text,
    this.side = LabAlign.left,
    required this.current,
  });

  final String text;

  final LabAlign side;

  final bool current;

  static Key keyFor(String id) => ValueKey('transcriptTextV6.$id');

  @override
  State<TranscriptTextV6> createState() => TranscriptTextV6State();
}

class TranscriptTextV6State extends State<TranscriptTextV6>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ink = AnimationController.unbounded(
    vsync: this,
    value: widget.current ? 1 : 0,
  );
  bool _reduce = false;

  double get ink => _ink.value;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    if (_reduce && _ink.isAnimating) _ink.value = widget.current ? 1 : 0;
  }

  @override
  void didUpdateWidget(TranscriptTextV6 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.current == widget.current) return;
    final target = widget.current ? 1.0 : 0.0;
    if (_reduce) {
      _ink.value = target;
    } else {
      _ink.springTo(
        target,
        CameoMotion.transcriptV6LineColorSpring,
        velocity: _ink.velocity,
      );
    }
  }

  @override
  void dispose() {
    _ink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = CameoTheme.colorsOf(context);
    final align = widget.side == LabAlign.right
        ? TextAlign.right
        : TextAlign.left;
    return Semantics(
      selected: widget.current,
      child: AnimatedBuilder(
        animation: _ink,
        builder: (context, _) => KeepAllText(
          widget.text,
          style: CameoTextStyles.transcriptLineV6,
          color: transcriptV6InkColor(c, _ink.value),
          textAlign: align,
        ),
      ),
    );
  }
}

class TranscriptLineV6 extends StatelessWidget {
  const TranscriptLineV6({
    super.key,
    required this.id,
    required this.text,
    this.side = LabAlign.left,
    required this.current,
    this.onPress,
  });

  final String id;
  final String text;
  final LabAlign side;
  final bool current;

  final VoidCallback? onPress;

  @override
  Widget build(BuildContext context) {
    final onPress = this.onPress;
    final text = TranscriptTextV6(
      key: TranscriptTextV6.keyFor(id),
      text: this.text,
      side: side,
      current: current,
    );
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: CameoLayout.transcriptV6LinePaddingX,
          vertical: CameoLayout.transcriptV6LinePaddingY,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: side == LabAlign.right
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (onPress == null)
              text
            else
              PressScale(
                onPress: onPress,
                accessibilityLabel: transcriptLineLabel(this.text),
                child: text,
              ),
          ],
        ),
      ),
    );
  }
}
