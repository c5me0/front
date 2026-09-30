// Pure photo-grid sizing and frame calculations. Normalize featured tiles to a two-by-
// two span and derive dimensions from viewport width.

import 'dart:math' as math;
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';

import '../design_system/design_system.dart';
import 'photo_grid_layout.dart';

@immutable
class GridV5Metrics {
  const GridV5Metrics({
    required this.columns,
    required this.gap,
    required this.paddingTop,
    required this.paddingX,
    required this.paddingBottom,
    required this.edgeRadius,
    required this.featuredExtraHeight,
  });

  const GridV5Metrics.album({
    required this.paddingTop,
    required this.paddingX,
    required this.paddingBottom,
  }) : columns = CameoLayout.albumV5GridColumns,
       gap = CameoLayout.albumV5GridGap,
       edgeRadius = CameoLayout.albumV5GridRowRadius,
       featuredExtraHeight =
           CameoLayout.albumV5FeaturedHeight - CameoLayout.albumV5FeaturedWidth;

  final int columns;
  final double gap;
  final double paddingTop;
  final double paddingX;
  final double paddingBottom;

  final double edgeRadius;

  final double featuredExtraHeight;

  @override
  bool operator ==(Object other) =>
      other is GridV5Metrics &&
      other.columns == columns &&
      other.gap == gap &&
      other.paddingTop == paddingTop &&
      other.paddingX == paddingX &&
      other.paddingBottom == paddingBottom &&
      other.edgeRadius == edgeRadius &&
      other.featuredExtraHeight == featuredExtraHeight;

  @override
  int get hashCode => Object.hash(
    columns,
    gap,
    paddingTop,
    paddingX,
    paddingBottom,
    edgeRadius,
    featuredExtraHeight,
  );
}

@immutable
class GridV5Box {
  const GridV5Box({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.rl,
    required this.rr,
    required this.row,
  });

  final double x;
  final double y;
  final double w;
  final double h;
  final double rl;
  final double rr;
  final int row;

  Rect toRect() => Rect.fromLTWH(x, y, w, h);

  bool sameFrame(GridV5Box other) =>
      other.x == x && other.y == y && other.w == w && other.h == h;

  @override
  bool operator ==(Object other) =>
      other is GridV5Box &&
      other.x == x &&
      other.y == y &&
      other.w == w &&
      other.h == h &&
      other.rl == rl &&
      other.rr == rr &&
      other.row == row;

  @override
  int get hashCode => Object.hash(x, y, w, h, rl, rr, row);

  @override
  String toString() => 'GridV5Box($x, $y, ${w}x$h, r $rl/$rr, row $row)';
}

@immutable
class GridV5Boxes {
  const GridV5Boxes({
    required this.ids,
    required this.boxes,
    required this.height,
    required this.rows,
    required this.width,
    required this.paddingX,
  });

  final List<String> ids;
  final Map<String, GridV5Box> boxes;

  final double height;

  final int rows;

  final double width;
  final double paddingX;
}

///   cell = (width − 2·paddingX − (columns−1)·gap) / columns   (393 → 73.8)
///   x = paddingX + col·(cell + gap) · y = paddingTop + row·(cell + gap)

///   height = paddingTop + rows·cell + (rows−1)·gap + paddingBottom (rows 0 → paddingTop + paddingBottom)
GridV5Boxes gridV5Boxes(
  List<String> ids,
  List<bool> liked,
  GridV5Metrics m,
  double width,
) {
  final layout = layoutPhotoGrid(liked, m.columns);
  final raw = (width - 2 * m.paddingX - (m.columns - 1) * m.gap) / m.columns;
  final cell = raw > 0 ? raw : 0.0;
  final step = cell + m.gap;
  final boxes = <String, GridV5Box>{};
  final out = <String>[];
  for (var i = 0; i < ids.length; i++) {
    final p = layout.placements[i];
    final w = p.span * cell + (p.span - 1) * m.gap;
    boxes[ids[i]] = GridV5Box(
      x: m.paddingX + p.col * step,
      y: m.paddingTop + p.row * step,
      w: w,
      h: p.span == 2 ? w + m.featuredExtraHeight : w,
      rl: p.col == 0 ? m.edgeRadius : 0,
      rr: p.col + p.span == m.columns ? m.edgeRadius : 0,
      row: p.row,
    );
    out.add(ids[i]);
  }
  final content = layout.rows > 0
      ? layout.rows * cell + (layout.rows - 1) * m.gap
      : 0.0;
  return GridV5Boxes(
    ids: List.unmodifiable(out),
    boxes: Map.unmodifiable(boxes),
    height: m.paddingTop + content + m.paddingBottom,
    rows: layout.rows,
    width: width,
    paddingX: m.paddingX,
  );
}

GridV5Box lerpGridV5Box(
  GridV5Box a,
  GridV5Box b,
  double t,
  double width,
  double paddingX,
) {
  final w = a.w + (b.w - a.w) * t;
  final rawX = a.x + (b.x - a.x) * t;
  return GridV5Box(
    x: math.max(paddingX, math.min(rawX, width - paddingX - w)),
    y: a.y + (b.y - a.y) * t,
    w: w,
    h: a.h + (b.h - a.h) * t,
    rl: a.rl + (b.rl - a.rl) * t,
    rr: a.rr + (b.rr - a.rr) * t,
    row: b.row,
  );
}

({List<String> entering, List<String> exiting}) gridV5Diff(
  List<String> prev,
  List<String> next,
) {
  final had = prev.toSet();
  final has = next.toSet();
  return (
    entering: [
      for (final id in next)
        if (!had.contains(id)) id,
    ],
    exiting: [
      for (final id in prev)
        if (!has.contains(id)) id,
    ],
  );
}

GridV5Boxes gridV5Current(GridV5Boxes from, GridV5Boxes to, double t) {
  if (t == 1) return to;
  final boxes = <String, GridV5Box>{};
  for (final id in to.ids) {
    final a = from.boxes[id];
    final b = to.boxes[id]!;
    boxes[id] = a != null ? lerpGridV5Box(a, b, t, to.width, to.paddingX) : b;
  }
  return GridV5Boxes(
    ids: to.ids,
    boxes: Map.unmodifiable(boxes),
    height: from.height + (to.height - from.height) * t,
    rows: to.rows,
    width: to.width,
    paddingX: to.paddingX,
  );
}

/// RN `gridV5CellLook`.
({GridV5Box box, double scale, double opacity})? gridV5CellLook(
  GridV5Boxes from,
  GridV5Boxes to,
  String id,
  double t,
  bool exiting,
) {
  final a = from.boxes[id];
  final b = to.boxes[id];
  final k = t.clamp(0.0, 1.0);
  if (exiting) {
    final box = a ?? b;
    return box == null ? null : (box: box, scale: 1 - k, opacity: 1 - k);
  }
  if (b == null) return null;
  if (a == null) return (box: b, scale: k, opacity: k);
  return (
    box: lerpGridV5Box(a, b, t, to.width, to.paddingX),
    scale: 1.0,
    opacity: 1.0,
  );
}
