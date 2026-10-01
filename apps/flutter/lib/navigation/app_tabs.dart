// Persistent album, camera, and settings tabs with one shared tab bar. Track the
// visible leaf route and keep outgoing overlays alive until their transitions finish.

//

import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../components/tab_bar_v6.dart';

export '../components/tab_bar_v6.dart'
    show
        TabBarCameraSlots,
        TabBarThumbnail,
        TabBarV6,
        TabBarV6Mode,
        TabBarV6Tone,
        TabBarV6Variant;
import '../design_system/design_system.dart';
import 'cameo_nav.dart';
import 'cameo_routes.dart';
import 'cameo_shell_route.dart';
import 'flow_demo.dart';
import 'route_activity.dart';
import 'spring_route.dart';
import 'spring_timing.dart';

abstract final class CameoTabs {
  static const int albums = 0;

  static const int camera = 1;
  static const int settings = 2;

  static const List<int> all = [albums, camera, settings];
}

abstract final class TabBarTone {
  static void report(BuildContext context, TabBarV6Tone tone) =>
      AppTabs.maybeOf(context)?._report(context, (r) => r.tone = tone);
}

abstract final class TabBarMode {
  static void report(
    BuildContext context,
    TabBarV6Mode mode, {
    VoidCallback? onExpand,
  }) => AppTabs.maybeOf(context)?._report(context, (r) {
    r.mode = mode;
    r.onExpand = onExpand;
  });
}

abstract final class TabBarCamera {
  static void report(BuildContext context, TabBarCameraSlots? slots) =>
      AppTabs.maybeOf(context)?._report(context, (r) => r.camera = slots);
}

///

abstract final class TabBarVisibility {
  static void report(BuildContext context, {required bool hidden}) =>
      AppTabs.maybeOf(context)?._report(context, (r) => r.hidden = hidden);
}

final class _TabReports {
  bool? hidden;
  TabBarV6Mode? mode;
  VoidCallback? onExpand;
  TabBarV6Tone? tone;
  TabBarCameraSlots? camera;

  ({
    bool? hidden,
    TabBarV6Mode? mode,
    VoidCallback? onExpand,
    TabBarV6Tone? tone,
    TabBarCameraSlots? camera,
  })
  get snapshot => (
    hidden: hidden,
    mode: mode,
    onExpand: onExpand,
    tone: tone,
    camera: camera,
  );
}

class _AlbumsStackObserver extends NavigatorObserver {
  _AlbumsStackObserver(this.onChange);

  final VoidCallback onChange;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      onChange();

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      onChange();

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      onChange();

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      onChange();
}

class CameoTabScope extends InheritedWidget {
  const CameoTabScope({
    super.key,
    required this.active,
    required this.host,
    required super.child,
  });

  final bool active;

  final Route<Object?>? host;

  static bool isVisible(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<CameoTabScope>();
    if (scope == null) return true;
    return scope.active && (scope.host?.isCurrent ?? true);
  }

  @override
  bool updateShouldNotify(CameoTabScope oldWidget) =>
      active != oldWidget.active || host != oldWidget.host;
}

class AppTabs extends StatefulWidget {
  const AppTabs({
    super.key,
    this.initialTab = CameoTabs.albums,
    this.albumsRoutes = const [CameoRoutes.home],
    this.initialLocation,
  });

  final int initialTab;

  final List<String> albumsRoutes;

  final String? initialLocation;

  static AppTabsState? maybeOf(BuildContext context) =>
      context.findAncestorStateOfType<AppTabsState>();

  @override
  State<AppTabs> createState() => AppTabsState();
}

