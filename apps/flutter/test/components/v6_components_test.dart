// Regression coverage for v6 components. Preserve behavior, layout, and interaction
// expectations.

//  TabBarV6 (2256:8826 · 2295:11151 · 2295:15974) · CallListCard (2166:5476) · SelectControl · HeartControl (2166:5659) ·
//  ToastV6 (2295:15893 · 2295:15973).
import 'package:cameo/components/call_list_card.dart';
import 'package:cameo/components/controls.dart';
import 'package:cameo/components/outside_shadow.dart';
import 'package:cameo/components/scrim_button.dart';
import 'package:cameo/components/scrim_pill.dart';
import 'package:cameo/components/solid_button.dart';
import 'package:cameo/components/tab_bar_v6.dart';
import 'package:cameo/components/toast.dart';
import 'package:cameo/components/toast_v6.dart';
import 'package:cameo/content/lab.g.dart';
import 'package:cameo/design_system/design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

const Size _figma = Size(402, 874);
const Size _legacy = Size(393, 852);

final CameoPalette _light = CameoPalette.of(CameoColorMode.light);
final CameoPalette _dark = CameoPalette.of(CameoColorMode.dark);

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Size size = _figma,
  CameoColorMode mode = CameoColorMode.light,
  bool positioned = false,
  bool reduceMotion = false,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: MediaQueryData(size: size, disableAnimations: reduceMotion),
        child: CameoTheme(
          mode: mode,
          child: Stack(
            children: [
              if (positioned)
                child
              else
                Positioned(left: 16, top: 62, child: child),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

ShapeDecoration _shape(WidgetTester tester, Finder finder) =>
    tester
            .widget<DecoratedBox>(
              find
                  .descendant(
                    of: finder,
                    matching: find.byWidgetPredicate(
                      (w) =>
                          w is DecoratedBox && w.decoration is ShapeDecoration,
                    ),
                  )
                  .first,
            )
            .decoration
        as ShapeDecoration;

BorderSide _side(ShapeDecoration d) =>
    (d.shape as RoundedSuperellipseBorder).side;

void _expectNoOpacityOverGlass(WidgetTester tester) {
  for (final e in find.byType(LiquidGlass).evaluate()) {
    e.visitAncestorElements((a) {
      final w = a.widget;
      if (w is Opacity) expect(w.opacity, 1, reason: '글래스 조상 Opacity');
      if (w is FadeTransition) fail('글래스 조상 FadeTransition');
      return true;
    });
  }
}

Rect _rect(WidgetTester tester, Key key) =>
    tester.getRect(find.byKey(key).first);

void main() {
  group('SolidButton v6 (2166:3575 · 4286 · 4557 — layout.solidButtonV6)', () {
    testWidgets(
      '크기 lg 54 (p16 · 22 · bodyLg) · md 46 (p12 · 22 · bodyLg) · sm 38 (p10 · 18 · bodyMd) · Frosted blur r12 · 테두리 없음',
      (tester) async {
        for (final (size, h, p, icon, style) in [
          (SolidButtonSize.lg, 54.0, 16.0, 22.0, CameoTextStyles.bodyLg),
          (SolidButtonSize.md, 46.0, 12.0, 22.0, CameoTextStyles.bodyLg),
          (SolidButtonSize.sm, 38.0, 10.0, 18.0, CameoTextStyles.bodyMd),
        ]) {
          await _pump(
            tester,
            SolidButton(size: size, icon: CameoIconName.x, onPress: () {}),
          );
          final box = _rect(tester, SolidButton.surfaceKey);
          expect(box.size, Size(h, h), reason: '$size');
          final iconRect = tester.getRect(find.byType(CameoIcon));
          expect(iconRect.size, Size(icon, icon));
          expect(iconRect.left - box.left, p, reason: '$size 여백');
          expect(find.byType(LiquidGlass), findsNothing, reason: 'Frosted');
          expect(find.byType(BackdropFilter), findsOneWidget);
          expect(solidButtonMetrics(size).label, style);
          final d = _shape(tester, find.byKey(SolidButton.surfaceKey));
          expect(_side(d), BorderSide.none);
        }
        expect(CameoBlur.blur.sigma, 6); // Figma BG blur 12
      },
    );

    testWidgets(
      'light default = 검정 채움 + 흰 글자 (라이브 회귀: 흰 채움 위 흰 글자) · dark default = 흰 + 검정',
      (tester) async {
        await _pump(tester, SolidButton(label: '공유 2', onPress: () {}));
        var d = _shape(tester, find.byKey(SolidButton.surfaceKey));
        expect(d.color, _light.backgroundFillNeutralInverted);
        expect(d.color, const Color(0xFF030305));
        final label = tester.widget<CameoText>(find.byType(CameoText));
        expect(label.color, _light.foregroundInvertedBase);
        expect(label.color, const Color(0xFFF7F7FB));
        await _pump(
          tester,
          SolidButton(label: '취침모드 종료', onPress: () {}),
          mode: CameoColorMode.dark,
        );
        d = _shape(tester, find.byKey(SolidButton.surfaceKey));
        expect(d.color, const Color(0xFFF7F7FB));
        expect(
          tester.widget<CameoText>(find.byType(CameoText)).color,
          const Color(0xFF030305),
        );
      },
    );

    test(
      '변형 색 = layout.solidButtonV6.\$roles (default · gray · system · ghost)',
      () {
        for (final p in [_light, _dark]) {
          expect(solidButtonColors(p, SolidButtonVariant.gray), (
            fill: p.backgroundFillNeutralBase,
            content: p.foregroundNeutralBase,
          ));
          expect(solidButtonColors(p, SolidButtonVariant.system), (
            fill: p.systemRed,
            content: p.staticWhiteBase,
          ));
          expect(solidButtonColors(p, SolidButtonVariant.ghost), (
            fill: null,
            content: p.foregroundNeutralBase,
          ));
          expect(
            solidButtonColors(
              p,
              SolidButtonVariant.ghost,
              disabled: true,
            ).content,
            p.foregroundNeutralSubtle,
          );
        }
      },
    );

    testWidgets(
      'stretch = 부모 폭 (전체 폭 CTA W − 32: 402 → 370 · 393 → 361) · 내용 가운데',
      (tester) async {
        for (final size in [_figma, _legacy]) {
          await _pump(
            tester,
            Positioned(
              left: 16,
              right: 16,
              top: 700,
              child: SolidButton(label: '다음', stretch: true, onPress: () {}),
            ),
            size: size,
            positioned: true,
          );
          final box = _rect(tester, SolidButton.surfaceKey);
          expect(box.width, size.width - 32);
          expect(box.height, 54);
          final label = tester.getRect(find.byType(CameoText));
          expect(label.center.dx, closeTo(box.center.dx, 0.5));
        }
      },
    );

    testWidgets(
      '비활성 = 전체 불투명도 0.3 (Frosted) · ghost = subtle 글자, 불투명도 없음 · 누름 없음',
      (tester) async {
        var pressed = 0;
        await _pump(
          tester,
          SolidButton(label: '다음', disabled: true, onPress: () => pressed++),
        );
        expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 0.3);
        await tester.tap(find.byKey(SolidButton.surfaceKey));
        expect(pressed, 0);
        await _pump(
          tester,
          SolidButton(
            label: '나중에',
            size: SolidButtonSize.md,
            variant: SolidButtonVariant.ghost,
            disabled: true,
          ),
        );
        expect(find.byType(Opacity), findsNothing);
        expect(
          tester.widget<CameoText>(find.byType(CameoText)).color,
          _light.foregroundNeutralSubtle,
        );
      },
    );
  });

  group('ScrimButton v6 (2256:5441 · 5474 · 5507 — Liquid Glass · F3)', () {
    testWidgets(
      '크기 lg 54 (p16 · 22) · md 46 (p12 · 22 · bodyLg) · sm 38 (p10 · 18) · 테두리 1 은 크기 밖',
      (tester) async {
        for (final (size, h, p, icon) in [
          (ScrimButtonSize.lg, 54.0, 16.0, 22.0),
          (ScrimButtonSize.md, 46.0, 12.0, 22.0),
          (ScrimButtonSize.sm, 38.0, 10.0, 18.0),
        ]) {
          await _pump(
            tester,
            ScrimButton(size: size, icon: CameoIconName.x, onPress: () {}),
          );
          final box = _rect(tester, ScrimButton.surfaceKey);
          expect(box.size, Size(h, h), reason: '$size');
          final iconRect = tester.getRect(find.byType(CameoIcon));
          expect(iconRect.size, Size(icon, icon));
          expect(iconRect.left - box.left, p, reason: '$size 여백 (테두리 포함)');
          expect(find.byType(LiquidGlass), findsOneWidget);
          expect(
            _side(_shape(tester, find.byKey(ScrimButton.surfaceKey))).width,
            1,
          );
        }
        expect(
          scrimButtonMetrics(ScrimButtonSize.md).label,
          CameoTextStyles.bodyLg,
        );
      },
    );

    testWidgets("라벨만 md '선택' = 12 + 4 + 라벨 + 4 + 12 × 46 (Figma 60)", (
      tester,
    ) async {
      await _pump(
        tester,
        ScrimButton(size: ScrimButtonSize.md, label: '선택', onPress: () {}),
      );
      final box = _rect(tester, ScrimButton.surfaceKey);
      final label = tester.getRect(find.byType(CameoText));
      expect(box.height, 46);
      expect(box.width, closeTo(12 + 4 + label.width + 4 + 12, 0.01));
    });

    testWidgets(
      'light 톤 = 흰 frosted #f7f7fb80 + 테두리 #f7f7fb2e + 어두운 내용 · dark 톤 = #03030580 + #f7f7fb14 + 흰 내용 · scrim 그림자 (바깥만)',
      (tester) async {
        for (final (tone, palette, content) in [
          (ScrimButtonTone.light, _light, _light.foregroundNeutralBase),
          (ScrimButtonTone.dark, _dark, _dark.staticWhiteBase),
        ]) {
          await _pump(
            tester,
            ScrimButton(
              icon: CameoIconName.refresh,
              tone: tone,
              onPress: () {},
            ),
            mode: tone == ScrimButtonTone.light
                ? CameoColorMode.dark
                : CameoColorMode.light,
          );
          final d = _shape(tester, find.byKey(ScrimButton.surfaceKey));
          expect(d.color, palette.backgroundFillScrimBase, reason: '$tone');
          expect(_side(d).color, palette.borderScrim);
          expect(
            tester.widget<CameoIcon>(find.byType(CameoIcon)).color,
            content,
          );
          final shadow = tester.widget<OutsideShadow>(
            find.byKey(ScrimButton.shadowKey),
          );
          expect(shadow.shadow, palette.shadows.scrim);
        }
        expect(_light.backgroundFillScrimBase, const Color(0x80F7F7FB));
        expect(_dark.backgroundFillScrimBase, const Color(0x80030305));
        expect(CameoShadows.scrim.offset, const Offset(0, 8));
        expect(CameoShadows.scrim.spreadRadius, -4);
      },
    );

    testWidgets(
      '비활성 = 틴트 · 테두리 · 그림자 · 내용 알파 × 0.3 (글래스에 Opacity 없음) · 누름 없음',
      (tester) async {
        var pressed = 0;
        await _pump(
          tester,
          ScrimButton(
            icon: CameoIconName.x,
            disabled: true,
            onPress: () => pressed++,
          ),
        );
        final d = _shape(tester, find.byKey(ScrimButton.surfaceKey));
        expect(
          d.color!.a,
          closeTo(_light.backgroundFillScrimBase.a * 0.3, 1e-6),
        );
        expect(_side(d).color.a, closeTo(_light.borderScrim.a * 0.3, 1e-6));
        _expectNoOpacityOverGlass(tester);
        await tester.tap(find.byKey(ScrimButton.surfaceKey));
        expect(pressed, 0);
        expect(ScrimButtonTone.light.mode, CameoColorMode.light);
        expect(ScrimButtonTone.dark.mode, CameoColorMode.dark);
      },
    );
  });

  group('ScrimPill (layout.scrimPillV6 — 46 · 항목 38 · gap 12 · p 4)', () {
    testWidgets(
      '폭 1 → 46 · 2 → 96 · 3 → 146 · 항목 38 이 (4, 4) 부터 50 간격 · 아이콘 22 가운데',
      (tester) async {
        for (final n in [1, 2, 3]) {
          await _pump(
            tester,
            ScrimPill(
              items: [
                for (var i = 0; i < n; i++)
                  ScrimPillItem(
                    icon: CameoIconName.heart,
                    semanticLabel: 'i$i',
                    onPress: () {},
                  ),
              ],
            ),
          );
          final box = _rect(tester, ScrimPill.surfaceKey);
          expect(box.size, Size(scrimPillWidth(n), 46));
          expect(scrimPillWidth(n), [46.0, 96.0, 146.0][n - 1]);
          for (var i = 0; i < n; i++) {
            final item = _rect(tester, ScrimPill.itemKey(i));
            expect(item.size, const Size(38, 38));
            expect(item.topLeft - box.topLeft, Offset(4 + 50.0 * i, 4));
          }
        }
      },
    );

    testWidgets(
      'light · dark = 글래스 (ScrimButton 과 같은 표면) · gray = Frosted background/fill/neutral/base, 테두리 · 그림자 없음',
      (tester) async {
        final items = [
          ScrimPillItem(
            icon: CameoIconName.phoneCall,
            semanticLabel: '전화',
            onPress: () {},
          ),
          const ScrimPillItem(icon: CameoIconName.heart, semanticLabel: '좋아요'),
        ];
        await _pump(tester, ScrimPill(items: items));
        expect(find.byType(LiquidGlass), findsOneWidget);
        var d = _shape(tester, find.byKey(ScrimPill.surfaceKey));
        expect(d.color, _light.backgroundFillScrimBase);
        expect(_side(d).color, _light.borderScrim);
        expect(find.byKey(ScrimPill.shadowKey), findsOneWidget);
        expect(
          tester.widget<CameoIcon>(find.byType(CameoIcon).first).color,
          _light.foregroundNeutralBase,
        );
        await _pump(tester, ScrimPill(items: items, tone: ScrimPillTone.dark));
        d = _shape(tester, find.byKey(ScrimPill.surfaceKey));
        expect(d.color, _dark.backgroundFillScrimBase);
        expect(
          tester.widget<CameoIcon>(find.byType(CameoIcon).first).color,
          _dark.staticWhiteBase,
        );
        await _pump(tester, ScrimPill(items: items, tone: ScrimPillTone.gray));
        expect(find.byType(LiquidGlass), findsNothing);
        d = _shape(tester, find.byKey(ScrimPill.surfaceKey));
        expect(d.color, _light.backgroundFillNeutralBase);
        expect(_side(d), BorderSide.none);
        expect(find.byKey(ScrimPill.shadowKey), findsNothing);
      },
    );

    testWidgets(
      'active → heart-filled (heartPop) · 누름 = onPress · 접근성 selected',
      (tester) async {
        var taps = 0;
        Widget pill(bool active) => ScrimPill(
          items: [
            ScrimPillItem(
              icon: CameoIconName.heart,
              active: active,
              semanticLabel: '좋아요',
              onPress: () => taps++,
            ),
          ],
        );
        await _pump(tester, pill(false));
        expect(
          find.byWidgetPredicate((w) => w is ToggleIcon && !w.active),
          findsOneWidget,
        );
        await tester.tap(find.byKey(ScrimPill.itemKey(0)));
        await tester.pumpAndSettle();
        expect(taps, 1);
        await _pump(tester, pill(true));
        final toggle = tester.widget<ToggleIcon>(find.byType(ToggleIcon));
        expect(toggle.active, isTrue);
        expect(toggle.activeIcon, CameoIconName.heartFilled);
        await tester.pumpAndSettle();
      },
    );
  });

  group('TabBarV6 (layout.tabBarV6 · motion.tabBarV6 — F6)', () {
    Widget bar({
      TabBarV6Mode mode = TabBarV6Mode.full,
      int selected = 0,
      TabBarV6Variant variant = TabBarV6Variant.album,
      TabBarV6Tone tone = TabBarV6Tone.photo,
      TabBarCameraSlots? camera,
      bool hidden = false,
      bool tabsDisabled = false,
      ValueChanged<int>? onSelect,
      VoidCallback? onCall,
    }) => Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: TabBarV6(
        mode: mode,
        selected: selected,
        onSelect: onSelect ?? (_) {},
        onCall: onCall ?? () {},
        variant: variant,
        tone: tone,
        camera: camera,
        hidden: hidden,
        tabsDisabled: tabsDisabled,
      ),
    );

    TabBarV6State state(WidgetTester tester) =>
        tester.state<TabBarV6State>(find.byType(TabBarV6));

    test('tabBarV6Frame 끝 상태 @402 = 토큰 · @393 = 규칙', () {
      final full = tabBarV6Frame(402);
      expect(full.containerHeight, 102);
      expect(full.pillLeft, 16);
      expect(full.pillTop, 12);
      expect(full.pillWidth, 308);
      expect(full.pillHeight, 56);
      expect(full.inset, 4);
      expect(full.itemWidth, 100);
      expect(full.itemHeight, 48);
      expect(full.buttonLeft, 332);
      expect(full.buttonTop, 13);
      expect(full.buttonScale, 1);
      expect(full.thumbnail, 0);
      final mini = tabBarV6Frame(402, mini: 1);
      expect(mini.containerHeight, 90);
      expect(mini.pillLeft, 106);
      expect(mini.pillWidth, 190);
      expect(mini.pillHeight, 44);
      expect(mini.inset, 5);
      expect(mini.itemWidth, 60);
      expect(mini.itemHeight, 34);
      expect(mini.pillTop + mini.pillHeight, 90 - 34);
      expect(mini.buttonLeft, 332 + 78);
      expect(mini.buttonScale, 0.5);
      expect(mini.buttonTop + 54, 90 - 35);
      final cam = tabBarV6Frame(402, camera: 1);
      expect(cam.pillLeft, 78);
      expect(cam.pillWidth, 246);
      expect(cam.itemWidth, closeTo(79.333333, 1e-5));
      expect(cam.buttonLeft, 332);
      expect(cam.thumbnail, 1);
      final legacy = tabBarV6Frame(393);
      expect(legacy.pillWidth, 299);
      expect(legacy.itemWidth, 97);
      expect(legacy.buttonLeft, 323);
      expect(tabBarV6Frame(393, mini: 1).pillLeft, 101.5);
      expect(tabBarV6Frame(393, camera: 1).pillWidth, 237);
      expect(tabBarV6Frame(393, camera: 1).itemWidth, closeTo(76.333333, 1e-5));
    });

    testWidgets(
      'full @402: 컨테이너 (0, 772) 402 × 102 · pill (16, 784) 308 × 56 · 탭 100 × 48 (20 · 120 · 220) · 통화 버튼 (332, 785) 54 · 라벨 history · camera · settings',
      (tester) async {
        await _pump(tester, bar(), positioned: true);
        expect(
          _rect(tester, TabBarV6.containerKey),
          const Rect.fromLTWH(0, 772, 402, 102),
        );
        expect(
          _rect(tester, TabBarV6.pillKey),
          const Rect.fromLTWH(16, 784, 308, 56),
        );
        for (var i = 0; i < 3; i++) {
          expect(
            _rect(tester, TabBarV6.tabKey(i)),
            Rect.fromLTWH(20 + 100.0 * i, 788, 100, 48),
          );
          final label = tester.widget<CameoText>(
            find.byKey(TabBarV6.labelKey(i)),
          );
          expect(label.text, ['history', 'camera', 'settings'][i]);
          expect(label.style, CameoTextStyles.tabLabel);
          expect(_rect(tester, TabBarV6.iconKey(i)).top, 788 + 6);
        }
        expect(
          _rect(tester, TabBarV6.buttonKey),
          const Rect.fromLTWH(332, 785, 54, 54),
        );
        expect(
          _rect(tester, TabBarV6.indicatorKey),
          _rect(tester, TabBarV6.tabKey(0)),
        );

        Color iconColor(int i) =>
            tester.widget<CameoIcon>(find.byKey(TabBarV6.iconKey(i))).color!;
        expect(iconColor(0), _light.foregroundNeutralBase);
        expect(iconColor(1), _light.foregroundNeutralSubtle);

        expect(find.byType(LiquidGlass), findsNWidgets(2));
        _expectNoOpacityOverGlass(tester);
        final fade = tester.widget<DecoratedBox>(find.byKey(TabBarV6.fadeKey));
        expect(
          (fade.decoration as BoxDecoration).gradient,
          _light.gradients.sectionFadeBottomV6,
        );
      },
    );

    testWidgets('full @393 (W 규칙): pill 299 · 탭 97 · 통화 버튼 x 323', (
      tester,
    ) async {
      await _pump(tester, bar(), positioned: true, size: _legacy);
      expect(
        _rect(tester, TabBarV6.pillKey),
        const Rect.fromLTWH(16, 762, 299, 56),
      );
      expect(_rect(tester, TabBarV6.tabKey(1)).width, 97);
      expect(_rect(tester, TabBarV6.buttonKey).left, 323);
    });

    testWidgets(
      'full → mini 모핑 (morphSpring): 끝 = 컨테이너 90 · pill (106, 796) 190 × 44 · 항목 60 × 34 · 라벨 0 · 통화 버튼 화면 밖 · 되돌리면 full',
      (tester) async {
        BackdropFilter backdrop() => tester.widget<BackdropFilter>(
          find
              .ancestor(
                of: find.byKey(TabBarV6.fadeKey),
                matching: find.byType(BackdropFilter),
              )
              .first,
        );
        LinearGradient gradient() =>
            (tester
                            .widget<DecoratedBox>(find.byKey(TabBarV6.fadeKey))
                            .decoration
                        as BoxDecoration)
                    .gradient!
                as LinearGradient;
        await _pump(tester, bar(), positioned: true);
        final glass = tester.element(find.byKey(TabBarV6.pillKey));
        expect(backdrop().enabled, isTrue);
        await _pump(tester, bar(mode: TabBarV6Mode.mini), positioned: true);
        await tester.pump(const Duration(milliseconds: 60));

        final mid = state(tester).miniProgress;
        expect(mid, inExclusiveRange(0, 1));
        expect(gradient().colors.last.a, inExclusiveRange(0, 1));
        _expectNoOpacityOverGlass(tester);
        await tester.pumpAndSettle();
        expect(state(tester).miniProgress, 1);
        expect(state(tester).labelOpacity, 0);
        expect(
          backdrop().enabled,
          isFalse,
          reason: '미니에서는 넓은 배경 블러가 사진을 가리지 않는다',
        );
        expect(gradient().colors.every((color) => color.a == 0), isTrue);
        expect(
          identical(glass, tester.element(find.byKey(TabBarV6.pillKey))),
          isTrue,
        );
        expect(
          _rect(tester, TabBarV6.containerKey),
          const Rect.fromLTWH(0, 784, 402, 90),
        );
        expect(
          _rect(tester, TabBarV6.pillKey),
          const Rect.fromLTWH(106, 796, 190, 44),
        );
        for (var i = 0; i < 3; i++) {
          expect(
            _rect(tester, TabBarV6.tabKey(i)),
            Rect.fromLTWH(111 + 60.0 * i, 801, 60, 34),
          );
        }
        final call = _rect(tester, TabBarV6.buttonKey);
        expect(call.left, greaterThanOrEqualTo(402), reason: '화면 밖');
        await _pump(tester, bar(), positioned: true);
        await tester.pumpAndSettle();
        expect(state(tester).miniProgress, 0);
        expect(state(tester).labelOpacity, 1);
        expect(backdrop().enabled, isTrue);
        expect(gradient(), _light.gradients.sectionFadeBottomV6);
        expect(
          identical(glass, tester.element(find.byKey(TabBarV6.pillKey))),
          isTrue,
        );
        expect(
          _rect(tester, TabBarV6.pillKey),
          const Rect.fromLTWH(16, 784, 308, 56),
        );
        expect(
          _rect(tester, TabBarV6.buttonKey),
          const Rect.fromLTWH(332, 785, 54, 54),
        );
      },
    );

    testWidgets(
      '선택 이동 = indicatorSpring (snap) · 탭 누름 = onSelect · 통화 버튼 = onCall',
      (tester) async {
        final selected = <int>[];
        var calls = 0;
        await _pump(
          tester,
          bar(onSelect: selected.add, onCall: () => calls++),
          positioned: true,
        );
        await tester.tap(find.byKey(TabBarV6.tabKey(2)));
        await tester.pumpAndSettle();
        expect(selected, [2]);
        await tester.tap(find.byKey(TabBarV6.buttonKey));
        await tester.pumpAndSettle();
        expect(calls, 1);
        await _pump(
          tester,
          bar(selected: 2, onSelect: selected.add),
          positioned: true,
        );
        await tester.pump(const Duration(milliseconds: 50));
        expect(state(tester).indicatorPosition, inExclusiveRange(0, 2));
        await tester.pumpAndSettle();
        expect(
          _rect(tester, TabBarV6.indicatorKey),
          _rect(tester, TabBarV6.tabKey(2)),
        );
      },
    );

    testWidgets(
      'camera 변형 @402: 썸네일 (16, 785) 54 · pill (78, 784) 246 × 56 · 항목 79.33 · 오른쪽 = 전환 (dark 틴트 · refresh) → onFlip · 톤 camera',
      (tester) async {
        var flips = 0;
        final slots = TabBarCameraSlots(
          thumbnail: TabBarThumbnail(
            image: const AssetImage(LabImages.cameraPlaceholder),
            semanticLabel: '마지막 사진',
            onPress: () {},
          ),
          onFlip: () => flips++,
          flipLabel: '카메라 전환',
        );
        await _pump(
          tester,
          bar(
            selected: 1,
            variant: TabBarV6Variant.camera,
            tone: TabBarV6Tone.camera,
            camera: slots,
          ),
          positioned: true,
        );
        expect(
          _rect(tester, TabBarV6.thumbnailKey),
          const Rect.fromLTWH(16, 785, 54, 54),
        );
        final pill = _rect(tester, TabBarV6.pillKey);
        expect(pill.left, 78);
        expect(pill.width, 246);
        expect(
          _rect(tester, TabBarV6.tabKey(1)).width,
          closeTo(79.333333, 1e-4),
        );
        final d = _shape(tester, find.byKey(TabBarV6.pillKey));
        expect(d.color, _dark.backgroundFillScrimBase);
        expect(_side(d).color, _dark.borderScrim);
        final button = _shape(tester, find.byKey(TabBarV6.buttonKey));
        expect(button.color, _dark.backgroundFillScrimBase);
        Opacity iconOpacity(Key key) => tester.widget<Opacity>(
          find
              .ancestor(of: find.byKey(key), matching: find.byType(Opacity))
              .first,
        );
        expect(iconOpacity(TabBarV6.flipIconKey).opacity, 1);
        expect(iconOpacity(TabBarV6.callIconKey).opacity, 0);
        await tester.tap(find.byKey(TabBarV6.buttonKey));
        await tester.pumpAndSettle();
        expect(flips, 1);
        final fade = tester.widget<DecoratedBox>(find.byKey(TabBarV6.fadeKey));
        expect(
          (fade.decoration as BoxDecoration).gradient,
          _light.gradients.cameraNavFadeV6,
        );

        expect(
          tester.widget<CameoIcon>(find.byKey(TabBarV6.iconKey(1))).color,
          _dark.foregroundNeutralBase,
        );
        _expectNoOpacityOverGlass(tester);
      },
    );

    testWidgets(
      '앨범 → 카메라 변형 모핑: pill 16 → 78 · 틴트 light → dark 보간 · 썸네일 0.5 → 1',
      (tester) async {
        final slots = TabBarCameraSlots(
          thumbnail: const SizedBox.expand(),
          flipLabel: '카메라 전환',
          onFlip: () {},
        );
        await _pump(tester, bar(camera: slots), positioned: true);
        expect(find.byKey(TabBarV6.thumbnailKey), findsNothing);
        await _pump(
          tester,
          bar(selected: 1, variant: TabBarV6Variant.camera, camera: slots),
          positioned: true,
        );
        await tester.pump(const Duration(milliseconds: 80));
        final c = state(tester).cameraProgress;
        expect(c, inExclusiveRange(0, 1));
        final left = _rect(tester, TabBarV6.pillKey).left;
        expect(left, inExclusiveRange(16, 78));
        _expectNoOpacityOverGlass(tester);
        await tester.pumpAndSettle();
        expect(_rect(tester, TabBarV6.pillKey).left, 78);
      },
    );

    testWidgets(
      'tabsDisabled (통화 모드 카메라) = 선택 탭 말고 알파 × 0.3 · 누름 없음 · hidden = 컨테이너 높이만큼 아래 · 누름 없음',
      (tester) async {
        final selected = <int>[];
        await _pump(
          tester,
          bar(selected: 1, tabsDisabled: true, onSelect: selected.add),
          positioned: true,
        );
        final idle = tester
            .widget<CameoIcon>(find.byKey(TabBarV6.iconKey(0)))
            .color!;
        expect(idle.a, closeTo(_light.foregroundNeutralSubtle.a * 0.3, 1e-6));
        await tester.tap(find.byKey(TabBarV6.tabKey(0)), warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(selected, isEmpty);
        await _pump(
          tester,
          bar(hidden: true, onSelect: selected.add),
          positioned: true,
        );
        await tester.pumpAndSettle();
        expect(_rect(tester, TabBarV6.containerKey).top, 874);
        await tester.tap(find.byKey(TabBarV6.tabKey(2)), warnIfMissed: false);
        expect(selected, isEmpty);
      },
    );

    testWidgets(
      '톤 = 컨테이너 페이드 (photo sectionFadeBottomV6 · canvas bottomLinear · camera cameraNavFadeV6) — 바뀌면 보간 · 글래스 배경 톤 = 톤에서',
      (tester) async {
        await _pump(tester, bar(), positioned: true);
        await _pump(tester, bar(tone: TabBarV6Tone.canvas), positioned: true);
        await tester.pumpAndSettle();
        final fade = tester.widget<DecoratedBox>(find.byKey(TabBarV6.fadeKey));
        expect(
          (fade.decoration as BoxDecoration).gradient,
          _light.gradients.bottomLinear,
        );
        expect(TabBarV6Tone.photo.backdrop, GlassBackdropTone.defaultTone);
        expect(TabBarV6Tone.canvas.backdrop, GlassBackdropTone.light);
        expect(TabBarV6Tone.camera.backdrop, GlassBackdropTone.dark);
        final backdrop = tester.widget<GlassBackdrop>(
          find.descendant(
            of: find.byType(TabBarV6),
            matching: find.byType(GlassBackdrop),
          ),
        );
        expect(backdrop.tone, GlassBackdropTone.light);
      },
    );

    testWidgets('모션 감소: 모핑 · 라벨 즉시', (tester) async {
      await _pump(tester, bar(), positioned: true, reduceMotion: true);
      await _pump(
        tester,
        bar(mode: TabBarV6Mode.mini),
        positioned: true,
        reduceMotion: true,
      );
      expect(state(tester).miniProgress, 1);
      expect(state(tester).labelOpacity, 0);
    });
  });

  group('CallListCard v6 (2166:5476 — layout.callListV6)', () {
    test(
      '변형 색: default = 불투명 흰 카드 (light 팔레트 — dark 모드에서도) · list · failed · content 키 scrim → list',
      () {
        for (final p in [_light, _dark]) {
          final def = callListColors(p, CallListVariant.defaultVariant);
          expect(def.fill, const Color(0xFFF7F7FB));
          expect(def.title, const Color(0xFF030305));
          expect(def.subtitle, _light.foregroundNeutralMuted);
          final list = callListColors(p, CallListVariant.list);
          expect(list.fill, p.backgroundFillNeutralList);
          expect(list.title, p.staticWhiteBase);
          expect(list.subtitle, p.staticWhiteMuted);
          final failed = callListColors(p, CallListVariant.failed);
          expect(failed.fill, p.systemRed);
          expect(failed.title, p.staticWhiteBase);
        }
        expect(CallListVariant.fromKey('scrim'), CallListVariant.list);
        expect(CallListVariant.fromKey('list'), CallListVariant.list);
        expect(CallListVariant.fromKey('failed'), CallListVariant.failed);
        expect(CallListVariant.fromKey('?'), CallListVariant.defaultVariant);
      },
    );

    testWidgets('폭 fill (W − 16: 402 → 386 · 393 → 377) × 76 · r14 · 방향 아이콘', (
      tester,
    ) async {
      for (final size in [_figma, _legacy]) {
        await _pump(
          tester,
          Positioned(
            left: 8,
            right: 8,
            top: 410,
            child: CallListCard(
              variant: CallListVariant.failed,
              direction: CallDirection.outgoing,
              title: '부재중',
              subtitle: const [
                LabTextSpan('00시 00분 ∙ 발신 통화 00분 00초', LabTextWeight.regular),
              ],
              onPress: () {},
            ),
          ),
          size: size,
          positioned: true,
        );
        final box = _rect(tester, CallListCard.surfaceKey);
        expect(box.size, Size(size.width - 16, 76));
        expect(
          tester.widget<CameoIcon>(find.byKey(CallListCard.iconKey)).name,
          CameoIconName.arrowUpRight,
        );
      }
    });
  });

  group(
    'SelectControl · HeartControl v6 (2166:5659 — 그림자 effect/shadow-legacy)',
    () {
      test(
        '체크 그림자 = shadowV5 (effect/shadow-legacy #1212213d) · 하트 그림자 #1212213d',
        () {
          expect(_light.shadows.shadowV5.color, const Color(0x3D121221));
          expect(_light.controlHeartShadow, const Color(0x3D121221));
          expect(CameoLayout.controlCheckSize, 20);
          expect(CameoLayout.controlHeartSize, 22);
        },
      );

      testWidgets('SelectControl 켜짐 = 흰 원판 + check 14 + legacy 그림자', (
        tester,
      ) async {
        await _pump(tester, const SelectControl(selected: true));
        final disc = tester.widget<DecoratedBox>(
          find.byKey(SelectControl.discKey),
        );
        final d = disc.decoration as BoxDecoration;
        expect(d.color, _light.staticWhiteBase);
        expect(d.boxShadow, [_light.shadows.shadowV5]);
      });
    },
  );

  group('ToastV6 (flat 2295:15893 · elevated 2295:15973)', () {
    testWidgets(
      'flat = pill 42 (12 + 18 + 12) · 테두리 · 그림자 없음 · 컨테이너 py12 → 66 · 아래 = 104 (H − 770)',
      (tester) async {
        final toast = ToastController();
        await _pump(
          tester,
          Positioned(
            left: 0,
            right: 0,
            bottom: toastV6FlatBottom(),
            child: ToastV6Host(controller: toast, autoHide: false),
          ),
          positioned: true,
        );
        toast.show('전후 15초 하이라이트가 저장됐어요!', CameoIconName.infoCircle);
        await tester.pumpAndSettle();
        final pill = _rect(tester, ToastV6Pill.pillKey);
        expect(pill.height, 42);
        expect(pill.bottom, 874 - 104 - 12);
        expect(toastV6FlatBottom(), 104);
        final d =
            tester.widget<Container>(find.byKey(ToastV6Pill.pillKey)).decoration
                as BoxDecoration;
        expect(d.border, isNull);
        expect(d.boxShadow, isNull);
        expect(d.color, _light.staticWhiteBase);
        expect(find.byType(LiquidGlass), findsNothing);
      },
    );

    testWidgets(
      'elevated · camera 자리 = pill 45 (테두리 1.5 stroke/base 포함) + legacy 그림자 · 컨테이너 top 66 + pt 24 → pill 90',
      (tester) async {
        final toast = ToastController();
        await _pump(
          tester,
          Positioned(
            left: 0,
            right: 0,
            top: CameoLayout.toastV6CameraContainerTop,
            child: ToastV6Host(
              controller: toast,
              autoHide: false,
              variant: ToastV6Variant.elevated,
              placement: ToastV6Placement.camera,
            ),
          ),
          positioned: true,
        );
        toast.show('Yurim님이 사진을 공유했어요!', CameoIconName.infoCircle);
        await tester.pumpAndSettle();
        final pill = _rect(tester, ToastV6Pill.pillKey);
        expect(pill.height, 45);
        expect(pill.top, 90);
        final d =
            tester.widget<Container>(find.byKey(ToastV6Pill.pillKey)).decoration
                as BoxDecoration;
        expect((d.border! as Border).top.width, 1.5);
        expect((d.border! as Border).top.color, _light.strokeBase);
        expect(d.boxShadow, [_light.shadows.shadowV5]);
        expect(
          toastV6VariantOf(ToastV6Variant.elevated),
          ToastVariant.v6Elevated,
        );
        expect(
          toastV6VariantOf(ToastV6Variant.flat, ToastV6Placement.camera),
          ToastVariant.v6Flat,
        );
      },
    );
  });
}
