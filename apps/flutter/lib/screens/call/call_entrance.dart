// Staggered call-screen entrance. Translate all items; fade only content that does not
// contain Liquid Glass.

import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../design_system/design_system.dart';

class CallEntrance extends StatefulWidget {
  const CallEntrance({
    super.key,
    required this.play,
    required this.index,
    required this.rise,
    this.fade = true,
    required this.child,
  });

  final bool play;

  final int index;

  final double rise;

  final bool fade;

  final Widget child;

  @override
  State<CallEntrance> createState() => _CallEntranceState();
}

class _CallEntranceState extends State<CallEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progress = AnimationController.unbounded(
    vsync: this,
    animationBehavior: AnimationBehavior.preserve,
  );
  Timer? _delay;
  bool _played = false;
  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _maybePlay();
  }

  @override
  void didUpdateWidget(CallEntrance oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybePlay();
  }

  void _maybePlay() {
    if (_played || !widget.play) return;
    _played = true;
    final delay = CameoMotion.staggerItem * widget.index;
    if (delay == Duration.zero) {
      _run();
    } else {
      _delay = Timer(delay, _run);
    }
  }

  void _run() {
    if (!mounted) return;
    if (_reduceMotion) {
      _progress.animateTo(
        1,
        duration: CameoMotion.durationBase,
        curve: CameoMotion.easingStandard,
      );
    } else {
      _progress.springTo(1, CameoMotion.staggerSpring).then((_) {
        if (mounted && !_progress.isAnimating) _progress.value = 1;
      });
    }
  }

  @override
  void dispose() {
    _delay?.cancel();
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rise = _reduceMotion ? 0.0 : widget.rise;
    return AnimatedBuilder(
      animation: _progress,
      child: widget.child,
      builder: (context, child) {
        final p = _progress.value;
        final moved = Transform.translate(
          offset: Offset(0, (1 - p) * rise),
          child: child,
        );
        if (!widget.fade) return moved;
        return Opacity(opacity: p.clamp(0.0, 1.0), child: moved);
      },
    );
  }
}
