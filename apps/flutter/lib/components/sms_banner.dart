// Simulated verification-message banner for prototype flows. Drag dismissal and timeout
// share the same exit transition.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../content/app.g.dart';
import '../design_system/design_system.dart';

enum _Phase { hidden, shown, exiting }

double _rubber(double x, double d) {
  if (x <= 0 || d <= 0) return 0;
  return (1 - 1 / (x * CameoMotion.rubberBandCoefficient / d + 1)) * d;
}

double smsBannerHiddenOffset({required double top, required double height}) =>
    top + height + CameoSpace.s16;

///

class SmsBanner extends StatefulWidget {
  const SmsBanner({
    super.key,
    required this.visible,
    required this.message,
    this.onPress,
    this.onDismiss,
    this.app,
    this.time,
    this.accessibilityLabel,
    this.autoHide = true,
    this.safeAreaTop,
  });

  final bool visible;

  final String message;
  final VoidCallback? onPress;
  final VoidCallback? onDismiss;

  final String? app;

  final String? time;

  final String? accessibilityLabel;
  final bool autoHide;

  /// null → MediaQuery.paddingOf(context).top
  final double? safeAreaTop;

  static const Key bannerKey = ValueKey('smsBanner.banner');

  static const Key appIconKey = ValueKey('smsBanner.appIcon');

  @override
  State<SmsBanner> createState() => SmsBannerState();
}

class SmsBannerState extends State<SmsBanner> with TickerProviderStateMixin {
  late final AnimationController _p;
  late final AnimationController _drag;
  _Phase _phase = _Phase.hidden;
  Timer? _autoHide;
  bool _reduceMotion = false;
  bool _started = false;

  int? _pointer;
  Offset _origin = Offset.zero;
  double _dragAtDown = 0;
  VelocityTracker? _tracker;
  final GlobalKey _bannerBox = GlobalKey();

  double get progress => _p.value;

  double get dragOffset => _drag.value;

  double get _height {
    final box = _bannerBox.currentContext?.findRenderObject();
    return box is RenderBox && box.hasSize ? box.size.height : 0;
  }

  double _top(BuildContext context) =>
      (widget.safeAreaTop ?? MediaQuery.paddingOf(context).top) +
      CameoLayout.smsBannerTop;

  @override
  void initState() {
    super.initState();
    _p = AnimationController.unbounded(vsync: this);
    _drag = AnimationController.unbounded(vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (!_started) {
      _started = true;
      if (widget.visible) _show();
    }
  }

  @override
  void didUpdateWidget(SmsBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visible == widget.visible) return;
    widget.visible ? _show() : _hide();
  }

  TickerFuture _animateP(double target, SpringDescription spring, double v) {
    if (_reduceMotion) {
      return _p.animateTo(target, duration: Duration.zero);
    }
    final x = _p.value;
    final away = (target > x && v < 0) || (target < x && v > 0);
    return _p.springTo(target, spring, velocity: away ? 0 : v);
  }

  void _show() {
    _autoHide?.cancel();
    if (_phase == _Phase.hidden) {
      _drag.value = 0;
      _p.value = 0;
    }

    _phase = _Phase.shown;
    _animateP(1, CameoMotion.smsBannerEnterSpring, _p.velocity);
    _armAutoHide();
  }

  void _armAutoHide() {
    _autoHide?.cancel();
    if (widget.autoHide) {
      _autoHide = Timer(CameoMotion.smsBannerVisible, () => _dismissSelf(0));
    }
  }

  void _hide() => _exit(0);

  void _dismissSelf(double velocityDp) {
    if (_phase != _Phase.shown) return;
    widget.onDismiss?.call();
    _exit(velocityDp);
  }

  void _exit(double velocityDp) {
    _autoHide?.cancel();
    _autoHide = null;
    if (_phase != _Phase.shown) return;
    _phase = _Phase.exiting;
    final travel = smsBannerHiddenOffset(top: _top(context), height: _height);

    final v = travel > 0 ? velocityDp / travel : 0.0;
    _animateP(0, CameoMotion.smsBannerExitSpring, v).then((_) {
      if (!mounted || _phase != _Phase.exiting) return;
      _drag.value = 0;
      setState(() => _phase = _Phase.hidden);
    });
  }

