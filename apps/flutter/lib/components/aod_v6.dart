// Sleep mode dims the photo and hides chrome by translation. Only the explicit wake
// button exits; restore brightness and volume when leaving sleep mode.

import 'package:flutter/widgets.dart';

import '../content/lab.g.dart';
import '../design_system/design_system.dart';
import 'call_camera_geometry.dart';
import 'solid_button.dart';

class AodV6Progress {
  AodV6Progress({
    required TickerProvider vsync,
    bool asleep = false,
    this.onSettled,
  }) : dim = AnimationController.unbounded(
         vsync: vsync,
         value: asleep ? 1 : 0,

         animationBehavior: AnimationBehavior.preserve,
       ),
       ui = AnimationController.unbounded(vsync: vsync, value: asleep ? 1 : 0),
       button = AnimationController.unbounded(
         vsync: vsync,
         value: asleep ? 1 : 0,
       ),
       _asleep = asleep;

  final AnimationController dim;

  final AnimationController ui;

  final AnimationController button;

  ValueChanged<bool>? onSettled;

  bool _asleep;
  bool get asleep => _asleep;

  int _run = 0;

  void update(bool asleep, {required bool reduceMotion}) {
    if (asleep == _asleep) return;
    _asleep = asleep;
    final to = asleep ? 1.0 : 0.0;
    final id = ++_run;
    if (reduceMotion) {
      for (final c in [dim, ui, button]) {
        c
          ..stop()
          ..value = to;
      }
      onSettled?.call(asleep);
      return;
    }
    var pending = 3;
    void done() {
      pending -= 1;
      if (pending == 0 && id == _run) onSettled?.call(asleep);
    }

    void settle(AnimationController c, TickerFuture run) {
      run.then((_) {
        if (id != _run || c.isAnimating) return;
        c.value = to;
        done();
      });
    }

    settle(
      dim,
      dim.animateTo(
        to,
        duration: asleep ? CameoMotion.sleepAod : CameoMotion.aodV6DimOut,
        curve: CameoMotion.easingStandard,
      ),
    );
    settle(
      ui,
      ui.springTo(
        to,
        asleep ? CameoMotion.sleepAodSpring : CameoMotion.aodV6EndSpring,
      ),
    );
    settle(button, button.springTo(to, CameoMotion.aodV6ButtonSpring));
  }

  void dispose() {
    dim.dispose();
    ui.dispose();
    button.dispose();
  }
}

class AodV6Dim extends StatelessWidget {
  const AodV6Dim({super.key, required this.dim});

  final Animation<double> dim;

  static const Key layerKey = ValueKey('aodV6.dim');

  @override
  Widget build(BuildContext context) {
    final c = CameoTheme.colorsOf(context);
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: dim,
        builder: (context, _) {
          final o = dim.value.clamp(0.0, 1.0);
          if (o <= 0) return const SizedBox.shrink(key: layerKey);
          return Opacity(
            key: layerKey,
            opacity: o,
            child: ColoredBox(color: c.dimScrim),
          );
        },
      ),
    );
  }
}

CameoIconName _iconOf(String name) => CameoIconName.values.firstWhere(
  (i) => i.key == name,
  orElse: () => CameoIconName.sunrise,
);

/// RN `<AodV6EndButton button asleep onEnd />`.
class AodV6EndButton extends StatelessWidget {
  const AodV6EndButton({
    super.key,
    required this.button,
    required this.asleep,
    required this.onEnd,
  });

  /// [AodV6Progress.button]
  final Animation<double> button;

  final bool asleep;
  final VoidCallback onEnd;

  static const Key buttonKey = ValueKey('aodV6.end');

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final rect = aodButtonRect(size.width, size.height);
    return Stack(
      children: [
        Positioned(
          left: CameoLayout.aodV6ButtonContainerPaddingX,
          right: CameoLayout.aodV6ButtonContainerPaddingX,
          top: rect.top,
          height: rect.height,
          child: IgnorePointer(
            ignoring: !asleep,
            child: ExcludeSemantics(
              excluding: !asleep,
              child: AnimatedBuilder(
                animation: button,
                builder: (context, child) {
                  final t = aodButtonTransform(button.value);
                  if (t.opacity <= 0) return const SizedBox.shrink();
                  return Opacity(
                    opacity: t.opacity,
                    child: Transform.translate(
                      offset: Offset(0, t.translateY),
                      child: child,
                    ),
                  );
                },
                child: Center(
                  child: CameoTheme(
                    mode: CameoColorMode.dark,
                    child: SolidButton(
                      key: buttonKey,
                      size: SolidButtonSize.lg,
                      icon: _iconOf(labV6.call.sleepEnd.icon),
                      label: labV6.call.sleepEnd.label,
                      onPress: onEnd,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
