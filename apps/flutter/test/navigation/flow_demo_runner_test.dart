// Regression coverage for flow demo runner. Preserve behavior, layout, and interaction
// expectations.

import 'package:cameo/navigation/navigation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

const int _frameMs = 16;
const int _transitionMs = 520;
const int _shutterFlashMs = 300;

const int _chainGapMs = _frameMs * 3;

const int _typePhoneMs = 1210;
const int _typeNameMs = 360;
const int _sendMs = 900;
const int _verifyMs = 1500;
const int _connectMs = 3000;
const int _permissionsMs = 1500;
const int _sheetMs = 520;

const int _scrollMs = 4200;
const int _toggleMs = 900;
const int _volumeMs = 400;

const int _stripMs = 350;
const int _reviewMs = 450;
const Map<FlowDemoAction, int> _settleMs = {
  FlowDemoAction.viewerStrip: _stripMs,
  FlowDemoAction.homeLiked: _frameMs,
  FlowDemoAction.likedClose: _frameMs,
  FlowDemoAction.homeDeleted: _frameMs,
  FlowDemoAction.deletedClose: _frameMs,
  FlowDemoAction.aodEnd: _frameMs,
  FlowDemoAction.reviewSend: _reviewMs,
  FlowDemoAction.phoneType: _typePhoneMs,
  FlowDemoAction.profileType: _typeNameMs,
  FlowDemoAction.homeScroll: _scrollMs,
  FlowDemoAction.viewerLike: _frameMs,
  FlowDemoAction.homeSelect: _frameMs,
  FlowDemoAction.selectToggle: _toggleMs,
  FlowDemoAction.selectClose: _frameMs,
  FlowDemoAction.callVolume: _volumeMs,
  FlowDemoAction.callHighlight: _frameMs,
  FlowDemoAction.callCamera: _frameMs,
  FlowDemoAction.callCloseCard: _frameMs,
  FlowDemoAction.callSleep: _frameMs,
  FlowDemoAction.settingsLogout: _sheetMs,
};

const int _slackMs = _frameMs * 5;

int _travelOf(FlowDemoStep step) {
  if (step.pending) return 0;
  return step.settle && step.action == FlowDemoAction.cameraShutter
      ? _reviewMs
      : _travelMs(step.action);
}

int _travelMs(FlowDemoAction action) =>
    _settleMs[action] ??
    switch (action) {
      FlowDemoAction.phoneSubmit => _sendMs + _transitionMs,
      FlowDemoAction.verifyAutofill => _verifyMs + _transitionMs,
      FlowDemoAction.partnerType => _connectMs + _transitionMs,
      FlowDemoAction.permissionsAllow => _permissionsMs + _transitionMs,
      FlowDemoAction.cameraShutter => _shutterFlashMs + _transitionMs,
      _ => _transitionMs,
    };

class _FakeLoop {
  int now = 0;

  int blockedUntil = -1;
  int _seq = 0;
  final Map<int, ({int at, VoidCallback cb})> _timers = {};
  final Map<int, VoidCallback> _frames = {};

  VoidCallback setTimeout(VoidCallback cb, int ms) {
    final id = ++_seq;
    _timers[id] = (at: now + ms, cb: cb);
    return () => _timers.remove(id);
  }

  VoidCallback requestFrame(VoidCallback cb) {
    final id = ++_seq;
    _frames[id] = cb;
    return () => _frames.remove(id);
  }

  void step() {
    now += _frameMs;
    if (now < blockedUntil) return;
    while (true) {
      MapEntry<int, ({int at, VoidCallback cb})>? next;
      for (final e in _timers.entries) {
        if (e.value.at <= now && (next == null || e.value.at < next.value.at)) {
          next = e;
        }
      }
      if (next == null) break;
      _timers.remove(next.key);
      next.value.cb();
    }
    final due = _frames.values.toList();
    _frames.clear();
    for (final cb in due) {
      cb();
    }
  }

  void runUntil(int ms, [bool Function()? stop]) {
    while (now < ms && !(stop?.call() ?? false)) {
      step();
    }
  }
}

class _FakeRoute {
  _FakeRoute(this.screen);

  final FlowDemoScreen? screen;
}

class _FakeStack {
  _FakeStack(this.loop);

  final _FakeLoop loop;
  final List<_FakeRoute> routes = [];
  int inFlight = 0;
  int transitionEnds = 0;

