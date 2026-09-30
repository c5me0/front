// Event-driven forty-step prototype flow. Wait for the destination and explicit
// settlement before the next dwell; report skipped, refused, or timed-out actions
// instead of silently continuing.

//

//

import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../state/captured_photo.dart';
import 'cameo_location.dart';
import 'cameo_routes.dart';
import 'route_activity.dart';

///

///  - homeOpenAlbum 'home.openAlbum' · homeOpenDayAlbum 'home.openDayAlbum' · gangneungOpenAlbum 'gangneung.openAlbum' ·
///    albumOpenPhotoCard 'album.openPhotoCard'
enum FlowDemoAction {
  welcomeStart('welcome.start'),
  phoneType('phone.type'),
  phoneSubmit('phone.submit'),
  verifyAutofill('verify.autofill'),
  profileType('profile.type'),
  profileSubmit('profile.submit'),
  partnerType('partner.type'),
  permissionsAllow('permissions.allow'),
  homeScroll('home.scroll'),
  homeOpenPhoto('home.openPhoto'),
  viewerStrip('viewer.strip'),
  viewerLike('viewer.like'),
  back('back'),
  homeLiked('home.liked'),
  likedClose('liked.close'),
  homeDeleted('home.deleted'),
  deletedClose('deleted.close'),
  homeSelect('home.select'),
  selectToggle('select.toggle'),
  selectClose('select.close'),
  homeCall('home.call'),
  callVolume('call.volume'),
  callHighlight('call.highlight'),
  callCamera('call.camera'),
  sheetLive('sheet.live'),
  cameraShutter('camera.shutter'),
  callCloseCard('call.closeCard'),
  callSleep('call.sleep'),
  aodEnd('aod.end'),
  callEndCall('call.endCall'),
  homeOpenCallCard('home.openCallCard'),
  tabsCamera('tabs.camera'),
  reviewSend('review.send'),
  cameraOpenShared('camera.openShared'),
  tabsSettings('tabs.settings'),
  settingsLogout('settings.logout'),
  sheetConfirm('sheet.confirm'),

  homeOpenAlbum('home.openAlbum'),
  homeOpenDayAlbum('home.openDayAlbum'),
  gangneungOpenAlbum('gangneung.openAlbum'),
  albumOpenPhotoCard('album.openPhotoCard');

  const FlowDemoAction(this.id);

  final String id;
}

enum FlowDemoScreen {
  welcome,
  phone,
  verify,
  profile,
  partner,
  permissions,
  home,
  photo,
  call,
  camera,
  transcript,
  capture,
  instant,
  settings,

  gangneung,
  album;

  static FlowDemoScreen? ofRouteName(String? name) {
    if (name == null) return null;
    return switch (CameoLocation.parse(name).path) {
      CameoRoutes.welcome => welcome,
      CameoRoutes.phone => phone,
      CameoRoutes.verifyPath => verify,
      CameoRoutes.profile => profile,
      CameoRoutes.partner => partner,
      CameoRoutes.permissions => permissions,
      CameoRoutes.home => home,
      CameoRoutes.photoPath => photo,
      CameoRoutes.callPath => call,
      CameoRoutes.camera => camera,
      CameoRoutes.transcriptPath => transcript,
      CameoRoutes.capture => capture,

      CameoRoutes.instant => photo,
      CameoRoutes.settings => settings,
      CameoRoutes.albumsGangneung => gangneung,
      CameoRoutes.album => album,
      _ => null,
    };
  }
}

const FlowDemoScreen flowDemoStart = FlowDemoScreen.welcome;

typedef FlowDemoStep = ({
  int afterMs,
  FlowDemoAction action,
  FlowDemoScreen to,
  bool settle,
  bool pending,
});

