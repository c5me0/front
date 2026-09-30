// Legacy photo grid with double-tap favorites and animated reflow. Featured photos
// occupy a two-by-two area.

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ClipOp;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter/widgets.dart';

import '../content/lab.g.dart';
import '../design_system/design_system.dart';
import 'heart_burst.dart';
import 'photo_grid_layout.dart';

enum PhotoGridVariant { bordered, gangneung }

class _VariantStyle {
  const _VariantStyle({
    required this.metrics,
    required this.edgeRadius,
    required this.cellRadius,
    required this.borderWidth,
  });

  final PhotoGridMetrics metrics;

  final double edgeRadius;

  final double cellRadius;

  final double borderWidth;
}

_VariantStyle _styleOf(PhotoGridVariant variant) => switch (variant) {
  PhotoGridVariant.bordered => const _VariantStyle(
    metrics: PhotoGridMetrics(
      columns: CameoLayout.photoGridColumns,
      padding: CameoLayout.photoGridPadding,
      gap: CameoLayout.photoGridGap,
    ),
    edgeRadius: CameoLayout.photoGridRowRadius,
    cellRadius: 0,
    borderWidth: CameoLayout.photoGridCellBorderWidth,
  ),
  PhotoGridVariant.gangneung => const _VariantStyle(
    metrics: PhotoGridMetrics(
      columns: CameoLayout.photoGridColumns,
      padding: CameoLayout.photoGridGangneungPadding,
      gap: CameoLayout.photoGridGangneungGap,
    ),
    edgeRadius: CameoLayout.photoGridGangneungCellRadius,
    cellRadius: CameoLayout.photoGridGangneungCellRadius,
    borderWidth: CameoLayout.photoGridGangneungCellBorderWidth,
  ),
};

@immutable
class _CellBox {
  const _CellBox({required this.frame, required this.rl, required this.rr});

  final PhotoGridFrame frame;
  final double rl;
  final double rr;

  static _CellBox lerp(_CellBox a, _CellBox b, double t, _GridBoxes to) =>
      _CellBox(
        frame: to.frameAt(a.frame, b.frame, t),
        rl: a.rl + (b.rl - a.rl) * t,
        rr: a.rr + (b.rr - a.rr) * t,
      );
}

@immutable
class _GridBoxes {
  const _GridBoxes({
    required this.boxes,
    required this.height,
    required this.padding,
    required this.width,
  });

  final List<_CellBox> boxes;
  final double height;
  final double padding;
  final double width;

  PhotoGridFrame frameAt(PhotoGridFrame a, PhotoGridFrame b, double t) =>
      PhotoGridFrame.lerp(a, b, t).containX(padding, width);

  static _GridBoxes lerp(_GridBoxes a, _GridBoxes b, double t) {
    if (t == 1) return b;
    if (t == 0) return a;
    return _GridBoxes(
      boxes: [
        for (var i = 0; i < b.boxes.length; i++)
          _CellBox.lerp(a.boxes[i], b.boxes[i], t, b),
      ],
      height: a.height + (b.height - a.height) * t,
      padding: b.padding,
      width: b.width,
    );
  }
}

_GridBoxes _gridBoxes(PhotoGridLayout layout, _VariantStyle v, double width) {
  final f = photoGridFrames(layout, v.metrics, width);
  final columns = v.metrics.columns;
  return _GridBoxes(
    boxes: [
      for (var i = 0; i < f.frames.length; i++)
        _CellBox(
          frame: f.frames[i],
          rl: layout.placements[i].col == 0 ? v.edgeRadius : v.cellRadius,
          rr: layout.placements[i].col + layout.placements[i].span == columns
              ? v.edgeRadius
              : v.cellRadius,
        ),
    ],
    height: f.height,
    padding: v.metrics.padding,
    width: width,
  );
}

int _lastToggled(List<bool> prev, List<bool> next, int fallback) {
  if (prev.length != next.length) return -1;
  var index = fallback;
  for (var i = 0; i < next.length; i++) {
    if (prev[i] != next[i]) index = i;
  }
  return index;
}

List<bool> photoGridInitialLikes(List<GridPhotoContent> photos) =>
    List.unmodifiable([for (final p in photos) p.liked]);

List<bool> photoGridToggleLike(List<bool> liked, int index) {
  if (index < 0 || index >= liked.length) return liked;
  return List.unmodifiable([
    for (var i = 0; i < liked.length; i++) i == index ? !liked[i] : liked[i],
  ]);
}

/// 'photoGrid.badge' · 'photoGrid.stroke' · 'photoGrid.burst'.
class PhotoGrid extends StatefulWidget {
  const PhotoGrid({
    super.key,
    required this.variant,
    required this.photos,
    required this.liked,
    this.onToggleLike,
    this.animateIn = false,
    this.appearIndex = 0,
    this.footer,
  });

