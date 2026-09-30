// Regression coverage for album v6 harness. Preserve behavior, layout, and interaction
// expectations.

import 'package:cameo/main.dart';
import 'package:cameo/navigation/navigation.dart';
import 'package:cameo/state/album_store.dart';
import 'package:cameo/state/device_services.dart';
import 'package:cameo/state/permissions.dart';
import 'package:cameo/state/session.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../navigation/app_harness.dart';

const Size kFigmaV6 = Size(402, 874);

void setIPhone17Pro(WidgetTester tester) {
  tester.view
    ..physicalSize = kFigmaV6
    ..devicePixelRatio = 1
    ..padding = const FakeViewPadding(top: 62, bottom: 34)
    ..viewPadding = const FakeViewPadding(top: 62, bottom: 34);
  addTearDown(tester.view.reset);
}

late SimulatedPhotoPickerService lastPicker;

Future<SessionController> pumpCameoAppV6(
  WidgetTester tester,
  String route, {
  Session? stored,
  PermissionService? permissions,
  SimulatedPhotoPickerService? picker,
  AlbumStore? album,
  bool settle = true,
}) async {
  setIPhone17Pro(tester);
  mockStoredSession(stored);
  final session = SessionController();
  addTearDown(session.dispose);
  lastPicker = picker ?? SimulatedPhotoPickerService();
  final base = DeviceServices.simulated();
  lastServices = DeviceServices(
    volume: base.volume,
    brightness: base.brightness,
    share: base.share,
    photos: lastPicker,
  );
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

void expectRect(Rect a, Rect b, {double eps = 1e-3, String? reason}) {
  final why = reason == null ? '' : '$reason: ';
  expect(a.left, closeTo(b.left, eps), reason: '${why}left $a vs $b');
  expect(a.top, closeTo(b.top, eps), reason: '${why}top $a vs $b');
  expect(a.width, closeTo(b.width, eps), reason: '${why}width $a vs $b');
  expect(a.height, closeTo(b.height, eps), reason: '${why}height $a vs $b');
}

void resetAlbumTestState() {
  FlowDemo.resetForTesting();
  ViewerSource.clear();
}
