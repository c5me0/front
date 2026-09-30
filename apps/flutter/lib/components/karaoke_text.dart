// Progressive text highlighting without splitting grapheme clusters. Word-joiner
// handling preserves intended line breaks; masks use alpha rather than color.

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../content/lab.g.dart';
import '../design_system/design_system.dart';

({Color opaque, Color clear}) _maskColors(CameoPalette c) => (
  opaque: c.staticWhite.withValues(alpha: 1),
  clear: c.staticWhite.withValues(alpha: 0),
);

const String _wordJoiner = '⁠';

bool _isHangul(String grapheme) => cameoIsHangul(grapheme.runes.first);

bool _isSpace(String grapheme) => grapheme.trim().isEmpty;

TextSpan keepAllSpan(String text, {required TextStyle style}) {
  final children = <InlineSpan>[];
  final run = StringBuffer();
  void flush() {
    if (run.isEmpty) return;
    children.addAll(cameoTrackedRuns(run.toString(), style));
    run.clear();
  }

  String? prev;
  for (final g in text.characters) {
    if (prev != null &&
        !_isSpace(prev) &&
        !_isSpace(g) &&
        (_isHangul(prev) || _isHangul(g))) {
      flush();
      children.add(
        const TextSpan(text: _wordJoiner, style: TextStyle(letterSpacing: 0)),
      );
    }
    run.write(g);
    prev = g;
  }
  flush();
  return TextSpan(children: children);
}

class KeepAllText extends StatelessWidget {
  const KeepAllText(
    this.text, {
    super.key,
    required this.style,
    required this.color,
    this.textAlign = TextAlign.left,
  });

  final String text;

  final TextStyle style;

  final Color color;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      keepAllSpan(text, style: style),
      style: style.copyWith(color: color),
      textAlign: textAlign,
      strutStyle: cameoStrutOf(style),
      textWidthBasis: TextWidthBasis.longestLine,
      textHeightBehavior: const TextHeightBehavior(
        leadingDistribution: TextLeadingDistribution.even,
      ),
      semanticsLabel: text,
    );
  }
}

typedef KaraokeFadeRange = ({double solidUntil, double clearFrom});

KaraokeFadeRange karaokeFadeRange(double progress, CameoKaraokeSpec karaoke) =>
    (
      solidUntil: progress,
      clearFrom: progress + (karaoke.fadeEnd - karaoke.fadeStart),
    );

class KaraokeText extends StatefulWidget {
  const KaraokeText(
    this.text, {
    super.key,
    required this.style,
    required this.karaoke,
    this.align = LabAlign.left,
    this.progress,
    this.progressValue,
    this.animated = true,
  });

  final String text;

  final TextStyle style;

  final CameoKaraokeSpec karaoke;

  final LabAlign align;

  final double? progress;

  final ValueListenable<double>? progressValue;

  final bool animated;

  double get _target => progress ?? karaoke.fadeStart;

  @override
  State<KaraokeText> createState() => KaraokeTextState();
}

class KaraokeTextState extends State<KaraokeText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progress;

  @override
  void initState() {
    super.initState();
    _progress = AnimationController.unbounded(
      vsync: this,
      value: widget._target,
    );
  }

  @visibleForTesting
  double get shownProgress => (widget.progressValue ?? _progress).value;

  @override
  void didUpdateWidget(covariant KaraokeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    final target = widget._target;
    if (target == oldWidget._target) return;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (!widget.animated || reduceMotion) {
      _progress.value = target;
    } else {
      _progress.springTo(
        target,
        CameoMotion.scrubberSeekSpring,
        velocity: _progress.velocity,
      );
    }
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  Shader _mask(Rect bounds, double progress, ({Color opaque, Color clear}) m) {
    final r = karaokeFadeRange(progress, widget.karaoke);
    final from = bounds.left + bounds.width * r.solidUntil;
    final to = bounds.left + bounds.width * r.clearFrom;
    return ui.Gradient.linear(
      Offset(from, bounds.top),

      Offset(to > from ? to : from + 1, bounds.top),
      [m.opaque, m.clear],
    );
  }

  @override
  Widget build(BuildContext context) {
    final textAlign = widget.align == LabAlign.right
        ? TextAlign.right
        : TextAlign.left;
    final ValueListenable<double> progress = widget.progressValue ?? _progress;
    final mask = _maskColors(CameoTheme.colorsOf(context));

    return Stack(
      fit: StackFit.passthrough,
      children: [
        KeepAllText(
          widget.text,
          style: widget.style,
          color: widget.karaoke.base,
          textAlign: textAlign,
        ),
        ExcludeSemantics(
          child: AnimatedBuilder(
            animation: progress,
            builder: (context, child) => ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (bounds) => _mask(bounds, progress.value, mask),
              child: child,
            ),
            child: KeepAllText(
              widget.text,
              style: widget.style,
              color: widget.karaoke.ink,
              textAlign: textAlign,
            ),
          ),
        ),
      ],
    );
  }
}
