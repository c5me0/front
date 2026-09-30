// Keep navigation compact while browsing photos, including pauses and direction
// changes. Restore it at rest near the top or after an explicit navigation request.

import '../design_system/tokens.g.dart';

class TabBarScrollState {
  bool _minimized = false;
  bool get minimized => _minimized;
  bool _active = false;
  double _last = 0;
  double _min = 0;
  double _max = 0;
  bool _expandedByUser = false;
  double _travelAfterExpansion = 0;

  bool get _atTop => _last - _min <= CameoMotion.tabBarV6ScrollRestTopInset;

  double _remember(double pixels, double min, double max) {
    final next = pixels.clamp(min, max);
    final delta = next - _last;
    _last = next;
    _min = min;
    _max = max;
    return delta;
  }

  void _defaultState() {
    _minimized = false;
    _expandedByUser = false;
    _travelAfterExpansion = 0;
  }

  void begin(double pixels, double min, double max) {
    _active = true;
    _remember(pixels, min, max);
  }

  bool end() {
    _active = false;
    final previous = minimized;
    if (_atTop || _max <= _min) _defaultState();
    return previous != minimized;
  }

  bool expand() {
    final changed = minimized;
    _minimized = false;
    _expandedByUser = !_atTop;
    _travelAfterExpansion = 0;
    return changed;
  }

  bool restore(double pixels, double min, double max) {
    final previous = minimized;
    _active = false;
    _remember(pixels, min, max);
    _defaultState();
    _minimized = max > min && !_atTop;
    return previous != minimized;
  }

  bool update(double pixels, double min, double max) {
    final previous = minimized;
    final delta = _remember(pixels, min, max);
    if (max <= min || (!_active && _atTop)) {
      _defaultState();
    } else if (!_atTop && !minimized) {
      if (_expandedByUser && pixels >= min && pixels <= max) {
        _travelAfterExpansion += delta.abs();
      }
      final browsingDistance = _expandedByUser
          ? _travelAfterExpansion
          : _last - min;
      if (browsingDistance >= CameoMotion.tabBarV6ScrollMinimizeDistance) {
        _minimized = true;
        _expandedByUser = false;
        _travelAfterExpansion = 0;
      }
    }
    return previous != minimized;
  }
}