const List<FlowDemoStep> flowDemoTimeline = [
  (
    afterMs: 1500,
    action: FlowDemoAction.welcomeStart,
    to: FlowDemoScreen.phone,
    settle: false,
    pending: false,
  ),
  (
    afterMs: 600,
    action: FlowDemoAction.phoneType,
    to: FlowDemoScreen.phone,
    settle: true,
    pending: false,
  ),
  (
    afterMs: 500,
    action: FlowDemoAction.phoneSubmit,
    to: FlowDemoScreen.verify,
    settle: false,
    pending: false,
  ),
  (
    afterMs: 1800,
    action: FlowDemoAction.verifyAutofill,
    to: FlowDemoScreen.profile,
    settle: false,
    pending: false,
  ),
  (
    afterMs: 600,
    action: FlowDemoAction.profileType,
    to: FlowDemoScreen.profile,
    settle: true,
    pending: false,
  ),
  (
    afterMs: 500,
    action: FlowDemoAction.profileSubmit,
    to: FlowDemoScreen.partner,
    settle: false,
    pending: false,
  ),
  (
    afterMs: 1200,
    action: FlowDemoAction.partnerType,
    to: FlowDemoScreen.permissions,
    settle: false,
    pending: false,
  ),
  (
    afterMs: 1200,
    action: FlowDemoAction.permissionsAllow,
    to: FlowDemoScreen.home,
    settle: false,
    pending: false,
  ),

  (
    afterMs: 1500,
    action: FlowDemoAction.homeScroll,
    to: FlowDemoScreen.home,
    settle: true,
    pending: false,
  ),
  (
    afterMs: 1000,
    action: FlowDemoAction.homeOpenPhoto,
    to: FlowDemoScreen.photo,
    settle: false,
    pending: false,
  ),
  (
    afterMs: 1500,
    action: FlowDemoAction.viewerStrip,
    to: FlowDemoScreen.photo,
    settle: true,
    pending: false,
  ),
  (
    afterMs: 1200,
    action: FlowDemoAction.viewerLike,
    to: FlowDemoScreen.photo,
    settle: true,
    pending: false,
  ),
  (
    afterMs: 1200,
    action: FlowDemoAction.back,
    to: FlowDemoScreen.home,
    settle: false,
    pending: false,
  ),

  (
    afterMs: 1500,
    action: FlowDemoAction.homeLiked,
    to: FlowDemoScreen.home,
    settle: true,
    pending: false,
  ),
  (
    afterMs: 1500,
    action: FlowDemoAction.likedClose,
    to: FlowDemoScreen.home,
    settle: true,
    pending: false,
  ),
  (
    afterMs: 1200,
    action: FlowDemoAction.homeDeleted,
    to: FlowDemoScreen.home,
    settle: true,
    pending: false,
  ),
  (
    afterMs: 1500,
    action: FlowDemoAction.deletedClose,
    to: FlowDemoScreen.home,
    settle: true,
    pending: false,
  ),
  (
    afterMs: 1200,
    action: FlowDemoAction.homeSelect,
    to: FlowDemoScreen.home,
    settle: true,
    pending: false,
  ),
  (
    afterMs: 800,
    action: FlowDemoAction.selectToggle,
    to: FlowDemoScreen.home,
    settle: true,
    pending: false,
  ),
  (
    afterMs: 1500,
    action: FlowDemoAction.selectClose,
    to: FlowDemoScreen.home,
    settle: true,
    pending: false,
  ),

  (
    afterMs: 1000,
    action: FlowDemoAction.homeCall,
    to: FlowDemoScreen.call,
    settle: false,
    pending: false,
  ),
  (
    afterMs: 1500,
    action: FlowDemoAction.callVolume,
    to: FlowDemoScreen.call,
    settle: true,
    pending: false,
  ),
  (
    afterMs: 1500,
    action: FlowDemoAction.callHighlight,
    to: FlowDemoScreen.call,
    settle: true,
    pending: false,
  ),
  (
    afterMs: 2000,
    action: FlowDemoAction.callCamera,
    to: FlowDemoScreen.call,
    settle: true,
    pending: false,
  ),
  (
    afterMs: 1500,
    action: FlowDemoAction.sheetLive,
    to: FlowDemoScreen.camera,
    settle: false,
    pending: false,
  ),
  (
    afterMs: 2000,
    action: FlowDemoAction.cameraShutter,
    to: FlowDemoScreen.call,
    settle: false,
    pending: false,
  ),
  (
    afterMs: 2500,
    action: FlowDemoAction.callCloseCard,
    to: FlowDemoScreen.call,
    settle: true,
    pending: false,
  ),
  (
    afterMs: 1200,
    action: FlowDemoAction.callSleep,
    to: FlowDemoScreen.call,
    settle: true,
    pending: false,
  ),
  (
    afterMs: 2500,
    action: FlowDemoAction.aodEnd,
    to: FlowDemoScreen.call,
    settle: true,
    pending: false,
  ),
  (
    afterMs: 1500,
    action: FlowDemoAction.callEndCall,
    to: FlowDemoScreen.home,
    settle: false,
    pending: false,
  ),

  (
    afterMs: 1500,
    action: FlowDemoAction.homeOpenCallCard,
    to: FlowDemoScreen.transcript,
    settle: false,
    pending: false,
  ),
  (
    afterMs: 2500,
    action: FlowDemoAction.back,
    to: FlowDemoScreen.home,
    settle: false,
    pending: false,
  ),

  (
    afterMs: 1200,
    action: FlowDemoAction.tabsCamera,
    to: FlowDemoScreen.capture,
    settle: false,
    pending: false,
  ),
  (
    afterMs: 1500,
    action: FlowDemoAction.cameraShutter,
    to: FlowDemoScreen.capture,
    settle: true,
    pending: false,
  ),
  (
    afterMs: 1500,
    action: FlowDemoAction.reviewSend,
    to: FlowDemoScreen.capture,
    settle: true,
    pending: false,
  ),
  (
    afterMs: 3200,
    action: FlowDemoAction.cameraOpenShared,
    to: FlowDemoScreen.photo,
    settle: false,
    pending: false,
  ),
  (
    afterMs: 2000,
    action: FlowDemoAction.back,
    to: FlowDemoScreen.capture,
    settle: false,
    pending: false,
  ),

  (
    afterMs: 1200,
    action: FlowDemoAction.tabsSettings,
    to: FlowDemoScreen.settings,
    settle: false,
    pending: false,
  ),
  (
    afterMs: 1500,
    action: FlowDemoAction.settingsLogout,
    to: FlowDemoScreen.settings,
    settle: true,
    pending: false,
  ),
  (
    afterMs: 1200,
    action: FlowDemoAction.sheetConfirm,
    to: FlowDemoScreen.welcome,
    settle: false,
    pending: false,
  ),
];

