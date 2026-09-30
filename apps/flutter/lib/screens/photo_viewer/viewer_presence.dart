// Keep viewer presence active through its closing transition so the source screen
// preserves compact navigation and source-cell visibility.

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

class _PresenceNotifier extends ChangeNotifier {
  void ping() => notifyListeners();
}

abstract final class ViewerPresence {
  static int _open = 0;
  static final _PresenceNotifier _notifier = _PresenceNotifier();
  static bool _pending = false;

  static bool get isOpen => _open > 0;

  static Listenable get listenable => _notifier;

  static void set(bool present) {
    _open = present ? _open + 1 : (_open > 0 ? _open - 1 : 0);
    if (_pending) return;
    _pending = true;
    SchedulerBinding.instance
      ..addPostFrameCallback((_) {
        _pending = false;
        _notifier.ping();
      })
      ..ensureVisualUpdate();
  }

  @visibleForTesting
  static void resetForTesting() {
    _open = 0;
    _pending = false;
  }
}
