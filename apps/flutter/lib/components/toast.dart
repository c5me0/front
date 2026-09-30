// Toast state, timing, and presentation variants. Repeated messages restart the visible
// interval; callers supply the message and icon.

import 'dart:async';

import 'package:flutter/widgets.dart';

import '../content/lab.g.dart';
import '../design_system/design_system.dart';
import 'toast_v6.dart';

enum ToastVariant { regular, v1, v6Flat, v6Elevated, v6ElevatedCamera }

CameoIconName toastIconOf(String key) => CameoIconName.values.firstWhere(
  (n) => n.key == key,
  orElse: () => CameoIconName.borderNone,
);

double toastBottom(double controlBarContainerHeight) =>
    controlBarContainerHeight + CameoLayout.toastOffsetAboveControlBar;

enum _ToastPhase { hidden, shown, exiting }

class Toast extends StatefulWidget {
  const Toast({
    super.key,
    required this.message,
    required this.icon,
    required this.visible,
    this.onHidden,
    this.showKey = 0,
    this.variant = ToastVariant.regular,
    this.autoHide = true,
    this.onPress,
  });

  final String message;

  final CameoIconName icon;

  final bool visible;

  final VoidCallback? onHidden;

  final int showKey;

  final ToastVariant variant;

  final bool autoHide;

  final VoidCallback? onPress;

  @override
  State<Toast> createState() => _ToastState();
}

