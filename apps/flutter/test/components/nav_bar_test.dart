// Regression coverage for nav bar. Preserve behavior, layout, and interaction
// expectations.

import 'package:cameo/components/nav_bar.dart';
import 'package:cameo/design_system/design_system.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

Widget _host(
  Widget navBar, {
  double safeTop = 0,
  bool disableAnimations = false,
  VoidCallback? onBackgroundTap,
}) {
  return MediaQuery(
    data: MediaQueryData(
      size: const Size(393, 852),
      padding: EdgeInsets.only(top: safeTop),
      disableAnimations: disableAnimations,
    ),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onBackgroundTap,
          ),
          navBar,
        ],
      ),
    ),
  );
}

void _screen(WidgetTester tester) {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

const _back = NavLeading(
  icon: CameoIconName.chevronLeft,
  accessibilityLabel: '뒤로',
);
const _close = NavLeading(
  icon: CameoIconName.chevronDown,
  accessibilityLabel: '닫기',
);

List<NavAction> _heartHistory({bool? liked, VoidCallback? onLike}) => [
  NavAction(
    icon: CameoIconName.heart,
    activeIcon: CameoIconName.heartFilled,
    active: liked,
    onPress: onLike,
    accessibilityLabel: '좋아요',
  ),
  const NavAction(icon: CameoIconName.history, accessibilityLabel: '기록'),
];

const _moonFocus = [
  NavAction(
    icon: CameoIconName.moon,
    activeIcon: CameoIconName.moonFilled,
    active: false,
    accessibilityLabel: '취침 모드',
  ),
  NavAction(icon: CameoIconName.focus, accessibilityLabel: '포커스'),
];

Finder get _row =>
    find.descendant(of: find.byType(NavBar), matching: find.byType(Row)).first;
Finder get _circles => find.byType(GlassIconButton);
Finder get _pill => find.byType(GlassIconButtonGroup);
Finder get _pillItems =>
    find.descendant(of: _pill, matching: find.byType(GlassPressable));
Finder get _surfaces => find.descendant(
  of: find.byType(NavBar),
  matching: find.byType(GlassSurface),
);
Finder get _icons =>
    find.descendant(of: find.byType(NavBar), matching: find.byType(CameoIcon));

Finder _toggle(CameoIconName icon) =>
    find.byWidgetPredicate((w) => w is ToggleIcon && w.icon == icon);

Finder _pressable(CameoIconName icon) => find
    .ancestor(of: _toggle(icon), matching: find.byType(GlassPressable))
    .first;

const _atRest = 1.0;

double _scaleOf(WidgetTester tester, CameoIconName icon) => tester
    .widget<ScaleTransition>(
      find.descendant(
        of: _toggle(icon),
        matching: find.byType(ScaleTransition),
      ),
    )
    .scale
    .value;

CameoIconName _shownIcon(WidgetTester tester, CameoIconName icon) => tester
    .widget<CameoIcon>(
      find.descendant(of: _toggle(icon), matching: find.byType(CameoIcon)),
    )
    .name;

void main() {
  group(
    'regular (layout.navBar · 2028:569 / 2042:3234 / 2042:3074 / 2042:2430)',
    () {
      testWidgets('393 폭: 행 361×56 @ y62 · 원형 56 · pill 106×56 · 항목 46', (
        tester,
      ) async {
        _screen(tester);
        await tester.pumpWidget(
          _host(NavBar(leading: _back, actions: _heartHistory())),
        );

        expect(tester.getRect(_row), const Rect.fromLTWH(16, 62, 361, 56));

        expect(
          tester.getRect(_circles.first),
          const Rect.fromLTWH(16, 62, 56, 56),
        );
        // pill 2028:572 at (271, 62): 106 = 1 + 4 + 46 + 4 + 46 + 4 + 1
        expect(tester.getRect(_pill), const Rect.fromLTWH(271, 62, 106, 56));
        expect(tester.getSize(_pill).width, CameoLayout.navBarActionPillWidth);

        expect(_pillItems, findsNWidgets(2));
        expect(
          tester.getRect(_pillItems.at(0)),
          const Rect.fromLTWH(276, 67, 46, 46),
        );
        expect(
          tester.getRect(_pillItems.at(1)),
          const Rect.fromLTWH(326, 67, 46, 46),
        );

        expect(
          tester.getRect(_icons.at(0)),
          const Rect.fromLTWH(33, 79, 22, 22),
        );
        expect(
          tester.getRect(_icons.at(1)),
          const Rect.fromLTWH(288, 79, 22, 22),
        );
        expect(
          tester.getRect(_icons.at(2)),
          const Rect.fromLTWH(338, 79, 22, 22),
        );
      });

      testWidgets(
        'dark 톤: glass/tint + glass/border 1 · glassNav · icon/on-dark',
        (tester) async {
          _screen(tester);
          await tester.pumpWidget(
            _host(NavBar(leading: _back, actions: _heartHistory())),
          );
          final surfaces = tester.widgetList<GlassSurface>(_surfaces).toList();
          expect(surfaces, hasLength(2));
          for (final s in surfaces) {
            expect(s.effect, GlassEffect.glass);
            expect(s.blur, CameoBlur.glassNav);
            expect(s.tint, CameoColors.glassTint);
            expect(s.border, CameoColors.glassBorder);
            expect(s.borderWidth, CameoLayout.navBarCircleButtonBorderWidth);
            expect(s.radius, CameoLayout.navBarCircleButtonRadius);
          }
          for (final i in tester.widgetList<CameoIcon>(_icons)) {
            expect(i.color, CameoColors.iconOnDark);
            expect(i.size, CameoLayout.navBarActionItemIconSize);
          }
        },
      );

      testWidgets(
        'light 톤 (구 16-13, 호환): background/neutral/subtle + stroke/neutral/base · 어두운 아이콘',
        (tester) async {
          _screen(tester);
          await tester.pumpWidget(
            _host(
              NavBar(
                tone: GlassNavTone.light,
                leading: _back,
                actions: _heartHistory(),
              ),
            ),
          );
          expect(
            tester.getRect(_circles.first),
            const Rect.fromLTWH(16, 62, 56, 56),
          );
          expect(tester.getRect(_pill), const Rect.fromLTWH(271, 62, 106, 56));
          for (final s in tester.widgetList<GlassSurface>(_surfaces)) {
            expect(s.tint, CameoColors.backgroundNeutralSubtle);
            expect(s.border, CameoColors.strokeNeutralBase);
            expect(s.borderWidth, CameoLayout.navBarActionPillBorderWidth);
          }
          for (final i in tester.widgetList<CameoIcon>(_icons)) {
            expect(i.color, CameoColors.foregroundNeutralBase);
          }
        },
      );

      testWidgets('통화 (2042:2430): chevron-down 56 + moon/focus pill 106', (
        tester,
      ) async {
        _screen(tester);
        await tester.pumpWidget(
          _host(const NavBar(leading: _close, actions: _moonFocus)),
        );
        expect(
          tester.widget<GlassIconButton>(_circles.first).icon,
          CameoIconName.chevronDown,
        );
        expect(
          tester.getRect(_circles.first),
          const Rect.fromLTWH(16, 62, 56, 56),
        );
        expect(tester.getRect(_pill), const Rect.fromLTWH(271, 62, 106, 56));
        expect(_shownIcon(tester, CameoIconName.moon), CameoIconName.moon);
      });
    },
  );

  group('borderless (layout.navBarBorderless · 2042:3234, 16-13 v3)', () {
    testWidgets(
      '행 361×54 @ y62 · 원형 54 p16 · pill 104×54 @ x273 · 항목 (4,4)/(54,4) · bottom 116',
      (tester) async {
        _screen(tester);
        await tester.pumpWidget(
          _host(
            NavBar(
              variant: GlassNavVariant.borderless,
              leading: _back,
              actions: _heartHistory(),
            ),
          ),
        );
        expect(tester.getRect(_row), const Rect.fromLTWH(16, 62, 361, 54));

        expect(
          tester.getRect(_circles.first),
          const Rect.fromLTWH(16, 62, 54, 54),
        );
        expect(
          tester.getRect(_icons.at(0)),
          const Rect.fromLTWH(32, 78, 22, 22),
        );

        expect(tester.getRect(_pill), const Rect.fromLTWH(273, 62, 104, 54));
        expect(
          tester.getRect(_pillItems.at(0)),
          const Rect.fromLTWH(277, 66, 46, 46),
        );
        expect(
          tester.getRect(_pillItems.at(1)),
          const Rect.fromLTWH(327, 66, 46, 46),
        );
        expect(
          tester.getRect(_icons.at(1)),
          const Rect.fromLTWH(289, 78, 22, 22),
        );
        expect(
          tester.getRect(_icons.at(2)),
          const Rect.fromLTWH(339, 78, 22, 22),
        );
        expect(navBarFrame(variant: GlassNavVariant.borderless), (
          top: 62.0,
          height: 54.0,
          bottom: 116.0,
        ));
        expect(
          navBarFrame(variant: GlassNavVariant.borderless).bottom,
          CameoLayout.navBarBorderlessTopAreaHeight,
        );
      },
    );

    testWidgets(
      'dark 모드: background/neutral/base 채움 · 테두리 없음 · Liquid Glass glassNav (G1) · foreground/neutral/base 아이콘 (tone 무시)',
      (tester) async {
        _screen(tester);
        await tester.pumpWidget(
          CameoTheme(
            mode: CameoColorMode.dark,
            child: _host(
              NavBar(
                variant: GlassNavVariant.borderless,
                tone: GlassNavTone.light,
                leading: _back,
                actions: _heartHistory(),
              ),
            ),
          ),
        );
        final surfaces = tester.widgetList<GlassSurface>(_surfaces).toList();
        expect(surfaces, hasLength(2));
        for (final s in surfaces) {
          expect(s.effect, GlassEffect.glass);
          expect(s.blur, CameoBlur.glassNav);
          expect(s.blur!.material, CameoBlurMaterial.glass);
          expect(s.tint, CameoColorsDark.backgroundNeutralBase);
          expect(s.border, isNull);
          expect(s.borderWidth, 0);
        }

        expect(
          find.descendant(
            of: find.byType(NavBar),
            matching: find.byType(LiquidGlass),
          ),
          findsNWidgets(2),
        );
        expect(
          find.descendant(
            of: find.byType(NavBar),
            matching: find.byType(BackdropFilter),
          ),
          findsNothing,
        );
        for (final i in tester.widgetList<CameoIcon>(_icons)) {
          expect(i.color, CameoColorsDark.foregroundNeutralBase);
          expect(i.size, CameoLayout.navBarBorderlessActionItemIconSize);
        }
      },
    );
  });

  testWidgets(
    'camera 톤 (16-14 2056:3347): 원형 56 · glass/tint + stroke/neutral/base 1 · foreground/neutral/inverse/base',
    (tester) async {
      _screen(tester);
      await tester.pumpWidget(
        _host(const NavBar(tone: GlassNavTone.camera, leading: _close)),
      );
      expect(
        tester.getRect(_circles.first),
        const Rect.fromLTWH(16, 62, 56, 56),
      );
      final s = tester.widget<GlassSurface>(_surfaces.first);
      expect(s.tint, CameoColors.glassTint);
      expect(s.border, CameoColors.strokeNeutralBase);
      expect(s.borderWidth, CameoLayout.navBarCircleButtonBorderWidth);
      expect(
        tester.widget<CameoIcon>(_icons.first).color,
        CameoColors.foregroundNeutralInverseBase,
      );
    },
  );

  group('compact (layout.navBarCompact · 2001:1174)', () {
    testWidgets('행 361×46 · 원형 46 p12 · pill 92×46 p0 · 테두리 없음', (
      tester,
    ) async {
      _screen(tester);
      await tester.pumpWidget(
        _host(
          const NavBar(
            variant: GlassNavVariant.compact,
            leading: _back,
            actions: [
              NavAction(icon: CameoIconName.star, accessibilityLabel: '즐겨찾기'),
              NavAction(icon: CameoIconName.dots, accessibilityLabel: '더보기'),
            ],
          ),
        ),
      );
      expect(tester.getRect(_row), const Rect.fromLTWH(16, 62, 361, 46));
      // 2001:1175 (16,62)–(62,108)
      expect(
        tester.getRect(_circles.first),
        const Rect.fromLTWH(16, 62, 46, 46),
      );
      // 2001:1177 (285,62)–(377,108), star 285..331 · dots 331..377
      expect(tester.getRect(_pill), const Rect.fromLTWH(285, 62, 92, 46));
      expect(
        tester.getSize(_pill).width,
        CameoLayout.navBarCompactActionPillWidth,
      );
      expect(
        tester.getRect(_pillItems.at(0)),
        const Rect.fromLTWH(285, 62, 46, 46),
      );
      expect(
        tester.getRect(_pillItems.at(1)),
        const Rect.fromLTWH(331, 62, 46, 46),
      );

      expect(tester.getRect(_icons.at(0)), const Rect.fromLTWH(28, 74, 22, 22));
      for (final s in tester.widgetList<GlassSurface>(_surfaces)) {
        expect(s.blur, CameoBlur.glassNav);
        expect(s.tint, CameoColors.glassTintCompact);
        expect(s.border, isNull);
        expect(s.borderWidth, CameoLayout.navBarCompactCircleButtonBorderWidth);
      }
      for (final i in tester.widgetList<CameoIcon>(_icons)) {
        expect(i.color, CameoColors.iconOnDarkMuted);
      }
    });
  });

  group('v1 (layout.navBarV1 · 2018:2077)', () {
    testWidgets(
      '행 66 = 8 + 50 + 8 @ y62 · 원형 50 p14 · 오른쪽 50 두 개 gap 12 · glassFigma',
      (tester) async {
        _screen(tester);
        await tester.pumpWidget(
          _host(
            const NavBar(
              variant: GlassNavVariant.v1,
              leading: _close,
              actions: _moonFocus,
            ),
          ),
        );
        final bar = find
            .descendant(of: find.byType(NavBar), matching: find.byType(Padding))
            .first;
        expect(tester.getRect(bar), const Rect.fromLTWH(0, 62, 393, 66));
        expect(tester.getRect(_row), const Rect.fromLTWH(16, 70, 361, 50));
        expect(_pill, findsNothing);
        expect(_circles, findsNWidgets(3));
        // 2018:2078 x 16–66 y 70–120 · 2018:2081 x 265–315 · 2018:2085 x 327–377
        expect(
          tester.getRect(_circles.at(0)),
          const Rect.fromLTWH(16, 70, 50, 50),
        );
        expect(
          tester.getRect(_circles.at(1)),
          const Rect.fromLTWH(265, 70, 50, 50),
        );
        expect(
          tester.getRect(_circles.at(2)),
          const Rect.fromLTWH(327, 70, 50, 50),
        );

        expect(
          tester.getRect(_circles.at(2)).right -
              tester.getRect(_circles.at(1)).left,
          CameoLayout.navBarV1CircleButtonSize * 2 +
              CameoLayout.navBarV1RightGroupGap,
        );

        expect(
          tester.getRect(_icons.at(0)),
          const Rect.fromLTWH(30, 84, 22, 22),
        );
        final surfaces = tester.widgetList<GlassSurface>(_surfaces).toList();
        expect(surfaces, hasLength(3));
        for (final s in surfaces) {
          expect(s.blur, CameoBlur.glassFigma);
          expect(s.tint, CameoColors.glassTintV1);
          expect(s.border, isNull);
          expect(s.borderWidth, CameoLayout.navBarV1CircleButtonBorderWidth);
        }
        for (final i in tester.widgetList<CameoIcon>(_icons)) {
          expect(i.color, CameoColors.foregroundNeutralInverseBase);
        }
      },
    );
  });

  group('배치 — top = max(안전 영역, 62)', () {
    test('navBarFrame: 인셋 0/59 → 62, 인셋 80 → 80 · bottom = top + 높이', () {
      expect(navBarFrame(), (top: 62.0, height: 56.0, bottom: 118.0));
      expect(navBarFrame().bottom, CameoLayout.screenTopAreaHeight);
      expect(navBarFrame(safeAreaTop: 59).top, CameoLayout.navBarTop);
      expect(
        navBarFrame(variant: GlassNavVariant.compact).top,
        CameoLayout.navBarCompactTop,
      );
      expect(navBarFrame(safeAreaTop: 80), (
        top: 80.0,
        height: 56.0,
        bottom: 136.0,
      ));
      expect(navBarFrame(variant: GlassNavVariant.compact), (
        top: 62.0,
        height: 46.0,
        bottom: 108.0,
      ));
      expect(navBarFrame(variant: GlassNavVariant.v1), (
        top: 62.0,
        height: 66.0,
        bottom: 128.0,
      ));
      expect(
        navBarFrame(variant: GlassNavVariant.v1).top,
        CameoLayout.navBarV1Top,
      );

      const aliased = NavBar(
        variant: NavBarVariant.compact,
        tone: NavBarTone.light,
        leading: _back,
      );
      expect(aliased.variant, GlassNavVariant.compact);
      expect(aliased.tone, GlassNavTone.light);
    });

    testWidgets('iPhone 16 인셋 59 → y62, 큰 인셋 80 → y80', (tester) async {
      _screen(tester);
      await tester.pumpWidget(
        _host(NavBar(leading: _back, actions: _heartHistory()), safeTop: 59),
      );
      expect(tester.getTopLeft(_circles.first), const Offset(16, 62));
      await tester.pumpWidget(
        _host(NavBar(leading: _back, actions: _heartHistory()), safeTop: 80),
      );
      expect(tester.getTopLeft(_circles.first), const Offset(16, 80));
      await tester.pumpWidget(
        _host(
          const NavBar(
            variant: GlassNavVariant.v1,
            leading: _close,
            actions: _moonFocus,
          ),
          safeTop: 80,
        ),
      );
      expect(tester.getTopLeft(_circles.first), const Offset(16, 88));
    });

    testWidgets('버튼 사이 빈 곳은 터치를 아래로 통과시킨다', (tester) async {
      _screen(tester);
      var backgroundTaps = 0;
      var backTaps = 0;
      await tester.pumpWidget(
        _host(
          NavBar(
            leading: NavLeading(
              icon: CameoIconName.chevronLeft,
              onPress: () => backTaps++,
              accessibilityLabel: '뒤로',
            ),
            actions: _heartHistory(),
          ),
          onBackgroundTap: () => backgroundTaps++,
        ),
      );
      await tester.tapAt(const Offset(196, 90));
      await tester.pumpAndSettle();
      expect(backgroundTaps, 1);
      await tester.tapAt(const Offset(44, 90));
      await tester.pumpAndSettle();
      expect(backTaps, 1);
      expect(backgroundTaps, 1);
    });

    testWidgets('v1: 오른쪽 원형 사이 gap 12 도 터치 통과 (RN box-none 과 동일)', (
      tester,
    ) async {
      _screen(tester);
      var backgroundTaps = 0;
      await tester.pumpWidget(
        _host(
          const NavBar(
            variant: GlassNavVariant.v1,
            leading: _close,
            actions: _moonFocus,
          ),
          onBackgroundTap: () => backgroundTaps++,
        ),
      );

      final gapX =
          (tester.getRect(_circles.at(1)).right +
              tester.getRect(_circles.at(2)).left) /
          2;
      await tester.tapAt(Offset(gapX, 95));
      await tester.pumpAndSettle();
      expect(backgroundTaps, 1);
    });
  });

  group('토글 — motion.heartPop', () {
    test(
      'springImpulse: bouncy 는 t* 에서 정확히 overshootScale, press 는 pressScale',
      () {
        for (final (spring, peak) in [
          (CameoMotion.heartPopSpring, CameoMotion.heartPopOvershootScale),
          (CameoSprings.press, CameoMotion.pressScale),
        ]) {
          final k = springImpulse(spring, peak);
          final sim = SpringSimulation(spring, 1, 1, k.velocity);
          final t = k.peak.inMicroseconds / Duration.microsecondsPerSecond;
          expect(sim.x(t), closeTo(peak, 1e-6));
          expect(sim.dx(t), closeTo(0, 1e-3));
        }
        // bouncy(260/13): t* = 78.331ms, v0 = 6.7073/s · press(700/38): t* = 41.803ms, v0 = −2.3418/s
        final pop = springImpulse(
          CameoSprings.bouncy,
          CameoMotion.heartPopOvershootScale,
        );
        expect(pop.peak.inMicroseconds, closeTo(78331, 1));
        expect(pop.velocity, closeTo(6.7073, 1e-4));
        final dip = springImpulse(CameoSprings.press, CameoMotion.pressScale);
        expect(dip.peak.inMicroseconds, closeTo(41803, 1));
        expect(dip.velocity, closeTo(-2.3418, 1e-4));
      },
    );

    Widget likeable({bool disableAnimations = false}) {
      var liked = false;
      return _host(
        StatefulBuilder(
          builder: (context, setState) => NavBar(
            leading: _back,
            actions: _heartHistory(
              liked: liked,
              onLike: () => setState(() => liked = !liked),
            ),
          ),
        ),
        disableAnimations: disableAnimations,
      );
    }

    testWidgets('켜짐: 1 → 1.25(정점에서 heartFilled 교체) → 1', (tester) async {
      _screen(tester);
      await tester.pumpWidget(likeable());
      final pop = springImpulse(
        CameoMotion.heartPopSpring,
        CameoMotion.heartPopOvershootScale,
      );
      expect(_shownIcon(tester, CameoIconName.heart), CameoIconName.heart);

      await tester.tap(_pressable(CameoIconName.heart));
      await tester.pump();
      expect(_scaleOf(tester, CameoIconName.heart), 1);

      await tester.pump(pop.peak - const Duration(milliseconds: 8));
      expect(_shownIcon(tester, CameoIconName.heart), CameoIconName.heart);
      expect(_scaleOf(tester, CameoIconName.heart), greaterThan(1.2));

      await tester.pump(const Duration(milliseconds: 8)); // t = t*
      expect(
        _scaleOf(tester, CameoIconName.heart),
        closeTo(CameoMotion.heartPopOvershootScale, 1e-3),
      );
      expect(
        _shownIcon(tester, CameoIconName.heart),
        CameoIconName.heartFilled,
      );

      await tester.pumpAndSettle();
      expect(_scaleOf(tester, CameoIconName.heart), _atRest);
      expect(
        _shownIcon(tester, CameoIconName.heart),
        CameoIconName.heartFilled,
      );

      final dip = springImpulse(CameoSprings.press, CameoMotion.pressScale);
      await tester.tap(_pressable(CameoIconName.heart));
      await tester.pump();
      expect(_shownIcon(tester, CameoIconName.heart), CameoIconName.heart);
      await tester.pump(dip.peak);
      expect(
        _scaleOf(tester, CameoIconName.heart),
        closeTo(CameoMotion.pressScale, 1e-3),
      );
      await tester.pumpAndSettle();
      expect(_scaleOf(tester, CameoIconName.heart), _atRest);
    });

    testWidgets('반복 토글: 매번 정확히 1 에서 시작 → 1.25 / 0.96 극값 → 정확히 1 로 정지', (
      tester,
    ) async {
      _screen(tester);
      await tester.pumpWidget(likeable());
      final pop = springImpulse(
        CameoMotion.heartPopSpring,
        CameoMotion.heartPopOvershootScale,
      );
      final dip = springImpulse(CameoSprings.press, CameoMotion.pressScale);
      for (var i = 0; i < 3; i++) {
        for (final on in [true, false]) {
          await tester.tap(_pressable(CameoIconName.heart));
          await tester.pump();
          expect(_scaleOf(tester, CameoIconName.heart), 1);
          await tester.pump(on ? pop.peak : dip.peak);
          expect(
            _scaleOf(tester, CameoIconName.heart),
            closeTo(
              on ? CameoMotion.heartPopOvershootScale : CameoMotion.pressScale,
              1e-4,
            ),
          );
          await tester.pumpAndSettle();
          expect(_scaleOf(tester, CameoIconName.heart), _atRest);
          expect(
            _shownIcon(tester, CameoIconName.heart),
            on ? CameoIconName.heartFilled : CameoIconName.heart,
          );
        }
      }
    });

    testWidgets('연타: 정점 전에 끄면 filled 로 바뀌지 않고 1 로 복귀', (tester) async {
      _screen(tester);
      var liked = false;
      late StateSetter setOuter;
      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (context, setState) {
              setOuter = setState;
              return NavBar(
                leading: _back,
                actions: _heartHistory(liked: liked),
              );
            },
          ),
        ),
      );
      void flip() => setOuter(() => liked = !liked);
      final pop = springImpulse(
        CameoMotion.heartPopSpring,
        CameoMotion.heartPopOvershootScale,
      );

      flip();
      await tester.pump();
      await tester.pump(pop.peak ~/ 2);
      final mid = _scaleOf(tester, CameoIconName.heart);
      expect(mid, greaterThan(1));
      flip();
      await tester.pump();
      for (var t = 0; t < 20; t++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(_shownIcon(tester, CameoIconName.heart), CameoIconName.heart);
      }
      await tester.pumpAndSettle();
      expect(_scaleOf(tester, CameoIconName.heart), _atRest);
      expect(_shownIcon(tester, CameoIconName.heart), CameoIconName.heart);
      expect(tester.takeException(), isNull);
    });

    testWidgets('애니메이션 중 제거해도 예외 없음 (컨트롤러 dispose)', (tester) async {
      _screen(tester);
      await tester.pumpWidget(likeable());
      await tester.tap(_pressable(CameoIconName.heart));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));
      await tester.pumpWidget(_host(const SizedBox.shrink()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('모션 감소: 스케일 없이 즉시 교체', (tester) async {
      _screen(tester);
      await tester.pumpWidget(likeable(disableAnimations: true));
      await tester.tap(_pressable(CameoIconName.heart));
      await tester.pump();
      expect(
        _shownIcon(tester, CameoIconName.heart),
        CameoIconName.heartFilled,
      );
      expect(_scaleOf(tester, CameoIconName.heart), 1);
      await tester.pump(const Duration(milliseconds: 50));
      expect(_scaleOf(tester, CameoIconName.heart), 1);
      await tester.pumpAndSettle();
    });

    testWidgets('v1 원형도 토글 (moon → moonFilled)', (tester) async {
      _screen(tester);
      var sleep = false;
      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (context, setState) => NavBar(
              variant: GlassNavVariant.v1,
              leading: _close,
              actions: [
                NavAction(
                  icon: CameoIconName.moon,
                  activeIcon: CameoIconName.moonFilled,
                  active: sleep,
                  onPress: () => setState(() => sleep = !sleep),
                  accessibilityLabel: '취침 모드',
                ),
                const NavAction(
                  icon: CameoIconName.focus,
                  accessibilityLabel: '포커스',
                ),
              ],
            ),
          ),
        ),
      );
      await tester.tap(_pressable(CameoIconName.moon));
      await tester.pumpAndSettle();
      expect(sleep, isTrue);
      expect(_shownIcon(tester, CameoIconName.moon), CameoIconName.moonFilled);
    });
  });

  testWidgets('접근성: 한국어 라벨 · 토글은 켜짐/꺼짐', (tester) async {
    _screen(tester);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(NavBar(leading: _back, actions: _heartHistory(liked: false))),
    );
    expect(find.bySemanticsLabel('뒤로'), findsOneWidget);
    expect(find.bySemanticsLabel('좋아요, 꺼짐'), findsOneWidget);
    expect(find.bySemanticsLabel('기록'), findsOneWidget);
    await tester.pumpWidget(
      _host(NavBar(leading: _back, actions: _heartHistory(liked: true))),
    );
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('좋아요, 켜짐'), findsOneWidget);
    semantics.dispose();
  });
}