  void _down(PointerDownEvent e) {
    if (_pointer != null || _phase != _Phase.shown) return;
    _pointer = e.pointer;
    _origin = e.position;
    _drag.stop();
    _dragAtDown = _drag.value;
    _tracker = VelocityTracker.withKind(e.kind)
      ..addPosition(e.timeStamp, e.position);
    _autoHide?.cancel();
  }

  void _move(PointerMoveEvent e) {
    if (e.pointer != _pointer) return;
    _tracker?.addPosition(e.timeStamp, e.position);
    final raw = _dragAtDown + (e.position.dy - _origin.dy);
    _drag.value = raw < 0 ? raw : _rubber(raw, _height);
  }

  void _up(PointerEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    final vy = _tracker?.getVelocity().pixelsPerSecond.dy ?? 0;
    _tracker = null;
    if (_phase != _Phase.shown) return;
    final h = _height;
    final dismiss =
        -_drag.value >= h * CameoMotion.transitionModalDismissProgress ||
        -vy >= CameoMotion.transitionModalDismissVelocity;
    if (dismiss) {
      _dismissSelf(math.min(vy, 0));
      return;
    }
    if (_reduceMotion) {
      _drag.value = 0;
    } else {
      _drag.springTo(0, CameoMotion.smsBannerEnterSpring, velocity: vy);
    }
    _armAutoHide();
  }

  @override
  void dispose() {
    _autoHide?.cancel();
    _p.dispose();
    _drag.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_phase == _Phase.hidden) return const SizedBox.shrink();
    final palette = CameoTheme.colorsOf(context);
    final top = _top(context);
    final app = widget.app ?? appContent.verify.sms.app;
    final time = widget.time ?? appContent.verify.sms.time;
    final label = widget.accessibilityLabel ?? '$app, $time, ${widget.message}';

    final banner = GlassSurface(
      key: SmsBanner.bannerKey,
      blur: CameoBlur.glassBar,
      tint: palette.glassTintPanel,
      radius: CameoLayout.smsBannerRadius,
      padding: const EdgeInsets.all(CameoLayout.smsBannerPadding),
      child: Row(
        children: [
          SizedBox.square(
            key: SmsBanner.appIconKey,
            dimension: CameoLayout.smsBannerAppIconSize,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: palette.backgroundInfoBase,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: CameoIcon(
                  CameoIconName.messageCircleFilled,
                  size: CameoLayout.smsBannerIconSize,
                  color: palette.staticWhite,
                ),
              ),
            ),
          ),
          const SizedBox(width: CameoLayout.smsBannerGap),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: CameoText(
                        app,
                        style: CameoTextStyles.bodySmStrong,
                        color: palette.foregroundNeutralBase,
                        maxLines: 1,
                      ),
                    ),
                    CameoText(
                      time,
                      style: CameoTextStyles.bodySm,
                      color: palette.foregroundNeutralMuted,
                      maxLines: 1,
                    ),
                  ],
                ),
                const SizedBox(height: CameoLayout.smsBannerLineGap),
                CameoText(
                  widget.message,
                  style: CameoTextStyles.bodyMd,
                  color: palette.foregroundNeutralBase,
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: top,
          left: CameoLayout.smsBannerMarginX,
          right: CameoLayout.smsBannerMarginX,
          child: AnimatedBuilder(
            animation: Listenable.merge([_p, _drag]),
            builder: (context, child) {
              final p = _p.value;

              return Transform.translate(
                offset: Offset(
                  0,
                  -(1 - p) * (top + CameoSpace.s16) + _drag.value,
                ),
                child: FractionalTranslation(
                  translation: Offset(0, -(1 - p)),
                  child: child,
                ),
              );
            },
            child: Semantics(
              container: true,
              liveRegion: true,
              button: widget.onPress != null,
              label: label,
              onTap: widget.onPress,
              onDismiss: () => _dismissSelf(0),
              excludeSemantics: true,
              child: Listener(
                onPointerDown: _down,
                onPointerMove: _move,
                onPointerUp: _up,
                onPointerCancel: _up,
                child: GlassPressable(
                  onPress: widget.onPress,
                  child: KeyedSubtree(key: _bannerBox, child: banner),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