  _FakeRoute? get top => routes.isEmpty ? null : routes.last;

  _FakeRoute add(FlowDemoScreen? screen) {
    final route = _FakeRoute(screen);
    routes.add(route);
    return route;
  }

  _FakeRoute push(FlowDemoScreen? screen, [VoidCallback? then]) {
    final route = add(screen);
    _transition(then);
    return route;
  }

  void pop([VoidCallback? then]) {
    routes.removeLast();
    _transition(then);
  }

  void replaceAll(FlowDemoScreen screen) {
    final route = add(screen);
    _transition(() => routes.removeWhere((r) => !identical(r, route)));
  }

  void switchLeaf(FlowDemoScreen screen) {
    routes
      ..removeLast()
      ..add(_FakeRoute(screen));
    _transition(null);
  }

  void _transition(VoidCallback? then) {
    inFlight++;
    loop.setTimeout(() {
      inFlight--;
      transitionEnds++;
      then?.call();
    }, _transitionMs);
  }

  FlowDemoStackSnapshot snapshot() => (
    topKey: top,
    top: top?.screen,
    idle: inFlight == 0,
    transitionEnds: transitionEnds,
  );
}

typedef _FakeFlowRun = ({
  List<({FlowDemoAction action, int at})> delivered,
  List<String> warnings,
  List<String> logs,
  FlowDemoRunResult? result,
  int outstanding,
  _FakeStack stack,
  _FakeLoop loop,
});

