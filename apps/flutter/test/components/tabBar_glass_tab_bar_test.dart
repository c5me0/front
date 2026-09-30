// ignore_for_file: file_names
// Regression coverage for tabBar glass tab bar. Preserve behavior, layout, and
// interaction expectations.

import 'package:cameo/components/glass_tab_bar.dart';
import 'package:cameo/design_system/design_system.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const Size _screen = Size(393, 852);

Finder _key(String k) => find.byKey(ValueKey(k));

Future<void> _pump(
  WidgetTester tester, {
  required int selectedIndex,
  ValueChanged<int>? onSelect,
  bool disableAnimations = false,
  Size size = _screen,
  VoidCallback? onBackgroundTap,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: size, disableAnimations: disableAnimations),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                key: const ValueKey('background'),
                behavior: HitTestBehavior.opaque,
                onTap: onBackgroundTap,
              ),
            ),
            GlassTabBar(selectedIndex: selectedIndex, onSelect: onSelect),
          ],
        ),
      ),
    ),
  );
}

Rect _figmaTab(int i) => Rect.fromLTWH(20 + i * 118.0, 766, 117, 46);

void _expectRect(Rect actual, Rect expected) {
  expect(actual.left, moreOrLessEquals(expected.left, epsilon: 1e-6));
  expect(actual.top, moreOrLessEquals(expected.top, epsilon: 1e-6));
  expect(actual.width, moreOrLessEquals(expected.width, epsilon: 1e-6));
  expect(actual.height, moreOrLessEquals(expected.height, epsilon: 1e-6));
}

