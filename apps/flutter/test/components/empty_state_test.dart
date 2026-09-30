// Regression coverage for empty state. Preserve behavior, layout, and interaction
// expectations.

import 'package:cameo/components/empty_state.dart';
import 'package:cameo/components/primary_button.dart';
import 'package:cameo/content/app.g.dart';
import 'package:cameo/design_system/design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

const Size _screen = Size(393, 852);

void _screenSize(WidgetTester tester) {
  tester.view.physicalSize = _screen;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget _host(Widget child) => MediaQuery(
  data: const MediaQueryData(size: _screen),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: CameoTheme(
      mode: CameoColorMode.light,
      child: Center(child: child),
    ),
  ),
);

void _expectGlassNeverFaded(WidgetTester tester) {
  for (final e in find.byType(LiquidGlass).evaluate()) {
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

void main() {
  testWidgets(
    '글래스 원 88 + users 32 · gap 16 · 제목 headingSm · 8 · 본문 bodyMd muted 가운데 · 24 · CTA hug 가운데',
    (tester) async {
      _screenSize(tester);
      var actions = 0;
      final e = appContent.home.empty;
      await tester.pumpWidget(
        _host(
          EmptyState(
            title: e.title,
            body: e.body,
            actionLabel: e.cta,
            onAction: () => actions++,
          ),
        ),
      );
      final circle = tester.getRect(find.byKey(EmptyState.circleKey));
      expect(circle.size, const Size(88, 88));
      expect(circle.center.dx, 393 / 2);
      final surface = tester.widget<GlassSurface>(
        find.descendant(
          of: find.byKey(EmptyState.circleKey),
          matching: find.byType(GlassSurface),
        ),
      );
      expect(surface.tint, CameoColors.backgroundNeutralSubtle);
      expect(find.byType(LiquidGlass), findsNWidgets(2));
      final icon = tester.widget<CameoIcon>(
        find.descendant(
          of: find.byKey(EmptyState.circleKey),
          matching: find.byType(CameoIcon),
        ),
      );
      expect(icon.name, CameoIconName.users);
      expect(icon.size, CameoLayout.emptyStateIconSize);
      final title = tester.getRect(find.byKey(EmptyState.titleKey));
      expect(title.top, circle.bottom + 16);
      expect(
        tester.widget<CameoText>(find.byKey(EmptyState.titleKey)).style,
        CameoTextStyles.headingSm,
      );
      final body = tester.getRect(find.byKey(EmptyState.bodyKey));
      expect(body.top, title.bottom + 8);
      final bodyText = tester.widget<CameoText>(find.byKey(EmptyState.bodyKey));
      expect(bodyText.color, CameoColors.foregroundNeutralMuted);
      expect(bodyText.textAlign, TextAlign.center);
      expect(body.left, greaterThanOrEqualTo(32));
      final action = tester.getRect(find.byKey(EmptyState.actionKey));
      expect(action.top, body.bottom + 24);
      expect(action.height, 56);
      expect(action.center.dx, closeTo(393 / 2, 0.01));
      final button = tester.widget<PrimaryButton>(
        find.byKey(EmptyState.actionKey),
      );
      expect(button.fullWidth, isFalse);
      expect(button.variant, PrimaryButtonVariant.prominent);
      await tester.tap(find.byKey(EmptyState.actionKey));
      await tester.pumpAndSettle();
      expect(actions, 1);
    },
  );

  testWidgets('actionLabel 이 없으면 버튼 없음', (tester) async {
    _screenSize(tester);
    await tester.pumpWidget(_host(const EmptyState(title: 'A', body: 'B')));
    expect(find.byType(PrimaryButton), findsNothing);
  });

  testWidgets(
    'entranceIndex: 원 · CTA(글래스) 는 이동만, 제목 · 본문은 페이드 + 상승 (같은 index)',
    (tester) async {
      _screenSize(tester);
      final e = appContent.home.empty;
      await tester.pumpWidget(
        _host(
          EmptyState(
            title: e.title,
            body: e.body,
            actionLabel: e.cta,
            onAction: () {},
            entranceIndex: 1,
          ),
        ),
      );
      double titleOpacity() => tester
          .widget<Opacity>(
            find
                .ancestor(
                  of: find.byKey(EmptyState.titleKey),
                  matching: find.byType(Opacity),
                )
                .first,
          )
          .opacity;
      double riseOf(Key key) => tester
          .widget<Transform>(
            find
                .ancestor(of: find.byKey(key), matching: find.byType(Transform))
                .last,
          )
          .transform
          .getTranslation()
          .y;
      expect(titleOpacity(), 0);
      expect(riseOf(EmptyState.circleKey), CameoMotion.staggerRise);
      for (var i = 0; i < 40; i++) {
        _expectGlassNeverFaded(tester);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pumpAndSettle();
      expect(titleOpacity(), 1);
      expect(riseOf(EmptyState.circleKey), closeTo(0, 1e-3));
    },
  );
}
