// Six-digit code input display with entry, verification, success, and clearing states.
// Clear from the last occupied slot and stagger success checks.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../content/lab.g.dart';
import '../design_system/design_system.dart';
import 'digit_entry.dart';
import 'onboarding_v6_layout.dart';
import 'phone_number_field.dart' show spokenDigits;

enum CodeBoxState { empty, active, verifying, success, error }

double codeBoxBreatheScale(double phase, double amplitude) {
  final s = (1 - math.cos(2 * math.pi * phase)) / 2;
  return 1 - (1 - CameoMotion.codeInputBreatheScale) * amplitude * s;
}

const String _defaultLabel = '코드';

class _Glyph {
  _Glyph(this.id, this.char, {required this.animateIn});

  final int id;
  final String char;
  final bool animateIn;
  bool exiting = false;
  Duration exitDelay = Duration.zero;
}

///

///   "0" headingSm `foreground/neutral/subtle`.

class CodeBox extends StatefulWidget {
  const CodeBox({
    super.key,
    required this.value,
    this.state = CodeBoxState.active,
    this.onComplete,
    this.accessibilityLabel = _defaultLabel,
    this.placeholder,
  });

  final String value;
  final CodeBoxState state;
  final ValueChanged<String>? onComplete;
  final String accessibilityLabel;

  final String? placeholder;

  static const Key boxKey = ValueKey('codeBox.box');

  static const Key borderKey = ValueKey('codeBox.border');

  static Key slotKey(int index) => ValueKey('codeBox.slot.$index');

  static Key placeholderKey(int index) =>
      ValueKey('codeBox.placeholder.$index');

  static Key checkKey(int index) => ValueKey('codeBox.check.$index');

  @override
  State<CodeBox> createState() => CodeBoxWidgetState();
}

class CodeBoxWidgetState extends State<CodeBox> with TickerProviderStateMixin {
  static int get _length => codeBoxV6SlotCount;

  late String _digits = _clean(widget.value);
  late final List<List<_Glyph>> _cells = [
    for (var i = 0; i < _length; i++)
      [if (i < _digits.length) _Glyph(_nextId++, _digits[i], animateIn: false)],
  ];
  int _nextId = 0;

  late final AnimationController _shown = AnimationController.unbounded(
    vsync: this,
    value: widget.state == CodeBoxState.empty ? 0 : 1,
  );
  late final AnimationController _ok = AnimationController.unbounded(
    vsync: this,
    value: widget.state == CodeBoxState.success ? 1 : 0,
  );
  late final AnimationController _err = AnimationController.unbounded(
    vsync: this,
    value: widget.state == CodeBoxState.error ? 1 : 0,
  );
  late final AnimationController _breathPhase = AnimationController(
    vsync: this,
    duration: CameoMotion.codeInputBreathe,
  );
  late final AnimationController _breathAmp = AnimationController.unbounded(
    vsync: this,
  );
  late final AnimationController _shake = AnimationController.unbounded(
    vsync: this,
  );

  late final List<AnimationController> _placeholder = [
    for (var i = 0; i < _length; i++)
      AnimationController.unbounded(
        vsync: this,
        value: i < _digits.length || widget.state == CodeBoxState.success
            ? 0
            : 1,
      ),
  ];
  late final List<AnimationController> _check = [
    for (var i = 0; i < _length; i++)
      AnimationController.unbounded(vsync: this),
  ];
  late final List<AnimationController> _checkScale = [
    for (var i = 0; i < _length; i++)
      AnimationController.unbounded(vsync: this),
  ];
  final List<Timer> _timers = [];
  bool _reduceMotion = false;
  bool _started = false;

  double get shakeOffset => _shake.value;

  double get breatheScale =>
      codeBoxBreatheScale(_breathPhase.value, _breathAmp.value);

  double get successProgress => _ok.value;

  double get errorProgress => _err.value;

  double checkScaleOf(int i) => _checkScale[i].value;
  double checkOpacityOf(int i) => _check[i].value;
  double placeholderOpacityOf(int i) => _placeholder[i].value;

  @override
  void initState() {
    super.initState();

    for (final c in [
      _shown,
      _ok,
      _err,
      _breathPhase,
      _breathAmp,
      _shake,
      ..._placeholder,
      ..._check,
      ..._checkScale,
    ]) {
      c.value;
    }
  }

  static String _clean(String v) {
    final d = v.replaceAll(RegExp(r'[^0-9]'), '');
    return d.length > _length ? d.substring(0, _length) : d;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (_started) return;
    _started = true;

    if (widget.state == CodeBoxState.verifying) _startBreathe();
    if (widget.state == CodeBoxState.success) _showChecks();
  }

  @override
  void didUpdateWidget(CodeBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _clean(widget.value);
    if (next != _digits) _applyValue(_digits, next);
    if (oldWidget.state != widget.state) _applyState(oldWidget.state);
  }