class _ToastState extends State<Toast> with SingleTickerProviderStateMixin {
  late final AnimationController _progress = AnimationController.unbounded(
    vsync: this,
  );
  _ToastPhase _phase = _ToastPhase.hidden;
  Timer? _autoHide;
  bool _reduceMotion = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (!_started) {
      _started = true;
      if (widget.visible) _show();
    }
  }

  @override
  void didUpdateWidget(Toast oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible != oldWidget.visible ||
        widget.showKey != oldWidget.showKey) {
      widget.visible ? _show() : _hide();
    }
  }

  void _show() {
    _autoHide?.cancel();

    if (_phase == _ToastPhase.shown) _progress.value = 0;
    _phase = _ToastPhase.shown;
    _animate(1, CameoMotion.toastEnterSpring);
    if (widget.autoHide) _autoHide = Timer(CameoMotion.toastVisible, _hide);
  }

  TickerFuture _animate(double target, SpringDescription spring) {
    final from = _progress.value;
    var velocity = _progress.velocity;
    if ((target > from && velocity < 0) || (target < from && velocity > 0)) {
      velocity = 0;
    }
    final run = _reduceMotion
        ? _progress.animateTo(
            target,
            duration: CameoMotion.durationBase,
            curve: CameoMotion.easingStandard,
          )
        : _progress.springTo(target, spring, velocity: velocity);
    run.then((_) {
      if (mounted && !_progress.isAnimating) _progress.value = target;
    });
    return run;
  }

  void _hide() {
    _autoHide?.cancel();
    _autoHide = null;
    if (_phase != _ToastPhase.shown) return;
    _phase = _ToastPhase.exiting;
    final done = _animate(0, CameoMotion.toastExitSpring);

    done.then((_) {
      if (!mounted || _phase != _ToastPhase.exiting) return;
      setState(() => _phase = _ToastPhase.hidden);
      widget.onHidden?.call();
    });
  }

  @override
  void dispose() {
    _autoHide?.cancel();
    _progress.dispose();
    super.dispose();
  }

  static EdgeInsets _containerPadding(ToastVariant variant) =>
      switch (variant) {
        ToastVariant.regular || ToastVariant.v1 => const EdgeInsets.all(
          CameoLayout.toastContainerPadding,
        ),
        ToastVariant.v6Flat => const EdgeInsets.symmetric(
          horizontal: CameoLayout.toastV6FlatPaddingX,
          vertical: CameoLayout.toastV6FlatPaddingY,
        ),
        ToastVariant.v6Elevated => const EdgeInsets.symmetric(
          horizontal: CameoLayout.toastV6ElevatedPaddingX,
          vertical: CameoLayout.toastV6ElevatedPaddingY,
        ),
        ToastVariant.v6ElevatedCamera => const EdgeInsets.fromLTRB(
          CameoLayout.toastV6ElevatedPaddingX,
          CameoLayout.toastV6CameraPaddingTop,
          CameoLayout.toastV6ElevatedPaddingX,
          CameoLayout.toastV6CameraPaddingBottom,
        ),
      };

  @override
  Widget build(BuildContext context) {
    final pill = switch (widget.variant) {
      ToastVariant.v6Flat => ToastV6Pill(
        message: widget.message,
        icon: widget.icon,
        variant: ToastV6Variant.flat,
      ),
      ToastVariant.v6Elevated || ToastVariant.v6ElevatedCamera => ToastV6Pill(
        message: widget.message,
        icon: widget.icon,
        variant: ToastV6Variant.elevated,
      ),
      ToastVariant.regular || ToastVariant.v1 => _v4Pill(context),
    };
    return _animated(context, pill);
  }

  Widget _v4Pill(BuildContext context) {
    final minWidth = widget.variant == ToastVariant.v1
        ? CameoLayout.toastV1MinWidth
        : CameoLayout.toastPillMinWidth;

    final palette = CameoTheme.colorsOf(context);
    return Container(
      constraints: BoxConstraints(minWidth: minWidth),
      padding: const EdgeInsets.symmetric(
        horizontal: CameoLayout.toastPillPaddingX,
        vertical: CameoLayout.toastPillPaddingY,
      ),

      decoration: BoxDecoration(
        color: palette.backgroundCanvasBase,
        border: Border.all(
          color: palette.strokeNeutralBase,
          width: CameoLayout.toastPillBorderWidth,
        ),
        borderRadius: BorderRadius.circular(CameoLayout.toastPillRadius),
        boxShadow: [palette.shadows.toastShadow],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CameoIcon(
            widget.icon,
            size: CameoLayout.toastIconSize,
            color: palette.foregroundNeutralBase,
          ),
          const SizedBox(width: CameoLayout.toastPillGap),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: CameoLayout.toastTextPaddingX,
              ),
              child: CameoText(
                widget.message,
                style: CameoTextStyles.bodyMd,
                color: palette.foregroundNeutralBase,
                maxLines: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _animated(BuildContext context, Widget pill) {
    final shown = widget.visible && _phase != _ToastPhase.hidden;
    final onPress = widget.onPress;
    if (onPress != null) {
      pill = GestureDetector(
        key: const ValueKey('toast.press'),
        onTap: onPress,
        child: pill,
      );
    }
    return IgnorePointer(
      ignoring: onPress == null || !shown,
      child: Padding(
        padding: _containerPadding(widget.variant),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: ExcludeSemantics(
                excluding: !shown,
                child: Semantics(
                  container: true,
                  liveRegion: true,
                  label: widget.message,
                  button: onPress != null,
                  onTap: shown ? onPress : null,
                  excludeSemantics: true,
                  child: AnimatedBuilder(
                    animation: _progress,
                    child: pill,
                    builder: (context, child) {
                      final p = _progress.value;
                      return Opacity(
                        opacity: p.clamp(0.0, 1.0),
                        child: Transform.translate(
                          offset: Offset(
                            0,
                            _reduceMotion
                                ? 0
                                : (1 - p) * CameoMotion.toastEnterOffset,
                          ),

                          child: Transform.scale(
                            scale: _reduceMotion
                                ? 1
                                : CameoMotion.toastEnterScale +
                                      (1 - CameoMotion.toastEnterScale) * p,
                            child: child,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ToastController extends ChangeNotifier {
  String _message = '';
  CameoIconName _icon = CameoIconName.borderNone;
  bool _visible = false;
  int _showKey = 0;
  ToastVariant? _variant;

  String get message => _message;
  CameoIconName get icon => _icon;
  bool get visible => _visible;
  int get showKey => _showKey;

  ToastVariant? get variant => _variant;

  void show(String message, CameoIconName icon, {ToastVariant? variant}) {
    _message = message;
    _icon = icon;
    _variant = variant;
    _visible = true;
    _showKey++;
    notifyListeners();
  }

  void showContent(ToastContent content, {ToastVariant? variant}) =>
      show(content.text, toastIconOf(content.icon), variant: variant);

  void hide() {
    if (!_visible) return;
    _visible = false;
    notifyListeners();
  }
}

class ToastHost extends StatelessWidget {
  const ToastHost({
    super.key,
    required this.controller,
    this.variant = ToastVariant.regular,
    this.autoHide = true,
    this.onPress,
  });

  final ToastController controller;

  final ToastVariant variant;
  final bool autoHide;

  final VoidCallback? onPress;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Toast(
        message: controller.message,
        icon: controller.icon,
        visible: controller.visible,
        showKey: controller.showKey,
        onHidden: controller.hide,
        variant: controller.variant ?? variant,
        autoHide: autoHide,
        onPress: onPress,
      ),
    );
  }
}
