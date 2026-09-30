// ignore_for_file: file_names
// Regression coverage for callControl bar. Preserve behavior, layout, and interaction
// expectations.

import 'package:cameo/components/call_control_bar.dart';
import 'package:cameo/design_system/design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const Size _screen = Size(393, 852);

void _screenSize(WidgetTester tester) {
  tester.view.physicalSize = _screen;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget _host(
  Widget bar, {
  double bottomPadding = 34,
  bool disableAnimations = false,
}) {
  return MediaQuery(
    data: MediaQueryData(
      size: _screen,
      padding: EdgeInsets.only(bottom: bottomPadding),
      disableAnimations: disableAnimations,
    ),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox.fromSize(
        size: _screen,
        child: Stack(children: [bar]),
      ),
    ),
  );
}

Finder get _container => find
    .descendant(of: find.byType(CallControlBar), matching: find.byType(Padding))
    .first;

Finder get _bar => find.byType(GlassSurface);

Finder _button(int i) => find.byType(PressScale).at(i);

FadeTransition _activeFade(WidgetTester tester, int i) => tester.widget(
  find.descendant(of: _button(i), matching: find.byType(FadeTransition)),
);

Rect _rect(WidgetTester tester, Finder f) => tester.getRect(f);

void main() {
  group('CallControlBar regular (2042:2460/2461)', () {
    testWidgets('컨테이너 393x112 @ y740 · 바 361x60 @ (16,756)', (tester) async {
      _screenSize(tester);
      await tester.pumpWidget(_host(const CallControlBar()));

      expect(_rect(tester, _container), const Rect.fromLTWH(0, 740, 393, 112));
      expect(_rect(tester, _bar), const Rect.fromLTWH(16, 756, 361, 60));
    });

    testWidgets('버튼 4 x 67.75x50 @ x21… · 종료 80x50 @ x292 · 아이콘 22', (
      tester,
    ) async {
      _screenSize(tester);
      await tester.pumpWidget(_host(const CallControlBar()));

      expect(find.byType(PressScale), findsNWidgets(5));
      const lefts = [21.0, 88.75, 156.5, 224.25];
      for (var i = 0; i < 4; i++) {
        expect(
          _rect(tester, _button(i)),
          Rect.fromLTWH(lefts[i], 761, 67.75, 50),
        );
      }
      expect(_rect(tester, _button(4)), const Rect.fromLTWH(292, 761, 80, 50));

      final icons = find.byType(CameoIcon);
      expect(icons, findsNWidgets(9));
      for (final e in icons.evaluate()) {
        expect(tester.getSize(find.byWidget(e.widget)), const Size(22, 22));
      }

      for (var i = 0; i < 5; i++) {
        final icon = find
            .descendant(of: _button(i), matching: find.byType(CameoIcon))
            .first;
        expect(tester.getCenter(icon), tester.getCenter(_button(i)));
      }
    });

    testWidgets(
      '글래스: blur glassBar · tint glass/tint-bar · border glass/border-bar(0.12) 1 · r999',
      (tester) async {
        _screenSize(tester);
        await tester.pumpWidget(_host(const CallControlBar()));
        final g = tester.widget<GlassSurface>(_bar);
        expect(g.effect, GlassEffect.glass);
        expect(g.blur, CameoBlur.glassBar);
        expect(g.tint, CameoColors.glassTintBar);

        expect(g.border, CameoColors.glassBorderBar);
        expect(g.border, isNot(CameoColors.glassBorder));
        expect(g.borderWidth, CameoLayout.callControlBarBarBorderWidth);
        expect(g.radius, CameoLayout.callControlBarBarRadius);
        expect(g.padding, EdgeInsets.all(CameoLayout.callControlBarBarPadding));
      },
    );

    testWidgets('하단 인셋 > 36 이면 pb = 인셋 (48 → 124)', (tester) async {
      _screenSize(tester);
      await tester.pumpWidget(_host(const CallControlBar(), bottomPadding: 48));
      expect(_rect(tester, _container), const Rect.fromLTWH(0, 728, 393, 124));
      expect(_rect(tester, _bar).top, 744);
      expect(callControlBarContainerHeight(bottomInset: 48), 124);
    });

    testWidgets('bottomInset 명시값이 MediaQuery 보다 우선', (tester) async {
      _screenSize(tester);
      await tester.pumpWidget(
        _host(const CallControlBar(bottomInset: 0), bottomPadding: 48),
      );
      expect(_rect(tester, _container), const Rect.fromLTWH(0, 740, 393, 112));
    });

    testWidgets('callControlBarContainerHeightOf = MediaQuery 하단 패딩 기준', (
      tester,
    ) async {
      _screenSize(tester);
      final heights = <double>[];
      Widget probe(double bottom) => _host(
        Builder(
          builder: (context) {
            heights
              ..add(callControlBarContainerHeightOf(context))
              ..add(
                callControlBarContainerHeightOf(
                  context,
                  variant: CallControlBarVariant.v1,
                ),
              );
            return const SizedBox();
          },
        ),
        bottomPadding: bottom,
      );
      await tester.pumpWidget(probe(34));
      await tester.pumpWidget(probe(48));
      expect(heights, [112, 110, 124, 122]);
    });

    testWidgets('positioned: false → Positioned 없이 부모 흐름 안에 배치', (
      tester,
    ) async {
      _screenSize(tester);
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: _screen,
            padding: EdgeInsets.only(bottom: 34),
          ),
          child: const Directionality(
            textDirection: TextDirection.ltr,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [CallControlBar(positioned: false)],
            ),
          ),
        ),
      );
      expect(find.byType(Positioned), findsNothing);
      expect(_rect(tester, _container), const Rect.fromLTWH(0, 740, 393, 112));
      expect(_rect(tester, _bar), const Rect.fromLTWH(16, 756, 361, 60));
    });

    testWidgets('onLayout → (top 740, height 112)', (tester) async {
      _screenSize(tester);
      final reports = <CallControlBarLayout>[];
      await tester.pumpWidget(_host(CallControlBar(onLayout: reports.add)));
      await tester.pump();
      expect(reports, [(top: 740.0, height: 112.0)]);

      await tester.pumpWidget(_host(CallControlBar(onLayout: reports.add)));
      await tester.pump();
      expect(reports.length, 1);
    });
  });

  group('CallControlBar v1 (2004:1798/1799)', () {
    testWidgets('컨테이너 393x110 @ y742 · 바 361x58 · 버튼 68.25 · 종료 @ x293', (
      tester,
    ) async {
      _screenSize(tester);
      await tester.pumpWidget(
        _host(const CallControlBar(variant: CallControlBarVariant.v1)),
      );

      expect(_rect(tester, _container), const Rect.fromLTWH(0, 742, 393, 110));
      expect(_rect(tester, _bar), const Rect.fromLTWH(16, 758, 361, 58));
      const lefts = [20.0, 88.25, 156.5, 224.75];
      for (var i = 0; i < 4; i++) {
        expect(
          _rect(tester, _button(i)),
          Rect.fromLTWH(lefts[i], 762, 68.25, 50),
        );
      }
      expect(_rect(tester, _button(4)), const Rect.fromLTWH(293, 762, 80, 50));
      for (final e in find.byType(CameoIcon).evaluate()) {
        expect(tester.getSize(find.byWidget(e.widget)), const Size(22, 22));
      }

      final g = tester.widget<GlassSurface>(_bar);
      expect(g.blur, CameoBlur.glassFigma);
      expect(g.tint, CameoColors.glassTintV1);
      expect(g.border, isNull);
      expect(g.borderWidth, 0);
      expect(
        callControlBarContainerHeight(
          variant: CallControlBarVariant.v1,
          bottomInset: 34,
        ),
        110,
      );
    });
  });

  group('토글 · 종료 · 접근성', () {
    testWidgets('탭 → onToggle(key) / onEndCall', (tester) async {
      _screenSize(tester);
      final toggled = <CallControlKey>[];
      var ended = 0;
      await tester.pumpWidget(
        _host(CallControlBar(onToggle: toggled.add, onEndCall: () => ended++)),
      );
      for (var i = 0; i < 5; i++) {
        await tester.tap(_button(i));
        await tester.pumpAndSettle();
      }
      expect(toggled, CallControlKey.values);
      expect(ended, 1);
    });

    testWidgets('active 변경 → 활성 아이콘 불투명도 0 → 1 (smooth 스프링)', (tester) async {
      _screenSize(tester);
      await tester.pumpWidget(_host(const CallControlBar()));
      expect(_activeFade(tester, 1).opacity.value, 0);

      await tester.pumpWidget(
        _host(
          const CallControlBar(active: CallControlActive(microphone: true)),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      final mid = _activeFade(tester, 1).opacity.value;
      expect(mid, greaterThan(0));
      expect(mid, lessThan(1));
      await tester.pumpAndSettle();
      expect(_activeFade(tester, 1).opacity.value, 1);
      expect(_activeFade(tester, 0).opacity.value, 0);
    });

    testWidgets('모션 감소 → durationBase 페이드', (tester) async {
      _screenSize(tester);
      await tester.pumpWidget(
        _host(const CallControlBar(), disableAnimations: true),
      );
      await tester.pumpWidget(
        _host(
          const CallControlBar(active: CallControlActive(camera: true)),
          disableAnimations: true,
        ),
      );

      await tester.pump(CameoMotion.durationBase);
      expect(_activeFade(tester, 2).opacity.value, 1);
      await tester.pump(const Duration(milliseconds: 1));
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('한국어 접근성 이름 (켜짐/꺼짐 포함)', (tester) async {
      _screenSize(tester);
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          CallControlBar(
            active: const CallControlActive(volume: true),
            onToggle: (_) {},
            onEndCall: () {},
          ),
        ),
      );
      for (final label in [
        '스피커, 켜짐',
        '마이크, 꺼짐',
        '카메라, 꺼짐',
        '15초 되감기, 꺼짐',
        '통화 종료',
      ]) {
        expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
      }
      handle.dispose();
    });

    testWidgets('콜백 있으면 button + tap · 없으면 비활성(역할·동작 없음)', (tester) async {
      _screenSize(tester);
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(CallControlBar(onToggle: (_) {}, onEndCall: () {})),
      );
      for (final label in ['마이크, 꺼짐', '통화 종료']) {
        expect(
          tester.getSemantics(find.bySemanticsLabel(label)),
          containsSemantics(label: label, isButton: true, hasTapAction: true),
          reason: label,
        );
      }

      await tester.pumpWidget(_host(const CallControlBar()));
      for (final label in ['마이크, 꺼짐', '통화 종료']) {
        expect(
          tester.getSemantics(find.bySemanticsLabel(label)),
          containsSemantics(label: label, isButton: false, hasTapAction: false),
          reason: label,
        );
      }
      handle.dispose();
    });

    testWidgets('연속 토글 · 애니메이션 도중 제거 — 예외·남은 티커 없음', (tester) async {
      _screenSize(tester);
      var a = CallControlActive.none;
      await tester.pumpWidget(_host(CallControlBar(active: a)));
      for (var i = 0; i < 5; i++) {
        a = a.toggled(CallControlKey.camera);
        await tester.pumpWidget(_host(CallControlBar(active: a)));
        await tester.pump(const Duration(milliseconds: 16));
      }

      await tester.pumpAndSettle();
      expect(_activeFade(tester, 2).opacity.value, 1);

      await tester.pumpWidget(
        _host(CallControlBar(active: a.toggled(CallControlKey.camera))),
      );
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
      expect(tester.hasRunningAnimations, isFalse);
    });

    test('CallControlActive.toggled / []', () {
      const a = CallControlActive.none;
      final b = a.toggled(CallControlKey.rewind);
      expect(b[CallControlKey.rewind], isTrue);
      expect(b.toggled(CallControlKey.rewind), a);
      expect(b, const CallControlActive(rewind: true));
    });
  });
}