const Map<FlowDemoAction, FlowDemoAction> flowDemoV5Aliases = {};

const Duration flowDemoWaitLimit = Duration(milliseconds: 15000);

typedef FlowDemoStackSnapshot = ({
  Object? topKey,
  FlowDemoScreen? top,
  bool idle,
  int transitionEnds,
});

enum FlowDemoRunResult { done, stopped, cancelled }

typedef FlowDemoHandler = dynamic Function();

final class _Registration {
  _Registration(this.handler, this.isReady);

  final FlowDemoHandler handler;
  final bool Function()? isReady;
}

void _debugLog(String message) => debugPrint('[cameo] flow demo: $message');

abstract interface class FlowDemoHost {
  void restartFlowDemo();
}

class FlowDemoHostScope extends InheritedWidget {
  const FlowDemoHostScope({
    super.key,
    required this.host,
    required super.child,
  });

  final FlowDemoHost host;

  @override
  bool updateShouldNotify(FlowDemoHostScope oldWidget) =>
      host != oldWidget.host;
}

///

abstract final class FlowDemo {
  static final Map<FlowDemoAction, List<_Registration>> _registry = {};
  static final Map<FlowDemoAction, int> _settles = {};
  static FlowDemoRunner? _runner;

  static VoidCallback register(
    FlowDemoAction action,
    FlowDemoHandler handler, {
    bool Function()? isReady,
  }) {
    final entry = _Registration(handler, isReady);
    (_registry[action] ??= []).add(entry);
    return () {
      final list = _registry[action];
      if (list == null) return;
      list.remove(entry);
      if (list.isEmpty) _registry.remove(action);
    };
  }

  static void settle(FlowDemoAction action) =>
      _settles[action] = (_settles[action] ?? 0) + 1;

  static int settleCount(FlowDemoAction action) {
    final alias = flowDemoV5Aliases[action];
    return (_settles[action] ?? 0) + (alias == null ? 0 : _settles[alias] ?? 0);
  }

  static bool get isActive => _runner?.isRunning ?? false;

  @visibleForTesting
  static FlowDemoRunner? get runner => _runner;

  static bool restart(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<FlowDemoHostScope>();
    if (scope == null) return false;
    scope.host.restartFlowDemo();
    return true;
  }

  static bool isRegistered(FlowDemoAction action) =>
      _registry[action]?.isNotEmpty ?? false;

