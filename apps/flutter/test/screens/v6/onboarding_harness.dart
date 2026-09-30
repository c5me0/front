// Regression coverage for onboarding harness. Preserve behavior, layout, and
// interaction expectations.

import 'package:cameo/design_system/design_system.dart';
import 'package:cameo/main.dart';
import 'package:cameo/state/album_store.dart';
import 'package:cameo/state/device_services.dart';
import 'package:cameo/state/permissions.dart';
import 'package:cameo/state/session.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../v4/v4_harness.dart';

export '../v4/v4_harness.dart';

const Size kIPhone17Pro = Size(402, 874);

void setIPhone17Pro(WidgetTester tester) {
  tester.view
    ..physicalSize = kIPhone17Pro
    ..devicePixelRatio = 1
    ..padding = const FakeViewPadding(top: 62, bottom: 34)
    ..viewPadding = const FakeViewPadding(top: 62, bottom: 34);
  addTearDown(tester.view.reset);
}

Future<SessionController> pumpCameoAppV6(
  WidgetTester tester,
  String route, {
  Session? stored,
  PermissionService? permissions,
  bool settle = true,
}) async {
  setIPhone17Pro(tester);
  mockStoredSession(stored);
  final session = SessionController();
  addTearDown(session.dispose);
  lastServices = DeviceServices.simulated();
  lastAlbum = AlbumStore();
  final store = lastAlbum;
  addTearDown(store.dispose);
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

Widget v6Frame(Widget child, {Size size = kIPhone17Pro}) => MediaQuery(
  data: MediaQueryData(
    size: size,
    padding: const EdgeInsets.only(top: 62, bottom: 34),
    viewPadding: const EdgeInsets.only(top: 62, bottom: 34),
  ),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: CameoTheme(mode: CameoColorMode.light, child: child),
  ),
);