  void _applyValue(String from, String to) {
    final lengthBefore = from.length;
    for (var i = 0; i < _length; i++) {
      final a = i < from.length ? from[i] : null;
      final b = i < to.length ? to[i] : null;
      if (a == b) continue;
      if (a != null) {
        final delay = b == null
            ? codeBoxClearDelay(
                i,
                lengthBefore,
                CameoMotion.codeInputAutofillInterval,
              )
            : Duration.zero;
        for (final g in _cells[i].where((g) => !g.exiting)) {
          g
            ..exiting = true
            ..exitDelay = delay;
        }
      }
      if (b != null) _cells[i].add(_Glyph(_nextId++, b, animateIn: true));

      final success = widget.state == CodeBoxState.success;
      final target = b != null || success ? 0.0 : 1.0;
      final delay = a != null && b == null
          ? codeBoxClearDelay(
              i,
              lengthBefore,
              CameoMotion.codeInputAutofillInterval,
            )
          : Duration.zero;
      _fadeLater(_placeholder[i], target, delay);
    }
    final wasFull = from.length >= _length;
    final isFull = to.length >= _length;
    _digits = to;
    if (!wasFull && isFull) {
      final code = to;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted && _digits.length >= _length) widget.onComplete?.call(code);
      });
    }
  }

  void _fadeLater(AnimationController c, double target, Duration delay) {
    void run() {
      if (!mounted) return;
      c.animateTo(
        target,
        duration: CameoMotion.durationFast,
        curve: CameoMotion.easingStandard,
      );
    }

    if (delay == Duration.zero) {
      run();
    } else {
      _timers.add(Timer(delay, run));
    }
  }

  void _applyState(CodeBoxState previous) {
    final state = widget.state;
    const border = CameoMotion.codeBoxV6BorderSpring;
    final shownTarget = state == CodeBoxState.empty ? 0.0 : 1.0;
    if (_reduceMotion) {
      _shown.value = shownTarget;
    } else {
      _shown.springTo(shownTarget, border);
    }
    _ok.springTo(state == CodeBoxState.success ? 1 : 0, border);
    _err.springTo(state == CodeBoxState.error ? 1 : 0, border);

    if (state == CodeBoxState.verifying) {
      _startBreathe();
    } else if (previous == CodeBoxState.verifying) {
      _stopBreathe();
    }

    if (state == CodeBoxState.success) {
      HapticFeedback.mediumImpact();
      _showChecks();
    } else if (previous == CodeBoxState.success) {
      _hideChecks();
    }

    if (state == CodeBoxState.error) {
      HapticFeedback.heavyImpact(); // error
      if (!_reduceMotion) {
        const spring = CameoMotion.shakeSpring;
        final kick = springImpulse(spring, 1 + CameoMotion.shakeDistance);
        _shake.value = 0;
        _shake.springTo(0, spring, velocity: kick.velocity);
      }
    }
  }

  void _startBreathe() {
    if (_reduceMotion) return;
    if (!_breathPhase.isAnimating) {
      _breathPhase
        ..value = 0
        ..repeat();
    }
    _breathAmp.springTo(1, CameoMotion.codeInputColorSpring);
  }

  void _stopBreathe() {
    _breathAmp.springTo(0, CameoMotion.codeInputColorSpring).then((_) {
      if (mounted && widget.state != CodeBoxState.verifying) {
        _breathPhase.stop();
      }
    });
  }

  void _showChecks() {
    for (var i = 0; i < _length; i++) {
      final delay = codeBoxCheckDelay(i, CameoMotion.codeBoxV6CheckStagger);
      final check = _check[i];
      final scale = _checkScale[i];
      _placeholder[i].animateTo(
        0,
        duration: CameoMotion.durationFast,
        curve: CameoMotion.easingStandard,
      );
      void run() {
        if (!mounted || widget.state != CodeBoxState.success) return;
        check.animateTo(
          1,
          duration: CameoMotion.durationFast,
          curve: CameoMotion.easingStandard,
        );
        if (_reduceMotion) {
          scale.value = 1;
          return;
        }

        const spring = CameoMotion.codeBoxV6CheckSpring;
        final kick = springImpulse(
          spring,
          CameoMotion.codeBoxV6CheckOvershootScale,
        );
        scale.value = 0;
        scale.springTo(1, spring, velocity: kick.velocity);
      }

      if (delay == Duration.zero) {
        run();
      } else {
        _timers.add(Timer(delay, run));
      }
    }
  }

  void _hideChecks() {
    for (var i = 0; i < _length; i++) {
      _check[i].animateTo(
        0,
        duration: CameoMotion.durationFast,
        curve: CameoMotion.easingStandard,
      );
      _checkScale[i]
        ..stop()
        ..value = 0;
      if (i >= _digits.length) {
        _placeholder[i].animateTo(
          1,
          duration: CameoMotion.durationFast,
          curve: CameoMotion.easingStandard,
        );
      }
    }
  }

  void _removeGlyph(int cell, int id) {
    if (!mounted) return;
    setState(() => _cells[cell].removeWhere((g) => g.id == id));
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    for (final c in [
      _shown,
      _ok,
      _err,
      _breathPhase,
      _breathAmp,
      _shake,
      ..._placeholder,
      ..._check,
      ..._checkScale,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = CameoTheme.colorsOf(context);
    final n = _digits.length;
    final label =
        '${widget.accessibilityLabel}, $_length자리 중 $n자리 입력'
        '${n > 0 ? ': ${spokenDigits(_digits)}' : ''}';
    final placeholder = widget.placeholder ?? labV6.verify.codePlaceholder;
    return Semantics(
      container: true,
      label: label,
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: Listenable.merge([_breathPhase, _breathAmp, _shake]),
        builder: (context, child) {
          final s = breatheScale;
          return Transform(
            key: CodeBox.boxKey,
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..translateByDouble(_shake.value, 0, 0, 1)
              ..scaleByDouble(s, s, 1, 1),
            child: child,
          );
        },
        child: SizedBox(
          height: CameoLayout.codeBoxV6Height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              BlurSurface(
                blur: CameoBlur.blur,
                tint: c.backgroundFillNeutralBase,
                radius: CameoLayout.codeBoxV6Radius,
                padding: const EdgeInsets.symmetric(
                  horizontal:
                      CameoLayout.codeBoxV6BorderWidth +
                      CameoLayout.codeBoxV6Padding,
                ),
                child: Row(
                  spacing: CameoLayout.codeBoxV6Gap,
                  children: [
                    for (var i = 0; i < _length; i++)
                      Expanded(child: _slot(i, c, placeholder)),
                  ],
                ),
              ),
              IgnorePointer(
                child: AnimatedBuilder(
                  animation: Listenable.merge([_shown, _ok, _err]),
                  builder: (context, _) {
                    final ok = Color.lerp(
                      c.staticBlackBase,
                      c.systemGreen,
                      _ok.value,
                    )!;
                    final color = Color.lerp(ok, c.systemRed, _err.value)!;
                    return Opacity(
                      key: CodeBox.borderKey,
                      opacity: _shown.value.clamp(0.0, 1.0),
                      child: DecoratedBox(
                        decoration: ShapeDecoration(
                          shape: RoundedSuperellipseBorder(
                            borderRadius: BorderRadius.circular(
                              CameoLayout.codeBoxV6Radius,
                            ),
                            side: BorderSide(
                              color: color,
                              width: CameoLayout.codeBoxV6BorderWidth,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _slot(int i, CameoPalette c, String placeholder) {
    return Padding(
      key: CodeBox.slotKey(i),
      padding: const EdgeInsets.symmetric(
        horizontal: CameoLayout.codeBoxV6SlotPaddingX,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _placeholder[i],
            builder: (context, child) => Opacity(
              key: CodeBox.placeholderKey(i),
              opacity: _placeholder[i].value.clamp(0.0, 1.0),
              child: child,
            ),
            child: CameoText(
              placeholder,
              style: CameoTextStyles.headingSm,
              color: c.foregroundNeutralSubtle,
              maxLines: 1,
            ),
          ),
          AnimatedBuilder(
            key: ValueKey('codeBox.digits.$i'),
            animation: _check[i],
            builder: (context, child) => Opacity(
              opacity: (1 - _check[i].value).clamp(0.0, 1.0),
              child: child,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                for (final g in _cells[i])
                  EntryGlyph(
                    key: ValueKey('codeBox.glyph.${g.id}'),
                    text: g.char,
                    style: CameoTextStyles.headingSm,
                    color: c.foregroundNeutralBase,
                    animateIn: g.animateIn,
                    exiting: g.exiting,
                    exitDelay: g.exitDelay,
                    onExited: () => _removeGlyph(i, g.id),
                  ),
              ],
            ),
          ),
          AnimatedBuilder(
            key: ValueKey('codeBox.checkLayer.$i'),
            animation: Listenable.merge([_check[i], _checkScale[i]]),
            builder: (context, child) => Opacity(
              opacity: _check[i].value.clamp(0.0, 1.0),
              child: Transform.scale(
                key: CodeBox.checkKey(i),
                scale: _checkScale[i].value,
                child: child,
              ),
            ),
            child: CameoIcon(
              CameoIconName.check,
              size: CameoLayout.codeBoxV6CheckSize,
              color: c.systemGreen,
            ),
          ),
        ],
      ),
    );
  }
}
