// ignore_for_file: file_names
// Regression coverage for mediaCard widget. Preserve behavior, layout, and interaction
// expectations.

import 'package:cameo/components/media_card.dart';
import 'package:cameo/content/lab.g.dart';
import 'package:cameo/design_system/design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const double _screenW = 393;
const double _screenH = 852;
const double _controlBarTop = 740;
const double _cardW = 361;
const List<double> _figmaHeights = [203.0625, 270.75, 361];
const List<double> _figmaContainerTops = [505, 437, 347];
const double _eps = 1e-6;

const double _flingDistance = 50;

int _outerDrags = 0;

Widget _host(
  Widget child, {
  bool disableAnimations = false,
  double width = _screenW,
}) => MediaQuery(
  data: MediaQueryData(
    size: Size(width, _screenH),
    disableAnimations: disableAnimations,
  ),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,

      child: GestureDetector(
        onVerticalDragUpdate: (_) => _outerDrags += 1,
        child: SizedBox(
          width: width,
          height: _screenH,
          child: Stack(children: [child]),
        ),
      ),
    ),
  ),
);

Finder get _card => find.byKey(MediaCard.cardKey);

double _cardHeight(WidgetTester tester) => tester.getSize(_card).height;

double _cardOpacity(WidgetTester tester) => tester
    .widget<Opacity>(
      find.ancestor(of: _card, matching: find.byType(Opacity)).first,
    )
    .opacity;

