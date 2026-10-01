// Call photo-sharing sheet with immediate-share and multi-select modes. The live camera
// cell opens capture; retained photo selections follow album state.

import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../content/app.g.dart';
import '../content/lab.g.dart';
import '../design_system/design_system.dart';
import '../state/session.dart' show PhotoSheetVariant;
import 'call_camera_geometry.dart';
import 'camera_viewfinder.dart';
import 'controls.dart';
import 'solid_button.dart';

@immutable
class PhotoSheetItem {
  const PhotoSheetItem({
    required this.id,
    required this.image,
    required this.checked,
  });

  final String id;
  final ImageProvider image;

  final bool checked;
}

class PhotoSheet extends StatefulWidget {
  const PhotoSheet({
    super.key,
    required this.open,
    required this.variant,
    required this.items,
    required this.selectedCount,
    required this.onTapPhoto,
    required this.onShare,
    required this.onLive,
    required this.onClose,
    this.onOpened,
    this.onClosed,
    this.livePreview = false,
    this.cameraListLoader,
  });

  final bool open;
  final PhotoSheetVariant variant;
  final List<PhotoSheetItem> items;

  final int selectedCount;
  final void Function(PhotoSheetItem item, int index) onTapPhoto;
  final VoidCallback onShare;
  final VoidCallback onLive;
  final VoidCallback onClose;

  final VoidCallback? onOpened;

  final VoidCallback? onClosed;

  final bool livePreview;

  final CameraListLoader? cameraListLoader;

  static const Key sheetKey = ValueKey('photoSheet.sheet');
  static const Key outsideKey = ValueKey('photoSheet.outside');
  static const Key headerKey = ValueKey('photoSheet.header');
  static const Key liveKey = ValueKey('photoSheet.live');
  static const Key closeKey = ValueKey('photoSheet.close');
  static const Key shareKey = ValueKey('photoSheet.share');
  static const Key gridKey = ValueKey('photoSheet.grid');
  static Key cellKey(int index) => ValueKey('photoSheet.cell.$index');

  @override
  State<PhotoSheet> createState() => PhotoSheetState();
}

