// ignore_for_file: file_names
// Regression coverage for callParts toast. Preserve behavior, layout, and interaction
// expectations.

import 'package:cameo/components/toast.dart';
import 'package:cameo/content/lab.g.dart';
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
  Widget toast, {
  double controlBarHeight = CameoLayout.callControlBarContainerHeight,
  bool disableAnimations = false,
}) {
  return MediaQuery(
    data: MediaQueryData(size: _screen, disableAnimations: disableAnimations),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox.fromSize(
        size: _screen,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: toastBottom(controlBarHeight),
              child: toast,
            ),
          ],
        ),
      ),
    ),
  );
}

Finder get _container => find.byType(Toast);

Finder get _pill => find.descendant(
  of: _container,
  matching: find.byWidgetPredicate(
    (w) =>
        w is DecoratedBox &&
        w.decoration is BoxDecoration &&
        (w.decoration as BoxDecoration).border != null,
  ),
);

Finder get _icon =>
    find.descendant(of: _pill, matching: find.byType(CameoIcon));

Finder get _textWrap => find
    .ancestor(of: find.byType(CameoText), matching: find.byType(Padding))
    .first;

void _expectRect(Rect actual, Rect expected, {double eps = 0.001}) {
  expect(actual.left, closeTo(expected.left, eps), reason: 'left');
  expect(actual.top, closeTo(expected.top, eps), reason: 'top');
  expect(actual.width, closeTo(expected.width, eps), reason: 'width');
  expect(actual.height, closeTo(expected.height, eps), reason: 'height');
}

double _opacity(WidgetTester tester) => tester
    .widget<Opacity>(
      find.descendant(of: _container, matching: find.byType(Opacity)),
    )
    .opacity;

Toast _toast({
  String message = 'OK',
  CameoIconName icon = CameoIconName.borderNone,
  bool visible = true,
  VoidCallback? onHidden,
  int showKey = 0,
  ToastVariant variant = ToastVariant.regular,
  bool autoHide = true,
}) => Toast(
  message: message,
  icon: icon,
  visible: visible,
  onHidden: onHidden,
  showKey: showKey,
  variant: variant,
  autoHide: autoHide,
);

