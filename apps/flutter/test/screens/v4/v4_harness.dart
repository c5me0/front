// Regression coverage for v4 harness. Preserve behavior, layout, and interaction
// expectations.

import 'package:cameo/components/auth_scaffold.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

import '../../navigation/app_harness.dart';

export '../../navigation/app_harness.dart';

const double kTol = 0.01;

Future<void> pumpFrames(WidgetTester tester, Duration duration) async {
  var t = Duration.zero;
  while (t < duration) {
    await tester.pump(kFrame);
    t += kFrame;
  }
}

Rect rectOf(WidgetTester tester, Finder finder) => tester.getRect(finder);

void expectRect(Rect actual, Rect expected, {double tol = kTol}) {
  expect(actual.left, closeTo(expected.left, tol), reason: 'left $actual');
  expect(actual.top, closeTo(expected.top, tol), reason: 'top $actual');
  expect(actual.width, closeTo(expected.width, tol), reason: 'width $actual');
  expect(
    actual.height,
    closeTo(expected.height, tol),
    reason: 'height $actual',
  );
}

double entranceOf(WidgetTester tester, Finder child) => tester
    .state<AuthEntranceState>(
      find.ancestor(of: child, matching: find.byType(AuthEntrance)).first,
    )
    .progress;

void expectGlassNeverFaded(WidgetTester tester) {
  for (final e in find.byType(LiquidGlass, skipOffstage: false).evaluate()) {
    e.visitAncestorElements((a) {
      final w = a.widget;
      if (w is Opacity) {
        expect(w.opacity, 1, reason: 'Liquid Glass 조상 Opacity');
      }
      if (w is FadeTransition) {
        expect(w.opacity.value, 1, reason: 'Liquid Glass 조상 FadeTransition');
      }
      return true;
    });
  }
}

List<String> mockPlatformChannel(WidgetTester tester) {
  final copied = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'Clipboard.setData') {
        copied.add((call.arguments as Map)['text'] as String);
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return copied;
}
