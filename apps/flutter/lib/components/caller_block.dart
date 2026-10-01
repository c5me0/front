// Caller identity and elapsed-time display. Timer units are time conversions rather
// than layout constants.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import '../content/app.g.dart';

import '../design_system/design_system.dart';

const Duration _second = Duration(seconds: 1);
const int _secondsPerMinute = 60;

const int _timeDigits = 2;
final RegExp _digits = RegExp(r'^\d+$');

enum CallerBlockVariant { regular, v1 }

int parseCallTime(String text) {
  var total = 0;
  for (final part in text.split(':')) {
    final t = part.trim();
    if (!_digits.hasMatch(t)) return 0;
    total = total * _secondsPerMinute + int.parse(t);
  }
  return total;
}

String formatCallTime(int totalSeconds) {
  final s = totalSeconds < 0 ? 0 : totalSeconds;
  final mm = (s ~/ _secondsPerMinute).toString().padLeft(_timeDigits, '0');
  final ss = (s % _secondsPerMinute).toString().padLeft(_timeDigits, '0');
  return '$mm:$ss';
}

double callerBlockTop(double topAreaBottom) =>
    topAreaBottom + CameoLayout.callerBlockOffsetBelowTopArea;

class CallerBlock extends StatefulWidget {
  const CallerBlock({
    super.key,
    required this.name,
    required this.startTime,
    this.variant = CallerBlockVariant.regular,
    this.running = true,
  });

  final String name;

  final String startTime;

  final CallerBlockVariant variant;

  final bool running;

  @override
  State<CallerBlock> createState() => _CallerBlockState();
}

class _CallerBlockState extends State<CallerBlock> {
  int _elapsed = 0;
  Timer? _ticker;

  bool _afterFirstFrame = false;

  @override
  void initState() {
    super.initState();

    final scheduler = WidgetsBinding.instance;
    scheduler.addPostFrameCallback((_) {
      if (!mounted) return;
      _afterFirstFrame = true;
      if (widget.running) _start();
    }, debugLabel: 'CallerBlock.start');
    scheduler.ensureVisualUpdate();
  }

  @override
  void didUpdateWidget(CallerBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.running != oldWidget.running && _afterFirstFrame) {
      widget.running ? _start() : _stop();
    }
  }

  void _start() {
    _stop();
    final base = _elapsed;

    _ticker = Timer.periodic(_second, (t) {
      if (mounted) setState(() => _elapsed = base + t.tick);
    });
  }

  void _stop() {
    _ticker?.cancel();
    _ticker = null;
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timer = formatCallTime(parseCallTime(widget.startTime) + _elapsed);
    // layout.callerBlock.$textStyles · $roles.text
    final color = CameoTheme.colorsOf(context).foregroundNeutralInverseBase;
    final timerStyle = switch (widget.variant) {
      CallerBlockVariant.regular =>
        CameoTextStyles.headingSm, // 2042:2495 18/26
      CallerBlockVariant.v1 => CameoTextStyles.bodyLg, // 2004:1816 16/22
    };
    return Semantics(
      container: true,
      label: fillTemplate(
        AppContent.of(context).v6.accessibility.callDuration,
        {'name': widget.name, 'time': timer},
      ),
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: CameoLayout.callerBlockPaddingX,
          vertical: CameoLayout.callerBlockPaddingY,
        ),

        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ExactLineBox(widget.name, CameoTextStyles.display, color),
            ExactLineBox(timer, timerStyle, color),
          ],
        ),
      ),
    );
  }
}

const TextHeightBehavior _evenLeading = TextHeightBehavior(
  leadingDistribution: TextLeadingDistribution.even,
);

double _baselineCorrection(LineMetrics metrics, double lineHeight) {
  final expected = lineHeight / 2 + (metrics.ascent - metrics.descent) / 2;
  final painted = (expected + 0.5).floorToDouble();
  return expected - painted;
}

class ExactLineBox extends StatelessWidget {
  const ExactLineBox(this.text, this.style, this.color, {super.key});

  final String text;
  final TextStyle style;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final lineHeight = scaler.scale(style.fontSize!) * style.height!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: cameoTextSpan(text, style),
          textAlign: TextAlign.center,
          textDirection: direction,
          textScaler: scaler,
          strutStyle: cameoStrutOf(style),
          textHeightBehavior: _evenLeading,
        )..layout(maxWidth: constraints.maxWidth);
        final metrics = painter.computeLineMetrics();
        painter.dispose();
        final lines = math.max(1, metrics.length);
        final shift = metrics.isEmpty
            ? 0.0
            : _baselineCorrection(metrics.first, lineHeight);
        return SizedBox(
          height: lines * lineHeight,
          child: OverflowBox(
            alignment: Alignment.topCenter,
            minHeight: 0,
            maxHeight: double.infinity,
            child: Transform.translate(
              offset: Offset(0, shift),
              child: CameoText(
                text,
                style: style,
                color: color,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      },
    );
  }
}
