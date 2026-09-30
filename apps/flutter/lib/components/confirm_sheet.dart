// Floating confirmation sheet with dimmed backdrop, spring translation, and drag
// dismissal. Never fade the glass sheet itself. Reduced motion skips movement;
// actionSize selects matching v6 buttons.

import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../design_system/design_system.dart';
import 'primary_button.dart';
import 'solid_button.dart';

const double _safeAreaAllowance = 26;

double confirmSheetBottom(double safeBottom) => math.max(
  safeBottom - _safeAreaAllowance,
  CameoLayout.confirmSheetMarginBottom,
);

class ConfirmSheetController {
  _ConfirmSheetState? _state;

  bool get isAttached => _state != null;

  bool confirm() => _state?._confirmFromController() ?? false;

  bool cancel() => _state?._cancelFromController() ?? false;
}

enum _Phase { hidden, shown, exiting }

///  padding 24: [title] headingSm `foreground/neutral/base` · titleGap 8 · [body] bodyMd `foreground/neutral/muted` · actionsGap 24 ·
///  [PrimaryButton] ([destructive] ? destructive : prominent) [confirmLabel] · buttonGap 8 · [PrimaryButton] secondary [cancelLabel].

class ConfirmSheet extends StatefulWidget {
  const ConfirmSheet({
    super.key,
    required this.visible,
    required this.title,
    required this.body,
    required this.confirmLabel,
    required this.cancelLabel,
    this.onConfirm,
    this.onCancel,
    this.destructive = false,
    this.onShown,
    this.controller,
    this.safeAreaBottom,
    this.actionSize,
  });

  final bool visible;
  final String title;
  final String body;
  final String confirmLabel;
  final String cancelLabel;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;

  final bool destructive;

  final VoidCallback? onShown;
  final ConfirmSheetController? controller;

  /// null → MediaQuery.paddingOf(context).bottom
  final double? safeAreaBottom;

  final SolidButtonSize? actionSize;

  static const Key dimKey = ValueKey('confirmSheet.dim');
  static const Key sheetKey = ValueKey('confirmSheet.sheet');
  static const Key confirmKey = ValueKey('confirmSheet.confirm');
  static const Key cancelKey = ValueKey('confirmSheet.cancel');

  @override
  State<ConfirmSheet> createState() => _ConfirmSheetState();
}

