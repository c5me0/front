// Regression coverage for sms banner. Preserve behavior, layout, and interaction
// expectations.

import 'package:cameo/components/sms_banner.dart';
import 'package:cameo/design_system/design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

const Size _screen = Size(393, 852);
const Duration _frame = Duration(milliseconds: 16);
const String _body = '[cameo] 인증번호는 482913입니다.';

void _screenSize(WidgetTester tester) {
  tester.view.physicalSize = _screen;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget _host(Widget banner, {bool reduceMotion = false}) => MediaQuery(
  data: MediaQueryData(
    size: _screen,
    padding: const EdgeInsets.only(top: 59, bottom: 34),
    disableAnimations: reduceMotion,
  ),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: CameoTheme(
      mode: CameoColorMode.light,
      child: Stack(children: [Positioned.fill(child: banner)]),
    ),
  ),
);

SmsBannerState _state(WidgetTester tester) =>
    tester.state<SmsBannerState>(find.byType(SmsBanner));

Finder _cameoText(String text) =>
    find.byWidgetPredicate((w) => w is CameoText && w.text == text);

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
  test('숨김 거리 = top + 높이 + 16', () {
    expect(smsBannerHiddenOffset(top: 67, height: 80), 163);
  });

  testWidgets(
    '숨김이면 아무것도 그리지 않는다 → visible: 위에서 bouncy 로 내려와 top = safeTop + 8, 좌우 8',
    (tester) async {
      _screenSize(tester);
      await tester.pumpWidget(
        _host(const SmsBanner(visible: false, message: _body)),
      );
      expect(find.byKey(SmsBanner.bannerKey), findsNothing);
      await tester.pumpWidget(
        _host(const SmsBanner(visible: true, message: _body)),
      );

      expect(
        tester.getRect(find.byKey(SmsBanner.bannerKey)).bottom,
        lessThanOrEqualTo(-16 + 0.01),
      );
      var maxP = 0.0;
      for (var i = 0; i < 40; i++) {
        await tester.pump(_frame);
        if (_state(tester).progress > maxP) maxP = _state(tester).progress;
      }
      expect(maxP, greaterThan(1));
      await tester.pumpAndSettle();
      final rect = tester.getRect(find.byKey(SmsBanner.bannerKey));
      expect(rect.left, 8);
      expect(rect.width, 393 - 16);
      expect(rect.top, closeTo(59 + 8, 0.01));

      final icon = tester.getRect(find.byKey(SmsBanner.appIconKey));
      expect(icon.size, const Size(38, 38));
      expect(icon.left, 8 + 14);
      final surface = tester.widget<GlassSurface>(
        find.byKey(SmsBanner.bannerKey),
      );
      expect(surface.tint, CameoColors.glassTintPanel); // D15
      expect(surface.radius, CameoLayout.smsBannerRadius);
      expect(find.byType(LiquidGlass), findsOneWidget);

      final app = tester.widget<CameoText>(_cameoText('메시지'));
      expect(app.style, CameoTextStyles.bodySmStrong);
      final time = tester.widget<CameoText>(_cameoText('지금'));
      expect(time.color, CameoColors.foregroundNeutralMuted);
      expect(
        tester.getRect(_cameoText('지금')).right,
        closeTo(rect.right - 14, 0.01),
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('누르지 않으면 smsBannerVisible(6 s) 뒤 스스로 사라진다 → onDismiss 한 번', (
    tester,
  ) async {
    _screenSize(tester);
    var dismissed = 0;
    var visible = true;
    late StateSetter setOuter;
    await tester.pumpWidget(
      _host(
        StatefulBuilder(
          builder: (context, setState) {
            setOuter = setState;
            return SmsBanner(
              visible: visible,
              message: _body,
              onDismiss: () {
                dismissed++;
                setOuter(() => visible = false);
              },
            );
          },
        ),
      ),
    );

    await tester.pump(
      CameoMotion.smsBannerVisible - const Duration(milliseconds: 100),
    );
    expect(dismissed, 0);
    await tester.pump(const Duration(milliseconds: 200));
    expect(dismissed, 1);
    await tester.pumpAndSettle();
    expect(find.byKey(SmsBanner.bannerKey), findsNothing);
    expect(dismissed, 1);
  });

  testWidgets(
    '탭 → onPress · 부모가 visible false → smooth 로 위로 사라짐 (onDismiss 없음)',
    (tester) async {
      _screenSize(tester);
      var presses = 0;
      var dismissed = 0;
      await tester.pumpWidget(
        _host(
          SmsBanner(
            visible: true,
            message: _body,
            onPress: () => presses++,
            onDismiss: () => dismissed++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(SmsBanner.bannerKey));
      await tester.pump();
      expect(presses, 1);
      await tester.pumpWidget(
        _host(
          SmsBanner(
            visible: false,
            message: _body,
            onPress: () => presses++,
            onDismiss: () => dismissed++,
          ),
        ),
      );
      await tester.pump(_frame);
      await tester.pump(const Duration(milliseconds: 60));
      expect(_state(tester).progress, inExclusiveRange(0, 1));
      await tester.pumpAndSettle();
      expect(find.byKey(SmsBanner.bannerKey), findsNothing);
      expect(dismissed, 0);
    },
  );

  testWidgets('위로 스와이프 → onDismiss + 속도를 이어받아 사라짐 · 짧게 끌면 제자리로', (
    tester,
  ) async {
    _screenSize(tester);
    var dismissed = 0;
    var presses = 0;
    await tester.pumpWidget(
      _host(
        SmsBanner(
          visible: true,
          message: _body,
          onPress: () => presses++,
          onDismiss: () => dismissed++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final center = tester.getCenter(find.byKey(SmsBanner.bannerKey));
    final g = await tester.startGesture(center);
    for (var i = 0; i < 4; i++) {
      await g.moveBy(const Offset(0, -5));
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(_state(tester).dragOffset, closeTo(-20, 0.01));
    await tester.pump(const Duration(milliseconds: 200));
    await g.up();
    await tester.pumpAndSettle();
    expect(dismissed, 0);
    expect(presses, 0);
    expect(_state(tester).dragOffset, closeTo(0, 0.01));

    await tester.fling(
      find.byKey(SmsBanner.bannerKey),
      const Offset(0, -60),
      1500,
    );
    await tester.pump();
    expect(dismissed, 1);
    await tester.pumpAndSettle();
    expect(find.byKey(SmsBanner.bannerKey), findsNothing);
  });

  testWidgets('아래로 끌면 고무줄 (손가락보다 덜 움직인다)', (tester) async {
    _screenSize(tester);
    await tester.pumpWidget(
      _host(const SmsBanner(visible: true, message: _body)),
    );
    await tester.pumpAndSettle();
    final g = await tester.startGesture(
      tester.getCenter(find.byKey(SmsBanner.bannerKey)),
    );
    await g.moveBy(const Offset(0, 60));
    await tester.pump();
    expect(_state(tester).dragOffset, inExclusiveRange(0, 60));
    await g.up();
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('등장·퇴장은 이동만 — 글래스에 불투명도 애니메이션 없음 (매 프레임)', (tester) async {
    _screenSize(tester);
    await tester.pumpWidget(
      _host(const SmsBanner(visible: false, message: _body)),
    );
    await tester.pumpWidget(
      _host(const SmsBanner(visible: true, message: _body)),
    );
    for (var i = 0; i < 40; i++) {
      _expectGlassNeverFaded(tester);
      await tester.pump(_frame);
    }
    await tester.pumpWidget(
      _host(const SmsBanner(visible: false, message: _body)),
    );
    for (var i = 0; i < 40; i++) {
      _expectGlassNeverFaded(tester);
      await tester.pump(_frame);
    }
    await tester.pumpAndSettle();
    expect(find.byKey(SmsBanner.bannerKey), findsNothing);
  });

  testWidgets('모션 감소: 이동·페이드 없이 즉시 나타나고 사라진다', (tester) async {
    _screenSize(tester);
    await tester.pumpWidget(
      _host(
        const SmsBanner(visible: false, message: _body),
        reduceMotion: true,
      ),
    );
    await tester.pumpWidget(
      _host(const SmsBanner(visible: true, message: _body), reduceMotion: true),
    );
    await tester.pump();
    expect(_state(tester).progress, 1);
    expect(
      tester.getRect(find.byKey(SmsBanner.bannerKey)).top,
      closeTo(67, 0.01),
    );
    _expectGlassNeverFaded(tester);
    await tester.pumpWidget(
      _host(
        const SmsBanner(visible: false, message: _body),
        reduceMotion: true,
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byKey(SmsBanner.bannerKey), findsNothing);
  });

  testWidgets('Semantics: liveRegion · 라벨 · onTap', (tester) async {
    _screenSize(tester);
    final handle = tester.ensureSemantics();
    var presses = 0;
    await tester.pumpWidget(
      _host(
        SmsBanner(
          visible: true,
          message: _body,
          accessibilityLabel: '메시지, 인증번호 482913. 눌러서 자동 입력',
          onPress: () => presses++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final node = tester.getSemantics(
      find.bySemanticsLabel('메시지, 인증번호 482913. 눌러서 자동 입력'),
    );
    expect(node.flagsCollection.isLiveRegion, isTrue);
    tester.semantics.tap(find.semantics.byLabel('메시지, 인증번호 482913. 눌러서 자동 입력'));
    expect(presses, 1);
    await tester.pumpWidget(const SizedBox());
    handle.dispose();
  });
}