  @visibleForTesting
  static void resetForTesting() {
    _registry.clear();
    _settles.clear();
    _runner?.cancel();
    _runner = null;
    _lastRun = null;
  }

  static FlowDemoAction? _lastRun;

  static bool run(FlowDemoAction action, {NavigatorState? navigator}) {
    final list = _registry[action] ?? _registry[flowDemoV5Aliases[action]];
    final bool ran;
    if (list != null && list.isNotEmpty) {
      final entry = list.last;
      ran = (entry.isReady?.call() ?? true) && entry.handler() != false;
    } else if (action == FlowDemoAction.back) {
      ran = _pop(navigator);
    } else if (action == FlowDemoAction.cameraShutter) {
      ran = _shutterFallback(navigator);
    } else {
      ran = false;
    }
    if (ran) _lastRun = action;
    return ran;
  }

  static bool _pop(NavigatorState? navigator, [Object? result]) {
    if (navigator != null) {
      if (!navigator.mounted || !navigator.canPop()) return false;
      navigator.pop(result);
      return true;
    }
    final leaf = CameoRouteActivity.leaf?.key;
    if (leaf is! Route<Object?>) return false;
    final nav = leaf.navigator;
    if (nav == null || !nav.mounted || !leaf.isCurrent || !nav.canPop()) {
      return false;
    }
    nav.pop(result);
    return true;
  }

  static bool _shutterFallback(NavigatorState? navigator) {
    if (_lastRun != FlowDemoAction.sheetLive &&
        _lastRun != FlowDemoAction.callCamera) {
      return false;
    }
    return _pop(navigator, CapturedPhoto.placeholder());
  }

  static FlowDemoStackSnapshot stackSnapshot() {
    final leaf = CameoRouteActivity.leaf;
    return (
      topKey: leaf?.key,
      top: FlowDemoScreen.ofRouteName(leaf?.name),
      idle: CameoRouteActivity.isIdle,
      transitionEnds: CameoRouteActivity.transitionEnds,
    );
  }

  static FlowDemoRunner startRunner({
    required bool Function() ownerReady,
    List<FlowDemoStep> steps = flowDemoTimeline,
  }) {
    _runner?.cancel();
    _lastRun = null;
    final runner = FlowDemoRunner(
      steps: steps,
      snapshot: stackSnapshot,
      ownerReady: ownerReady,
      deliver: (action) => run(action),
      settles: settleCount,
    );
    _runner = runner;
    runner.start();
    return runner;
  }

  static void cancelRunner() {
    _runner?.cancel();
    _runner = null;
  }
}

class FlowDemoRunner {
  FlowDemoRunner({
    this.steps = flowDemoTimeline,
    required this.snapshot,
    required this.ownerReady,
    required this.deliver,
    int Function(FlowDemoAction action)? settles,
    VoidCallback Function(VoidCallback callback)? nextFrame,
    VoidCallback Function(Duration delay, VoidCallback callback)? after,
    void Function(String message)? log,
    void Function(String message)? warn,
    this.waitLimit = flowDemoWaitLimit,
    this.onFinish,
  }) : _settles = settles ?? FlowDemo.settleCount,
       _nextFrame = nextFrame ?? _postFrame,
       _after = after ?? _timer,
       _log = log ?? _debugLog,
       _warn = warn ?? _debugLog;

  final List<FlowDemoStep> steps;

  final FlowDemoStackSnapshot Function() snapshot;

  final bool Function() ownerReady;

  final bool Function(FlowDemoAction action) deliver;

  final Duration waitLimit;
  final void Function(FlowDemoRunResult result)? onFinish;

  final int Function(FlowDemoAction action) _settles;

  final List<int> skipped = [];

  final VoidCallback Function(VoidCallback callback) _nextFrame;
  final VoidCallback Function(Duration delay, VoidCallback callback) _after;
  final void Function(String message) _log;
  final void Function(String message) _warn;

  VoidCallback? _cancelPending;
  bool _started = false;
  bool _finished = false;
  FlowDemoRunResult? _result;

  FlowDemoRunResult? get result => _result;

  bool get isRunning => _started && !_finished;

