// Stable-key photo grid with favorite reflow, selection, and removal transitions. Keep
// surviving image Elements mounted while neighboring photos move or disappear.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter/widgets.dart';

import '../design_system/design_system.dart';
import '../navigation/spring_timing.dart';
import '../screens/home_timeline/album_timeline_model.dart'
    show GridBadge, cellHeartShown;
import 'album_appear.dart';
import 'controls.dart';
import 'heart_burst.dart';
import 'photo_grid_v5_model.dart';

@immutable
class PhotoGridV6Item {
  const PhotoGridV6Item({
    required this.id,
    required this.image,
    required this.tile,
    required this.label,
  });

  final String id;
  final ImageProvider image;

  final bool tile;

  final String label;

  @override
  bool operator ==(Object other) =>
      other is PhotoGridV6Item &&
      other.id == id &&
      other.image == image &&
      other.tile == tile &&
      other.label == label;

  @override
  int get hashCode => Object.hash(id, image, tile, label);
}

const GridV5Metrics photoGridV6Metrics = GridV5Metrics(
  columns: CameoLayout.albumV6GridColumns,
  gap: CameoLayout.albumV6GridGap,
  paddingTop: CameoLayout.albumV6GridPadding,
  paddingX: CameoLayout.albumV6GridPadding,
  paddingBottom: CameoLayout.albumV6GridPadding,
  edgeRadius: CameoLayout.albumV6GridRowRadius,
  featuredExtraHeight: 0,
);

class PhotoGridV6 extends StatefulWidget {
  const PhotoGridV6({
    super.key,
    required this.items,
    this.badge = GridBadge.tile,
    this.selecting = false,
    this.selected = const {},
    this.modeKey = '',
    this.onToggleLike,
    this.onOpen,
    this.onToggleSelect,
    this.rowAppear,
    this.appearRise = 0,
  });

  final List<PhotoGridV6Item> items;

  final GridBadge badge;

  final bool selecting;
  final Set<String> selected;

  final String modeKey;

  final ValueChanged<String>? onToggleLike;

  final ValueChanged<String>? onOpen;

  final ValueChanged<String>? onToggleSelect;

  final List<Animation<double>>? rowAppear;

  final double appearRise;

  static Key cellKey(String id) => ValueKey('photoGridV6.cell.$id');
  static const Key burstKey = ValueKey('photoGridV6.burst');
  static const Key heartKey = ValueKey('photoGridV6.heart');
  static const Key checkKey = ValueKey('photoGridV6.check');
  static const Key imageKey = ValueKey('photoGridV6.image');

  @override
  State<PhotoGridV6> createState() => PhotoGridV6State();
}

enum _ReflowMode { spring, fade }