void main() {
  test('toastIconOf: 콘텐츠 키 → 아이콘, 모르는 키는 border-none', () {
    expect(
      toastIconOf(labInCall.toasts.systemMessage.icon),
      CameoIconName.borderNone,
    );
    expect(
      toastIconOf(labInCall.toasts.sleepModeRequest.icon),
      CameoIconName.moonFilled,
    );
    expect(toastIconOf('toString'), CameoIconName.borderNone);
    expect(toastIconOf('nope'), CameoIconName.borderNone);
    expect(
      toastBottom(CameoLayout.callControlBarContainerHeight),
      CameoLayout.callControlBarContainerHeight,
    );
  });

  group('Toast 레이아웃 regular (2042:2497/2498)', () {
    testWidgets(
      '컨테이너 393x77 @ y663 (= 852 − 112 − 77) · pill 200x45 (minWidth) 가운데',
      (tester) async {
        _screenSize(tester);
        await tester.pumpWidget(_host(_toast(autoHide: false)));
        await tester.pumpAndSettle();

        _expectRect(
          tester.getRect(_container),
          const Rect.fromLTWH(0, CameoLayout.toastFigmaTop, 393, 77),
        );
        expect(tester.getRect(_container).bottom, 852 - 112);

        _expectRect(
          tester.getRect(_pill),
          const Rect.fromLTWH(96.5, 679, 200, 45),
        );

        final deco =
            tester.widget<DecoratedBox>(_pill).decoration as BoxDecoration;
        expect(deco.color, CameoColors.backgroundCanvasBase);
        expect(
          deco.border,
          Border.all(color: CameoColors.strokeNeutralBase, width: 1.5),
        );
        expect(deco.borderRadius, BorderRadius.circular(999));
        expect(deco.boxShadow, const [CameoShadows.toastShadow]);
      },
    );

    testWidgets(
      '긴 문구: hug = 1.5 + 16 + 아이콘 18 + gap 2 + (4 + 텍스트 + 4) + 16 + 1.5',
      (tester) async {
        _screenSize(tester);
        await tester.pumpWidget(
          _host(
            _toast(
              message: labInCall.toasts.systemMessage.text,
              icon: toastIconOf(labInCall.toasts.systemMessage.icon),
              autoHide: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final pill = tester.getRect(_pill);
        final icon = tester.getRect(_icon);
        final wrap = tester.getRect(_textWrap);
        final text = tester.getRect(find.byType(CameoText));

        const eps = 0.01;
        expect(pill.height, closeTo(45, eps));
        expect(icon.size, const Size(18, 18));
        expect(icon.center.dy, closeTo(pill.center.dy, eps));
        expect(wrap.left - icon.right, closeTo(2, eps)); // gap 2
        expect(text.left - wrap.left, closeTo(4, eps));
        expect(wrap.right - text.right, closeTo(4, eps));
        expect(text.height, closeTo(18, eps)); // bodyMd 14/18
        expect(pill.width, greaterThan(CameoLayout.toastPillMinWidth));
        expect(icon.left - pill.left, closeTo(1.5 + 16, eps));
        expect(pill.right - wrap.right, closeTo(16 + 1.5, eps));
        expect(
          pill.width,
          closeTo(1.5 + 16 + 18 + 2 + 4 + text.width + 4 + 16 + 1.5, eps),
        );
        expect(tester.widget<CameoIcon>(_icon).name, CameoIconName.borderNone);
        expect(
          tester.widget<CameoText>(find.byType(CameoText)).style,
          CameoTextStyles.bodyMd,
        );
      },
    );

    testWidgets('아주 긴 문구는 한 줄로 잘리고 pill 은 361(= 393 − 2·16) 을 넘지 않는다', (
      tester,
    ) async {
      _screenSize(tester);
      await tester.pumpWidget(
        _host(_toast(message: 'x' * 200, autoHide: false)),
      );
      await tester.pumpAndSettle();
      _expectRect(tester.getRect(_pill), const Rect.fromLTWH(16, 679, 361, 45));
      expect(tester.widget<CameoText>(find.byType(CameoText)).maxLines, 1);
    });
  });

  group('Toast v1 (2004:1817/1818)', () {
    testWidgets('minWidth 없음(hug) · 컨테이너 @ y665 (= 852 − 110 − 77)', (
      tester,
    ) async {
      _screenSize(tester);
      await tester.pumpWidget(
        _host(
          _toast(
            icon: CameoIconName.moonFilled,
            variant: ToastVariant.v1,
            autoHide: false,
          ),
          controlBarHeight: CameoLayout.callControlBarV1ContainerHeight,
        ),
      );
      await tester.pumpAndSettle();

      _expectRect(
        tester.getRect(_container),
        const Rect.fromLTWH(0, CameoLayout.toastV1FigmaTop, 393, 77),
      );
      expect(tester.getRect(_container).bottom, 852 - 110);
      final text = tester.getSize(find.byType(CameoText));
      final pill = tester.getRect(_pill);
      expect(
        pill.width,
        closeTo(1.5 + 16 + 18 + 2 + 4 + text.width + 4 + 16 + 1.5, 0.01),
      );
      expect(pill.width, lessThan(CameoLayout.toastPillMinWidth));
      expect(pill.height, closeTo(45, 0.001));
      expect(pill.center.dx, closeTo(393 / 2, 0.001));
    });
  });

  group('Toast 모션 (motion.toast)', () {
    testWidgets(
      '등장: enterOffset 24 아래·투명 → bouncy(오버슛) → visibleMs 후 smooth 퇴장 → onHidden 1회',
      (tester) async {
        _screenSize(tester);
        var hidden = 0;
        await tester.pumpWidget(_host(_toast(onHidden: () => hidden++)));

        final restY = 679 + 45 / 2;
        expect(_opacity(tester), 0);
        expect(
          tester.getCenter(_pill).dy,
          restY + CameoMotion.toastEnterOffset,
        );
        expect(
          tester.getRect(_pill).size,
          const Size(200, 45) * CameoMotion.toastEnterScale,
        );

        var minY = double.infinity;
        for (var i = 0; i < 60; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          final y = tester.getCenter(_pill).dy;
          if (y < minY) minY = y;
        }
        expect(minY, lessThan(restY));
        await tester.pumpAndSettle();
        expect(_opacity(tester), 1);
        expect(tester.getCenter(_pill).dy, restY);
        expect(hidden, 0);

        await tester.pump(
          CameoMotion.toastVisible - const Duration(milliseconds: 1100),
        );
        expect(_opacity(tester), 1);
        await tester.pump(const Duration(milliseconds: 1100));
        await tester.pump(const Duration(milliseconds: 100));
        expect(_opacity(tester), lessThan(1));
        await tester.pumpAndSettle();
        expect(_opacity(tester), 0);
        expect(hidden, 1);
      },
    );

    testWidgets('visible=false → 즉시 퇴장, 끝나면 onHidden', (tester) async {
      _screenSize(tester);
      var hidden = 0;
      await tester.pumpWidget(_host(_toast(onHidden: () => hidden++)));
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        _host(_toast(visible: false, onHidden: () => hidden++)),
      );
      await tester.pumpAndSettle();
      expect(_opacity(tester), 0);
      expect(hidden, 1);

      await tester.pump(CameoMotion.toastVisible);
      expect(hidden, 1);
    });

    testWidgets('퇴장 중 재표시 → 현재 위치에서 다시 올라오고 onHidden 은 불리지 않는다', (
      tester,
    ) async {
      _screenSize(tester);
      var hidden = 0;
      Widget build({required bool visible}) => _host(
        _toast(visible: visible, onHidden: () => hidden++, autoHide: false),
      );
      await tester.pumpWidget(build(visible: true));
      await tester.pumpAndSettle();

      await tester.pumpWidget(build(visible: false));
      await tester.pump(const Duration(milliseconds: 120));
      final mid = _opacity(tester);
      expect(mid, inExclusiveRange(0, 1));

      await tester.pumpWidget(build(visible: true));

      expect(_opacity(tester), closeTo(mid, 0.05));
      await tester.pumpAndSettle();
      expect(_opacity(tester), 1);
      expect(hidden, 0);
    });

    testWidgets('퇴장 중 언마운트 → 예외·onHidden 없음', (tester) async {
      _screenSize(tester);
      var hidden = 0;
      await tester.pumpWidget(_host(_toast(onHidden: () => hidden++)));
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        _host(_toast(visible: false, onHidden: () => hidden++)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(CameoMotion.toastVisible);
      expect(tester.takeException(), isNull);
      expect(hidden, 0);
    });

    testWidgets('autoHide=false 면 visibleMs 뒤에도 유지', (tester) async {
      _screenSize(tester);
      await tester.pumpWidget(_host(_toast(autoHide: false)));
      await tester.pumpAndSettle();
      await tester.pump(CameoMotion.toastVisible * 2);
      await tester.pumpAndSettle();
      expect(_opacity(tester), 1);
    });

    testWidgets('모션 감소: 이동·스케일 없이 durationBase 페이드', (tester) async {
      _screenSize(tester);
      await tester.pumpWidget(
        _host(_toast(autoHide: false), disableAnimations: true),
      );
      final restY = 679 + 45 / 2;
      expect(tester.getCenter(_pill).dy, restY);
      expect(_opacity(tester), 0);
      await tester.pump(CameoMotion.durationBase ~/ 2);
      expect(tester.getCenter(_pill).dy, restY);
      expect(_opacity(tester), inExclusiveRange(0, 1));
      await tester.pump(CameoMotion.durationBase ~/ 2);
      expect(_opacity(tester), 1);
      expect(tester.getSize(_pill), const Size(200, 45));
    });

    testWidgets(
      'ToastController: 재표시는 처음부터 다시 시작(타이머 리셋), 숨김 후 visible=false',
      (tester) async {
        _screenSize(tester);
        final toast = ToastController();
        addTearDown(toast.dispose);
        await tester.pumpWidget(_host(ToastHost(controller: toast)));
        expect(_opacity(tester), 0);

        toast.showContent(labInCall.toasts.systemMessage);
        await tester.pumpAndSettle();
        expect(_opacity(tester), 1);
        expect(find.text('시스템 메시지입니다.'), findsOneWidget);
        expect(tester.widget<CameoIcon>(_icon).name, CameoIconName.borderNone);

        await tester.pump(const Duration(milliseconds: 500));
        expect(_opacity(tester), 1);
        toast.showContent(labInCall.toasts.sleepModeRequest);
        await tester.pump();
        expect(_opacity(tester), 0);
        expect(tester.widget<CameoIcon>(_icon).name, CameoIconName.moonFilled);
        await tester.pumpAndSettle();

        await tester.pump(const Duration(milliseconds: 500));
        expect(_opacity(tester), 1);
        expect(toast.visible, isTrue);

        await tester.pump(CameoMotion.toastVisible);
        await tester.pumpAndSettle();
        expect(_opacity(tester), 0);
        expect(toast.visible, isFalse);
      },
    );

    testWidgets('접근성: 보일 때만 문구를 liveRegion 으로 노출', (tester) async {
      _screenSize(tester);
      final handle = tester.ensureSemantics();
      final toast = ToastController();
      addTearDown(toast.dispose);
      await tester.pumpWidget(_host(ToastHost(controller: toast)));
      expect(find.semantics.byLabel('시스템 메시지입니다.'), findsNothing);

      toast.showContent(labInCall.toasts.systemMessage);
      await tester.pumpAndSettle();
      expect(find.semantics.byLabel('시스템 메시지입니다.'), findsOne);
      expect(
        tester.getSemantics(find.bySemanticsLabel('시스템 메시지입니다.')),
        matchesSemantics(label: '시스템 메시지입니다.', isLiveRegion: true),
      );

      await tester.pump(CameoMotion.toastVisible);
      await tester.pumpAndSettle();
      expect(find.semantics.byLabel('시스템 메시지입니다.'), findsNothing);
      handle.dispose();
    });
  });
}
