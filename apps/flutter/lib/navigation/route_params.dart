// Typed parsing for supported route parameters. Unknown values use documented defaults
// instead of leaking raw query strings into screens.

import 'dart:async';

import 'package:flutter/scheduler.dart';

enum TranscriptTheme {
  dark('dark'),
  photo('photo');

  const TranscriptTheme(this.param);

  final String param;

  static const TranscriptTheme fallback = TranscriptTheme.dark;

  static const Map<String, TranscriptTheme> legacyParams = {
    'light': TranscriptTheme.dark,
  };

  static TranscriptTheme? tryParse(String? value) {
    for (final t in values) {
      if (t.param == value) return t;
    }
    return legacyParams[value];
  }
}

///  - media-4x3   16-10 (2042:2581) 4:3
///  - media-1x1   16-11 (2042:2650) 1:1

enum CallState {
  base('base'),
  media16x9('media-16x9'),
  media4x3('media-4x3'),
  media1x1('media-1x1'),

  sleepToast('sleep-toast'),

  volume('volume'),

  highlight('highlight'),

  aod('aod');

  const CallState(this.param);

  final String param;

  static const CallState fallback = CallState.base;

  static CallState? tryParse(String? value) {
    for (final s in values) {
      if (s.param == value) return s;
    }
    return null;
  }
}

typedef DemoStep = ({Duration at, VoidCallback run});

class DemoTimeline {
  final List<Timer> _timers = [];

  int _epoch = 0;
  bool _waitingForFrame = false;

  bool get isActive => _waitingForFrame || _timers.any((t) => t.isActive);

  void start(List<DemoStep> steps) {
    cancel();
    final epoch = _epoch;
    _waitingForFrame = true;
    final scheduler = SchedulerBinding.instance;
    scheduler.addPostFrameCallback((_) {
      if (epoch != _epoch) return;
      _waitingForFrame = false;
      for (final step in steps) {
        _timers.add(Timer(step.at, step.run));
      }
    }, debugLabel: 'DemoTimeline.start');
    scheduler.ensureVisualUpdate();
  }

  void cancel() {
    _epoch++;
    _waitingForFrame = false;
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
  }
}

enum AlbumView {
  timeline('timeline'),
  liked('liked'),
  deleted('deleted'),
  select('select');

  const AlbumView(this.param);

  final String param;

  static const AlbumView fallback = AlbumView.timeline;

  static AlbumView? tryParse(String? value) {
    for (final v in values) {
      if (v.param == value) return v;
    }
    return null;
  }
}

enum PartnerRouteState {
  input('input'),
  done('done');

  const PartnerRouteState(this.param);

  final String param;

  static const PartnerRouteState fallback = PartnerRouteState.input;

  static PartnerRouteState? tryParse(String? value) {
    for (final v in values) {
      if (v.param == value) return v;
    }
    return null;
  }
}

enum VerifyRouteState {
  input('input'),
  success('success');

  const VerifyRouteState(this.param);

  final String param;

  static const VerifyRouteState fallback = VerifyRouteState.input;

  static VerifyRouteState? tryParse(String? value) {
    for (final v in values) {
      if (v.param == value) return v;
    }
    return null;
  }
}
