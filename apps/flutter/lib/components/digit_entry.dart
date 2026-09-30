// Shared digit and separator entry/exit motion for phone and verification fields. Use
// token durations and spring parameters.

import 'dart:async';

import 'package:flutter/widgets.dart';

import '../design_system/design_system.dart';

enum EntryGlyphKind { digit, separator }

///

class EntryGlyph extends StatefulWidget {
  const EntryGlyph({
    super.key,
    required this.text,
    required this.style,
    this.color,
    this.kind = EntryGlyphKind.digit,
    this.animateIn = true,
    this.exiting = false,
    this.exitDelay = Duration.zero,
    this.collapseOnExit = false,
    this.onExited,
  });

  final String text;

  final TextStyle style;

  /// null → `foreground/neutral/base`
  final Color? color;
  final EntryGlyphKind kind;

  final bool animateIn;

  final bool exiting;

  final Duration exitDelay;

  final bool collapseOnExit;

  final VoidCallback? onExited;

  @override
  State<EntryGlyph> createState() => EntryGlyphState();
}

class EntryGlyphState extends State<EntryGlyph> with TickerProviderStateMixin {
  late final bool _enterDigit =
      widget.animateIn && widget.kind == EntryGlyphKind.digit;
  late final bool _enterSeparator =
      widget.animateIn && widget.kind == EntryGlyphKind.separator;

  late final AnimationController _scale = AnimationController.unbounded(
    vsync: this,
    value: _enterDigit ? CameoMotion.digitEntryScaleFrom : 1,
  );

  late final AnimationController _rise = AnimationController.unbounded(
    vsync: this,
    value: _enterDigit ? 1 : 0,
  );

  late final AnimationController _fade = AnimationController.unbounded(
    vsync: this,
    value: _enterDigit || _enterSeparator ? 0 : 1,
  );

  late final AnimationController _exit = AnimationController.unbounded(
    vsync: this,
  );
  late final Listenable _all = Listenable.merge([_scale, _rise, _fade, _exit]);

  bool _started = false;
  bool _reduceMotion = false;
  Timer? _exitTimer;
  bool _exitStarted = false;

  double get scale => _reduceMotion
      ? 1
      : _scale.value *
            (1 -
                (1 - CameoMotion.digitEntryScaleFrom) *
                    _exit.value.clamp(0.0, 1.0));

  double get opacity =>
      _fade.value.clamp(0.0, 1.0) * (1 - _exit.value.clamp(0.0, 1.0));

  double get dy => _reduceMotion ? 0 : CameoMotion.digitEntryRise * _rise.value;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (_started) return;
    _started = true;
    if (widget.animateIn) _enter();
    if (widget.exiting) _scheduleExit();
  }

  @override
  void didUpdateWidget(EntryGlyph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.exiting && !oldWidget.exiting) _scheduleExit();
  }

  void _enter() {
    if (_reduceMotion) {
      _scale.value = 1;
      _rise.value = 0;
      _fade.value = 0;
      _fade.animateTo(
        1,
        duration: CameoMotion.durationFast,
        curve: CameoMotion.easingStandard,
      );
      return;
    }
    if (_enterDigit) {
      _scale.springTo(1, CameoMotion.digitEntrySpring);
      _rise.springTo(0, CameoMotion.digitEntryRiseSpring);
    }
    _fade.animateTo(
      1,
      duration: CameoMotion.durationFast,
      curve: CameoMotion.easingStandard,
    );
  }

  void _scheduleExit() {
    if (_exitStarted) return;
    _exitStarted = true;
    if (widget.exitDelay == Duration.zero) {
      _runExit();
    } else {
      _exitTimer = Timer(widget.exitDelay, _runExit);
    }
  }

  void _runExit() {
    if (!mounted) return;
    if (_reduceMotion) {
      _exit
          .animateTo(
            1,
            duration: CameoMotion.durationFast,
            curve: CameoMotion.easingStandard,
          )
          .then((_) {
            if (mounted) widget.onExited?.call();
          });
      return;
    }
    _exit.springTo(1, CameoMotion.digitEntryExitSpring).then((_) {
      if (mounted) widget.onExited?.call();
    });
  }

  @override
  void dispose() {
    _exitTimer?.cancel();
    _scale.dispose();
    _rise.dispose();
    _fade.dispose();
    _exit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final glyph = CameoText(
      widget.text,
      style: widget.style,
      color: widget.color,
      maxLines: 1,
    );
    return AnimatedBuilder(
      animation: _all,
      child: glyph,
      builder: (context, child) {
        Widget g = Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, dy),
            child: Transform.scale(scale: scale, child: child),
          ),
        );
        if (widget.collapseOnExit) {
          g = Align(
            alignment: Alignment.centerLeft,
            widthFactor: (1 - _exit.value).clamp(0.0, 1.0),
            child: g,
          );
        }
        return g;
      },
    );
  }
}