class PhotoGridV6State extends State<PhotoGridV6>
    with TickerProviderStateMixin {
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

  double? _width;
  GridV5Boxes? _from;
  GridV5Boxes? _to;

  List<PhotoGridV6Item> _shownItems = const [];
  String _shownMode = '';

  List<PhotoGridV6Item> _exiting = const [];
  int _token = 0;

  String _burstId = '';
  int _burstTrigger = 0;

  String _toggledId = '';
  bool _reduceMotion = false;

  @visibleForTesting
  GridV5Boxes? get targetBoxes => _to;
  @visibleForTesting
  GridV5Boxes? get fromBoxes => _from;
  @visibleForTesting
  double get reflowProgress => _progress.value;
  @visibleForTesting
  List<String> get exitingIds => [for (final p in _exiting) p.id];

  @visibleForTesting
  SpringDescription? lastSpring;

  @override
  void initState() {
    super.initState();

    _progress;
    _fade;
    _shownItems = widget.items;
    _shownMode = widget.modeKey;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  }

  static GridV5Boxes _targetFor(PhotoGridV6 w, double width) => gridV5Boxes(
    [for (final p in w.items) p.id],
    [for (final p in w.items) p.tile],
    photoGridV6Metrics,
    width,
  );

  static bool _sameLayoutInput(PhotoGridV6 a, PhotoGridV6 b) {
    if (a.items.length != b.items.length) return false;
    for (var i = 0; i < a.items.length; i++) {
      if (a.items[i].id != b.items[i].id) return false;
      if (a.items[i].tile != b.items[i].tile) return false;
    }
    return true;
  }

  @override
  void didUpdateWidget(PhotoGridV6 oldWidget) {
    super.didUpdateWidget(oldWidget);
    final width = _width;
    if (width == null || _to == null) return;
    if (_sameLayoutInput(oldWidget, widget)) {
      _shownItems = widget.items;
      _shownMode = widget.modeKey;
      return;
    }
    final target = _targetFor(widget, width);
    final diff = gridV5Diff(_to!.ids, target.ids);
    final modeChanged = _shownMode != widget.modeKey;

    var likedAt = '';
    var unlikedAt = '';
    if (!modeChanged &&
        !widget.selecting &&
        diff.entering.isEmpty &&
        diff.exiting.isEmpty) {
      final prevTile = {for (final p in _shownItems) p.id: p.tile};
      for (final p in widget.items) {
        final was = prevTile[p.id];
        if (was == null) continue;
        if (p.tile && !was) {
          likedAt = p.id;
        } else if (!p.tile && was) {
          unlikedAt = p.id;
        }
      }
    }
    final toggled = likedAt.isNotEmpty ? likedAt : unlikedAt;
    if (toggled.isNotEmpty) _toggledId = toggled;
    final mode = _reduceMotion ? _ReflowMode.fade : _ReflowMode.spring;
    final exitSet = diff.exiting.toSet();
    _exiting = mode == _ReflowMode.spring
        ? [
            for (final p in _shownItems)
              if (exitSet.contains(p.id)) p,
          ]
        : const [];
    _token += 1;
    _shownItems = widget.items;
    _shownMode = widget.modeKey;
    final spring = modeChanged && diff.entering.isEmpty && diff.exiting.isEmpty
        ? CameoMotion.selectModeSpring
        : CameoMotion.likeReflowSpring;
    _reflow(target, mode, spring, _token);
    if (likedAt.isNotEmpty) {
      _burstId = likedAt;
      _burstTrigger += 1;
      unawaited(HapticFeedback.mediumImpact());
    } else if (unlikedAt.isNotEmpty) {
      unawaited(HapticFeedback.lightImpact());
    }
  }

  void _reflow(
    GridV5Boxes next,
    _ReflowMode mode,
    SpringDescription spring,
    int token,
  ) {
    lastSpring = spring;
    _from = gridV5Current(_from!, _to!, _progress.value);
    _to = next;
    if (mode == _ReflowMode.fade) {
      _progress.value = 1;
      _fade.value = 0;
      _fade.animateTo(1, curve: CameoMotion.easingStandard);
      return;
    }
    _fade.value = 1;
    _progress.value = 0;
    _progress.animateWith(cameoSpringSimulation(spring, from: 0, to: 1)).then((
      _,
    ) {
      if (mounted && _token == token && _exiting.isNotEmpty) {
        setState(() => _exiting = const []);
      }
    });
  }

  @override
  void dispose() {
    _progress.dispose();
    _fade.dispose();
    super.dispose();
  }

  Rect? locate(String id) {
    final b = _to?.boxes[id];
    final box = context.findRenderObject();
    if (b == null || box is! RenderBox || !box.hasSize || !box.attached) {
      return null;
    }
    return MatrixUtils.transformRect(box.getTransformTo(null), b.toRect());
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (_width != width || _to == null) {
          _width = width;
          final target = _targetFor(widget, width);
          _from = target;
          _to = target;
          _exiting = const [];
          _shownItems = widget.items;
          _shownMode = widget.modeKey;
        }
        return _buildGrid(context);
      },
    );
  }

  Widget _buildGrid(BuildContext context) {
    final from = _from!;
    final to = _to!;
    final w = widget;

    final fills = <String, Widget>{
      for (final p in [..._exiting, ...w.items])
        p.id: Image(
          key: PhotoGridV6.imageKey,
          image: p.image,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          excludeFromSemantics: true,
        ),
    };

    final below = <PhotoGridV6Item>[];
    final above = <PhotoGridV6Item>[];
    PhotoGridV6Item? top;
    for (final p in w.items) {
      if (p.id == _toggledId) {
        top = p;
      } else if (p.tile) {
        above.add(p);
      } else {
        below.add(p);
      }
    }
    final order = [...below, ...above, ?top];
    final exiting = _exiting;
    const burstSize = CameoMotion.likeBurstSize;

    return AnimatedBuilder(
      animation: _ticks,
      builder: (context, _) {
        final t = _progress.value;
        final fade = _fade.value;
        final height = math.max(
          0.0,
          from.height + (to.height - from.height) * t,
        );
        Widget cell(PhotoGridV6Item item, {required bool exiting}) {
          final id = item.id;
          final look = gridV5CellLook(from, to, id, t, exiting);

          final key = ValueKey('photoGridV6.slot.$id');
          if (look == null) return SizedBox.shrink(key: key);
          final f = look.box;
          final a = from.boxes[id];
          final b = to.boxes[id];
          final changed = a == null || b == null || !a.sameFrame(b);
          final row = (b ?? a)?.row ?? 0;
          final rows = w.rowAppear;
          final appear = rows != null && row < rows.length
              ? rows[row]
              : kAlwaysCompleteAnimation;
          return Positioned(
            key: key,
            left: f.x,
            top: f.y,
            width: math.max(0, f.w),
            height: math.max(0, f.h),
            child: Opacity(
              opacity: (look.opacity * (changed ? fade : 1)).clamp(0.0, 1.0),
              child: Transform.scale(
                scale: look.scale,
                child: AlbumAppear(
                  progress: appear,
                  rise: w.appearRise,
                  child: _PhotoCellV6(
                    item: item,
                    exiting: exiting,
                    badge: w.badge,
                    selecting: w.selecting,
                    selected: !exiting && w.selected.contains(id),
                    reduceMotion: _reduceMotion,
                    radiusLeft: math.max(0, f.rl),
                    radiusRight: math.max(0, f.rr),
                    fill: fills[id]!,
                    onToggleLike: w.onToggleLike,
                    onOpen: w.onOpen,
                    onToggleSelect: w.onToggleSelect,
                  ),
                ),
              ),
            ),
          );
        }

        var burstLeft = 0.0;
        var burstTop = 0.0;
        if (_burstId.isNotEmpty) {
          final look = gridV5CellLook(from, to, _burstId, t, false);
          if (look != null) {
            final f = look.box;
            burstLeft = f.x + f.w / 2 - burstSize / 2;
            burstTop = f.y + f.h / 2 - burstSize / 2;
          }
        }
        return SizedBox(
          height: height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (final p in exiting) cell(p, exiting: true),
              for (final p in order) cell(p, exiting: false),
              Positioned(
                key: PhotoGridV6.burstKey,
                left: burstLeft,
                top: burstTop,
                width: burstSize,
                height: burstSize,
                child: IgnorePointer(
                  child: HeartBurst(trigger: _burstTrigger, size: burstSize),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PhotoCellV6 extends StatefulWidget {
  const _PhotoCellV6({
    required this.item,
    required this.exiting,
    required this.badge,
    required this.selecting,
    required this.selected,
    required this.reduceMotion,
    required this.radiusLeft,
    required this.radiusRight,
    required this.fill,
    required this.onToggleLike,
    required this.onOpen,
    required this.onToggleSelect,
  });

  final PhotoGridV6Item item;
  final bool exiting;
  final GridBadge badge;
  final bool selecting;
  final bool selected;
  final bool reduceMotion;
  final double radiusLeft;
  final double radiusRight;
  final Widget fill;
  final ValueChanged<String>? onToggleLike;
  final ValueChanged<String>? onOpen;
  final ValueChanged<String>? onToggleSelect;

  bool get heartOn => cellHeartShown(
    badge,
    tile: item.tile,
    selected: selecting && selected,
    exiting: exiting,
  );

  @override
  State<_PhotoCellV6> createState() => _PhotoCellV6State();
}

class _PhotoCellV6State extends State<_PhotoCellV6>
    with TickerProviderStateMixin {
  late final AnimationController _press = AnimationController.unbounded(
    vsync: this,
    value: 1,
  );

  late final AnimationController _heart = AnimationController.unbounded(
    vsync: this,
    value: widget.heartOn ? 1 : 0,
  );
  late bool _heartMounted = widget.heartOn;
  Timer? _heartDelay;

  late final AnimationController _dim = AnimationController.unbounded(
    vsync: this,
    value: widget.selected ? 1 : 0,
  );

  Offset? _downAt;

  @override
  void initState() {
    super.initState();
    _press;
    _heart;
    _dim;
  }

  @override
  void didUpdateWidget(_PhotoCellV6 oldWidget) {
    super.didUpdateWidget(oldWidget);
    final on = widget.heartOn;
    if (oldWidget.heartOn != on) {
      if (on) _heartMounted = true;
      _animateHeart(on);
    }
    if (oldWidget.selected != widget.selected) {
      final target = widget.selected ? 1.0 : 0.0;
      if (widget.reduceMotion) {
        _dim.value = target;
      } else {
        _dim.springTo(target, CameoMotion.selectModeSpring);
      }
    }
  }

  void _animateHeart(bool on) {
    _heartDelay?.cancel();
    _heartDelay = null;
    final target = on ? 1.0 : 0.0;
    if (widget.reduceMotion) {
      _heart.animateTo(
        target,
        duration: CameoMotion.durationFast,
        curve: CameoMotion.easingStandard,
      );
    } else if (on) {
      _heart.stop();
      _heartDelay = Timer(CameoMotion.likeBadgeDelay, () {
        if (mounted) _heart.springTo(1, CameoMotion.likeBadgeSpring);
      });
    } else {
      _heart.springTo(0, CameoSprings.press);
    }
  }

  void _pointerDown(PointerDownEvent event) {
    _downAt = event.position;
    if (widget.reduceMotion) {
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
    if (widget.reduceMotion) {
      _press.value = 1;
    } else {
      _press.springTo(1, CameoSprings.chewy);
    }
  }

  @override
  void dispose() {
    _heartDelay?.cancel();
    _press.dispose();
    _heart.dispose();
    _dim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final id = w.item.id;
    final reduce = w.reduceMotion;

    final every = w.badge == GridBadge.every;
    final body = ClipRRect(
      borderRadius: BorderRadius.horizontal(
        left: Radius.circular(w.radiusLeft),
        right: Radius.circular(w.radiusRight),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: _dim,
            child: w.fill,
            builder: (context, child) => Opacity(
              opacity:
                  1 -
                  (1 - CameoLayout.albumV6BadgeSelectedImageOpacity) *
                      _dim.value.clamp(0.0, 1.0),
              child: child,
            ),
          ),
          if (_heartMounted)
            Positioned(
              key: const ValueKey('photoGridV6.heartSlot'),
              right: every
                  ? CameoLayout.albumV6BadgeHeartInset
                  : CameoLayout.albumV6GridLikedHeartInsetRight,
              bottom: every
                  ? CameoLayout.albumV6BadgeHeartInset
                  : CameoLayout.albumV6GridLikedHeartInsetBottom,
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _heart,
                  child: const HeartControl(
                    key: PhotoGridV6.heartKey,
                    active: true,
                  ),
                  builder: (context, child) {
                    final k = _heart.value;
                    return Opacity(
                      opacity: reduce ? k.clamp(0.0, 1.0) : 1,
                      child: Transform.scale(
                        scale: reduce ? 1 : math.max(0, k),
                        child: child,
                      ),
                    );
                  },
                ),
              ),
            ),
          if (w.selecting && w.selected && !w.exiting)
            Positioned(
              key: const ValueKey('photoGridV6.checkSlot'),
              right: CameoLayout.albumV6BadgeCheckInset,
              bottom: CameoLayout.albumV6BadgeCheckInset,
              child: _CheckPop(reduceMotion: reduce),
            ),
        ],
      ),
    );
    final pressed = ScaleTransition(scale: _press, child: body);

    final exiting = w.exiting;
    final selecting = w.selecting;
    final onTap = exiting
        ? null
        : selecting
        ? (w.onToggleSelect == null ? null : () => w.onToggleSelect!(id))
        : (w.onOpen == null ? null : () => w.onOpen!(id));
    final onDoubleTap = exiting || selecting || w.onToggleLike == null
        ? null
        : () => w.onToggleLike!(id);
    return IgnorePointer(
      ignoring: exiting,
      child: ExcludeSemantics(
        excluding: exiting,
        child: Semantics(
          container: true,
          button: true,
          selected: selecting ? w.selected : w.item.tile,
          label: w.item.label,
          onTap: onTap,
          customSemanticsActions: onDoubleTap == null
              ? null
              : {const CustomSemanticsAction(label: '좋아요'): onDoubleTap},
          excludeSemantics: true,
          child: Listener(
            onPointerDown: exiting ? null : _pointerDown,
            onPointerMove: exiting ? null : _pointerMove,
            onPointerUp: exiting ? null : _release,
            onPointerCancel: exiting ? null : _release,
            child: GestureDetector(
              key: PhotoGridV6.cellKey(id),
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              onDoubleTap: onDoubleTap,
              child: pressed,
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckPop extends StatefulWidget {
  const _CheckPop({required this.reduceMotion});

  final bool reduceMotion;

  @override
  State<_CheckPop> createState() => _CheckPopState();
}

class _CheckPopState extends State<_CheckPop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController.unbounded(
    vsync: this,
    value: widget.reduceMotion ? 1 : 0,
  );

  @override
  void initState() {
    super.initState();
    if (!widget.reduceMotion) {
      _pop.animateWith(
        cameoSpringSimulation(
          CameoMotion.selectModeCheckSpring,
          from: 0,
          to: 1,
        ),
      );
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedBuilder(
      animation: _pop,
      child: const SelectControl(
        key: PhotoGridV6.checkKey,
        selected: true,
        showRing: false,
      ),
      builder: (context, child) =>
          Transform.scale(scale: math.max(0, _pop.value), child: child),
    ),
  );
}
