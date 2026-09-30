// Transcript-line entrance delayed until route settlement, with per-line spring
// staggering.

import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../design_system/design_system.dart';

class StaggerIn extends StatefulWidget {
  const StaggerIn({
    super.key,
    required this.index,
    required this.active,
    required this.child,
  });

  final int index;

  final bool active;

  final Widget child;

  @override
  State<StaggerIn> createState() => _StaggerInState();
}

class _StaggerInState extends State<StaggerIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progress = AnimationController.unbounded(
    vsync: this,
    value: 0,
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
  void didUpdateWidget(StaggerIn oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybePlay();
  }

  void _maybePlay() {
    if (!widget.active || _played) return;
    _played = true;
    final delay = CameoMotion.staggerItem * widget.index;
    if (delay == Duration.zero) {
      _play();
    } else {
      _delay = Timer(delay, _play);
    }
  }

  void _play() {
    if (!mounted) return;
    if (_reduceMotion) {
      _progress.animateTo(
        1,
        duration: CameoMotion.durationBase,
        curve: CameoMotion.easingStandard,
      );
    } else {
      _progress.springTo(1, CameoMotion.staggerSpring).then((_) {
        if (mounted) _progress.value = 1;
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
    final rise = _reduceMotion ? 0.0 : CameoMotion.staggerRise;
    return AnimatedBuilder(
      animation: _progress,
      child: widget.child,
      builder: (context, child) {
        final p = _progress.value;
        return Opacity(
          opacity: p.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - p) * rise),
            child: child,
          ),
        );
      },
    );
  }
}
