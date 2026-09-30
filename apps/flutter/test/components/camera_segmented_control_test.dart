// Regression coverage for camera segmented control. Preserve behavior, layout, and
// interaction expectations.

import 'package:cameo/components/segmented_control.dart';
import 'package:cameo/content/lab.g.dart';
import 'package:cameo/design_system/design_system.dart';
import 'package:cameo/navigation/navigation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const Duration _frame = Duration(milliseconds: 16);

final List<SegmentedControlItem<CameraModeId>> _items = [
  for (final m in labCamera.modes)
    SegmentedControlItem(id: m.id, label: m.label),
];

Future<void> _pump(
  WidgetTester tester, {
  required CameraModeId selected,
  ValueChanged<CameraModeId>? onChanged,
  bool disableAnimations = false,
}) {
  return tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SegmentedControl<CameraModeId>(
            items: _items,
            selected: selected,
            onChanged: onChanged,
          ),
        ),
      ),
    ),
  );
}

Future<void> _run(WidgetTester tester, Duration total) async {
  for (var i = 0; i < total.inMicroseconds ~/ _frame.inMicroseconds; i++) {
    await tester.pump(_frame);
  }
}

void _expectRect(Rect actual, Rect expected, {double eps = 1e-6}) {
  expect(actual.left, moreOrLessEquals(expected.left, epsilon: eps));
  expect(actual.top, moreOrLessEquals(expected.top, epsilon: eps));
  expect(actual.width, moreOrLessEquals(expected.width, epsilon: eps));
  expect(actual.height, moreOrLessEquals(expected.height, epsilon: eps));
}

Color? _labelColor(WidgetTester tester, String label) =>
    tester.widget<CameoText>(find.widgetWithText(CameoText, label)).color;

void main() {
  group('SegmentedControl — Figma 2056:3393 레이아웃', () {
    testWidgets('컨테이너 160x56 = 1 + 4 + 73 + 4 + 73 + 4 + 1 · 글래스 역할', (
      tester,
    ) async {
      await _pump(tester, selected: CameraModeId.photo);
      _expectRect(
        tester.getRect(find.byType(SegmentedControl<CameraModeId>)),
        const Rect.fromLTWH(0, 0, 160, 56),
      );
      final surface = tester.widget<GlassSurface>(find.byType(GlassSurface));
      expect(surface.blur, CameoBlur.glassNav);
      expect(surface.tint, CameoColors.glassTint);
      expect(surface.border, CameoColors.strokeNeutralBase);
      expect(surface.borderWidth, 1);
    });

    testWidgets('세그먼트 73x46 @ (5,5) · (82,5) — 선택 pill = 사진 자리', (
      tester,
    ) async {
      await _pump(tester, selected: CameraModeId.photo);
      _expectRect(
        tester.getRect(find.byKey(SegmentedControl.segmentKey(0))),
        const Rect.fromLTWH(5, 5, 73, 46),
      );
      _expectRect(
        tester.getRect(find.byKey(SegmentedControl.segmentKey(1))),
        const Rect.fromLTWH(82, 5, 73, 46),
      );
      _expectRect(
        tester.getRect(find.byKey(SegmentedControl.pillKey)),
        const Rect.fromLTWH(5, 5, 73, 46),
      );
      final pill = tester.widget<DecoratedBox>(
        find.byKey(SegmentedControl.pillKey),
      );
      expect(
        (pill.decoration as ShapeDecoration).color,
        CameoColors.backgroundCanvasBase,
      );
    });

    testWidgets(
      '라벨: 활성 foreground/neutral/base · 비활성 inverse/subtle, bodyLg 22',
      (tester) async {
        await _pump(tester, selected: CameraModeId.photo);
        expect(_labelColor(tester, '사진'), CameoColors.foregroundNeutralBase);
        expect(
          _labelColor(tester, '동영상'),
          CameoColors.foregroundNeutralInverseSubtle,
        );
        expect(
          tester.getSize(find.widgetWithText(CameoText, '사진')).height,
          moreOrLessEquals(CameoLayout.segmentedControlLabelHeight),
        );
      },
    );
  });

  group('SegmentedControl — 동작', () {
    testWidgets('탭 → onChanged(id) 만 (제어 컴포넌트)', (tester) async {
      final taps = <CameraModeId>[];
      await _pump(tester, selected: CameraModeId.photo, onChanged: taps.add);
      await tester.tap(find.byKey(SegmentedControl.segmentKey(1)));
      await tester.pump();
      expect(taps, [CameraModeId.video]);
      _expectRect(
        tester.getRect(find.byKey(SegmentedControl.pillKey)),
        const Rect.fromLTWH(5, 5, 73, 46),
      );
    });

    testWidgets('selected 변경 → pill 이 snap 스프링으로 77 이동 (도중 늘어남) · 라벨 색 교대', (
      tester,
    ) async {
      await _pump(tester, selected: CameraModeId.photo);
      await _pump(tester, selected: CameraModeId.video);
      await _run(tester, const Duration(milliseconds: 64));
      final moving = tester.getRect(find.byKey(SegmentedControl.pillKey));
      expect(moving.center.dx, greaterThan(5 + 73 / 2));
      expect(moving.center.dx, lessThan(82 + 73 / 2));

      expect(moving.width, greaterThan(73));

      await _run(tester, springSettleDuration(CameoMotion.tabIndicatorSpring));
      await tester.pumpAndSettle();
      _expectRect(
        tester.getRect(find.byKey(SegmentedControl.pillKey)),
        const Rect.fromLTWH(82, 5, 73, 46),
      );
      expect(_labelColor(tester, '동영상'), CameoColors.foregroundNeutralBase);
      expect(
        _labelColor(tester, '사진'),
        CameoColors.foregroundNeutralInverseSubtle,
      );
    });

    testWidgets('모션 감소 → 즉시 이동', (tester) async {
      await _pump(
        tester,
        selected: CameraModeId.photo,
        disableAnimations: true,
      );
      await _pump(
        tester,
        selected: CameraModeId.video,
        disableAnimations: true,
      );
      await tester.pump();
      _expectRect(
        tester.getRect(find.byKey(SegmentedControl.pillKey)),
        const Rect.fromLTWH(82, 5, 73, 46),
      );
    });

    test('segmentLabelColor — pill 과의 거리로 보간 (RN interpolateColor)', () {
      const p = CameoPalette.light;
      expect(
        segmentLabelColor(p, position: 0, index: 0),
        p.foregroundNeutralBase,
      );
      expect(
        segmentLabelColor(p, position: 0, index: 1),
        p.foregroundNeutralInverseSubtle,
      );
      expect(
        segmentLabelColor(p, position: 0.5, index: 1),
        Color.lerp(
          p.foregroundNeutralInverseSubtle,
          p.foregroundNeutralBase,
          0.5,
        ),
      );
    });
  });
}