class AppTabsState extends State<AppTabs>
    with TickerProviderStateMixin
    implements CameoLeafHost {
  final GlobalKey<NavigatorState> albumsNavigatorKey = GlobalKey(
    debugLabel: 'cameo.tabs.albums',
  );

  final Object _cameraLeaf = Object();
  final Object _settingsLeaf = Object();

  late final AnimationController _switch = AnimationController.unbounded(
    vsync: this,
    value: 1,
  );

  late final AnimationController _tabBarIn = AnimationController.unbounded(
    vsync: this,
    value: 0,
  );

  late int _tab = _normalize(widget.initialTab);

  int? _from;

  late final Set<int> _built = {_tab};

  final List<VoidCallback> _unregister = [];

  CameoShellRoute<Object?>? _shell;
  ModalRoute<Object?>? _route;

  final Expando<_TabReports> _reports = Expando('cameo.tabBarReports');

  bool _barHidden = false;
  TabBarV6Mode _barMode = TabBarV6Mode.full;
  TabBarV6Tone? _barTone;
  TabBarCameraSlots? _barCamera;

  bool _updatePending = false;
  late final _AlbumsStackObserver _albumsObserver = _AlbumsStackObserver(
    _requestBarUpdate,
  );

  int get selectedTab => _tab;

  bool get tabBarHidden => _barHidden;

  TabBarV6Mode get tabBarMode => _barMode;

  TabBarV6Mode get tabBarModeShown =>
      _viewerCovering ? TabBarV6Mode.mini : _barMode;

  TabBarV6Variant get tabBarVariant =>
      _tab == CameoTabs.camera && _barCamera != null
      ? TabBarV6Variant.camera
      : TabBarV6Variant.album;

  TabBarV6Tone get tabBarTone =>
      _barTone ??
      (tabBarVariant == TabBarV6Variant.camera
          ? TabBarV6Tone.camera
          : TabBarV6Tone.photo);

  TabBarCameraSlots? get tabBarCamera => _barCamera;

  NavigatorState? get albumsNavigator => albumsNavigatorKey.currentState;

  static int _normalize(int tab) =>
      CameoTabs.all.contains(tab) ? tab : CameoTabs.albums;

  bool get _reduceMotion =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  bool get _viewerCovering =>
      (_shell?.coveredByViewer ?? false) &&
      (_route?.secondaryAnimation?.value ?? 0) > 0;

  @override
  void initState() {
    super.initState();
    _barHidden = _selectedHidden();
    CameoRouteActivity.attachAnimation(_switch);
    _switch.addStatusListener(_onSwitchStatus);
    _unregister
      ..add(
        FlowDemo.register(
          FlowDemoAction.tabsCamera,
          () => _fromFlowDemo(CameoTabs.camera),
        ),
      )
      ..add(
        FlowDemo.register(
          FlowDemoAction.tabsSettings,
          () => _fromFlowDemo(CameoTabs.settings),
        ),
      )
      ..add(FlowDemo.register(FlowDemoAction.homeCall, _callFromFlowDemo));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_reduceMotion) {
        _tabBarIn.value = 1;
      } else {
        _tabBarIn.animateWith(
          cameoSpringSimulation(CameoMotion.tabBarEnterSpring, from: 0, to: 1),
        );
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (!identical(route, _route)) {
      final previous = _route;
      if (previous != null) CameoRouteActivity.detachHost(previous, this);
      _route = route;
      _shell = route is CameoShellRoute<Object?> ? route : null;
      if (route != null) CameoRouteActivity.attachHost(route, this);
    }
  }

  @override
  void dispose() {
    for (final unregister in _unregister) {
      unregister();
    }
    final route = _route;
    if (route != null) CameoRouteActivity.detachHost(route, this);
    _switch.removeStatusListener(_onSwitchStatus);
    CameoRouteActivity.detachAnimation(_switch);
    _switch.dispose();
    _tabBarIn.dispose();
    super.dispose();
  }

  void _onSwitchStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && _from != null && mounted) {
      setState(() => _from = null);
    }
  }

  bool _fromFlowDemo(int index) {
    if (!mounted || !CameoNav.isTop(context)) return false;
    select(index);
    return true;
  }

  bool _callFromFlowDemo() {
    if (!mounted || !CameoNav.isTop(context)) return false;
    if (_tab != CameoTabs.albums || _barHidden) return false;
    if (tabBarModeShown != TabBarV6Mode.full) return false;
    _openCall();
    return true;
  }

  void _openCall() {
    if (!mounted) return;
    CameoNav.openCall(context);
  }

  void select(int index) {
    if (!mounted) return;

    _selectedReports()?.onExpand?.call();
    final next = _normalize(index);
    if (next == _tab) {
      if (next == CameoTabs.albums) {
        albumsNavigator?.popUntil((route) => route.isFirst);
      }
      return;
    }

    final reverse = _from == next && _switch.isAnimating;
    final from = reverse ? 1 - _switch.value : 0.0;
    final velocity = reverse ? -_switch.velocity : 0.0;
    setState(() {
      _from = _tab;
      _tab = next;
      _built.add(next);
    });
    _updateBar();
    if (_reduceMotion) {
      _switch.animateWith(
        EasedTimingSimulation(
          from: from,
          to: 1,
          duration: CameoMotion.durationBase,
          curve: CameoMotion.easingStandard,
        ),
      );
    } else {
      _switch.animateWith(
        cameoSpringSimulation(
          CameoMotion.transitionTabSpring,
          from: from,
          to: 1,
          velocity: velocity,
        ),
      );
    }
  }

  Future<T?> pushAlbums<T extends Object?>(Route<T> route) {
    if (_tab != CameoTabs.albums) select(CameoTabs.albums);
    final navigator = albumsNavigator;
    if (navigator != null) return navigator.push<T>(route);
    final result = Completer<T?>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final built = albumsNavigator;
      if (built == null) {
        result.complete(null);
      } else {
        result.complete(built.push<T>(route));
      }
    });
    return result.future;
  }

  Object _tabKey(int tab) =>
      tab == CameoTabs.camera ? _cameraLeaf : _settingsLeaf;

  Object _reportKey(BuildContext context) {
    final route = ModalRoute.of(context);
    final navigator = albumsNavigator;
    final inAlbums = route != null && identical(route.navigator, navigator);
    return inAlbums
        ? route
        : _tabKey(
            context.findAncestorWidgetOfExactType<_TabIndex>()?.tab ??
                CameoTabs.settings,
          );
  }

  void _report(BuildContext context, void Function(_TabReports r) write) {
    final key = _reportKey(context);
    final reports = _reports[key] ??= _TabReports();
    final before = reports.snapshot;
    write(reports);
    if (reports.snapshot == before) return;
    _requestBarUpdate();
  }

  _TabReports? _selectedReports() {
    final Object? key;
    if (_tab == CameoTabs.albums) {
      final navigator = albumsNavigator;
      key = navigator == null
          ? null
          : CameoRouteActivity.currentRouteIn(navigator);
    } else {
      key = _tabKey(_tab);
    }
    return key == null ? null : _reports[key];
  }

  bool _selectedHidden() {
    final r = _selectedReports();
    if (_tab == CameoTabs.camera && r?.camera == null) return true;
    return r?.hidden ?? false;
  }

  void _requestBarUpdate() {
    if (_updatePending) return;
    _updatePending = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _updatePending = false;
      if (mounted) _updateBar();
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  void _updateBar() {
    final r = _selectedReports();
    final hidden = _selectedHidden();
    final mode = r?.mode ?? TabBarV6Mode.full;
    final camera = _tab == CameoTabs.camera ? r?.camera : null;
    final tone = r?.tone;
    if (hidden == _barHidden &&
        mode == _barMode &&
        camera == _barCamera &&
        tone == _barTone) {
      return;
    }
    setState(() {
      _barHidden = hidden;
      _barMode = mode;
      _barCamera = camera;
      _barTone = tone;
    });
  }

  @override
  CameoLeaf leafOf(Route<Object?> route) {
    if (_tab == CameoTabs.camera) {
      return (key: _cameraLeaf, name: CameoRoutes.capture);
    }
    if (_tab == CameoTabs.settings) {
      return (key: _settingsLeaf, name: CameoRoutes.settings);
    }
    final navigator = albumsNavigator;
    final top = navigator == null
        ? null
        : CameoRouteActivity.currentRouteIn(navigator);
    if (top == null) return (key: route, name: CameoRoutes.home);
    return (key: top, name: top.settings.name);
  }

  @override
  Widget build(BuildContext context) {
    final order = [
      for (final tab in CameoTabs.all)
        if (tab != _tab) tab,
      _tab,
    ];
    final secondary = _route?.secondaryAnimation ?? kAlwaysDismissedAnimation;
    return Stack(
      fit: StackFit.expand,
      children: [
        for (final tab in order)
          if (_built.contains(tab))
            KeyedSubtree(key: ValueKey('appTabs.tab.$tab'), child: _layer(tab)),

        Positioned(
          key: const ValueKey('appTabs.layer.tabBar'),
          left: 0,
          right: 0,
          bottom: 0,
          child: AnimatedBuilder(
            animation: Listenable.merge([_tabBarIn, secondary]),
            builder: (context, child) => Transform.translate(
              offset: Offset(
                0,
                (1 - _tabBarIn.value) * CameoLayout.tabBarV6FullContainerHeight,
              ),
              child: TabBarV6(
                key: const ValueKey('appTabs.tabBar'),
                mode: tabBarModeShown,
                selected: _tab,
                onSelect: select,
                onCall: _openCall,
                variant: tabBarVariant,
                tone: tabBarTone,
                camera: _barCamera,
                hidden: _barHidden || _viewerCovering,
                tabsDisabled: _barCamera?.recording == true,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _layer(int tab) {
    final target = tab == _tab;
    final source = tab == _from;
    final visible = target || source;
    final initial = tab == widget.initialTab ? widget.initialLocation : null;
    final Widget content = switch (tab) {
      CameoTabs.albums => Navigator(
        key: albumsNavigatorKey,
        observers: [_albumsObserver],
        onGenerateInitialRoutes: (_, _) => [
          for (final name in widget.albumsRoutes)
            onGenerateCameoTabRoute(RouteSettings(name: name)),
        ],
        onGenerateRoute: onGenerateCameoTabRoute,
      ),
      CameoTabs.camera => cameoScreenFor(
        context,
        initial ?? CameoRoutes.capture,
      ),
      _ => cameoScreenFor(context, initial ?? CameoRoutes.settings),
    };
    return Offstage(
      offstage: !visible,
      child: TickerMode(
        enabled: visible,
        child: IgnorePointer(
          ignoring: !target,
          child: CameoTabScope(
            active: target,
            host: _route,
            child: _TabIndex(
              tab: tab,
              child: AnimatedBuilder(
                animation: _switch,
                child: content,
                builder: (context, child) {
                  final p = _switch.value;
                  final switching = _from != null;
                  final scale = switching && target && !_reduceMotion
                      ? lerpDouble(CameoMotion.transitionTabScaleFrom, 1, p)!
                      : 1.0;
                  return Transform.scale(
                    key: ValueKey('appTabs.scale.$tab'),
                    scale: scale,
                    child: child,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabIndex extends StatelessWidget {
  const _TabIndex({required this.tab, required this.child});

  final int tab;
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