_FakeFlowRun _runFakeFlow({
  List<FlowDemoStep> steps = flowDemoTimeline,
  bool chainEndCall = false,
  int ownerReadyAt = 0,
  Map<FlowDemoAction, int> refuse = const {},
  Set<FlowDemoAction> noop = const {},
  Set<FlowDemoAction> noSettle = const {},
  Set<FlowDemoAction> unbuilt = const {},
  bool reviewUnbuilt = false,
  Map<FlowDemoAction, int> staleSettles = const {},
  (int, int)? block,
  (int, int)? intrude,
  int? cancelAt,
  int untilMs = 120000,
}) {
  final loop = _FakeLoop();
  final stack = _FakeStack(loop);
  stack.add(FlowDemoScreen.welcome);
  final settles = <FlowDemoAction, int>{...staleSettles};
  void settleAfter(FlowDemoAction action, int ms) {
    if (noSettle.contains(action)) return;
    loop.setTimeout(() => settles[action] = (settles[action] ?? 0) + 1, ms);
  }

  final refusals = {...refuse};
  bool Function() onTop(FlowDemoScreen screen, VoidCallback go) => () {
    if (stack.top?.screen != screen) return false;
    go();
    return true;
  };
  final handlers = <FlowDemoAction, bool Function()>{
    FlowDemoAction.welcomeStart: onTop(
      FlowDemoScreen.welcome,
      () => stack.push(FlowDemoScreen.phone),
    ),
    FlowDemoAction.phoneType: onTop(
      FlowDemoScreen.phone,
      () => settleAfter(FlowDemoAction.phoneType, _typePhoneMs),
    ),
    FlowDemoAction.phoneSubmit: onTop(
      FlowDemoScreen.phone,
      () => loop.setTimeout(() => stack.push(FlowDemoScreen.verify), _sendMs),
    ),
    FlowDemoAction.verifyAutofill: onTop(
      FlowDemoScreen.verify,
      () => loop.setTimeout(
        () => stack.replaceAll(FlowDemoScreen.profile),
        _verifyMs,
      ),
    ),
    FlowDemoAction.profileType: onTop(
      FlowDemoScreen.profile,
      () => settleAfter(FlowDemoAction.profileType, _typeNameMs),
    ),
    FlowDemoAction.profileSubmit: onTop(
      FlowDemoScreen.profile,
      () => stack.push(FlowDemoScreen.partner),
    ),
    FlowDemoAction.partnerType: onTop(
      FlowDemoScreen.partner,
      () => loop.setTimeout(
        () => stack.push(FlowDemoScreen.permissions),
        _connectMs,
      ),
    ),
    FlowDemoAction.permissionsAllow: onTop(
      FlowDemoScreen.permissions,
      () => loop.setTimeout(
        () => stack.replaceAll(FlowDemoScreen.home),
        _permissionsMs,
      ),
    ),
    FlowDemoAction.back: () {
      if (stack.routes.length < 2) return false;
      stack.pop();
      return true;
    },

    FlowDemoAction.homeScroll: onTop(
      FlowDemoScreen.home,
      () => settleAfter(FlowDemoAction.homeScroll, _scrollMs),
    ),
    FlowDemoAction.homeOpenPhoto: onTop(
      FlowDemoScreen.home,
      () => stack.push(FlowDemoScreen.photo),
    ),
    FlowDemoAction.viewerStrip: onTop(
      FlowDemoScreen.photo,
      () => settleAfter(FlowDemoAction.viewerStrip, _stripMs),
    ),
    FlowDemoAction.viewerLike: onTop(
      FlowDemoScreen.photo,
      () => settleAfter(FlowDemoAction.viewerLike, _frameMs),
    ),
    for (final a in [
      FlowDemoAction.homeLiked,
      FlowDemoAction.likedClose,
      FlowDemoAction.homeDeleted,
      FlowDemoAction.deletedClose,
      FlowDemoAction.homeSelect,
      FlowDemoAction.selectToggle,
      FlowDemoAction.selectClose,
    ])
      a: onTop(FlowDemoScreen.home, () => settleAfter(a, _settleMs[a]!)),
    FlowDemoAction.homeCall: onTop(
      FlowDemoScreen.home,
      () => stack.push(FlowDemoScreen.call),
    ),

    for (final a in [
      FlowDemoAction.callVolume,
      FlowDemoAction.callHighlight,
      FlowDemoAction.callCamera,
      FlowDemoAction.callCloseCard,
      FlowDemoAction.callSleep,
      FlowDemoAction.aodEnd,
    ])
      a: onTop(FlowDemoScreen.call, () => settleAfter(a, _settleMs[a]!)),
    FlowDemoAction.sheetLive: onTop(
      FlowDemoScreen.call,
      () => stack.push(FlowDemoScreen.camera),
    ),

    FlowDemoAction.cameraShutter: () {
      final top = stack.top?.screen;
      if (top == FlowDemoScreen.camera) {
        loop.setTimeout(stack.pop, _shutterFlashMs);
        return true;
      }
      if (top == FlowDemoScreen.capture && !reviewUnbuilt) {
        settleAfter(FlowDemoAction.cameraShutter, _reviewMs);
        return true;
      }
      return false;
    },

    FlowDemoAction.callEndCall: onTop(
      FlowDemoScreen.call,
      () => stack.pop(
        chainEndCall
            ? () => loop.setTimeout(
                () => stack.push(FlowDemoScreen.transcript),
                _chainGapMs,
              )
            : null,
      ),
    ),
    FlowDemoAction.homeOpenCallCard: onTop(
      FlowDemoScreen.home,
      () => stack.push(FlowDemoScreen.transcript),
    ),

    FlowDemoAction.tabsCamera: onTop(
      FlowDemoScreen.home,
      () => stack.switchLeaf(FlowDemoScreen.capture),
    ),
    FlowDemoAction.reviewSend: onTop(
      FlowDemoScreen.capture,
      () => settleAfter(FlowDemoAction.reviewSend, _reviewMs),
    ),
    FlowDemoAction.cameraOpenShared: onTop(
      FlowDemoScreen.capture,
      () => stack.push(FlowDemoScreen.photo),
    ),
    FlowDemoAction.tabsSettings: onTop(
      FlowDemoScreen.capture,
      () => stack.switchLeaf(FlowDemoScreen.settings),
    ),
    FlowDemoAction.settingsLogout: onTop(
      FlowDemoScreen.settings,
      () => settleAfter(FlowDemoAction.settingsLogout, _sheetMs),
    ),
    FlowDemoAction.sheetConfirm: onTop(
      FlowDemoScreen.settings,
      () => stack.replaceAll(FlowDemoScreen.welcome),
    ),
  };

  final delivered = <({FlowDemoAction action, int at})>[];
  final warnings = <String>[];
  final logs = <String>[];
  var outstanding = 0;
  VoidCallback track(
    VoidCallback Function(VoidCallback) schedule,
    VoidCallback cb,
  ) {
    outstanding++;
    var live = true;
    final cancel = schedule(() {
      if (live) outstanding--;
      live = false;
      cb();
    });
    return () {
      if (live) outstanding--;
      live = false;
      cancel();
    };
  }

  if (intrude != null) {
    loop.setTimeout(() => stack.push(null), intrude.$1);
    loop.setTimeout(stack.pop, intrude.$2);
  }
  if (block != null) {
    loop.setTimeout(() => loop.blockedUntil = block.$2, block.$1);
  }

  final runner = FlowDemoRunner(
    steps: steps,
    snapshot: stack.snapshot,
    ownerReady: () => loop.now >= ownerReadyAt,
    settles: (action) => settles[action] ?? 0,
    deliver: (action) {
      final left = refusals[action] ?? 0;
      if (left > 0) {
        refusals[action] = left - 1;
        return false;
      }
      if (noop.contains(action)) {
        delivered.add((action: action, at: loop.now));
        return true;
      }

      if (unbuilt.contains(action)) return false;
      final ok = handlers[action]!();
      if (ok) delivered.add((action: action, at: loop.now));
      return ok;
    },
    nextFrame: (cb) => track(loop.requestFrame, cb),
    after: (delay, cb) =>
        track((c) => loop.setTimeout(c, delay.inMilliseconds), cb),
    log: logs.add,
    warn: warnings.add,
  )..start();

  if (cancelAt != null) {
    loop.runUntil(cancelAt);
    runner.cancel();
  }
  loop.runUntil(untilMs, () => runner.result != null && cancelAt == null);
  return (
    delivered: delivered,
    warnings: warnings,
    logs: logs,
    result: runner.result,
    outstanding: outstanding,
    stack: stack,
    loop: loop,
  );
}

