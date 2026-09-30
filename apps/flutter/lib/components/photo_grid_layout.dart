// Deterministic photo packing: place featured photos first, then fill remaining cells
// in reading order. Preserve computation order so shared layout vectors remain valid.

library;

import 'dart:math' as math;
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';

@immutable
class PhotoGridPlacement {
  const PhotoGridPlacement({
    required this.row,
    required this.col,
    required this.span,
  });

  final int row;
  final int col;
  final int span;

  @override
  bool operator ==(Object other) =>
      other is PhotoGridPlacement &&
      other.row == row &&
      other.col == col &&
      other.span == span;

  @override
  int get hashCode => Object.hash(row, col, span);

  @override
  String toString() => 'PhotoGridPlacement(row: $row, col: $col, span: $span)';
}

@immutable
class PhotoGridLayout {
  const PhotoGridLayout({required this.placements, required this.rows});

  final List<PhotoGridPlacement> placements;
  final int rows;
}

PhotoGridLayout layoutPhotoGrid(List<bool> liked, int columns) {
  if (columns < 2) {
    throw ArgumentError.value(columns, 'columns', 'must be >= 2');
  }

  final occupied = <int>{};
  bool free(int r, int c) => !occupied.contains(r * columns + c);
  final placements = <PhotoGridPlacement>[];
  var prevRow = 0;
  var prevCol = 0;
  var maxRow = -1;
  for (final isLiked in liked) {
    int r;
    int c;
    int span;
    if (isLiked) {
      r = prevRow;
      c = prevCol;
      while (!(c <= columns - 2 &&
          free(r, c) &&
          free(r, c + 1) &&
          free(r + 1, c) &&
          free(r + 1, c + 1))) {
        c += 1;
        if (c >= columns) {
          c = 0;
          r += 1;
        }
      }
      occupied
        ..add(r * columns + c)
        ..add(r * columns + c + 1)
        ..add((r + 1) * columns + c)
        ..add((r + 1) * columns + c + 1);
      span = 2;
    } else {
      r = 0;
      c = 0;
      while (!free(r, c)) {
        c += 1;
        if (c >= columns) {
          c = 0;
          r += 1;
        }
      }
      occupied.add(r * columns + c);
      span = 1;
    }
    placements.add(PhotoGridPlacement(row: r, col: c, span: span));
    final bottom = r + span - 1;
    if (bottom > maxRow) maxRow = bottom;
    prevRow = r;
    prevCol = c;
  }
  return PhotoGridLayout(
    placements: List.unmodifiable(placements),
    rows: maxRow + 1,
  );
}

/// gangneung: CameoLayout.photoGridColumns + photoGridGangneung{Padding,Gap}).
@immutable
class PhotoGridMetrics {
  const PhotoGridMetrics({
    required this.columns,
    required this.padding,
    required this.gap,
  });

  final int columns;
  final double padding;
  final double gap;
}

@immutable
class PhotoGridFrame {
  const PhotoGridFrame({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });

  final double x;
  final double y;
  final double w;
  final double h;

  Rect toRect() => Rect.fromLTWH(x, y, w, h);

  static PhotoGridFrame lerp(PhotoGridFrame a, PhotoGridFrame b, double t) =>
      PhotoGridFrame(
        x: a.x + (b.x - a.x) * t,
        y: a.y + (b.y - a.y) * t,
        w: a.w + (b.w - a.w) * t,
        h: a.h + (b.h - a.h) * t,
      );

  PhotoGridFrame containX(double padding, double width) => PhotoGridFrame(
    x: math.max(padding, math.min(x, width - padding - w)),
    y: y,
    w: w,
    h: h,
  );

  @override
  bool operator ==(Object other) =>
      other is PhotoGridFrame &&
      other.x == x &&
      other.y == y &&
      other.w == w &&
      other.h == h;

  @override
  int get hashCode => Object.hash(x, y, w, h);

  @override
  String toString() => 'PhotoGridFrame(x: $x, y: $y, w: $w, h: $h)';
}

@immutable
class PhotoGridFrames {
  const PhotoGridFrames({
    required this.frames,
    required this.cellSize,
    required this.contentHeight,
    required this.height,
  });

  final List<PhotoGridFrame> frames;

  final double cellSize;

  final double contentHeight;

  final double height;
}

///   step = cellSize + gap,  x = padding + col·step,  y = padding + row·step,  w = h = span·cellSize + (span−1)·gap

PhotoGridFrames photoGridFrames(
  PhotoGridLayout layout,
  PhotoGridMetrics metrics,
  double width,
) {
  final columns = metrics.columns;
  final padding = metrics.padding;
  final gap = metrics.gap;
  final raw = (width - 2 * padding - (columns - 1) * gap) / columns;
  final cellSize = raw > 0 ? raw : 0.0;
  final step = cellSize + gap;
  final frames = <PhotoGridFrame>[
    for (final p in layout.placements)
      PhotoGridFrame(
        x: padding + p.col * step,
        y: padding + p.row * step,
        w: p.span * cellSize + (p.span - 1) * gap,
        h: p.span * cellSize + (p.span - 1) * gap,
      ),
  ];
  final rows = layout.rows;
  final contentHeight = rows > 0 ? rows * cellSize + (rows - 1) * gap : 0.0;
  return PhotoGridFrames(
    frames: List.unmodifiable(frames),
    cellSize: cellSize,
    contentHeight: contentHeight,
    height: contentHeight + 2 * padding,
  );
}
