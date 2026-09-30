// Visible leaf-route and transition activity tracking used by navigation guards and
// flow playback.

import 'package:flutter/widgets.dart';

import 'spring_route.dart';

typedef CameoLeaf = ({Object key, String? name});

abstract interface class CameoLeafHost {
  CameoLeaf leafOf(Route<Object?> route);
}

///

///

abstract final class CameoRouteActivity {
  static final List<CameoSpringRoute<Object?>> _routes = [];
  static final Map<Animation<double>, AnimationStatusListener>
  _statusListeners = {};
  static final List<Animation<double>> _animations = [];
  static final Map<Route<Object?>, CameoLeafHost> _hosts = {};
  static final Expando<bool> _rootNavigators = Expando('cameo.rootNavigator');
  static int _transitionEnds = 0;
  static final _Changes _changes = _Changes();

  static Listenable get changes => _changes;

  static int get transitionEnds => _transitionEnds;

  static List<CameoSpringRoute<Object?>> get routes =>
      List.unmodifiable(_routes);

  static CameoSpringRoute<Object?>? get top {
    for (final route in _routes.reversed) {
      if (route.isCurrent) return route;
    }
    return null;
  }

  static CameoSpringRoute<Object?>? get rootTop {
    for (final route in _routes.reversed) {
      if (route.isCurrent && _isRoot(route.navigator)) return route;
    }
    return top;
  }

  static CameoSpringRoute<Object?>? currentRouteIn(NavigatorState navigator) {
    for (final route in _routes.reversed) {
      if (route.isCurrent && identical(route.navigator, navigator)) {
        return route;
      }
    }
    return null;
  }

  static CameoLeaf? get leaf {
    final root = rootTop;
    if (root == null) return null;
    final host = _hosts[root];
    if (host != null) return host.leafOf(root);
    return (key: root, name: root.settings.name);
  }

  static bool _isRoot(NavigatorState? navigator) {
    if (navigator == null || !navigator.mounted) return false;
    return _rootNavigators[navigator] ??=
        navigator.context.findAncestorStateOfType<NavigatorState>() == null;
  }

  static bool get isIdle {
    for (final route in _routes) {
      if (route.animation?.isAnimating ?? false) return false;
      if (route.navigator?.userGestureInProgress ?? false) return false;
    }
    for (final animation in _animations) {
      if (animation.isAnimating) return false;
    }
    return true;
  }

  static bool isAttached(Route<Object?> route) => _routes.contains(route);

  static void attach(CameoSpringRoute<Object?> route) {
    if (_routes.contains(route)) return;
    _routes.add(route);
    final animation = route.animation;
    if (animation != null) _listen(animation);
    _notify();
  }

  static void detach(CameoSpringRoute<Object?> route) {
    final animation = route.animation;
    if (animation != null) _unlisten(animation);
    _hosts.remove(route);
    if (_routes.remove(route)) _notify();
  }

  static void attachAnimation(Animation<double> animation) {
    if (_animations.contains(animation)) return;
    _animations.add(animation);
    _listen(animation);
    _notify();
  }

  static void detachAnimation(Animation<double> animation) {
    _unlisten(animation);
    if (_animations.remove(animation)) _notify();
  }

  static void attachHost(Route<Object?> route, CameoLeafHost host) {
    _hosts[route] = host;
    _notify();
  }

  static void detachHost(Route<Object?> route, CameoLeafHost host) {
    if (identical(_hosts[route], host)) {
      _hosts.remove(route);
      _notify();
    }
  }

  static void _listen(Animation<double> animation) {
    void onStatus(AnimationStatus status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        _transitionEnds++;
        _notify();
      }
    }

    _statusListeners[animation] = onStatus;
    animation.addStatusListener(onStatus);
  }

  static void _unlisten(Animation<double> animation) {
    final listener = _statusListeners.remove(animation);
    if (listener != null) animation.removeStatusListener(listener);
  }

  static void _notify() => _changes.notify();
}

class _Changes extends ChangeNotifier {
  void notify() => notifyListeners();
}
