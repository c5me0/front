// Connection completion presentation with paired avatars and a timed transition. A
// preset preview does not automatically navigate away.

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../content/app.g.dart';
import '../content/lab.g.dart';
import '../design_system/design_system.dart';
import 'avatar_v6.dart';
import 'heart_burst.dart';
import 'onboarding_v6_layout.dart';

///

class ConnectDoneV6 extends StatefulWidget {
  const ConnectDoneV6({
    super.key,
    required this.visible,
    required this.myName,
    required this.partnerName,
    this.partnerImage,
    this.onDone,
  });

  final bool visible;

  final String myName;

  final String partnerName;

  final String? partnerImage;
  final VoidCallback? onDone;

  static const Key rootKey = ValueKey('connectDone');
  static const Key canvasKey = ValueKey('connectDone.canvas');
  static const Key meKey = ValueKey('connectDone.me');
  static const Key partnerKey = ValueKey('connectDone.partner');
  static const Key messageKey = ValueKey('connectDone.message');

  @override
  State<ConnectDoneV6> createState() => ConnectDoneV6State();
}

class ConnectDoneV6State extends State<ConnectDoneV6>
    with TickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: CameoMotion.celebrationBackdrop,
  );
  late final AnimationController _travel = AnimationController.unbounded(
    vsync: this,
  )..addListener(_watchOverlap);
  late final AnimationController _text = AnimationController.unbounded(
    vsync: this,
  );
  late final AnimationController _exit = AnimationController(
    vsync: this,
    duration: CameoMotion.durationFast,
  );
  final List<Timer> _timers = [];
  int _burst = 0;
  bool _met = false;
  bool _playing = false;
  bool _started = false;
  bool _reduceMotion = false;

  double get avatarProgress => _travel.value;

  int get burstTrigger => _burst;

  double get textProgress => _text.value;

  double get canvasOpacity => _fade.value;

  @override
  void initState() {
    super.initState();

    for (final c in [_fade, _travel, _text, _exit]) {
      c.value;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (!_started) {
      _started = true;
      if (widget.visible) _play();
    }
  }

  @override
  void didUpdateWidget(ConnectDoneV6 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visible == widget.visible) return;
    widget.visible ? _play() : _stop();
  }

  void _play() {
    _cancelTimers();
    _playing = true;
    _met = false;
    _exit.value = 1;
    _fade.value = 0;
    _travel.value = 0;
    _text.value = 0;
    _fade.animateTo(1, curve: CameoMotion.easingStandard);
    if (_reduceMotion) {
      _travel.animateTo(
        1,
        duration: CameoMotion.celebrationBackdrop,
        curve: CameoMotion.easingStandard,
      );
    } else {
      _travel.springTo(1, CameoMotion.celebrationAvatarSpring);
    }
    _timers.add(
      Timer(CameoMotion.celebrationHold, () {
        if (mounted && _playing) widget.onDone?.call();
      }),
    );
  }

  void _watchOverlap() {
    if (_met || !_playing || _travel.value < 1) return;
    _met = true;
    HapticFeedback.mediumImpact();
    setState(() => _burst++);
    _timers.add(
      Timer(CameoMotion.celebrationTextDelay, () {
        if (!mounted || !_playing) return;
        if (_reduceMotion) {
          _text.animateTo(
            1,
            duration: CameoMotion.durationBase,
            curve: CameoMotion.easingStandard,
          );
        } else {
          _text.springTo(1, CameoMotion.staggerSpring);
        }
      }),
    );
  }

  void _stop() {
    _cancelTimers();
    _playing = false;
    _met = false;
    _exit.animateTo(0, curve: CameoMotion.easingStandard);
  }

  void _cancelTimers() {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
  }

  @override
  void dispose() {
    _cancelTimers();
    _fade.dispose();
    _travel.dispose();
    _text.dispose();
    _exit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = CameoTheme.colorsOf(context);
    final padding = MediaQuery.paddingOf(context);
    final size = MediaQuery.sizeOf(context);
    final message = fillTemplate(labV6.connected.message, {
      'partner': widget.partnerName,
    });
    const avatar = CameoLayout.connectDoneV6AvatarSize;
    const burst = CameoMotion.likeBurstSize;
    final groupTop = connectDoneGroupTop(
      padding.top,
      size.height,
      padding.bottom,
    );
    final centerX = size.width / 2;
    final rise = _reduceMotion ? 0.0 : CameoMotion.staggerRise;

    Widget avatarAt(Key key, int side, Widget child) => AnimatedBuilder(
      key: key,
      animation: Listenable.merge([_travel, _fade]),
      child: child,
      builder: (context, child) {
        final p = _reduceMotion ? 1.0 : _travel.value;
        return Positioned(
          left: centerX + connectDoneAvatarX(side, p) - avatar / 2,
          top: groupTop,
          width: avatar,
          height: avatar,
          child: Opacity(opacity: _fade.value.clamp(0.0, 1.0), child: child),
        );
      },
    );

    return AnimatedBuilder(
      key: ConnectDoneV6.rootKey,
      animation: _exit,
      builder: (context, child) {
        if (!widget.visible && _exit.value == 0) {
          return const SizedBox.shrink();
        }
        return IgnorePointer(
          ignoring: !widget.visible,
          child: Opacity(opacity: _exit.value.clamp(0.0, 1.0), child: child),
        );
      },
      child: Semantics(
        container: true,
        liveRegion: true,
        label: message,
        excludeSemantics: true,
        child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: FadeTransition(
                key: ConnectDoneV6.canvasKey,
                opacity: _fade,
                child: ColoredBox(color: c.backgroundCanvasNeutralBase),
              ),
            ),
            avatarAt(
              ConnectDoneV6.meKey,
              -1,
              AvatarV6(
                size: avatar,
                name: widget.myName,
                initialStyle: CameoTextStyles.headingLg,
              ),
            ),

            avatarAt(
              ConnectDoneV6.partnerKey,
              1,
              AvatarV6(
                size: avatar,
                image: widget.partnerImage ?? labV6.connected.partnerPhoto,
                name: widget.partnerName,
                initialStyle: CameoTextStyles.headingLg,
              ),
            ),

            Positioned(
              key: const ValueKey('connectDone.burst'),
              left: centerX - burst / 2,
              top: groupTop + avatar / 2 - burst / 2,
              child: HeartBurst(trigger: _burst),
            ),
            Positioned(
              key: const ValueKey('connectDone.messageBox'),
              left: 0,
              right: 0,
              top: groupTop + avatar + CameoLayout.connectDoneV6Gap,
              child: AnimatedBuilder(
                animation: _text,
                builder: (context, child) {
                  final t = _text.value;
                  return Opacity(
                    opacity: t.clamp(0.0, 1.0),
                    child: Transform.translate(
                      offset: Offset(0, (1 - t) * rise),
                      child: child,
                    ),
                  );
                },
                child: CameoText(
                  message,
                  key: ConnectDoneV6.messageKey,
                  style: CameoTextStyles.headingMdStrong,
                  color: c.foregroundNeutralBase,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
