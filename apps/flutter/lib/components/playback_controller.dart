// Playback position, scrubbing, and formatted time. Clamp seeks to the track bounds and
// resume only when the prior playback state requires it.

import 'package:flutter/foundation.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';

import '../content/lab.g.dart';
import '../design_system/design_system.dart';

const int _secondsPerMinute = 60;

const int _timeDigits = 2;

double _clamp01(double v) => v.isNaN ? 0 : v.clamp(0.0, 1.0).toDouble();

String formatPlaybackTime(double seconds) {
  final total = seconds.isFinite && seconds > 0 ? seconds.floor() : 0;
  final m = total ~/ _secondsPerMinute;
  final s = total % _secondsPerMinute;
  return '${m.toString().padLeft(_timeDigits, '0')}:'
      '${s.toString().padLeft(_timeDigits, '0')}';
}

///

///

class PlaybackController extends ChangeNotifier {
  PlaybackController({
    required TickerProvider vsync,
    required this.durationSec,
    double initialSec = 0,
    bool playing = false,
    this.externallyDriven = false,
    this.onPlayingChange,
    this.onSeekSeconds,
  }) : _seconds = initialSec.clamp(0.0, durationSec).toDouble(),
       _playing = playing {
    _position = ValueNotifier<double>(_clockFraction);
    _seekOrigin = _clockFraction;
    _ticker = vsync.createTicker(_tick);
    if (_playing) {
      final scheduler = SchedulerBinding.instance;
      scheduler.addPostFrameCallback((_) {
        if (_disposed) return;
        _clockArmed = true;
        if (_playing) _ensureTicking();
      }, debugLabel: 'PlaybackController.start');
      scheduler.ensureVisualUpdate();
    } else {
      _clockArmed = true;
    }
  }

  factory PlaybackController.fromContent(
    PlayerContent player, {
    required TickerProvider vsync,
  }) => PlaybackController(
    vsync: vsync,
    durationSec: player.durationSeconds.toDouble(),
    initialSec: player.progress * player.durationSeconds,
    playing: player.playing,
  );

  final double durationSec;
  final bool externallyDriven;
  final void Function(bool)? onPlayingChange;
  final void Function(double)? onSeekSeconds;
  bool _resumeAfterScrub = false;

  void syncExternal(double seconds, bool playing) {
    if (_disposed || !externallyDriven) return;
    if (!_scrubbing) _setSeconds(seconds);
    final changed = _playing != playing;
    _playing = playing;
    _publish();
    if (changed) notifyListeners();
  }

  late final Ticker _ticker;
  late final ValueNotifier<double> _position;
  Duration _lastElapsed = Duration.zero;

  double _seconds;
  bool _playing;
  bool _scrubbing = false;
  bool _disposed = false;

  bool _clockArmed = false;

  late double _seekOrigin;

  double _seekOffset = 0;
  SpringSimulation? _seekSim;
  double _seekTime = 0;

  bool reduceMotion = false;

  ValueListenable<double> get position => _position;

  double get seconds => _seconds;

  double get seekOrigin => _seekOrigin;

  int get wholeSeconds => _seconds.floor();

  bool get playing => _playing;

  bool get scrubbing => _scrubbing;

  double get _clockFraction => durationSec > 0 ? _seconds / durationSec : 0;

  void play() {
    if (externallyDriven) {
      onPlayingChange?.call(true);
      return;
    }
    if (_playing) return;
    if (_seconds >= durationSec) {
      _seconds = 0;
      _stopSeek();
      _seekOrigin = 0;
    }
    _playing = true;
    _clockArmed = true;
    _ensureTicking();
    _publish();
    notifyListeners();
  }

  void pause() {
    if (externallyDriven) {
      onPlayingChange?.call(false);
      return;
    }
    if (!_playing) return;
    _playing = false;
    notifyListeners();
  }

  void toggle() => _playing ? pause() : play();

  void seekTo(double fraction, {bool animated = true}) {
    final target = _clamp01(fraction);
    final from = _position.value;
    _setSeconds(target * durationSec);
    if (externallyDriven) onSeekSeconds?.call(_seconds);
    if (animated && !reduceMotion) {
      _seekOrigin = from;
      _seekOffset = from - target;
      _seekTime = 0;
      _seekSim = SpringSimulation(
        CameoMotion.scrubberSeekSpring,
        _seekOffset,
        0,
        0,
        tolerance: cameoSpringTolerance,
      );
      _ensureTicking();
    } else {
      _seekOrigin = target;
      _stopSeek();
    }
    _publish();
  }

  void beginScrub() {
    if (externallyDriven) {
      _resumeAfterScrub = _playing;
      onPlayingChange?.call(false);
    }
    final from = _position.value;
    _stopSeek();
    _seekOrigin = from;
    _setSeconds(from * durationSec);
    _scrubbing = true;
    _publish();
    notifyListeners();
  }

  void scrubTo(double fraction) {
    final target = _clamp01(fraction);
    _stopSeek();
    _seekOrigin = target;
    _setSeconds(target * durationSec);
    _publish();
  }

  void endScrub() {
    if (!_scrubbing) return;
    _scrubbing = false;
    if (externallyDriven) {
      onSeekSeconds?.call(_seconds);
      if (_resumeAfterScrub) onPlayingChange?.call(true);
    }
    notifyListeners();
  }

  void _stopSeek() {
    _seekSim = null;
    _seekOffset = 0;
  }

  void _setSeconds(double next) {
    final before = wholeSeconds;
    _seconds = next.clamp(0.0, durationSec).toDouble();
    if (wholeSeconds != before) notifyListeners();
  }

  void _publish() {
    _position.value = _clamp01(_clockFraction + _seekOffset);
  }

  void _ensureTicking() {
    if (_ticker.isActive) return;
    _lastElapsed = Duration.zero;
    _ticker.start();
  }

  void _tick(Duration elapsed) {
    final dt =
        (elapsed - _lastElapsed).inMicroseconds /
        Duration.microsecondsPerSecond;
    _lastElapsed = elapsed;

    if (!externallyDriven && _playing && !_scrubbing && _clockArmed) {
      final next = _seconds + dt;
      if (next >= durationSec) {
        _setSeconds(durationSec);
        _playing = false;
        notifyListeners();
      } else {
        _setSeconds(next);
      }
    }

    final sim = _seekSim;
    if (sim != null) {
      _seekTime += dt;
      if (sim.isDone(_seekTime)) {
        _stopSeek();
      } else {
        _seekOffset = sim.x(_seekTime);
      }
    }

    _publish();
    if ((!_playing || !_clockArmed) && _seekSim == null) _ticker.stop();
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker.dispose();
    _position.dispose();
    super.dispose();
  }
}
