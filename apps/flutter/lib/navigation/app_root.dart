// Session-driven navigation root and flow-demo owner. Replace the full stack when
// authentication state changes, and reset only live album state when leaving a member
// session.

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../state/album_store.dart';
import '../state/permissions.dart';
import '../state/session.dart';
import 'cameo_nav.dart';
import 'cameo_routes.dart';
import 'flow_demo.dart';
import 'initial_route.dart';
import 'session_gate.dart';

class CameoAppRoot extends StatefulWidget {
  const CameoAppRoot({
    super.key,
    required this.session,
    this.album,
    required this.navigatorKey,
    this.startFlowDemo = false,
    this.permissions = const SystemPermissionService(),
    required this.child,
  });

  final SessionController session;

  final AlbumStore? album;

  final GlobalKey<NavigatorState> navigatorKey;

  final bool startFlowDemo;

  final PermissionService permissions;

  final Widget child;

  @override
  State<CameoAppRoot> createState() => CameoAppRootState();
}

class CameoAppRootState extends State<CameoAppRoot>
    implements FlowDemoHost, CameoLocationHost {
  late SessionStatus _status;
  String? _partnerId;
  String? _requiredLocation;

  bool _applying = false;

  final SimulatedPermissionService _simulated = SimulatedPermissionService();

  @override
  void initState() {
    super.initState();
    _status = widget.session.session.status;
    _requiredLocation = requiredLiveLocation(widget.session);
    _partnerId = widget.session.session.partner?.id;
    widget.session.addListener(_onSession);
    if (widget.startFlowDemo) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startRunner();
      });
    }
  }

  @override
  void didUpdateWidget(CameoAppRoot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.session, widget.session)) {
      oldWidget.session.removeListener(_onSession);
      widget.session.addListener(_onSession);
      _status = widget.session.session.status;
      _requiredLocation = requiredLiveLocation(widget.session);
    }
  }

  @override
  void dispose() {
    widget.session.removeListener(_onSession);
    FlowDemo.cancelRunner();
    super.dispose();
  }

  void _onSession() {
    final status = widget.session.session.status;
    final partnerId = widget.session.session.partner?.id;
    final lostPartner = _partnerId != null && _partnerId != partnerId;
    _partnerId = partnerId;
    final previousRequired = _requiredLocation;
    _requiredLocation = requiredLiveLocation(widget.session);
    final accessChanged =
        previousRequired != _requiredLocation &&
        (previousRequired == CameoRoutes.paywall ||
            _requiredLocation == CameoRoutes.paywall ||
            previousRequired == CameoRoutes.profile);
    if (!accessChanged &&
        status == _status &&
        !(status == SessionStatus.member &&
            lostPartner &&
            widget.session.usesBackend)) {
      return;
    }
    final wasMember = _status == SessionStatus.member;
    _status = status;
    if (_applying) return;

    final album = widget.album;
    if (wasMember &&
        album != null &&
        (status != SessionStatus.member || lostPartner)) {
      album.reset(empty: album.emptyMode);
    }
    _replaceStack(
      cameoSessionEntryRoute(
        widget.session.session,
        controller: widget.session,
      ),
    );
  }

  void _replaceStack(Route<dynamic> route) {
    final navigator = widget.navigatorKey.currentState;
    if (navigator == null) return;
    void replace() {
      if (navigator.mounted) {
        navigator.pushAndRemoveUntil<dynamic>(route, (_) => false);
      }
    }

    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => replace());
    } else {
      replace();
    }
  }

  @override
  void openLocation(String location) {
    final launch = CameoLaunch.parse(
      location,
      allowDemo: !widget.session.usesBackend,
    );
    final dev = launch.devSession;
    _applying = true;
    try {
      if (dev != null) {
        widget.session.applyDevSession(dev, partnerNone: launch.partnerNone);
      }
    } finally {
      _applying = false;
    }
    final albumReset = launch.albumReset;
    if (albumReset != null) widget.album?.reset(empty: albumReset);
    final session = widget.session.session;
    final names = initialLocationsFor(
      launch.location,
      session,
      controller: widget.session,
    );
    _replaceStack(
      cameoSessionEntryRoute(
        session,
        location: names.last,
        controller: widget.session,
      ),
    );
    if (launch.flowDemo) {
      _startRunner();
    } else {
      FlowDemo.cancelRunner();
    }
  }

  @override
  void restartFlowDemo() => openLocation(CameoRoutes.flowDemo);

  void _startRunner() {
    _simulated.reset();
    FlowDemo.startRunner(
      ownerReady: () => mounted && widget.navigatorKey.currentState != null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FlowDemoHostScope(
      host: this,
      child: CameoLocationHostScope(
        host: this,
        child: PermissionServiceScope(
          system: widget.permissions,
          simulated: _simulated,
          useSimulated: _useSimulated,
          child: widget.child,
        ),
      ),
    );
  }

  static bool _useSimulated() => FlowDemo.isActive;
}
