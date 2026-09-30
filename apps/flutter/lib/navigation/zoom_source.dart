// Store measured source rectangles by destination so opening and closing zooms align
// with the original content.

import 'dart:ui' show Rect;

import 'cameo_routes.dart';

enum ZoomTarget {
  gangneung('gangneung', CameoRoutes.albumsGangneung),
  album('album', CameoRoutes.album);

  const ZoomTarget(this.id, this.location);

  final String id;

  final String location;
}

abstract final class ZoomSource {
  static final Map<ZoomTarget, Rect> _rects = {};

  static void set(ZoomTarget target, Rect rect) => _rects[target] = rect;

  static Rect? rectOf(ZoomTarget target) => _rects[target];

  static void clear([ZoomTarget? target]) {
    if (target == null) {
      _rects.clear();
    } else {
      _rects.remove(target);
    }
  }
}