int _indexOf(_FakeFlowRun r, FlowDemoAction action, [int nth = 0]) {
  var seen = 0;
  for (var i = 0; i < r.delivered.length; i++) {
    if (r.delivered[i].action != action) continue;
    if (seen++ == nth) return i;
  }
  return -1;
}

void main() {
  test(
    '한 바퀴 (40 단계): 표 순서대로 모두 · 첫 단계 = 웰컴 멈춤 + 1500 · 각 단계 = 앞 단계 도착 + afterMs · 끝 = 웰컴',
    () {
      final r = _runFakeFlow();
      expect(r.result, FlowDemoRunResult.done);
      expect(r.warnings, isEmpty);
      expect(
        [for (final d in r.delivered) d.action],
        [for (final s in flowDemoTimeline) s.action],
      );
      expect(r.logs.first, '시작');
      expect(r.logs.last, '끝');
      expect(r.logs, contains("40/40 'sheet.confirm' → welcome"));
      expect(
        [for (final x in r.stack.routes) x.screen],
        [FlowDemoScreen.welcome],
      );
      final first = r.delivered.first.at;
      final firstMin = flowDemoTimeline.first.afterMs;
      expect(first, inInclusiveRange(firstMin, firstMin + _slackMs));
      for (var i = 1; i < r.delivered.length; i++) {
        final gap = r.delivered[i].at - r.delivered[i - 1].at;
        final min =
            _travelOf(flowDemoTimeline[i - 1]) + flowDemoTimeline[i].afterMs;
        expect(
          gap,
          inInclusiveRange(min, min + _slackMs),
          reason: '${i + 1} ${flowDemoTimeline[i].action.id}',
        );
      }
      expect(r.outstanding, 0);
    },
  );

  test('시작: 주인(앱 루트)이 준비되기 전에는 재지 않는다', () {
    const readyAt = 4000;
    final r = _runFakeFlow(ownerReadyAt: readyAt);
    expect(
      r.delivered.first.at,
      greaterThanOrEqualTo(readyAt + flowDemoTimeline.first.afterMs),
    );
    expect(r.result, FlowDemoRunResult.done);
  });

  test(
    '같은 화면 단계 (phone.type · home.scroll · call.* · settings.logout): 전환이 아니라 settle 로 도착 — 전달 전의 settle 은 세지 않는다',
    () {
      final r = _runFakeFlow(
        staleSettles: {
          FlowDemoAction.phoneType: 3,
          FlowDemoAction.settingsLogout: 1,
        },
      );
      expect(r.result, FlowDemoRunResult.done);
      final type = r.delivered[_indexOf(r, FlowDemoAction.phoneType)].at;
      final submit = r.delivered[_indexOf(r, FlowDemoAction.phoneSubmit)].at;
      expect(
        submit - type,
        greaterThanOrEqualTo(_typePhoneMs + flowDemoTimeline[2].afterMs),
      );
    },
  );

  test('같은 화면 단계에 settle 이 오지 않으면: 상한 뒤 경고하고 멈춘다', () {
    final r = _runFakeFlow(noSettle: {FlowDemoAction.profileType});
    expect(r.result, FlowDemoRunResult.stopped);
    expect(r.warnings.single, contains('profile.type'));
    expect(r.warnings.single, contains('도착'));
    expect(
      r.delivered.map((d) => d.action),
      isNot(contains(FlowDemoAction.profileSubmit)),
    );
    expect(r.outstanding, 0);
  });

  test('멈춤(검증 r1 flow 재현): 스레드가 수 초 막혔다 풀려도 단계가 한꺼번에 발화하거나 빠지지 않는다', () {
    final r = _runFakeFlow(
      block: (flowDemoTimeline.first.afterMs + _frameMs * 4, 9000),
    );
    expect(r.result, FlowDemoRunResult.done);
    expect(
      [for (final d in r.delivered) d.action],
      [for (final s in flowDemoTimeline) s.action],
    );
    final start = r.delivered[_indexOf(r, FlowDemoAction.welcomeStart)].at;
    final type = r.delivered[_indexOf(r, FlowDemoAction.phoneType)].at;
    expect(
      type - start,
      greaterThanOrEqualTo(_transitionMs + flowDemoTimeline[1].afterMs),
    );
  });

  test('거부: 경고 한 번 · 다음 프레임에 다시 (세 번 거부 = 세 프레임 뒤)', () {
    final r = _runFakeFlow(refuse: {FlowDemoAction.verifyAutofill: 3});
    expect(r.result, FlowDemoRunResult.done);
    expect(r.warnings.where((w) => w.contains('verify.autofill')).length, 1);
    final submit = r.delivered[_indexOf(r, FlowDemoAction.phoneSubmit)].at;
    final autofill = r.delivered[_indexOf(r, FlowDemoAction.verifyAutofill)].at;
    final expected =
        submit +
        _sendMs +
        _transitionMs +
        flowDemoTimeline[3].afterMs +
        _frameMs * 3;
    expect(autofill, inInclusiveRange(expected, expected + _slackMs));
  });

  test('도착 없음: 상한 뒤 경고하고 멈춘다 — 다음 단계를 보내지 않는다', () {
    final r = _runFakeFlow(noop: {FlowDemoAction.sheetLive});
    expect(r.result, FlowDemoRunResult.stopped);
    expect(r.warnings, hasLength(1));
    expect(r.warnings.single, contains('sheet.live'));
    expect(r.warnings.single, contains('도착'));
    expect(
      r.delivered.map((d) => d.action),
      isNot(contains(FlowDemoAction.cameraShutter)),
    );
    final camera = r.delivered[_indexOf(r, FlowDemoAction.sheetLive)];
    expect(
      r.loop.now,
      greaterThanOrEqualTo(camera.at + flowDemoWaitLimit.inMilliseconds),
    );
    expect(r.outstanding, 0);
  });

  test('이어지는 이동(닫힘 → 푸시 — dismissModalThen): 중간의 홈을 도착으로 보지 않는다', () {
    final end = flowDemoTimeline.indexWhere(
      (s) => s.action == FlowDemoAction.callEndCall,
    );
    final steps = [
      for (var i = 0; i < flowDemoTimeline.length; i++)
        if (i == end)
          (
            afterMs: flowDemoTimeline[i].afterMs,
            action: FlowDemoAction.callEndCall,
            to: FlowDemoScreen.transcript,
            settle: false,
            pending: false,
          )
        else if (i != end + 1)
          flowDemoTimeline[i],
    ];
    final r = _runFakeFlow(steps: steps, chainEndCall: true);
    expect(r.result, FlowDemoRunResult.done);
    expect(r.warnings, isEmpty);
    final endAt = r.delivered[_indexOf(r, FlowDemoAction.callEndCall)].at;
    final backAt = r.delivered[_indexOf(r, FlowDemoAction.back, 1)].at;
    expect(
      backAt - endAt,
      greaterThanOrEqualTo(_transitionMs * 2 + _chainGapMs + 2000),
    );
  });

  test(
    '세션 전이 (스택 교체): 나가는 스택이 치워지기 전에도 새 잎이 멈추면 도착 — 인증 → 프로필 · 온보딩 → 홈 · 로그아웃 → 웰컴',
    () {
      final r = _runFakeFlow();
      final verify = r.delivered[_indexOf(r, FlowDemoAction.verifyAutofill)].at;
      final typeName = r.delivered[_indexOf(r, FlowDemoAction.profileType)].at;
      expect(
        typeName - verify,
        inInclusiveRange(
          _verifyMs + _transitionMs + 600,
          _verifyMs + _transitionMs + 600 + _slackMs,
        ),
      );
    },
  );

  test('사용자 개입: 머무는 동안 다른 화면이 올라왔다 내려가면 출발 화면이 다시 맨 위가 되고 멈춘 뒤에 전달', () {
    final base = _runFakeFlow();

    final home = base.delivered[_indexOf(base, FlowDemoAction.back)].at;
    final at = home + _transitionMs + _frameMs * 4;
    final closeAt = at + 3000;
    final r = _runFakeFlow(intrude: (at, closeAt));
    expect(r.result, FlowDemoRunResult.done);
    expect(r.warnings, isEmpty);
    final select = r.delivered[_indexOf(r, FlowDemoAction.homeSelect)].at;
    expect(select, greaterThanOrEqualTo(closeAt + _transitionMs));
  });

  test(
    'pending (v6 화면이 아직 없음 — R6): 받을 화면이 없으면 경고 한 번 · 건너뜀 · settle 없이 도착 · 끝까지 간다',
    () {
      final pending = {
        for (final s in flowDemoTimeline)
          if (s.pending && s.action != FlowDemoAction.cameraShutter) s.action,
      };

      final reviewPending = flowDemoTimeline.any(
        (s) => s.pending && s.action == FlowDemoAction.cameraShutter,
      );
      final r = _runFakeFlow(unbuilt: pending, reviewUnbuilt: reviewPending);
      expect(r.result, FlowDemoRunResult.done);
      final skipped = [
        for (var i = 0; i < flowDemoTimeline.length; i++)
          if (flowDemoTimeline[i].pending) i,
      ];
      expect(skipped, isNot(contains(33)));
      expect(skipped, isNot(contains(34)));
      expect(r.warnings, hasLength(skipped.length));
      for (final w in r.warnings) {
        expect(w, contains('pending'));
      }

      expect(
        r.logs.where((l) => RegExp(r'^\d+/40 ').hasMatch(l)),
        hasLength(40),
      );
      expect(
        [for (final d in r.delivered) d.action],
        [
          for (final s in flowDemoTimeline)
            if (!s.pending) s.action,
        ],
      );
      expect(r.outstanding, 0);
    },
  );

  test('pending 이 아닌 단계를 받을 화면이 없으면: 거부 · 상한 뒤 멈춘다 (건너뛰지 않는다)', () {
    final r = _runFakeFlow(unbuilt: {FlowDemoAction.aodEnd});
    expect(r.result, FlowDemoRunResult.stopped);
    expect(r.warnings.first, contains('aod.end'));
    expect(r.warnings.first, contains('받지 않았다'));
    expect(
      r.delivered.map((d) => d.action),
      isNot(contains(FlowDemoAction.callEndCall)),
    );
  });

  test('표 규칙: pending 은 settle 단계만 · settle = 출발과 같은 화면', () {
    for (var i = 0; i < flowDemoTimeline.length; i++) {
      final s = flowDemoTimeline[i];
      final from = i == 0 ? flowDemoStart : flowDemoTimeline[i - 1].to;
      expect(s.settle, s.to == from, reason: '${i + 1} ${s.action.id}');
      if (s.pending) {
        expect(s.settle, isTrue, reason: '${i + 1} ${s.action.id}');
      }
    }
  });

  test('cancel: 대기 중인 프레임·타이머를 모두 해제하고 더는 전달하지 않는다', () {
    final r = _runFakeFlow(cancelAt: 5000, untilMs: 30000);
    expect(r.result, FlowDemoRunResult.cancelled);
    expect(r.outstanding, 0);
    expect(r.delivered.every((d) => d.at <= 5000), isTrue);
  });
}
