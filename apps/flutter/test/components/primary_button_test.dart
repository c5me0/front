// Regression coverage for primary button. Preserve behavior, layout, and interaction
// expectations.

import 'package:cameo/components/primary_button.dart';
import 'package:cameo/design_system/design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

const Size _screen = Size(393, 852);
const Duration _frame = Duration(milliseconds: 16);

void _screenSize(WidgetTester tester) {
  tester.view.physicalSize = _screen;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget _host(Widget button, {bool reduceMotion = false, bool bottom = true}) {
  return MediaQuery(
    data: MediaQueryData(size: _screen, disableAnimations: reduceMotion),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: CameoTheme(
        mode: CameoColorMode.light,
        child: Stack(
          children: [
            if (bottom)
              Positioned(
                left: CameoLayout.screenGutter,
                right: CameoLayout.screenGutter,
                bottom: CameoLayout.tabBarContainerPaddingBottom,
                child: button,
              )
            else
              Center(child: button),
          ],
        ),
      ),
    ),
  );
}

Color _tint(WidgetTester tester) =>
    tester.widget<GlassSurface>(find.byKey(PrimaryButton.surfaceKey)).tint!;

double _labelOpacity(WidgetTester tester) =>
    tester.widget<Opacity>(find.byKey(PrimaryButton.labelKey)).opacity;

Future<void> _run(WidgetTester tester, Duration total) async {
  for (var t = Duration.zero; t < total; t += _frame) {
    await tester.pump(_frame);
  }
}