class _ConfirmSheetState extends State<ConfirmSheet>
    with TickerProviderStateMixin {
  late final AnimationController _p;

  late final AnimationController _drag;

  late final AnimationController _dim;
  _Phase _phase = _Phase.hidden;
  bool _started = false;
  bool _reduceMotion = false;
  final GlobalKey _sheetBox = GlobalKey();

  double get _sheetHeight {
    final box = _sheetBox.currentContext?.findRenderObject();
    return box is RenderBox && box.hasSize ? box.size.height : 0;
  }

  @override
  void initState() {
    super.initState();
    _p = AnimationController.unbounded(vsync: this);
    _drag = AnimationController.unbounded(vsync: this);
    _dim = AnimationController(vsync: this, duration: CameoMotion.durationBase);
    widget.controller?._state = this;
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
  void didUpdateWidget(ConfirmSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      if (oldWidget.controller?._state == this) {
        oldWidget.controller!._state = null;
      }
      widget.controller?._state = this;
    }
    if (oldWidget.visible != widget.visible) {
      widget.visible ? _show() : _hide();
    }
  }

  @override
  void dispose() {
    if (widget.controller?._state == this) widget.controller!._state = null;
    _p.dispose();
    _drag.dispose();
    _dim.dispose();
    super.dispose();
  }

  TickerFuture _animateP(double target, double velocity) {
    final x = _p.value;
    final away = (target > x && velocity < 0) || (target < x && velocity > 0);
    return _p.springTo(
      target,
      CameoMotion.sheetSpring,
      velocity: away ? 0 : velocity,
    );
  }

  void _show() {
    if (_phase == _Phase.hidden) {
      _p.value = 0;
      _drag.value = 0;
      _dim.value = 0;
    }
    _phase = _Phase.shown;
    final TickerFuture done;
    if (_reduceMotion) {
      _p.value = 1;
      done = _dim.animateTo(1, curve: CameoMotion.easingStandard);
    } else {
      done = _animateP(1, _p.velocity);
    }
    done.then((_) {
      if (mounted && _phase == _Phase.shown) widget.onShown?.call();
    });
  }

  void _hide({double velocity = 0}) {
    if (_phase != _Phase.shown) return;
    _phase = _Phase.exiting;
    final TickerFuture done;
    if (_reduceMotion) {
      _p.value = 0;
      done = _dim.animateTo(0, curve: CameoMotion.easingStandard);
    } else {
      done = _animateP(0, velocity);
    }
    done.then((_) {
      if (!mounted || _phase != _Phase.exiting) return;
      _drag.value = 0;
      setState(() => _phase = _Phase.hidden);
    });
  }

  bool _confirmFromController() {
    if (_phase != _Phase.shown || !widget.visible) return false;
    widget.onConfirm?.call();
    return true;
  }

  bool _cancelFromController() {
    if (_phase != _Phase.shown || !widget.visible) return false;
    widget.onCancel?.call();
    return true;
  }

  double get _travel => _sheetHeight + CameoLayout.confirmSheetMarginBottom;

  double _rawDrag = 0;

  void _dragStart(DragStartDetails d) {
    if (_phase != _Phase.shown) return;
    _drag.stop();
    _rawDrag = _drag.value;
  }

  void _dragUpdate(DragUpdateDetails d) {
    if (_phase != _Phase.shown) return;
    _rawDrag += d.delta.dy;

    final h = _sheetHeight;
    if (_rawDrag >= 0 || h <= 0) {
      _drag.value = math.max(_rawDrag, 0);
    } else {
      final x = -_rawDrag;
      _drag.value =
          -(1 - 1 / (x * CameoMotion.rubberBandCoefficient / h + 1)) * h;
    }
  }

  double get _shownDrag => _drag.value;

  void _dragEnd(DragEndDetails d) {
    if (_phase != _Phase.shown) return;
    final vy = d.velocity.pixelsPerSecond.dy;
    final h = _sheetHeight;
    final dismiss =
        (h > 0 && _drag.value >= h * CameoMotion.sheetDismissProgress) ||
        vy >= CameoMotion.sheetDismissVelocity;
    if (dismiss) {
      final travel = _travel;
      if (travel > 0 && !_reduceMotion) {
        final shown = _shownDrag;
        _drag.value = 0;
        _p.value = (_p.value - shown / travel).clamp(0.0, 1.0);
      }
      widget.onCancel?.call();
      _hide(velocity: travel > 0 ? -vy / travel : 0);
      return;
    }
    if (_reduceMotion) {
      _drag.value = 0;
    } else {
      _drag.springTo(0, CameoMotion.sheetSpring, velocity: vy);
    }
  }

  @override
  Widget build(BuildContext context) => GlassBackdrop(
    tone: GlassBackdropTone.fromToken(
      CameoEffects.liquidGlassBackdropCanvasScreen,
    ),
    child: Builder(builder: _buildOnCanvas),
  );

  Widget _buildOnCanvas(BuildContext context) {
    if (_phase == _Phase.hidden) return const SizedBox.shrink();
    final palette = CameoTheme.colorsOf(context);
    final bottom = confirmSheetBottom(
      widget.safeAreaBottom ?? MediaQuery.paddingOf(context).bottom,
    );
    final interactive = _phase == _Phase.shown;

    final sheet = GlassSurface(
      blur: CameoBlur.glassBar,
      tint: palette.glassTintPanel,
      radius: CameoLayout.confirmSheetRadius,
      padding: const EdgeInsets.all(CameoLayout.confirmSheetPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: CameoText(
              widget.title,
              style: CameoTextStyles.headingSm,
              color: palette.foregroundNeutralBase,
            ),
          ),
          const SizedBox(height: CameoLayout.confirmSheetTitleGap),
          CameoText(
            widget.body,
            style: CameoTextStyles.bodyMd,
            color: palette.foregroundNeutralMuted,
          ),
          const SizedBox(height: CameoLayout.confirmSheetActionsGap),
          if (widget.actionSize case final size?)
            SolidButton(
              key: ConfirmSheet.confirmKey,
              size: size,
              stretch: true,
              label: widget.confirmLabel,
              variant: widget.destructive
                  ? SolidButtonVariant.system
                  : SolidButtonVariant.defaultVariant,
              onPress: widget.onConfirm,
            )
          else
            PrimaryButton(
              key: ConfirmSheet.confirmKey,
              label: widget.confirmLabel,
              variant: widget.destructive
                  ? PrimaryButtonVariant.destructive
                  : PrimaryButtonVariant.prominent,
              onPress: widget.onConfirm,
            ),
          const SizedBox(height: CameoLayout.confirmSheetButtonGap),
          if (widget.actionSize case final size?)
            SolidButton(
              key: ConfirmSheet.cancelKey,
              size: size,
              stretch: true,
              label: widget.cancelLabel,
              variant: SolidButtonVariant.gray,
              onPress: widget.onCancel,
            )
          else
            PrimaryButton(
              key: ConfirmSheet.cancelKey,
              label: widget.cancelLabel,
              variant: PrimaryButtonVariant.secondary,
              onPress: widget.onCancel,
            ),
        ],
      ),
    );

    return IgnorePointer(
      ignoring: !interactive,
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onCancel,
            child: AnimatedBuilder(
              animation: Listenable.merge([_p, _dim]),
              builder: (context, _) => Opacity(
                key: ConfirmSheet.dimKey,
                opacity: _reduceMotion ? _dim.value : _p.value.clamp(0.0, 1.0),
                child: ColoredBox(color: palette.overlayDim),
              ),
            ),
          ),
          Positioned(
            left: CameoLayout.confirmSheetMarginX,
            right: CameoLayout.confirmSheetMarginX,
            bottom: bottom,
            child: AnimatedBuilder(
              animation: Listenable.merge([_p, _drag]),
              builder: (context, child) {
                final p = _p.value;

                return Transform.translate(
                  offset: Offset(
                    0,
                    (1 - p) * CameoLayout.confirmSheetMarginBottom + _shownDrag,
                  ),
                  child: FractionalTranslation(
                    translation: Offset(0, 1 - p),
                    child: child,
                  ),
                );
              },
              child: Semantics(
                scopesRoute: true,
                namesRoute: true,
                explicitChildNodes: true,
                label: widget.title,
                onDismiss: widget.onCancel,
                child: GestureDetector(
                  key: ConfirmSheet.sheetKey,
                  behavior: HitTestBehavior.opaque,
                  dragStartBehavior: DragStartBehavior.down,
                  onVerticalDragStart: _dragStart,
                  onVerticalDragUpdate: _dragUpdate,
                  onVerticalDragEnd: _dragEnd,
                  child: KeyedSubtree(key: _sheetBox, child: sheet),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