void main() {
  group('GlassTabBar — Figma 2001:1375 레이아웃 (393 x 852)', () {
    testWidgets('컨테이너 393x106 @ top 746 = 852 − 106 (pt16 · pb36)', (
      tester,
    ) async {
      await _pump(tester, selectedIndex: 0);
      _expectRect(
        tester.getRect(_key('glassTabBar.container')),
        const Rect.fromLTWH(0, 746, 393, 106),
      );
      expect(
        CameoLayout.tabBarContainerPaddingTop +
            CameoLayout.tabBarPillHeight +
            CameoLayout.tabBarContainerPaddingBottom,
        CameoLayout.tabBarContainerHeight,
      );
    });

    testWidgets('pill 361x54 @ (16, 762) — 54 = 4 + 46 + 4', (tester) async {
      await _pump(tester, selectedIndex: 0);
      _expectRect(
        tester.getRect(_key('glassTabBar.pill')),
        const Rect.fromLTWH(16, 762, 361, 54),
      );
      final pill = tester.widget<GlassSurface>(find.byType(GlassSurface));
      expect(pill.effect, GlassEffect.glass);
      expect(pill.blur, CameoBlur.glassTabBar);
      expect(pill.tint, CameoColors.glassTintTabBar);
      expect(pill.borderWidth, 0);
      expect(pill.radius, CameoRadius.full);
    });

    testWidgets('탭 3개 117x46, pill 안 x 4 · 122 · 240 (gap 1)', (tester) async {
      await _pump(tester, selectedIndex: 0);
      for (var i = 0; i < 3; i++) {
        _expectRect(tester.getRect(_key('glassTabBar.tab.$i')), _figmaTab(i));
      }
      final pillLeft = tester.getTopLeft(_key('glassTabBar.pill')).dx;
      expect(
        [
          for (var i = 0; i < 3; i++)
            tester.getTopLeft(_key('glassTabBar.tab.$i')).dx - pillLeft,
        ],
        [4, 122, 240],
      );
    });

    testWidgets('아이콘 22 (phone-filled · settings-filled, icon/on-dark), 탭 중앙', (
      tester,
    ) async {
      await _pump(tester, selectedIndex: 0);
      final icons = tester
          .widgetList<CameoIcon>(find.byType(CameoIcon))
          .toList();
      expect(icons.map((i) => i.name), [
        CameoIconName.phoneFilled,
        CameoIconName.settingsFilled,
      ]);
      for (final icon in icons) {
        expect(icon.size, 22);
        expect(icon.color, CameoColors.iconOnDark);
      }
      for (var i = 0; i < 2; i++) {
        final rect = tester.getRect(find.byType(CameoIcon).at(i));
        _expectRect(
          rect,
          Rect.fromLTWH(
            _figmaTab(i + 1).left + 47.5,
            _figmaTab(i + 1).top + 12,
            22,
            22,
          ),
        );
      }
    });

    testWidgets('아바타 17 원형 — 22 박스 안 (3,3) = 중앙 + 0.5', (tester) async {
      await _pump(tester, selectedIndex: 0);
      final box = _figmaTab(0);
      _expectRect(
        tester.getRect(_key('glassTabBar.avatar')),
        Rect.fromLTWH(box.left + 47.5 + 3, box.top + 12 + 3, 17, 17),
      );
    });

    testWidgets('선택 배경 = 선택 탭 rect (117x46, tab-bar/selected, r999)', (
      tester,
    ) async {
      await _pump(tester, selectedIndex: 1);
      _expectRect(tester.getRect(_key('glassTabBar.indicator')), _figmaTab(1));
      final box = tester.widget<DecoratedBox>(_key('glassTabBar.indicator'));
      final deco = box.decoration as BoxDecoration;
      expect(deco.color, CameoColors.tabBarSelected);
      expect(
        deco.borderRadius,
        const BorderRadius.all(Radius.circular(CameoLayout.tabBarTabRadius)),
      );
    });

    testWidgets('폭 430 에서도 flex 1: 탭 폭 = (430 − 32 − 8 − 2) / 3', (
      tester,
    ) async {
      await _pump(tester, selectedIndex: 2, size: const Size(430, 932));
      const w = (430 - 32 - 8 - 2) / 3;
      _expectRect(
        tester.getRect(_key('glassTabBar.tab.2')),
        const Rect.fromLTWH(20 + 2 * (w + 1), 932 - 106 + 20, w, 46),
      );
      _expectRect(
        tester.getRect(_key('glassTabBar.indicator')),
        tester.getRect(_key('glassTabBar.tab.2')),
      );
    });
  });

  group('GlassTabBar — 인터랙션 · 모션', () {
    testWidgets('탭 누름 → onSelect(index) (제어 컴포넌트: 선택은 부모가 바꾼다)', (
      tester,
    ) async {
      final taps = <int>[];
      await _pump(tester, selectedIndex: 0, onSelect: taps.add);
      await tester.tap(_key('glassTabBar.tab.2'));
      await tester.pumpAndSettle();
      await tester.tap(_key('glassTabBar.tab.1'));
      await tester.pumpAndSettle();
      expect(taps, [2, 1]);

      _expectRect(tester.getRect(_key('glassTabBar.indicator')), _figmaTab(0));
    });

    testWidgets('선택 변경 → snap 스프링 이동 + 가로 늘어남(면적 보존) → 목표 탭에 정착', (
      tester,
    ) async {
      await _pump(tester, selectedIndex: 0);
      await _pump(tester, selectedIndex: 2);
      var maxSx = 1.0;
      var moved = false;
      for (var f = 0; f < 12; f++) {
        await tester.pump(const Duration(milliseconds: 16));
        final r = tester.getRect(_key('glassTabBar.indicator'));
        final sx = r.width / 117;
        final sy = r.height / 46;
        expect(sx * sy, moreOrLessEquals(1, epsilon: 1e-9));
        expect(
          sx,
          lessThanOrEqualTo(CameoMotion.tabIndicatorStretchMax + 1e-9),
        );
        if (sx > maxSx) maxSx = sx;
        if (r.center.dx > _figmaTab(0).center.dx) moved = true;
      }
      expect(moved, isTrue);
      expect(maxSx, greaterThan(1.1));
      await tester.pumpAndSettle();
      _expectRect(tester.getRect(_key('glassTabBar.indicator')), _figmaTab(2));
    });

    testWidgets('이동 중 재선택 → 현재 위치에서 새 목표로 이어서 정착', (tester) async {
      await _pump(tester, selectedIndex: 0);
      await _pump(tester, selectedIndex: 2);
      await tester.pump(const Duration(milliseconds: 48));
      await _pump(tester, selectedIndex: 1);
      await tester.pumpAndSettle();
      _expectRect(tester.getRect(_key('glassTabBar.indicator')), _figmaTab(1));
    });

    testWidgets('모션 감소 → 스프링 없이 즉시 이동 (늘어남 없음)', (tester) async {
      await _pump(tester, selectedIndex: 0, disableAnimations: true);
      await _pump(tester, selectedIndex: 1, disableAnimations: true);
      _expectRect(tester.getRect(_key('glassTabBar.indicator')), _figmaTab(1));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('이동 중 언마운트 → 예외·남은 프레임 없음 (컨트롤러 dispose)', (tester) async {
      await _pump(tester, selectedIndex: 0);
      await _pump(tester, selectedIndex: 2);
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('폭 0 (첫 프레임 등) → 예외 없음, 탭 폭 0 으로 클램프', (tester) async {
      await _pump(tester, selectedIndex: 2, size: Size.zero);
      expect(tester.takeException(), isNull);
      expect(tester.getSize(_key('glassTabBar.indicator')).width, 0);
    });

    testWidgets('pill 위 여백(pt16)은 터치를 아래로 통과시킨다', (tester) async {
      var background = 0;
      await _pump(
        tester,
        selectedIndex: 0,
        onBackgroundTap: () => background++,
      );
      await tester.tapAt(const Offset(196.5, 746 + 8));
      expect(background, 1);
    });
  });

  group('GlassTabBar — 접근성', () {
    testWidgets('탭 역할 · 한국어 라벨 · 선택 상태', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, selectedIndex: 1, onSelect: (_) {});
      for (var i = 0; i < 3; i++) {
        final node = tester.getSemantics(
          find.bySemanticsLabel(glassTabBarLabels[i]),
        );
        final data = node.getSemanticsData();
        expect(data.role, SemanticsRole.tab);
        expect(data.flagsCollection.isSelected, i == 1);
        expect(data.hasAction(SemanticsAction.tap), isTrue);
      }
      expect(glassTabBarLabels, ['앨범', '통화', '설정']);
      handle.dispose();
    });

    testWidgets('onSelect 없음 → 탭 비활성 (탭 액션 없음)', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, selectedIndex: 0);
      for (var i = 0; i < 3; i++) {
        final data = tester
            .getSemantics(find.bySemanticsLabel(glassTabBarLabels[i]))
            .getSemanticsData();
        expect(data.role, SemanticsRole.tab);
        expect(data.flagsCollection.hasEnabledState, isTrue);
        expect(data.flagsCollection.isEnabled, isFalse);
        expect(data.hasAction(SemanticsAction.tap), isFalse);
      }
      handle.dispose();
    });
  });
}