void main() {
  testWidgets(
    'fullWidth: 393 화면 x 16 · 361 × 56 · top 760 · Liquid Glass pill (반경 999)',
    (tester) async {
      _screenSize(tester);
      await tester.pumpWidget(
        _host(PrimaryButton(label: '다음', onPress: () {})),
      );
      final rect = tester.getRect(find.byKey(PrimaryButton.surfaceKey));
      expect(rect, const Rect.fromLTWH(16, 760, 361, 56));
      final surface = tester.widget<GlassSurface>(
        find.byKey(PrimaryButton.surfaceKey),
      );
      expect(surface.effect, GlassEffect.glass);
      expect(surface.blur, CameoBlur.glassNav);
      expect(surface.radius, CameoLayout.primaryButtonRadius);
      expect(
        find.descendant(
          of: find.byType(PrimaryButton),
          matching: find.byType(LiquidGlass),
        ),
        findsOneWidget,
      );
      expect(find.byType(GlassPressable), findsOneWidget);
    },
  );

  testWidgets('fullWidth false: 폭 = 라벨 + paddingX 24 × 2 (hug)', (
    tester,
  ) async {
    _screenSize(tester);
    await tester.pumpWidget(
      _host(
        PrimaryButton(label: '상대 연결하기', onPress: () {}, fullWidth: false),
        bottom: false,
      ),
    );
    final label = tester.getSize(find.byType(CameoText));
    final rect = tester.getRect(find.byKey(PrimaryButton.surfaceKey));
    expect(rect.width, closeTo(label.width + 2 * 24, 0.01));
    expect(rect.height, 56);
    expect(rect.center.dx, closeTo(393 / 2, 0.01));
  });

  testWidgets('변형 틴트 · 라벨 역할 (layout.primaryButton.\$roles)', (tester) async {
    _screenSize(tester);
    final palette = CameoPalette.light;
    for (final (variant, tint, label) in [
      (
        PrimaryButtonVariant.prominent,
        palette.backgroundNeutralInverse,
        palette.foregroundNeutralInverseBase,
      ),
      (
        PrimaryButtonVariant.secondary,
        palette.glassTintCompact,
        palette.foregroundNeutralBase,
      ),
      (
        PrimaryButtonVariant.destructive,
        palette.backgroundCriticalBase,
        palette.staticWhite,
      ),
    ]) {
      await tester.pumpWidget(
        _host(
          PrimaryButton(
            key: ValueKey(variant),
            label: 'A',
            onPress: () {},
            variant: variant,
          ),
        ),
      );
      expect(_tint(tester), tint, reason: '$variant');
      final text = tester.widget<CameoText>(find.byType(CameoText));
      expect(text.color, label, reason: '$variant');
    }
  });

  testWidgets('비활성 → 활성: 진행값 스프링(smooth)으로 색 보간 · 비활성 중엔 누르지 못한다', (
    tester,
  ) async {
    _screenSize(tester);
    var presses = 0;
    final palette = CameoPalette.light;
    await tester.pumpWidget(
      _host(
        PrimaryButton(label: 'A', onPress: () => presses++, disabled: true),
      ),
    );
    expect(_tint(tester), palette.backgroundNeutralSubtle);
    await tester.tap(find.byType(PrimaryButton), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(presses, 0);

    await tester.pumpWidget(
      _host(PrimaryButton(label: 'A', onPress: () => presses++)),
    );
    await tester.pump(_frame);
    await tester.pump(const Duration(milliseconds: 60));
    final mid = _tint(tester);
    expect(mid, isNot(palette.backgroundNeutralSubtle));
    expect(mid, isNot(palette.backgroundNeutralInverse));
    await tester.pumpAndSettle();
    expect(_tint(tester), palette.backgroundNeutralInverse);
    await tester.tap(find.byType(PrimaryButton));
    await tester.pumpAndSettle();
    expect(presses, 1);
  });

  testWidgets('로딩: 라벨 labelFade(150 ms) 로 사라지고 점 3개가 사인으로 튄다 · 누르지 못한다', (
    tester,
  ) async {
    _screenSize(tester);
    var presses = 0;
    await tester.pumpWidget(
      _host(PrimaryButton(label: '인증번호 받기', onPress: () => presses++)),
    );
    expect(_labelOpacity(tester), 1);
    await tester.pumpWidget(
      _host(
        PrimaryButton(
          label: '인증번호 받기',
          onPress: () => presses++,
          loading: true,
        ),
      ),
    );
    await _run(tester, CameoMotion.primaryButtonLabelFade + _frame);
    expect(_labelOpacity(tester), 0);

    final d0 = tester.getRect(find.byKey(PrimaryButton.dotKey(0)));
    final d1 = tester.getRect(find.byKey(PrimaryButton.dotKey(1)));
    expect(d0.size, const Size(6, 6));
    expect(d1.left - d0.right, closeTo(6, 0.01));

    final ys = <double>{};
    for (var i = 0; i < 20; i++) {
      await tester.pump(_frame);
      ys.add(
        tester
            .widget<Transform>(find.byKey(PrimaryButton.dotKey(0)))
            .transform
            .getTranslation()
            .y,
      );
    }
    expect(ys.length, greaterThan(3));
    expect(ys.reduce((a, b) => a < b ? a : b), greaterThanOrEqualTo(-4.0001));
    await tester.tap(find.byType(PrimaryButton), warnIfMissed: false);
    await tester.pump(_frame);
    expect(presses, 0);

    await tester.pumpWidget(
      _host(PrimaryButton(label: '인증번호 받기', onPress: () => presses++)),
    );
    await _run(tester, CameoMotion.primaryButtonLabelFade + _frame * 2);
    expect(_labelOpacity(tester), 1);
    await tester.pumpAndSettle();
  });

  test('로딩 점 오프셋 = −rise · sin²(π · phase), 점 사이 120 ms', () {
    expect(primaryButtonDotOffset(0, Duration.zero), 0);
    expect(
      primaryButtonDotOffset(0, const Duration(milliseconds: 300)),
      closeTo(-CameoMotion.primaryButtonLoadingRise, 1e-9),
    );
    expect(
      primaryButtonDotOffset(0, const Duration(milliseconds: 150)),
      closeTo(-2, 1e-9),
    );

    expect(
      primaryButtonDotOffset(1, const Duration(milliseconds: 420)),
      closeTo(-CameoMotion.primaryButtonLoadingRise, 1e-9),
    );

    expect(
      primaryButtonDotOffset(2, const Duration(milliseconds: 100)),
      closeTo(
        primaryButtonDotOffset(2, const Duration(milliseconds: 700)),
        1e-9,
      ),
    );
  });

  testWidgets('Semantics: button · enabled · 로딩 중 라벨 + 처리 중', (tester) async {
    _screenSize(tester);
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(PrimaryButton(label: '다음', onPress: () {})));
    final node = tester.getSemantics(find.byType(PrimaryButton));
    expect(node.label, '다음');
    expect(node.flagsCollection.isButton, isTrue);
    expect(node.flagsCollection.isEnabled, isTrue);
    await tester.pumpWidget(
      _host(PrimaryButton(label: '다음', onPress: () {}, disabled: true)),
    );
    expect(
      tester.getSemantics(find.byType(PrimaryButton)).flagsCollection.isEnabled,
      isFalse,
    );
    await tester.pumpWidget(
      _host(PrimaryButton(label: '다음', onPress: () {}, loading: true)),
    );
    expect(tester.getSemantics(find.byType(PrimaryButton)).label, '다음, 처리 중');
    await tester.pumpWidget(const SizedBox());
    handle.dispose();
  });

  testWidgets('모션 감소: 색은 durationBase 페이드, 점은 제자리', (tester) async {
    _screenSize(tester);
    final palette = CameoPalette.light;
    await tester.pumpWidget(
      _host(
        PrimaryButton(label: 'A', onPress: () {}, disabled: true),
        reduceMotion: true,
      ),
    );
    await tester.pumpWidget(
      _host(PrimaryButton(label: 'A', onPress: () {}), reduceMotion: true),
    );
    await tester.pump(CameoMotion.durationBase + _frame);
    expect(_tint(tester), palette.backgroundNeutralInverse);
    await tester.pumpWidget(
      _host(
        PrimaryButton(label: 'A', onPress: () {}, loading: true),
        reduceMotion: true,
      ),
    );
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      expect(
        tester
            .widget<Transform>(find.byKey(PrimaryButton.dotKey(i)))
            .transform
            .getTranslation()
            .y,
        0,
      );
    }
  });
}
