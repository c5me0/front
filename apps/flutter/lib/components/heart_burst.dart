// Favorite feedback overlay. Replay for each nonzero trigger change and ignore pointer
// events over the source photo.

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';

import '../design_system/design_system.dart';

class HeartBurst extends StatefulWidget {
  const HeartBurst({
    super.key,
    required this.trigger,
    this.size = CameoMotion.likeBurstSize,
  });

  final int trigger;

  final double size;

  @override
  State<HeartBurst> createState() => _HeartBurstState();
}

class _HeartBurstState extends State<HeartBurst> with TickerProviderStateMixin {
  late final AnimationController _pop = AnimationController.unbounded(
    vsync: this,
  );

  late final AnimationController _exit = AnimationController(
    vsync: this,
    duration: CameoMotion.durationFast,
    value: 1,
  );
  late final Listenable _both = Listenable.merge([_pop, _exit]);
  Timer? _hold;
  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  }

  @override
  void didUpdateWidget(HeartBurst oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != oldWidget.trigger && widget.trigger != 0) _play();
  }

  void _play() {
    _hold?.cancel();
    _pop.value = 0;
    if (_reduceMotion) {
      _pop.animateTo(
        1,
        duration: CameoMotion.durationFast,
        curve: CameoMotion.easingStandard,
      );
    } else {
      _pop.springTo(1, CameoMotion.likeBurstSpring);
    }
    _exit.value = 0;
    _hold = Timer(CameoMotion.likeBurstHold, () {
      if (mounted) _exit.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _hold?.cancel();
    _pop.dispose();
    _exit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final glyph = _HeartGlyph(size: widget.size);
    return IgnorePointer(
      key: const ValueKey('heartBurst'),
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: _both,
          child: glyph,
          builder: (context, child) {
            final p = _pop.value;
            final e = CameoMotion.easingAccelerate.transform(
              _exit.value.clamp(0.0, 1.0),
            );
            final fadeIn = _reduceMotion ? p.clamp(0.0, 1.0) : 1.0;
            final scale = _reduceMotion
                ? 1.0
                : math.max(0.0, p) *
                      (1 + (CameoMotion.likeBurstExitScale - 1) * e);
            return Opacity(
              opacity: (fadeIn * (1 - e)).clamp(0.0, 1.0),
              child: Transform.scale(scale: scale, child: child),
            );
          },
        ),
      ),
    );
  }
}

class _HeartGlyph extends StatelessWidget {
  const _HeartGlyph({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = CameoTheme.colorsOf(context);
    final shadow = palette.shadows.overlay;
    return Stack(
      fit: StackFit.expand,
      children: [
        Transform.translate(
          offset: shadow.offset,
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: shadow.blurSigma,
              sigmaY: shadow.blurSigma,
            ),
            child: CameoIcon(
              CameoIconName.heartFilled,
              size: size,
              color: shadow.color,
            ),
          ),
        ),
        CameoIcon(
          CameoIconName.heartFilled,
          size: size,
          color: palette.staticWhite,
        ),
      ],
    );
  }
}
