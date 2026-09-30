// System and simulated permission adapters. Requesting screens own ordering; route-
// scoped flow playback uses the simulated provider.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import '../design_system/design_system.dart';
import 'session.dart';

abstract class PermissionService {
  Future<PermissionState> status(PermissionKind kind);

  Future<PermissionState> request(PermissionKind kind);
}

///

///  - granted · limited · provisional → granted

///  - permanentlyDenied · restricted → denied
class SystemPermissionService implements PermissionService {
  const SystemPermissionService();

  static ph.Permission _permission(PermissionKind kind) => switch (kind) {
    PermissionKind.microphone => ph.Permission.microphone,
    PermissionKind.camera => ph.Permission.camera,
    PermissionKind.notifications => ph.Permission.notification,
  };

  static PermissionState _map(
    ph.PermissionStatus status, {
    required bool requested,
  }) => switch (status) {
    ph.PermissionStatus.granted ||
    ph.PermissionStatus.limited ||
    ph.PermissionStatus.provisional => PermissionState.granted,
    ph.PermissionStatus.denied =>
      requested ? PermissionState.denied : PermissionState.undetermined,
    ph.PermissionStatus.permanentlyDenied ||
    ph.PermissionStatus.restricted => PermissionState.denied,
  };

  @override
  Future<PermissionState> status(PermissionKind kind) async =>
      _map(await _permission(kind).status, requested: false);

  @override
  Future<PermissionState> request(PermissionKind kind) async =>
      _map(await _permission(kind).request(), requested: true);
}

class SimulatedPermissionService implements PermissionService {
  SimulatedPermissionService({this.gap = CameoMotion.permissionGap});

  final Duration gap;

  final Map<PermissionKind, PermissionState> _states = {};

  @visibleForTesting
  final List<PermissionKind> requests = [];

  @override
  Future<PermissionState> status(PermissionKind kind) =>
      SynchronousFuture(_states[kind] ?? PermissionState.undetermined);

  @override
  Future<PermissionState> request(PermissionKind kind) async {
    requests.add(kind);
    await Future<void>.delayed(gap);
    return _states[kind] = PermissionState.granted;
  }

  void reset() {
    _states.clear();
    requests.clear();
  }
}

class PermissionServiceScope extends InheritedWidget {
  const PermissionServiceScope({
    super.key,
    required this.system,
    required this.simulated,
    required this.useSimulated,
    required super.child,
  });

  final PermissionService system;

  final PermissionService simulated;

  final bool Function() useSimulated;

  static PermissionService of(BuildContext context) {
    final scope = context
        .getInheritedWidgetOfExactType<PermissionServiceScope>();
    if (scope == null) return const SystemPermissionService();
    return scope.useSimulated() ? scope.simulated : scope.system;
  }

  @override
  bool updateShouldNotify(PermissionServiceScope oldWidget) =>
      system != oldWidget.system ||
      simulated != oldWidget.simulated ||
      useSimulated != oldWidget.useSimulated;
}
