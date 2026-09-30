// Locate the current photo cell in global coordinates for viewer dismissal and reverse
// zooms.

import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart' show VoidCallback;

typedef CellLocate = Rect? Function(String photoId);

final Set<CellLocate> _locators = {};

VoidCallback registerCellLocator(CellLocate locate) {
  _locators.add(locate);
  return () => _locators.remove(locate);
}

Rect? locateAlbumCell(String photoId) {
  for (final locate in _locators) {
    final rect = locate(photoId);
    if (rect != null) return rect;
  }
  return null;
}
