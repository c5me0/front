// Regression coverage for permissions. Preserve behavior, layout, and interaction
// expectations.

import 'package:cameo/design_system/design_system.dart';
import 'package:cameo/state/permissions.dart';
import 'package:cameo/state/session.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../navigation/app_harness.dart';

void main() {
  testWidgets(
    '시뮬레이트: 요청 → permission.gapMs 뒤 granted · status 가 기억 · reset 하면 undetermined',
    (tester) async {
      final service = SimulatedPermissionService();
      expect(service.gap, CameoMotion.permissionGap);
      expect(
        await service.status(PermissionKind.camera),
        PermissionState.undetermined,
      );
      PermissionState? result;
      service.request(PermissionKind.camera).then((r) => result = r);
      await tester.pump(
        CameoMotion.permissionGap - const Duration(milliseconds: 1),
      );
      expect(result, isNull);
      await tester.pump(const Duration(milliseconds: 1));
      expect(result, PermissionState.granted);
      expect(
        await service.status(PermissionKind.camera),
        PermissionState.granted,
      );
      expect(service.requests, [PermissionKind.camera]);
      service.reset();
      expect(
        await service.status(PermissionKind.camera),
        PermissionState.undetermined,
      );
      expect(service.requests, isEmpty);
    },
  );

  testWidgets(
    'PermissionServiceScope.of: 판정 함수가 true 면 시뮬레이트 · 아니면 시스템 · 스코프 밖 = 시스템',
    (tester) async {
      final system = FakeSystemPermissions();
      final simulated = SimulatedPermissionService();
      var demo = false;
      late BuildContext context;
      await tester.pumpWidget(
        PermissionServiceScope(
          system: system,
          simulated: simulated,
          useSimulated: () => demo,
          child: Builder(
            builder: (c) {
              context = c;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(PermissionServiceScope.of(context), same(system));
      demo = true;
      expect(PermissionServiceScope.of(context), same(simulated));

      await tester.pumpWidget(
        Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      );
      expect(
        PermissionServiceScope.of(context),
        isA<SystemPermissionService>(),
      );
    },
  );
}