  final PhotoGridVariant variant;

  final List<String> photos;

  final List<bool> liked;

  final ValueChanged<int>? onToggleLike;

  final bool animateIn;

  final int appearIndex;

  final Widget? footer;

  @override
  State<PhotoGrid> createState() => _PhotoGridState();
}

class _PhotoGridState extends State<PhotoGrid> with TickerProviderStateMixin {
  late final AnimationController _progress = AnimationController.unbounded(
    vsync: this,
    value: 1,
  );

  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: CameoMotion.durationFast,
    value: 1,
  );
  late final Listenable _ticks = Listenable.merge([_progress, _fade]);

  late PhotoGridLayout _layout;

  late final List<int> _orders;

  _GridBoxes? _from;
  double? _fromWidth;

  double? _lastWidth;

  int _burstIndex = -1;
  int _burstTrigger = 0;

  int _topIndex = -1;
  bool _reduceMotion = false;

  _VariantStyle get _style => _styleOf(widget.variant);

  @override
  void initState() {
    super.initState();

    _progress;
    _fade;
    assert(widget.photos.length == widget.liked.length);
    final columns = _style.metrics.columns;
    _layout = layoutPhotoGrid(widget.liked, columns);
    _orders = [
      for (final p in _layout.placements)
        widget.appearIndex + p.row * columns + p.col,
    ];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  }

  @override
  void didUpdateWidget(PhotoGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    assert(widget.photos.length == widget.liked.length);
    if (oldWidget.variant == widget.variant &&
        listEquals(oldWidget.liked, widget.liked)) {
      return;
    }
    final style = _style;
    final width = _lastWidth;
    final sameShape =
        oldWidget.variant == widget.variant &&
        oldWidget.liked.length == widget.liked.length;
    final animate = sameShape && width != null;
    if (animate) {
      final oldTo = _gridBoxes(_layout, style, width);
      final stored = _from;
      final oldFrom =
          stored != null &&
              _fromWidth == width &&
              stored.boxes.length == oldTo.boxes.length
          ? stored
          : oldTo;
      _from = _GridBoxes.lerp(oldFrom, oldTo, _progress.value);
      _fromWidth = width;
    } else {
      _from = null;
      _fromWidth = null;
    }
    _layout = layoutPhotoGrid(widget.liked, style.metrics.columns);
    _topIndex = _lastToggled(oldWidget.liked, widget.liked, _topIndex);

    var likedAt = -1;
    var unlikedAt = -1;
    if (sameShape) {
      for (var i = 0; i < widget.liked.length; i++) {
        if (widget.liked[i] && !oldWidget.liked[i]) {
          likedAt = i;
        } else if (!widget.liked[i] && oldWidget.liked[i]) {
          unlikedAt = i;
        }
      }
    }

    if (!animate) {
      _progress.value = 1;
      _fade.value = 1;
    } else if (_reduceMotion) {
      _progress.value = 1;
      _fade.value = 0;
      _fade.animateTo(1, curve: CameoMotion.easingStandard);
    } else {
      _fade.value = 1;
      _progress.value = 0;
      _progress.springTo(1, CameoMotion.likeReflowSpring);
    }

    if (likedAt >= 0) {
      _burstIndex = likedAt;
      _burstTrigger += 1;
      unawaited(HapticFeedback.mediumImpact());
    } else if (unlikedAt >= 0) {
      unawaited(HapticFeedback.lightImpact());
    }
  }

  @override
  void dispose() {
    _progress.dispose();
    _fade.dispose();
    super.dispose();
  }

  void _toggle(int index) => widget.onToggleLike?.call(index);

  @override
  Widget build(BuildContext context) {
    final style = _style;
    final m = style.metrics;
    final footer = widget.footer;

    final trim = footer != null ? m.padding : 0.0;
    return Column(
      key: const ValueKey('photoGrid'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) =>
              _buildGrid(style, constraints.maxWidth, trim),
        ),
        if (footer != null)
          Padding(
            padding: EdgeInsets.fromLTRB(
              m.padding,
              m.gap,
              m.padding,
              m.padding,
            ),
            child: footer,
          ),
      ],
    );
  }

  Widget _buildGrid(_VariantStyle style, double width, double trim) {
    _lastWidth = width;
    final to = _gridBoxes(_layout, style, width);
    final stored = _from;
    final from =
        stored != null &&
            _fromWidth == width &&
            stored.boxes.length == to.boxes.length
        ? stored
        : to;
    final liked = widget.liked;
    final top = _topIndex;

    final paintOrder = [
      for (var i = 0; i < liked.length; i++)
        if (!liked[i] && i != top) i,
      for (var i = 0; i < liked.length; i++)
        if (liked[i] && i != top) i,
      if (top >= 0 && top < liked.length) top,
    ];

    final fills = [
      for (final image in widget.photos)
        _PhotoFill(image: image, borderWidth: style.borderWidth),
    ];
    const burstSize = CameoMotion.likeBurstSize;

    return AnimatedBuilder(
      animation: _ticks,
      builder: (context, _) {
        final t = _progress.value;
        final fade = _fade.value;
        final height = math.max(
          0.0,
          from.height + (to.height - from.height) * t - trim,
        );
        var burstLeft = 0.0;
        var burstTop = 0.0;
        final b = _burstIndex;
        if (b >= 0 && b < to.boxes.length) {
          final f = to.frameAt(from.boxes[b].frame, to.boxes[b].frame, t);
          burstLeft = f.x + f.w / 2 - burstSize / 2;
          burstTop = f.y + f.h / 2 - burstSize / 2;
        }
        return SizedBox(
          height: height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (final i in paintOrder)
                _positionedCell(i, from, to, t, fade, fills[i]),
              Positioned(
                key: const ValueKey('photoGrid.burst'),
                left: burstLeft,
                top: burstTop,
                width: burstSize,
                height: burstSize,
                child: HeartBurst(trigger: _burstTrigger, size: burstSize),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _positionedCell(
    int i,
    _GridBoxes from,
    _GridBoxes to,
    double t,
    double fade,
    Widget fill,
  ) {
    final a = from.boxes[i];
    final b = to.boxes[i];
    final box = _CellBox.lerp(a, b, t, to);
    final f = box.frame;
    return Positioned(
      key: ValueKey('photoGrid.photo.$i'),
      left: f.x,
      top: f.y,
      width: math.max(0, f.w),
      height: math.max(0, f.h),
      child: _PhotoCell(
        index: i,
        liked: widget.liked[i],

        order: i < _orders.length ? _orders[i] : widget.appearIndex + i,
        animateIn: widget.animateIn,
        fade: a.frame == b.frame ? 1 : fade,
        borderRadius: BorderRadius.horizontal(
          left: Radius.circular(math.max(0, box.rl)),
          right: Radius.circular(math.max(0, box.rr)),
        ),
        onToggleLike: widget.onToggleLike == null ? null : _toggle,
        fill: fill,
      ),
    );
  }
}

class _PhotoFill extends StatelessWidget {
  const _PhotoFill({required this.image, required this.borderWidth});

  final String image;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(image, fit: BoxFit.cover),
        if (borderWidth > 0)
          DecoratedBox(
            key: const ValueKey('photoGrid.stroke'),
            decoration: BoxDecoration(
              border: Border.all(
                color: CameoTheme.colorsOf(context).strokeNeutralBase,
                width: borderWidth,
              ),
            ),
          ),
      ],
    );
  }
}

class _PhotoCell extends StatefulWidget {
  const _PhotoCell({
    required this.index,
    required this.liked,
    required this.order,
    required this.animateIn,
    required this.fade,
    required this.borderRadius,
    required this.onToggleLike,
    required this.fill,
  });

  final int index;
  final bool liked;
  final int order;
  final bool animateIn;

  final double fade;
  final BorderRadius borderRadius;
  final ValueChanged<int>? onToggleLike;
  final Widget fill;

  @override
  State<_PhotoCell> createState() => _PhotoCellState();
}

class _PhotoCellState extends State<_PhotoCell> with TickerProviderStateMixin {
  late final AnimationController _press = AnimationController.unbounded(
    vsync: this,
    value: 1,
  );

  late final AnimationController _badge = AnimationController.unbounded(
    vsync: this,
    value: widget.liked ? 1 : 0,
  );
  Timer? _badgeDelay;

  Offset? _downAt;
  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  }

  @override
  void didUpdateWidget(_PhotoCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.liked != widget.liked) _animateBadge(widget.liked);
  }

  void _animateBadge(bool liked) {
    _badgeDelay?.cancel();
    _badgeDelay = null;
    if (_reduceMotion) {
      _badge.animateTo(
        liked ? 1 : 0,
        duration: CameoMotion.durationFast,
        curve: CameoMotion.easingStandard,
      );
    } else if (liked) {
      _badge.stop();
      _badgeDelay = Timer(CameoMotion.likeBadgeDelay, () {
        if (mounted) _badge.springTo(1, CameoMotion.likeBadgeSpring);
      });
    } else {
      _badge.springTo(0, CameoSprings.press);
    }
  }

  void _pointerDown(PointerDownEvent event) {
    _downAt = event.position;
    if (_reduceMotion) {
      _press.value = CameoMotion.pressScale;
    } else {
      _press.springTo(CameoMotion.pressScale, CameoSprings.press);
    }
  }

  void _pointerMove(PointerMoveEvent event) {
    final start = _downAt;
    if (start != null && (event.position - start).distance > kTouchSlop) {
      _release();
    }
  }

  void _release([PointerEvent? _]) {
    if (_downAt == null) return;
    _downAt = null;
    if (_reduceMotion) {
      _press.value = 1;
    } else {
      _press.springTo(1, CameoSprings.chewy);
    }
  }

  void _toggle() => widget.onToggleLike?.call(widget.index);

  @override
  void dispose() {
    _badgeDelay?.cancel();
    _press.dispose();
    _badge.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onToggleLike != null;
    return _StaggerAppear(
      order: widget.order,
      animateIn: widget.animateIn,
      fade: widget.fade,
      child: Semantics(
        container: true,
        button: enabled,
        selected: widget.liked,
        label: '사진 ${widget.index + 1}${widget.liked ? ', 좋아요' : ''}',
        onTap: enabled ? _toggle : null,
        excludeSemantics: true,
        child: Listener(
          onPointerDown: _pointerDown,
          onPointerMove: _pointerMove,
          onPointerUp: _release,
          onPointerCancel: _release,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onDoubleTap: enabled ? _toggle : null,
            child: ScaleTransition(
              scale: _press,
              child: ClipRRect(
                borderRadius: widget.borderRadius,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    widget.fill,
                    Positioned(
                      right: CameoLayout.photoGridGangneungBadgeInset,
                      bottom: CameoLayout.photoGridGangneungBadgeInset,
                      width: CameoLayout.photoGridGangneungBadgeSize,
                      height: CameoLayout.photoGridGangneungBadgeSize,
                      child: AnimatedBuilder(
                        animation: _badge,
                        builder: (context, _) {
                          final b = _badge.value;
                          if (!widget.liked && b <= 0) {
                            return const SizedBox.shrink();
                          }
                          return Opacity(
                            opacity: _reduceMotion ? b.clamp(0.0, 1.0) : 1,
                            child: Transform.scale(
                              scale: _reduceMotion ? 1 : math.max(0, b),
                              child: const _Badge(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge();

  @override
  Widget build(BuildContext context) {
    final palette = CameoTheme.colorsOf(context);
    return IgnorePointer(
      key: const ValueKey('photoGrid.badge'),
      child: CustomPaint(
        painter: _OutsetShadowPainter(palette.shadows.overlay),
        child: CameoIcon(
          CameoIconName.heartFilled,
          size: CameoIconTokens.sizeXxs,
          color: palette.iconOnDark,
        ),
      ),
    );
  }
}

class _OutsetShadowPainter extends CustomPainter {
  const _OutsetShadowPainter(this.shadow);

  final BoxShadow shadow;

  @override
  void paint(Canvas canvas, Size size) {
    final box = Offset.zero & size;
    canvas
      ..save()
      ..clipRect(box, clipOp: ClipOp.difference)
      ..drawRect(
        box.shift(shadow.offset).inflate(shadow.spreadRadius),
        shadow.toPaint(),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_OutsetShadowPainter oldDelegate) =>
      oldDelegate.shadow != shadow;
}

class _StaggerAppear extends StatefulWidget {
  const _StaggerAppear({
    required this.order,
    required this.animateIn,
    required this.fade,
    required this.child,
  });

  final int order;
  final bool animateIn;
  final double fade;
  final Widget child;

  @override
  State<_StaggerAppear> createState() => _StaggerAppearState();
}

class _StaggerAppearState extends State<_StaggerAppear>
    with SingleTickerProviderStateMixin {
  late final AnimationController _appear = AnimationController.unbounded(
    vsync: this,
    value: widget.animateIn ? 0 : 1,
  );
  Timer? _delay;
  bool _scheduled = false;
  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (!_scheduled) {
      _scheduled = true;
      if (widget.animateIn) {
        final delay = CameoMotion.staggerItem * widget.order;
        if (delay == Duration.zero) {
          _play();
        } else {
          _delay = Timer(delay, _play);
        }
      }
    }
  }

  void _play() {
    if (!mounted) return;
    if (_reduceMotion) {
      _appear.animateTo(
        1,
        duration: CameoMotion.durationBase,
        curve: CameoMotion.easingStandard,
      );
    } else {
      _appear.springTo(1, CameoMotion.staggerSpring).whenCompleteOrCancel(() {
        if (mounted) _appear.value = 1;
      });
    }
  }

  @override
  void dispose() {
    _delay?.cancel();
    _appear.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rise = _reduceMotion ? 0.0 : CameoMotion.staggerRise;
    return AnimatedBuilder(
      animation: _appear,
      child: widget.child,
      builder: (context, child) {
        final p = _appear.value;
        return Opacity(
          opacity: (p.clamp(0.0, 1.0) * widget.fade).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - p) * rise),
            child: child,
          ),
        );
      },
    );
  }
}
