// System and simulated brightness adapters. Sleep mode temporarily overrides brightness
// and must restore the previous level on exit.

//

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:screen_brightness/screen_brightness.dart';

import 'device_services.dart';

abstract class BrightnessService {
  Future<double> get();

  Future<void> set(double value);

  Future<void> restore();

  static BrightnessService of(BuildContext context) =>
      DeviceServicesScope.maybeOf(context)?.brightness ??
      SystemBrightnessService.shared;
}

class SystemBrightnessService implements BrightnessService {
  SystemBrightnessService._();

  static final SystemBrightnessService shared = SystemBrightnessService._();

  double _last = 1;

  @override
  Future<double> get() async {
    try {
      _last = await ScreenBrightness.instance.application;
    } catch (error) {
      debugPrint('[cameo] brightness: 읽기 실패 → 마지막 값 ($error)');
    }
    return _last;
  }

  @override
  Future<void> set(double value) async {
    _last = value.clamp(0.0, 1.0);
    try {
      await ScreenBrightness.instance.setApplicationScreenBrightness(_last);
    } catch (error) {
      debugPrint('[cameo] brightness: 쓰기 실패 ($error)');
    }
  }

  @override
  Future<void> restore() async {
    try {
      await ScreenBrightness.instance.resetApplicationScreenBrightness();
      _last = await ScreenBrightness.instance.application;
    } catch (error) {
      debugPrint('[cameo] brightness: 되돌리기 실패 ($error)');
    }
  }
}

class SimulatedBrightnessService implements BrightnessService {
  SimulatedBrightnessService({this.system = 0.8}) : _value = system;

  final double system;
  double _value;

  double get value => _value;

  bool get overridden => _value != system;

  @override
  Future<double> get() => SynchronousFuture(_value);

  @override
  Future<void> set(double value) {
    _value = value.clamp(0.0, 1.0);
    return SynchronousFuture(null);
  }

  @override
  Future<void> restore() {
    _value = system;
    return SynchronousFuture(null);
  }
}
