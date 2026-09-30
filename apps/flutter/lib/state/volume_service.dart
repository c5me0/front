// System and simulated call-volume control with cancellable fades. Suppress the system
// HUD where supported and release listeners when the service is disposed.

//

import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';

import 'device_services.dart';

const Duration kVolumeFadeStep = Duration(milliseconds: 50);

abstract class VolumeService {
  Future<double> get();

  Future<void> set(double value);

  Future<bool> fadeTo(double target, Duration duration);

  Stream<double> get stream;

  void dispose();

  static VolumeService of(BuildContext context) =>
      DeviceServicesScope.maybeOf(context)?.volume ??
      SystemVolumeService.shared;
}

abstract class FadingVolumeService implements VolumeService {
  int _generation = 0;
  Timer? _timer;
  Completer<bool>? _pending;

  @protected
  Future<double> readVolume();

  @protected
  Future<void> writeVolume(double value);

  bool get isFading => _timer?.isActive ?? false;

  void _cancelFade() {
    _generation++;
    _timer?.cancel();
    _timer = null;
    final pending = _pending;
    _pending = null;
    if (pending != null && !pending.isCompleted) pending.complete(false);
  }

  @override
  Future<double> get() => readVolume();

  @override
  Future<void> set(double value) {
    _cancelFade();
    return writeVolume(value.clamp(0.0, 1.0));
  }

  @override
  Future<bool> fadeTo(double target, Duration duration) async {
    _cancelFade();
    final generation = _generation;
    final to = target.clamp(0.0, 1.0);
    if (duration <= Duration.zero) {
      await writeVolume(to);
      return true;
    }
    final from = await readVolume();
    if (generation != _generation) return false;
    final done = Completer<bool>();
    _pending = done;
    final total = duration.inMicroseconds;
    void step(Timer timer) {
      if (generation != _generation) {
        timer.cancel();
        return;
      }

      final elapsed = timer.tick * kVolumeFadeStep.inMicroseconds;
      final t = (elapsed / total).clamp(0.0, 1.0);
      final v = lerpDouble(from, to, t)!;
      writeVolume(v);
      if (t >= 1) {
        timer.cancel();
        _timer = null;
        _pending = null;
        if (!done.isCompleted) done.complete(true);
      }
    }

    _timer = Timer.periodic(kVolumeFadeStep, step);
    return done.future;
  }

  @override
  void dispose() => _cancelFade();
}

class SystemVolumeService extends FadingVolumeService {
  SystemVolumeService._();

  static final SystemVolumeService shared = SystemVolumeService._();

  double _last = 1;
  bool _hudHidden = false;
  StreamSubscription<double>? _listener;

  late final StreamController<double> _changes = StreamController.broadcast(
    onListen: _listen,
    onCancel: _unlisten,
  );

  Future<void> _hideHud() async {
    if (_hudHidden) return;
    _hudHidden = true;
    try {
      await FlutterVolumeController.updateShowSystemUI(false);
    } catch (error) {
      debugPrint('[cameo] volume: HUD 숨김 실패 ($error)');
    }
  }

  void _listen() {
    try {
      _listener = FlutterVolumeController.addListener(
        (v) {
          _last = v;
          _changes.add(v);
        },
        category: AudioSessionCategory.ambient,
        emitOnStart: false,
      );
    } catch (error) {
      debugPrint('[cameo] volume: 리스너 실패 ($error)');
    }
  }

  void _unlisten() {
    if (_listener == null) return;
    _listener = null;
    try {
      FlutterVolumeController.removeListener();
    } catch (_) {}
  }

  @override
  Future<double> readVolume() async {
    try {
      final v = await FlutterVolumeController.getVolume();
      if (v != null) _last = v;
    } catch (error) {
      debugPrint('[cameo] volume: 읽기 실패 → 마지막 값 ($error)');
    }
    return _last;
  }

  @override
  Future<void> writeVolume(double value) async {
    _last = value;
    await _hideHud();
    try {
      await FlutterVolumeController.setVolume(value);
    } catch (error) {
      debugPrint('[cameo] volume: 쓰기 실패 ($error)');
    }

    if (_changes.hasListener) _changes.add(value);
  }

  @override
  Stream<double> get stream => _changes.stream.distinct();
}

class SimulatedVolumeService extends FadingVolumeService {
  SimulatedVolumeService({double initial = 1}) : _value = initial.clamp(0, 1);

  double _value;
  final StreamController<double> _changes = StreamController.broadcast();

  double get value => _value;

  final List<double> writes = [];

  void simulateHardware(double value) {
    _value = value.clamp(0, 1);
    _changes.add(_value);
  }

  @override
  Future<double> readVolume() => SynchronousFuture(_value);

  @override
  Future<void> writeVolume(double value) {
    _value = value;
    writes.add(value);
    _changes.add(value);
    return SynchronousFuture(null);
  }

  @override
  Stream<double> get stream => _changes.stream;

  @override
  void dispose() {
    super.dispose();
    _changes.close();
  }
}