class PhotoSheetState extends State<PhotoSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _y = AnimationController.unbounded(
    vsync: this,
  );
  bool _placed = false;

  Size _screen = Size.zero;
  final ScrollController _scroll = ScrollController();
  late final _SheetPullPhysics _physics = _SheetPullPhysics(
    pull: _pullBy,
    pulled: () => _pulled,
  );

  double _releaseVelocity = 0;
  VelocityTracker? _tracker;
  bool _reduceMotion = false;

  double get offset => _y.value;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _screen = MediaQuery.sizeOf(context);
    if (!_placed) {
      _placed = true;
      _y.value = widget.open ? 0 : photoSheetHiddenOffset(_screen.height);
    }
  }

  double get _sheetHeight =>
      photoSheetRect(_screen.width, _screen.height).height;

  @override
  void didUpdateWidget(PhotoSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.open != oldWidget.open) _animate();
  }

  void _animate() {
    final open = widget.open;
    final velocity = _releaseVelocity;
    _releaseVelocity = 0;
    if (open && _scroll.hasClients) _scroll.jumpTo(0);
    final to = open ? 0.0 : photoSheetHiddenOffset(_screen.height);
    void done() => open ? widget.onOpened?.call() : widget.onClosed?.call();
    if (_reduceMotion) {
      _y
        ..stop()
        ..value = to;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.open == open) done();
      });
      return;
    }
    _y.springTo(to, CameoMotion.photoSheetSpring, velocity: velocity).then((_) {
      if (!mounted || _y.isAnimating || widget.open != open) return;
      _y.value = to;
      done();
    });
  }

  void _pullBy(double delta) {
    if (!widget.open) return;
    _y
      ..stop()
      ..value = math.max(0, _y.value + delta);
  }

  double get _pulled => widget.open ? _y.value : 0;

  void _release(double velocity) {
    if (!widget.open) return;
    final d = _y.value;
    if (d <= 0) return;
    if (photoSheetShouldClose(d, velocity, _sheetHeight)) {
      _releaseVelocity = velocity;
      widget.onClose();
      return;
    }
    if (_reduceMotion) {
      _y.value = 0;
    } else {
      _y.springTo(0, CameoMotion.photoSheetSpring, velocity: velocity);
    }
  }

  @override
  void dispose() {
    _y.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CameoTheme(
      mode: CameoColorMode.light,
      child: Builder(builder: _buildSheet),
    );
  }

  Widget _buildSheet(BuildContext context) {
    final c = CameoTheme.colorsOf(context);
    final open = widget.open;
    final rect = photoSheetRect(_screen.width, _screen.height);
    const radius = CameoLayout.photoSheetV6Radius;
    final sheet = SizedBox(
      key: PhotoSheet.sheetKey,
      width: rect.width,
      height: rect.height,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: c.backgroundCanvasNeutralBase,
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          shadows: [c.shadows.overlay],
        ),
        child: ClipRSuperellipse(
          borderRadius: BorderRadius.circular(radius),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(context),
              SizedBox(
                height: photoSheetGridHeight(_screen.height),
                child: _grid(context, rect.width),
              ),
            ],
          ),
        ),
      ),
    );
    return IgnorePointer(
      ignoring: !open,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (open)
            GestureDetector(
              key: PhotoSheet.outsideKey,
              behavior: HitTestBehavior.opaque,
              onTap: widget.onClose,
              excludeFromSemantics: true,
            )
          else
            const SizedBox.shrink(key: ValueKey('photoSheet.noOutside')),
          Positioned(
            key: const ValueKey('photoSheet.layer'),
            left: rect.left,
            top: rect.top,
            width: rect.width,
            height: rect.height,
            child: AnimatedBuilder(
              animation: _y,
              child: ExcludeSemantics(
                excluding: !open,
                child: Semantics(
                  scopesRoute: open,
                  explicitChildNodes: true,
                  child: sheet,
                ),
              ),
              builder: (context, child) => Transform.translate(
                offset: Offset(0, _y.value),
                child: child,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    final c = CameoTheme.colorsOf(context);
    return GestureDetector(
      key: PhotoSheet.headerKey,
      behavior: HitTestBehavior.opaque,

      dragStartBehavior: DragStartBehavior.down,
      onVerticalDragUpdate: (d) => _pullBy(d.primaryDelta ?? 0),
      onVerticalDragEnd: (d) => _release(d.primaryVelocity ?? 0),
      onVerticalDragCancel: () => _release(0),
      child: SizedBox(
        height: CameoLayout.photoSheetV6HeaderHeight,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: CameoLayout.photoSheetV6HeaderTitleTop,
              child: Semantics(
                header: true,
                child: CameoText(
                  LabSamples.of(context).labInCallV5.photoSheet.title,
                  style: CameoTextStyles.headingSmStrong,
                  color: c.foregroundNeutralBase,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            Positioned(
              left: CameoLayout.photoSheetV6HeaderPadding,
              top: CameoLayout.photoSheetV6HeaderPadding,
              child: SolidButton(
                key: PhotoSheet.closeKey,
                size: SolidButtonSize.md,
                variant: SolidButtonVariant.gray,
                icon: CameoIconName.x,
                semanticLabel: AppContent.of(context).photoSheetV5.closeLabel,
                onPress: widget.onClose,
              ),
            ),
            if (widget.variant == PhotoSheetVariant.multi)
              Positioned(
                right: CameoLayout.photoSheetV6HeaderPadding,
                top: CameoLayout.photoSheetV6HeaderPadding,
                child: _ShareButton(
                  count: widget.selectedCount,
                  onPress: widget.onShare,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _grid(BuildContext context, double width) {
    final items = widget.items;
    final w = _screen.width;
    final live = photoSheetLiveCell(w);
    final content = SizedBox(
      width: width,
      height: photoSheetContentHeight(items.length, w),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            width: live.width,
            height: live.height,
            child: Semantics(
              button: true,
              label: AppContent.of(context).photoSheetV5.liveCameraLabel,
              excludeSemantics: true,
              child: GestureDetector(
                key: PhotoSheet.liveKey,
                behavior: HitTestBehavior.opaque,
                onTap: widget.onLive,

                child: widget.livePreview && widget.open
                    ? CameraViewfinder(
                        facing: CameraFacing.back,
                        placeholder: labInCallV5.photoSheet.liveCell.image,
                        radius: 0,
                        cameraListLoader: widget.cameraListLoader,
                      )
                    : Image.asset(
                        labInCallV5.photoSheet.liveCell.image,
                        fit: BoxFit.cover,
                        excludeFromSemantics: true,
                        gaplessPlayback: true,
                      ),
              ),
            ),
          ),
          for (var i = 0; i < items.length; i++)
            _cell(items[i], i, photoSheetCellFrame(i, w)),
        ],
      ),
    );

    return Listener(
      onPointerDown: (e) {
        _tracker = VelocityTracker.withKind(e.kind)
          ..addPosition(e.timeStamp, e.position);
      },
      onPointerMove: (e) => _tracker?.addPosition(e.timeStamp, e.position),
      onPointerUp: (e) {
        final v = _tracker?.getVelocity().pixelsPerSecond.dy ?? 0;
        _tracker = null;
        if (_pulled > 0) _release(v);
      },
      onPointerCancel: (_) {
        _tracker = null;
        if (_pulled > 0) _release(0);
      },
      child: SingleChildScrollView(
        key: PhotoSheet.gridKey,
        controller: _scroll,
        physics: _physics,
        child: content,
      ),
    );
  }

  Widget _cell(
    PhotoSheetItem item,
    int index,
    ({double x, double y, double size, int row, int col}) frame,
  ) {
    final n = index + 1;
    final multi = widget.variant == PhotoSheetVariant.multi;
    final label = multi
        ? fillTemplate(AppContent.of(context).v6.accessibility.photo, {
            'index': n,
          })
        : item.checked
        ? fillTemplate(AppContent.of(context).v6.accessibility.resendPhoto, {
            'index': n,
          })
        : fillTemplate(AppContent.of(context).v6.accessibility.sendPhoto, {
            'index': n,
          });
    return Positioned(
      key: ValueKey('photoSheet.slot.${item.id}'),
      left: frame.x,
      top: frame.y,
      width: frame.size,
      height: frame.size,
      child: Semantics(
        selected: multi ? item.checked : null,
        child: PressScale(
          key: PhotoSheet.cellKey(index),
          onPress: () => widget.onTapPhoto(item, index),
          accessibilityLabel: label,
          child: _SheetCellBody(item: item),
        ),
      ),
    );
  }
}

class _SheetCellBody extends StatelessWidget {
  const _SheetCellBody({required this.item});

  final PhotoSheetItem item;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedOpacity(
          opacity: item.checked ? CameoLayout.controlSelectedImageOpacity : 1,
          duration: reduceMotion ? Duration.zero : CameoMotion.durationFast,
          curve: CameoMotion.easingStandard,
          child: Image(
            image: item.image,
            fit: BoxFit.cover,
            excludeFromSemantics: true,
            gaplessPlayback: true,
          ),
        ),
        Positioned(
          right: CameoLayout.controlCheckInsetSheet,
          bottom: CameoLayout.controlCheckInsetSheet,
          child: SelectControl(selected: item.checked),
        ),
      ],
    );
  }
}

class _ShareButton extends StatefulWidget {
  const _ShareButton({required this.count, required this.onPress});

  final int count;
  final VoidCallback onPress;

  @override
  State<_ShareButton> createState() => _ShareButtonState();
}

class _ShareButtonState extends State<_ShareButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scale = AnimationController.unbounded(
    vsync: this,
    value: widget.count > 0 ? 1 : CameoMotion.transitionZoomChromeScaleFrom,
  );
  late int _shown = math.max(1, widget.count);

  @override
  void didUpdateWidget(_ShareButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.count > 0) _shown = widget.count;
    final was = oldWidget.count > 0;
    final visible = widget.count > 0;
    if (was == visible) return;
    final to = visible ? 1.0 : CameoMotion.transitionZoomChromeScaleFrom;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _scale.value = to;
      return;
    }
    _scale
        .springTo(
          to,
          visible
              ? CameoMotion.transitionZoomChromeSpring
              : CameoMotion.transitionZoomChromeExitSpring,
        )
        .then((_) {
          if (mounted && !_scale.isAnimating) _scale.value = to;
        });
  }

  @override
  void dispose() {
    _scale.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.count > 0;
    final vars = {'count': _shown};
    return IgnorePointer(
      ignoring: !visible,
      child: ExcludeSemantics(
        excluding: !visible,
        child: ScaleTransition(
          scale: _scale,
          child: SolidButton(
            key: PhotoSheet.shareKey,
            size: SolidButtonSize.md,
            label: fillTemplate(
              AppContent.of(context).photoSheetV5.share,
              vars,
            ),
            semanticLabel: fillTemplate(
              AppContent.of(context).photoSheetV5.shareAccessibilityLabel,
              vars,
            ),
            onPress: widget.onPress,
          ),
        ),
      ),
    );
  }
}

class _SheetPullPhysics extends ClampingScrollPhysics {
  const _SheetPullPhysics({required this.pull, this.pulled, super.parent});

  final ValueChanged<double> pull;

  final double Function()? pulled;

  @override
  _SheetPullPhysics applyTo(ScrollPhysics? ancestor) => _SheetPullPhysics(
    pull: pull,
    pulled: pulled,
    parent: buildParent(ancestor),
  );

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    if (offset > 0 && position.pixels <= position.minScrollExtent) {
      pull(offset);
      return 0;
    }
    final down = pulled?.call() ?? 0;
    if (offset < 0 && down > 0) {
      final used = math.min(-offset, down);
      pull(-used);
      return offset + used;
    }
    return super.applyPhysicsToUserOffset(position, offset);
  }
}
