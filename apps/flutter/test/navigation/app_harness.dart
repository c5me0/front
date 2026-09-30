// Regression coverage for app harness. Preserve behavior, layout, and interaction
// expectations.

import 'dart:convert';

import 'package:cameo/main.dart';
import 'package:cameo/navigation/navigation.dart';
import 'package:cameo/state/album_store.dart';
import 'package:cameo/state/device_services.dart';
import 'package:cameo/state/permissions.dart';
import 'package:cameo/state/session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Size kIPhone16 = Size(393, 852);

const Size kIPhone17Pro = Size(402, 874);
const Duration kFrame = Duration(milliseconds: 16);

void setIPhone16(WidgetTester tester, [Size size = kIPhone16]) {
  final top = size == kIPhone17Pro ? 62.0 : 59.0;
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1
    ..padding = FakeViewPadding(top: top, bottom: 34)
    ..viewPadding = FakeViewPadding(top: top, bottom: 34);
  addTearDown(tester.view.reset);
}

void mockStoredSession(Session? stored) {
  SharedPreferences.setMockInitialValues({
    if (stored != null) kSessionStorageKey: jsonEncode(stored.toJson()),
  });
}

class FakeSystemPermissions implements PermissionService {
  FakeSystemPermissions({this.result = PermissionState.granted});

  final PermissionState result;
  final List<PermissionKind> requests = [];

  @override
  Future<PermissionState> status(PermissionKind kind) =>
      SynchronousFuture(PermissionState.undetermined);

  @override
  Future<PermissionState> request(PermissionKind kind) {
    requests.add(kind);
    return SynchronousFuture(result);
  }
}

late DeviceServices lastServices;

late AlbumStore lastAlbum;

Future<SessionController> pumpCameoApp(
  WidgetTester tester,
  String route, {
  Session? stored,
  PermissionService? permissions,
  DeviceServices? services,
  AlbumStore? album,
  bool settle = true,
  Size size = kIPhone16,
}) async {
  setIPhone16(tester, size);
  mockStoredSession(stored);
  final session = SessionController();
  addTearDown(session.dispose);
  lastServices = services ?? DeviceServices.simulated();
  lastAlbum = album ?? AlbumStore();
  final store = lastAlbum;
  if (album == null) addTearDown(store.dispose);
  await tester.pumpWidget(
    CameoApp(
      initialRoute: route,
      session: session,
      permissions: permissions ?? FakeSystemPermissions(),
      services: lastServices,
      album: store,
    ),
  );
  await tester.pump();
  if (settle) await settleApp(tester);
  return session;
}

Future<void> settleApp(
  WidgetTester tester, {
  Duration quiet = const Duration(seconds: 2),
  Duration timeout = const Duration(seconds: 20),
}) async {
  var elapsed = Duration.zero;
  var idle = Duration.zero;
  while (true) {
    await tester.pump(kFrame);
    elapsed += kFrame;
    if (!tester.binding.hasScheduledFrame) return;
    idle = CameoRouteActivity.isIdle ? idle + kFrame : Duration.zero;
    if (idle >= quiet) return;
    if (elapsed >= timeout) {
      fail('settleApp: $timeout 안에 멈추지 않았다');
    }
  }
}

Future<void> scrollIntoCenter(WidgetTester tester, Finder finder) async {
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await settleApp(tester);
}

Future<void> disposeApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
}

NavigatorState rootNavigator(WidgetTester tester) =>
    tester.state<NavigatorState>(find.byType(Navigator).first);

SimulatedVolumeService get simulatedVolume =>
    lastServices.volume as SimulatedVolumeService;

SimulatedBrightnessService get simulatedBrightness =>
    lastServices.brightness as SimulatedBrightnessService;

SimulatedShareService get simulatedShare =>
    lastServices.share as SimulatedShareService;

AppTabsState? appTabs(WidgetTester tester) {
  final finder = find.byType(AppTabs, skipOffstage: false);
  if (finder.evaluate().isEmpty) return null;
  return tester.state<AppTabsState>(finder.first);
}

Future<void> withDebugPrintLogs(
  Future<void> Function(List<String> logs) body,
) async {
  final logs = <String>[];
  final original = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) => logs.add(message ?? '');
  try {
    await body(logs);
  } finally {
    debugPrint = original;
  }
}