  static VoidCallback _postFrame(VoidCallback callback) {
    var live = true;
    final binding = SchedulerBinding.instance;
    binding.addPostFrameCallback((_) {
      if (live) callback();
    }, debugLabel: 'FlowDemoRunner');
    binding.ensureVisualUpdate();
    return () => live = false;
  }

  static VoidCallback _timer(Duration delay, VoidCallback callback) =>
      Timer(delay, callback).cancel;

  void start() {
    if (_started) return;
    _started = true;
    _waitUntil(
      '웰컴 준비',
      _holds((s) => s.idle && s.top == flowDemoStart && ownerReady()),
      () {
        _log('시작');
        _dwell(0);
      },
    );
  }

  void cancel() => _finish(FlowDemoRunResult.cancelled);

  void _finish(FlowDemoRunResult result) {
    if (_finished) return;
    _finished = true;
    _result = result;
    _cancelPending?.call();
    _cancelPending = null;
    onFinish?.call(result);
  }

  void _waitUntil(String what, bool Function() ready, VoidCallback then) {
    VoidCallback? cancelFrame;
    late final VoidCallback cancelLimit;
    void tick() {
      cancelFrame = null;
      if (_finished) return;
      if (ready()) {
        cancelLimit();
        _cancelPending = null;
        then();
        return;
      }
      cancelFrame = _nextFrame(tick);
    }

    cancelLimit = _after(waitLimit, () {
      cancelFrame?.call();
      _cancelPending = null;
      _warn('$what: ${waitLimit.inMilliseconds} ms 안에 되지 않았다 — 데모를 멈춘다');
      _finish(FlowDemoRunResult.stopped);
    });
    _cancelPending = () {
      cancelFrame?.call();
      cancelLimit();
    };
    cancelFrame = _nextFrame(tick);
  }

  bool Function() _holds(bool Function(FlowDemoStackSnapshot s) cond) {
    FlowDemoStackSnapshot? last;
    return () {
      final s = snapshot();
      if (!cond(s)) {
        last = null;
        return false;
      }
      final previous = last;
      final held =
          previous != null &&
          identical(previous.topKey, s.topKey) &&
          previous.transitionEnds == s.transitionEnds;
      last = s;
      return held;
    };
  }

  void _dwell(int i) {
    if (i >= steps.length) {
      _log('끝');
      _finish(FlowDemoRunResult.done);
      return;
    }
    _cancelPending = _after(Duration(milliseconds: steps[i].afterMs), () {
      _cancelPending = null;
      _deliver(i);
    });
  }

  FlowDemoScreen _fromOf(int i) => i == 0 ? flowDemoStart : steps[i - 1].to;

  void _deliver(int i) {
    final step = steps[i];
    final from = _fromOf(i);
    FlowDemoStackSnapshot? before;
    var settlesBefore = 0;
    var refused = false;
    _waitUntil(
      "'${step.action.id}' 전달 (${from.name} 에서)",
      () {
        final s = snapshot();
        if (!s.idle || s.top != from) return false;

        final settled = _settles(step.action);
        if (!deliver(step.action)) {
          if (step.pending) {
            skipped.add(i);
            _warn("'${step.action.id}' pending — v6 화면이 아직 받지 않아 건너뛴다");
            before = s;
            settlesBefore = settled;
            return true;
          }
          if (!refused) {
            refused = true;
            _warn("'${step.action.id}' 를 ${from.name} 화면이 받지 않았다 — 다음 프레임에 다시");
          }
          return false;
        }
        before = s;
        settlesBefore = settled;
        return true;
      },
      () {
        final b = before;
        if (b != null) _arrive(i, b, settlesBefore);
      },
    );
  }

  void _arrive(int i, FlowDemoStackSnapshot before, int settlesBefore) {
    final step = steps[i];
    _log("${i + 1}/${steps.length} '${step.action.id}' → ${step.to.name}");
    _waitUntil(
      "'${step.action.id}' 도착 (${step.to.name})",
      _holds(
        step.settle
            ? (s) =>
                  s.idle &&
                  s.top == step.to &&
                  identical(s.topKey, before.topKey) &&
                  (step.pending || _settles(step.action) > settlesBefore)
            : (s) =>
                  s.idle &&
                  s.top == step.to &&
                  !identical(s.topKey, before.topKey) &&
                  s.transitionEnds > before.transitionEnds,
      ),
      () => _dwell(i + 1),
    );
  }
}