void _setScreen(WidgetTester tester, {double width = _screenW}) {
  _outerDrags = 0;
  tester.view.physicalSize = Size(width, _screenH);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  test('mediaCardDetentHeights — 393 폭에서 Figma 높이 (aspectDetents 로 계산)', () {
    final h = mediaCardDetentHeights(_screenW);
    for (var i = 0; i < _figmaHeights.length; i += 1) {
      expect(h[i], closeTo(_figmaHeights[i], _eps), reason: 'detent $i');
    }
    expect(mediaCardDefaultBottomOffset, _screenH - _controlBarTop);
  });

  group('Figma 기하 (393×852, bottomOffset 기본 112)', () {
    for (var i = 0; i < _figmaHeights.length; i += 1) {
      testWidgets('detent $i → 카드 361×${_figmaHeights[i]} · 아래 724', (
        tester,
      ) async {
        _setScreen(tester);
        await tester.pumpWidget(_host(MediaCard(visible: true, detent: i)));
        final rect = tester.getRect(_card);
        expect(rect.width, closeTo(_cardW, _eps));
        expect(rect.height, closeTo(_figmaHeights[i], _eps));
        expect(rect.left, closeTo(16, _eps));

        expect(rect.bottom, closeTo(_controlBarTop - 16, _eps));

        expect(rect.top - 16, closeTo(_figmaContainerTops[i], 0.25 + _eps));
        expect(_cardOpacity(tester), 1);
      });
    }

    testWidgets('폭에 따라 높이가 바뀐다 (430 → 398 · 223.875 / 298.5 / 398)', (
      tester,
    ) async {
      _setScreen(tester, width: 430);
      await tester.pumpWidget(
        _host(const MediaCard(visible: true, detent: 1), width: 430),
      );
      expect(tester.getSize(_card), const Size(398, 298.5));
    });

    testWidgets('bottomOffset 은 컨테이너 아래 위치', (tester) async {
      _setScreen(tester);
      await tester.pumpWidget(
        _host(const MediaCard(visible: true, bottomOffset: 146)),
      );
      expect(tester.getRect(_card).bottom, closeTo(_screenH - 146 - 16, _eps));
    });

    testWidgets('visible: false → 높이 0, 터치·시맨틱 없음', (tester) async {
      _setScreen(tester);
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(const MediaCard(visible: false)));
      expect(_cardHeight(tester), 0);
      expect(find.bySemanticsLabel('미디어 카드'), findsNothing);
      handle.dispose();
    });
  });

  group('등장 · 퇴장 (enterSpring chewy)', () {
    testWidgets('visible false → true: 0 에서 자라며 오버슈트 후 디텐트 높이', (tester) async {
      _setScreen(tester);
      await tester.pumpWidget(_host(const MediaCard(visible: false)));
      await tester.pumpWidget(_host(const MediaCard(visible: true)));
      var maxH = 0.0;
      await tester.pump(const Duration(milliseconds: 16));
      final first = _cardHeight(tester);
      expect(first, greaterThan(0));
      expect(first, lessThan(_figmaHeights[0]));
      for (var t = 0; t < 60; t += 1) {
        await tester.pump(const Duration(milliseconds: 16));
        final h = _cardHeight(tester);
        if (h > maxH) maxH = h;
      }
      expect(maxH, greaterThan(_figmaHeights[0] + 1), reason: 'chewy 오버슈트');
      await tester.pumpAndSettle();
      expect(_cardHeight(tester), closeTo(_figmaHeights[0], _eps));

      expect(tester.getRect(_card).bottom, closeTo(_controlBarTop - 16, _eps));
    });

    testWidgets('visible true → false: 0 까지 줄어들고 튀어 오르지 않는다(클램프)', (
      tester,
    ) async {
      _setScreen(tester);
      await tester.pumpWidget(_host(const MediaCard(visible: true, detent: 2)));
      await tester.pumpWidget(
        _host(const MediaCard(visible: false, detent: 2)),
      );
      var prev = _cardHeight(tester);
      for (var t = 0; t < 60; t += 1) {
        await tester.pump(const Duration(milliseconds: 16));
        final h = _cardHeight(tester);
        expect(h, lessThanOrEqualTo(prev + _eps));
        expect(h, greaterThanOrEqualTo(0));
        prev = h;
      }
      await tester.pumpAndSettle();
      expect(_cardHeight(tester), 0);
    });

    testWidgets('detent prop 변경 → detentSpring 으로 이동, onDetentChange 없음', (
      tester,
    ) async {
      _setScreen(tester);
      final changes = <int>[];
      await tester.pumpWidget(
        _host(MediaCard(visible: true, onDetentChange: changes.add)),
      );
      await tester.pumpWidget(
        _host(MediaCard(visible: true, detent: 2, onDetentChange: changes.add)),
      );
      await tester.pump(const Duration(milliseconds: 16));
      expect(_cardHeight(tester), greaterThan(_figmaHeights[0]));
      await tester.pumpAndSettle();
      expect(_cardHeight(tester), closeTo(_figmaHeights[2], _eps));
      expect(changes, isEmpty);
    });
  });

  group('드래그 디텐트', () {
    testWidgets('천천히 위로 80 → 가장 가까운 4:3 (onDetentChange 1)', (tester) async {
      _setScreen(tester);
      final changes = <int>[];
      await tester.pumpWidget(
        _host(MediaCard(visible: true, onDetentChange: changes.add)),
      );
      await tester.timedDrag(
        _card,
        const Offset(0, -80),
        const Duration(seconds: 1),
      );
      await tester.pumpAndSettle();
      expect(changes, [1]);
      expect(_cardHeight(tester), closeTo(_figmaHeights[1], _eps));
      expect(_outerDrags, 0, reason: '카드 드래그가 바깥(모달) 드래그를 이긴다');
    });

    testWidgets('같은 짧은 거리를 천천히 → 가장 가까운 16:9 로 복귀', (tester) async {
      _setScreen(tester);
      final changes = <int>[];
      await tester.pumpWidget(
        _host(MediaCard(visible: true, onDetentChange: changes.add)),
      );
      await tester.timedDrag(
        _card,
        const Offset(0, -_flingDistance),
        const Duration(seconds: 1),
      );
      await tester.pumpAndSettle();
      expect(changes, isEmpty);
      expect(_cardHeight(tester), closeTo(_figmaHeights[0], _eps));
    });

    testWidgets('빠르게 위로 튕기면(≥ detentVelocity) 짧아도 다음 디텐트', (tester) async {
      _setScreen(tester);
      final changes = <int>[];
      await tester.pumpWidget(
        _host(MediaCard(visible: true, onDetentChange: changes.add)),
      );
      await tester.fling(
        _card,
        const Offset(0, -_flingDistance),
        CameoMotion.mediaCardDetentVelocity * 2,
      );
      await tester.pumpAndSettle();
      expect(changes, [1]);
      expect(_cardHeight(tester), closeTo(_figmaHeights[1], _eps));
    });

    testWidgets('1:1 에서 빠르게 아래로 → 4:3 (닫히지 않음)', (tester) async {
      _setScreen(tester);
      final changes = <int>[];
      var dismissed = 0;
      await tester.pumpWidget(
        _host(
          MediaCard(
            visible: true,
            detent: 2,
            onDetentChange: changes.add,
            onDismiss: () => dismissed += 1,
          ),
        ),
      );
      await tester.fling(
        _card,
        const Offset(0, _flingDistance),
        CameoMotion.mediaCardDetentVelocity * 2,
      );
      await tester.pumpAndSettle();
      expect(changes, [1]);
      expect(dismissed, 0);
      expect(_cardHeight(tester), closeTo(_figmaHeights[1], _eps));
    });

    testWidgets('가장 큰 디텐트 위로는 러버밴드 → 놓으면 복귀', (tester) async {
      _setScreen(tester);
      await tester.pumpWidget(_host(const MediaCard(visible: true, detent: 2)));
      final g = await tester.startGesture(tester.getCenter(_card));
      await g.moveBy(const Offset(0, -20));
      await g.moveBy(const Offset(0, -200));
      await tester.pump();
      final h = _cardHeight(tester);
      double band(double px) =>
          _cardW +
          (1 - 1 / (px / _cardW * CameoMotion.rubberBandCoefficient + 1)) *
              _cardW;

      expect(h, greaterThanOrEqualTo(band(200) - 1e-3));
      expect(h, lessThanOrEqualTo(band(202) + 1e-3));
      await g.up();
      await tester.pumpAndSettle();
      expect(_cardHeight(tester), closeTo(_figmaHeights[2], _eps));
    });
  });

  group('닫기', () {
    testWidgets('가장 작은 디텐트 아래로 임계 이상 → onDismiss, 카드는 바로 줄어든다', (tester) async {
      _setScreen(tester);
      var dismissed = 0;
      final changes = <int>[];
      Widget card(bool visible) => _host(
        MediaCard(
          visible: visible,
          onDetentChange: changes.add,
          onDismiss: () => dismissed += 1,
        ),
      );
      await tester.pumpWidget(card(true));
      await tester.timedDrag(
        _card,
        const Offset(0, 100),
        const Duration(seconds: 1),
      );
      expect(dismissed, 1);
      expect(_outerDrags, 0);

      await tester.pumpAndSettle();
      expect(_cardHeight(tester), 0);
      await tester.pumpWidget(card(false));
      await tester.pumpAndSettle();
      expect(_cardHeight(tester), 0);
      expect(changes, isEmpty);

      await tester.pumpWidget(card(true));
      await tester.pumpAndSettle();
      expect(_cardHeight(tester), closeTo(_figmaHeights[0], _eps));
    });

    testWidgets('빠르게 아래로 튕기면(속도 임계) 짧아도 닫힌다', (tester) async {
      _setScreen(tester);
      var dismissed = 0;
      await tester.pumpWidget(
        _host(MediaCard(visible: true, onDismiss: () => dismissed += 1)),
      );
      await tester.fling(
        _card,
        const Offset(0, _flingDistance),
        CameoMotion.transitionModalDismissVelocity * 2,
      );
      await tester.pumpAndSettle();
      expect(dismissed, 1);
      expect(_cardHeight(tester), 0);
    });

    testWidgets('onDismiss 가 없으면 같은 드래그도 원래 디텐트로 복귀', (tester) async {
      _setScreen(tester);
      await tester.pumpWidget(_host(const MediaCard(visible: true)));
      await tester.timedDrag(
        _card,
        const Offset(0, 100),
        const Duration(seconds: 1),
      );
      await tester.pumpAndSettle();
      expect(_cardHeight(tester), closeTo(_figmaHeights[0], _eps));
    });
  });

  group('모션 감소 (MediaQuery.disableAnimations)', () {
    testWidgets('등장 = 제자리 페이드 인, 퇴장 = 페이드 아웃 (스프링 없음)', (tester) async {
      _setScreen(tester);
      Widget card(bool visible, int detent) => _host(
        MediaCard(visible: visible, detent: detent),
        disableAnimations: true,
      );
      await tester.pumpWidget(card(false, 0));
      await tester.pumpWidget(card(true, 0));
      expect(_cardHeight(tester), closeTo(_figmaHeights[0], _eps));
      expect(_cardOpacity(tester), 0);
      await tester.pump(CameoMotion.durationBase ~/ 2);
      expect(_cardOpacity(tester), inExclusiveRange(0, 1));
      await tester.pumpAndSettle();
      expect(_cardOpacity(tester), 1);

      await tester.pumpWidget(card(true, 2));
      expect(_cardHeight(tester), closeTo(_figmaHeights[2], _eps));

      await tester.pumpWidget(card(false, 2));
      await tester.pump(CameoMotion.durationBase ~/ 2);
      expect(_cardHeight(tester), closeTo(_figmaHeights[2], _eps));
      expect(_cardOpacity(tester), inExclusiveRange(0, 1));
      await tester.pumpAndSettle();
      expect(_cardOpacity(tester), 0);
      expect(_cardHeight(tester), 0);
    });

    testWidgets('페이드 아웃 도중 다시 보이면 지금 불투명도에서 페이드 인 (0 으로 깜빡이지 않음)', (
      tester,
    ) async {
      _setScreen(tester);
      Widget card(bool visible) =>
          _host(MediaCard(visible: visible), disableAnimations: true);
      await tester.pumpWidget(card(true));
      await tester.pumpWidget(card(false));
      await tester.pump(CameoMotion.durationBase ~/ 2);
      final mid = _cardOpacity(tester);
      expect(mid, inExclusiveRange(0, 1));
      await tester.pumpWidget(card(true));
      expect(_cardOpacity(tester), closeTo(mid, _eps));
      expect(_cardHeight(tester), closeTo(_figmaHeights[0], _eps));
      await tester.pumpAndSettle();
      expect(_cardOpacity(tester), 1);
      expect(_cardHeight(tester), closeTo(_figmaHeights[0], _eps));
    });
  });

  testWidgets('드래그 도중 visible=false → 놓아도 무시, 다시 보이면 정상 등장·드래그', (
    tester,
  ) async {
    _setScreen(tester);
    final changes = <int>[];
    Widget card(bool visible) =>
        _host(MediaCard(visible: visible, onDetentChange: changes.add));
    await tester.pumpWidget(card(true));
    final g = await tester.startGesture(tester.getCenter(_card));
    await g.moveBy(const Offset(0, -20));
    await g.moveBy(const Offset(0, -40));
    await tester.pump();
    await tester.pumpWidget(card(false));
    await g.moveBy(const Offset(0, -40));
    await g.up();
    await tester.pumpAndSettle();
    expect(_cardHeight(tester), 0);
    expect(changes, isEmpty);
    await tester.pumpWidget(card(true));
    await tester.pumpAndSettle();
    expect(_cardHeight(tester), closeTo(_figmaHeights[0], _eps));
    await tester.timedDrag(
      _card,
      const Offset(0, -80),
      const Duration(seconds: 1),
    );
    await tester.pumpAndSettle();
    expect(changes, [1]);
  });

  testWidgets('접근성: 라벨·값·조절·닫기', (tester) async {
    _setScreen(tester);
    final handle = tester.ensureSemantics();
    final changes = <int>[];
    var dismissed = 0;
    await tester.pumpWidget(
      _host(
        MediaCard(
          visible: true,
          onDetentChange: changes.add,
          onDismiss: () => dismissed += 1,
        ),
      ),
    );
    expect(
      tester.getSemantics(_card),
      containsSemantics(
        label: '미디어 카드',
        value: '16:9',
        increasedValue: '4:3',
        hasIncreaseAction: true,
        hasDecreaseAction: false,
        hasDismissAction: true,

        hasScrollUpAction: false,
        hasScrollDownAction: false,
      ),
    );
    tester.semantics.increase(find.semantics.byLabel('미디어 카드'));
    await tester.pumpAndSettle();
    expect(changes, [1]);
    expect(_cardHeight(tester), closeTo(_figmaHeights[1], _eps));
    tester.semantics.dismiss(find.semantics.byLabel('미디어 카드'));
    await tester.pumpAndSettle();
    expect(dismissed, 1);
    expect(_cardHeight(tester), 0);
    handle.dispose();
  });

  group('image (v3-plan §3 — 카메라 캡처)', () {
    DecoratedBox fill(WidgetTester tester) => tester.widget<DecoratedBox>(
      find.descendant(of: _card, matching: find.byType(DecoratedBox)).first,
    );

    testWidgets('없으면 평면 채움만 (media/card, Figma 16-9…11)', (tester) async {
      _setScreen(tester);
      await tester.pumpWidget(_host(const MediaCard(visible: true)));
      final d = fill(tester).decoration as BoxDecoration;
      expect(d.image, isNull);
      expect(d.color, CameoColors.mediaCard);
    });

    testWidgets('있으면 cover 로 채우고 채움·모서리는 그대로 · 디텐트가 바뀌어도 같은 사진', (
      tester,
    ) async {
      _setScreen(tester);
      const image = AssetImage(LabImages.cameraPlaceholder);
      await tester.pumpWidget(
        _host(const MediaCard(visible: true, image: image)),
      );
      var d = fill(tester).decoration as BoxDecoration;
      expect(d.image?.image, image);
      expect(d.image?.fit, BoxFit.cover);
      expect(d.color, CameoColors.mediaCard);
      expect(
        d.borderRadius,
        const BorderRadius.all(
          Radius.circular(CameoLayout.mediaCardCardRadius),
        ),
      );
      expect(_cardHeight(tester), closeTo(_figmaHeights[0], _eps));

      await tester.pumpWidget(
        _host(const MediaCard(visible: true, detent: 2, image: image)),
      );
      await tester.pumpAndSettle();
      d = fill(tester).decoration as BoxDecoration;
      expect(d.image?.image, image);
      expect(_cardHeight(tester), closeTo(_figmaHeights[2], 0.01));
    });
  });
}
