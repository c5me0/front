// Regression coverage for album gangneung screen. Preserve behavior, layout, and
// interaction expectations.

import 'package:cameo/components/album_hero.dart';
import 'package:cameo/components/glass_tab_bar.dart';
import 'package:cameo/components/nav_bar.dart';
import 'package:cameo/components/photo_grid.dart';
import 'package:cameo/components/quote_card.dart';
import 'package:cameo/content/lab.g.dart';
import 'package:cameo/design_system/design_system.dart';
import 'package:cameo/navigation/navigation.dart';
import 'package:cameo/screens/album_gangneung/album_gangneung_screen.dart';
import 'package:flutter/gestures.dart' show kPressTimeout;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const Size _screen = Size(393, 852);
const EdgeInsets _safeArea = EdgeInsets.only(top: 59, bottom: 34);

const double _tol = 0.01;

const double _gridTop = 393; // 2001:1131 y
const double _gridPadding = 6;
const double _cell = 74.6; // (393 − 12 − 8) / 5
const double _step = 76.6;
const double _featured = 151.2;
const double _cardTop = _gridTop + 465.6;
const double _cardHeight = 156;
const double _tabBarTop = 746; // 2001:1375
const double _contentHeight =
    _gridTop + 465.6 + _cardHeight + _gridPadding + 106; // 1126.6
const double _maxScroll = _contentHeight - 852; // 274.6

Widget _harness({
  double? initialScroll,
  bool disableAnimations = false,
  bool demo = false,
}) {
  return MediaQuery(
    data: MediaQueryData(
      size: _screen,
      padding: _safeArea,
      viewPadding: _safeArea,
      disableAnimations: disableAnimations,
    ),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: AlbumGangneungScreen(initialScroll: initialScroll, demo: demo),
    ),
  );
}

Future<GlobalKey<NavigatorState>> _pumpInNavigator(
  WidgetTester tester, {
  required List<String> pushed,
  bool home = false,
}) async {
  _setScreen(tester);
  final navigator = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(
        size: _screen,
        padding: _safeArea,
        viewPadding: _safeArea,
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Navigator(
          key: navigator,
          onGenerateInitialRoutes: (_, _) => [
            PageRouteBuilder<void>(
              pageBuilder: (_, _, _) => const SizedBox.expand(),
            ),
            PageRouteBuilder<void>(
              pageBuilder: (_, _, _) => AlbumGangneungScreen(home: home),
            ),
          ],
          onGenerateRoute: (settings) {
            pushed.add(settings.name ?? '?');
            return PageRouteBuilder<void>(
              settings: settings,
              pageBuilder: (_, _, _) => const SizedBox.expand(),
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
            );
          },
        ),
      ),
    ),
  );
  await tester.pump(const Duration(seconds: 2));
  await tester.pumpAndSettle();
  return navigator;
}

void _setScreen(WidgetTester tester) {
  tester.view
    ..physicalSize = _screen
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _pump(
  WidgetTester tester, {
  double? initialScroll,
  bool disableAnimations = false,
}) async {
  _setScreen(tester);
  await tester.pumpWidget(
    _harness(
      initialScroll: initialScroll,
      disableAnimations: disableAnimations,
    ),
  );
  await tester.pump(const Duration(seconds: 2));
  await tester.pumpAndSettle();
}

Finder _key(String key) => find.byKey(ValueKey(key));

Finder _photo(int i) => _key('photoGrid.photo.$i');

Future<void> _doubleTap(WidgetTester tester, Finder target) async {
  await tester.tap(target);
  await tester.pump(const Duration(milliseconds: 80));
  await tester.tap(target);
}

List<bool> _gridLiked(WidgetTester tester) =>
    tester.widget<PhotoGrid>(find.byType(PhotoGrid)).liked;

ScrollPosition _position(WidgetTester tester) =>
    tester.state<ScrollableState>(find.byType(Scrollable)).position;

Finder get _heroImage =>
    find.descendant(of: find.byType(AlbumHero), matching: find.byType(Image));

void _expectRect(Rect actual, double x, double y, double w, double h) {
  expect(actual.left, closeTo(x, _tol), reason: 'x of $actual');
  expect(actual.top, closeTo(y, _tol), reason: 'y of $actual');
  expect(actual.width, closeTo(w, _tol), reason: 'width of $actual');
  expect(actual.height, closeTo(h, _tol), reason: 'height of $actual');
}

final double _quoteLine =
    (CameoTextStyles.quote.fontSize! * CameoTextStyles.quote.height!)
        .roundToDouble();

double _quoteWrapExtra(WidgetTester tester) {
  var extra = 0.0;
  for (final line in labAlbumGangneung.quoteCard.lines) {
    final h = tester.getSize(find.byKey(ValueKey(line.nodeId))).height;
    final lines = (h / _quoteLine).round();
    expect(lines, greaterThanOrEqualTo(1));
    expect(
      h,
      closeTo(lines * _quoteLine, _tol),
      reason: 'line box ${line.text}',
    );
    extra += h - _quoteLine;
  }
  return extra;
}

void main() {
  group('Figma 위치 (393x852, 안전 영역 59/34)', () {
    testWidgets(
      '내비 compact 2001:1174: y 62 · 뒤로 46 원형 (16, 62) · pill 92x46 (285, 62)',
      (tester) async {
        await _pump(tester);
        final bar = tester.widget<NavBar>(find.byType(NavBar));
        expect(bar.variant, NavBarVariant.compact);
        _expectRect(
          tester.getRect(find.byType(GlassIconButton)),
          16,
          62,
          46,
          46,
        );
        _expectRect(
          tester.getRect(find.byType(GlassIconButtonGroup)),
          285,
          62,
          92,
          46,
        );

        _expectRect(
          tester.getRect(find.byKey(const ValueKey(CameoIconName.star))),
          285,
          62,
          46,
          46,
        );
        _expectRect(
          tester.getRect(find.byKey(const ValueKey(CameoIconName.dots))),
          331,
          62,
          46,
          46,
        );

        expect(
          find.byWidgetPredicate(
            (w) => w is CameoIcon && w.name == CameoIconName.chevronLeft,
          ),
          findsOneWidget,
        );
        expect(bar.actions.first.icon, CameoIconName.star);
        expect(bar.actions.first.activeIcon, CameoIconName.starFilled);
        expect(bar.actions.first.active, isFalse);
      },
    );

    testWidgets('히어로 2001:1128: (0, 0) 393x393 · 제목 y 317 h34 · 날짜 y 355 h22', (
      tester,
    ) async {
      await _pump(tester);
      _expectRect(tester.getRect(find.byType(AlbumHero)), 0, 0, 393, 393);
      final hero = tester.widget<AlbumHero>(find.byType(AlbumHero));
      expect(hero.gradient, AlbumHeroGradient.albumHeroGangneung);
      expect(hero.stats, isNull);
      final title = tester.getRect(find.text(labAlbumGangneung.title));
      expect(title.left, closeTo(16, _tol));
      expect(title.top, closeTo(317, _tol));
      expect(title.height, closeTo(34, _tol));
      final date = tester.getRect(find.text(labAlbumGangneung.date));
      expect(date.left, closeTo(16, _tol));
      expect(date.top, closeTo(355, _tol));
      expect(date.bottom, closeTo(377, _tol));

      _expectRect(tester.getRect(_heroImage), 0, 0, 393, 393);
    });

    testWidgets(
      '그리드 2001:1131: y 393 · 행 y 399 + r·76.6 · 셀 74.6 · 열 x 6 + c·76.6',
      (tester) async {
        await _pump(tester);
        final grid = tester.getRect(_key('photoGrid'));
        expect(grid.top, closeTo(_gridTop, _tol));
        expect(grid.width, closeTo(393, _tol));
        // 6 + 6 × 74.6 + 5 × 2 + 2 + 156 + 6 = 627.6
        expect(grid.height - _quoteWrapExtra(tester), closeTo(627.6, _tol));

        _expectRect(tester.getRect(_photo(1)), 159.2, 399, _cell, _cell);
        _expectRect(tester.getRect(_photo(3)), 312.4, 399, _cell, _cell);
        _expectRect(tester.getRect(_photo(4)), 159.2, 475.6, _cell, _cell);
        _expectRect(tester.getRect(_photo(7)), 6, 552.2, _cell, _cell);
        _expectRect(tester.getRect(_photo(19)), 6, 782, _cell, _cell);
        _expectRect(tester.getRect(_photo(23)), 312.4, 782, _cell, _cell);
        // r3c3 (Figma 2001:1…) = #15
        _expectRect(tester.getRect(_photo(14)), 235.8, 628.8, _cell, _cell);
        expect(_photo(24), findsNothing);
      },
    );

    testWidgets(
      '추천 타일 = 좋아요한 사진 #1 (6, 399) · #14 (82.6, 628.8) 151.2 + 하트 12 (inset 4)',
      (tester) async {
        await _pump(tester);
        _expectRect(tester.getRect(_photo(0)), 6, 399, _featured, _featured);
        _expectRect(
          tester.getRect(_photo(13)),
          6 + _step,
          399 + 3 * _step,
          _featured,
          _featured,
        );
        expect(_gridLiked(tester), [
          for (var i = 0; i < 24; i++) i == 0 || i == 13,
        ]);
        final badges = _key('photoGrid.badge');
        expect(badges, findsNWidgets(2));

        _expectRect(
          tester.getRect(badges.at(0)),
          6 + _featured - 4 - 12,
          399 + _featured - 4 - 12,
          12,
          12,
        );
      },
    );

    testWidgets('인용 카드 2015:1954: 그리드 footer, (6, 858.6) 381x156 (접힘 아래)', (
      tester,
    ) async {
      await _pump(tester);
      final card = find.byType(QuoteCard);
      expect(
        find.descendant(of: find.byType(PhotoGrid), matching: card),
        findsOneWidget,
      );
      final rect = tester.getRect(card);
      _expectRect(
        rect,
        6,
        _cardTop,
        381,
        _cardHeight + _quoteWrapExtra(tester),
      );
      expect(find.text(labAlbumGangneung.quoteCard.label), findsOneWidget);
    });

    testWidgets(
      '탭바 2001:1375: (0, 746) 393x106 · pill (16, 762) 361x54 · 탭 0 선택',
      (tester) async {
        await _pump(tester);
        _expectRect(
          tester.getRect(_key('glassTabBar.container')),
          0,
          _tabBarTop,
          393,
          106,
        );
        _expectRect(tester.getRect(_key('glassTabBar.pill')), 16, 762, 361, 54);
        _expectRect(
          tester.getRect(_key('glassTabBar.tab.0')),
          20,
          766,
          117,
          46,
        );
        _expectRect(
          tester.getRect(_key('glassTabBar.indicator')),
          20,
          766,
          117,
          46,
        );
        expect(
          tester.widget<GlassTabBar>(find.byType(GlassTabBar)).selectedIndex,
          labAlbumGangneung.tabBar.selectedIndex,
        );
      },
    );

    testWidgets('상태바·홈 인디케이터 목업을 그리지 않는다 — 텍스트 9:41 없음', (tester) async {
      await _pump(tester);
      expect(find.text('9:41'), findsNothing);
    });
  });

  group('스크롤', () {
    testWidgets(
      '본문 높이 = 1020.6 + 탭바 106 → 최대 스크롤 274.6, 끝에서 카드 아래 = 탭바 위 746',
      (tester) async {
        await _pump(tester);
        final position = _position(tester);
        expect(position.pixels, 0);
        expect(
          position.maxScrollExtent - _quoteWrapExtra(tester),
          closeTo(_maxScroll, _tol),
        );
        position.jumpTo(position.maxScrollExtent);
        await tester.pump();
        final card = tester.getRect(find.byType(QuoteCard));
        expect(card.bottom + _gridPadding, closeTo(_tabBarTop, _tol));

        expect(tester.getRect(find.byType(GlassIconButton)).top, 62);
        expect(tester.getRect(_key('glassTabBar.container')).top, _tabBarTop);
      },
    );

    testWidgets('드래그로 위로 스크롤 → 히어로 이미지 패럴랙스 (스크롤 × 0.5)', (tester) async {
      await _pump(tester);
      await tester.drag(find.byType(Scrollable), const Offset(0, -100));
      await tester.pumpAndSettle();
      final y = _position(tester).pixels;
      expect(y, greaterThan(0));
      final hero = tester.getRect(find.byType(AlbumHero));
      expect(hero.top, closeTo(-y, _tol));
      expect(
        tester.getRect(_heroImage).top - hero.top,
        closeTo(y * CameoMotion.heroParallax, _tol),
      );
    });

    testWidgets('당겨 내림(바운스) → 히어로 배경이 화면 맨 위(0)까지 늘어난다', (tester) async {
      await _pump(tester);
      final gesture = await tester.startGesture(const Offset(200, 300));
      await gesture.moveBy(const Offset(0, 40));
      await gesture.moveBy(const Offset(0, 80));
      await tester.pump();
      final y = _position(tester).pixels;
      expect(y, lessThan(0));
      expect(tester.getRect(find.byType(AlbumHero)).top, closeTo(-y, _tol));

      final backdrop = find
          .descendant(
            of: find.byType(AlbumHero),
            matching: find.byType(ClipRect),
          )
          .first;
      final box = tester.renderObject<RenderBox>(backdrop);
      final top = box.localToGlobal(Offset.zero).dy;
      final bottom = box.localToGlobal(Offset(0, box.size.height)).dy;
      expect(top, closeTo(0, _tol));
      expect(bottom, closeTo(-y + 393, _tol));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(_position(tester).pixels, 0);
    });

    testWidgets('모션 감소: 스크롤해도 히어로 이미지는 정지 (패럴랙스 없음)', (tester) async {
      await _pump(tester, disableAnimations: true);
      _position(tester).jumpTo(120);
      await tester.pump();
      final hero = tester.getRect(find.byType(AlbumHero));
      expect(hero.top, closeTo(-120, _tol));
      expect(tester.getRect(_heroImage).top, closeTo(hero.top, _tol));
    });
  });

  group('initialScroll (개발용 ?scroll=)', () {
    testWidgets('첫 프레임부터 그 위치 (점프 없음) · 패럴랙스도 같은 값', (tester) async {
      _setScreen(tester);
      await tester.pumpWidget(_harness(initialScroll: 200));

      expect(_position(tester).pixels, 200);
      expect(
        tester.getRect(find.byType(QuoteCard)).top,
        closeTo(_cardTop - 200, _tol),
      );
      final hero = tester.getRect(find.byType(AlbumHero));
      expect(hero.top, closeTo(-200, _tol));
      expect(tester.getRect(_heroImage).top - hero.top, closeTo(100, _tol));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(_position(tester).pixels, 200);
    });

    testWidgets('최대 스크롤보다 크면 첫 프레임부터 최대값(274.6) — 되튐·점프 없음', (tester) async {
      _setScreen(tester);
      await tester.pumpWidget(_harness(initialScroll: 5000));

      final position = _position(tester);
      expect(position.pixels, position.maxScrollExtent);
      expect(position.isScrollingNotifier.value, isFalse);
      expect(
        position.pixels - _quoteWrapExtra(tester),
        closeTo(_maxScroll, _tol),
      );
      expect(
        tester.getRect(find.byType(QuoteCard)).bottom + _gridPadding,
        closeTo(_tabBarTop, _tol),
      );

      await tester.pump(const Duration(milliseconds: 16));
      expect(position.pixels, closeTo(position.maxScrollExtent, _tol));

      final hero = tester.getRect(find.byType(AlbumHero));
      expect(hero.top, closeTo(-position.pixels, _tol));
      expect(
        tester.getRect(_heroImage).top - hero.top,
        closeTo(position.pixels * CameoMotion.heroParallax, _tol),
      );
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(position.pixels, closeTo(position.maxScrollExtent, _tol));
      expect(
        tester.getRect(_heroImage).top -
            tester.getRect(find.byType(AlbumHero)).top,
        closeTo(position.pixels * CameoMotion.heroParallax, _tol),
      );
    });

    testWidgets('null 이면 맨 위', (tester) async {
      await _pump(tester);
      expect(_position(tester).pixels, 0);
    });
  });

  group('인터랙션', () {
    testWidgets('별: star ↔ star-filled 토글 — 탭마다 켜짐/꺼짐 (접근성 라벨), heartPop', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester);
      expect(find.bySemanticsLabel('즐겨찾기, 꺼짐'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey(CameoIconName.star)));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('즐겨찾기, 켜짐'), findsOneWidget);
      expect(
        tester.widget<NavBar>(find.byType(NavBar)).actions.first.active,
        isTrue,
      );
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is ToggleIcon &&
              w.icon == CameoIconName.star &&
              w.activeIcon == CameoIconName.starFilled &&
              w.active,
        ),
        findsOneWidget,
      );

      expect(
        find.byWidgetPredicate(
          (w) => w is CameoIcon && w.name == CameoIconName.starFilled,
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey(CameoIconName.star)));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('즐겨찾기, 꺼짐'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is CameoIcon && w.name == CameoIconName.starFilled,
        ),
        findsNothing,
      );
      semantics.dispose();
    });

    testWidgets(
      '탭바: 설정(2) → 인디케이터가 그 탭으로 · 전화(1) → 통화 모달, 선택은 그대로 (v3-plan §2)',
      (tester) async {
        final pushed = <String>[];
        await _pumpInNavigator(tester, pushed: pushed);

        int selected() => tester
            .widget<GlassTabBar>(find.byType(GlassTabBar, skipOffstage: false))
            .selectedIndex;
        await tester.tap(_key('glassTabBar.tab.2'));
        await tester.pumpAndSettle();
        expect(selected(), 2);
        _expectRect(
          tester.getRect(_key('glassTabBar.indicator')),
          20 + 2 * (117 + 1),
          766,
          117,
          46,
        );
        expect(pushed, isEmpty);

        await tester.tap(_key('glassTabBar.tab.1'));
        await tester.pump();
        expect(pushed, [CameoRoutes.call()]);
        expect(pushed, ['/call']);
        expect(selected(), 2);
        await tester.pumpAndSettle();
      },
    );

    testWidgets('탭바 선택 표시: 탭 0 ↔ 2 인디케이터 이동 (Navigator 없이도 선택만)', (
      tester,
    ) async {
      await _pump(tester);
      await tester.tap(_key('glassTabBar.tab.2'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<GlassTabBar>(find.byType(GlassTabBar)).selectedIndex,
        2,
      );
      await tester.tap(_key('glassTabBar.tab.0'));
      await tester.pumpAndSettle();
      _expectRect(
        tester.getRect(_key('glassTabBar.indicator')),
        20,
        766,
        117,
        46,
      );
    });

    testWidgets('인용 카드 = 누름 피드백 (PressScale 수축) → 놓으면 기록 상세 dark', (
      tester,
    ) async {
      final pushed = <String>[];
      await _pumpInNavigator(tester, pushed: pushed);
      final position = _position(tester);
      position.jumpTo(position.maxScrollExtent);
      await tester.pump();
      final press = find.descendant(
        of: find.byType(QuoteCard),
        matching: find.byType(PressScale),
      );
      expect(press, findsOneWidget);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(QuoteCard)),
      );

      await tester.pump(kPressTimeout);
      await tester.pump(const Duration(milliseconds: 80));
      final scale = tester
          .widget<ScaleTransition>(
            find.descendant(of: press, matching: find.byType(ScaleTransition)),
          )
          .scale
          .value;
      expect(scale, lessThan(1));
      expect(pushed, isEmpty);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(pushed, ['/transcript?theme=dark']);
    });

    testWidgets('히어로 탭 → 16-6 앨범 (누름 피드백 + 버튼 라벨)', (tester) async {
      final pushed = <String>[];
      await _pumpInNavigator(tester, pushed: pushed);
      final hero = tester.widget<AlbumHero>(find.byType(AlbumHero));
      expect(hero.onPress, isNotNull);
      expect(hero.accessibilityLabel, '${labAlbumGangneung.title}, 날짜별 앨범 열기');
      final press = find.descendant(
        of: find.byType(AlbumHero),
        matching: find.byType(PressScale),
      );
      expect(press, findsOneWidget);
      await tester.tapAt(tester.getCenter(find.byType(AlbumHero)));
      await tester.pumpAndSettle();
      expect(pushed, ['/album']);
    });

    testWidgets(
      '홈(home: true, v3 호환) 뒤로 → Lab(/lab) 푸시 · 흐름 데모 gangneung.openAlbum 등록/해제',
      (tester) async {
        FlowDemo.resetForTesting();
        final pushed = <String>[];
        await _pumpInNavigator(tester, pushed: pushed, home: true);
        final back = tester.widget<NavBar>(find.byType(NavBar)).leading;
        expect(back.accessibilityLabel, '뒤로, 개발용 목록');
        await tester.tap(find.byType(GlassIconButton));
        await tester.pumpAndSettle();
        expect(pushed, ['/lab']);

        expect(FlowDemo.run(FlowDemoAction.gangneungOpenAlbum), isFalse);
        await tester.pumpAndSettle();
        expect(pushed, ['/lab']);
        tester.state<NavigatorState>(find.byType(Navigator)).pop();
        await tester.pumpAndSettle();

        expect(
          FlowDemo.isRegistered(FlowDemoAction.gangneungOpenAlbum),
          isTrue,
        );
        expect(FlowDemo.isRegistered(FlowDemoAction.homeOpenAlbum), isFalse);
        expect(FlowDemo.isRegistered(FlowDemoAction.tabsCamera), isFalse);
        expect(FlowDemo.run(FlowDemoAction.gangneungOpenAlbum), isTrue);
        await tester.pumpAndSettle();
        expect(pushed, ['/lab', '/album']);

        await tester.pumpWidget(const SizedBox());
        expect(
          FlowDemo.isRegistered(FlowDemoAction.gangneungOpenAlbum),
          isFalse,
        );
      },
    );

    testWidgets(
      'inTabs (v4 /albums/gangneung) — 자기 탭바 없음 · 아래 여백 106 유지 · 뒤로 = 자기 스택 pop',
      (tester) async {
        _setScreen(tester);
        final navigator = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(
              size: _screen,
              padding: _safeArea,
              viewPadding: _safeArea,
            ),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Navigator(
                key: navigator,
                onGenerateInitialRoutes: (_, _) => [
                  PageRouteBuilder<void>(
                    pageBuilder: (_, _, _) => const SizedBox.expand(),
                  ),
                  CameoPageRoute<void>(
                    builder: (_) => const AlbumGangneungScreen(inTabs: true),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
        expect(find.byType(GlassTabBar), findsNothing);
        final scroll = tester.widget<SingleChildScrollView>(
          find.byType(SingleChildScrollView),
        );
        expect(
          scroll.padding,
          const EdgeInsets.only(bottom: CameoLayout.tabBarContainerHeight),
        );
        final back = tester.widget<NavBar>(find.byType(NavBar)).leading;
        expect(back.accessibilityLabel, '뒤로');
        await tester.tap(find.byType(GlassIconButton).first);
        await tester.pumpAndSettle();
        expect(find.byType(AlbumGangneungScreen), findsNothing);
      },
    );

    testWidgets('사진 싱글탭 → 누름 피드백만 (화면 유지, 좋아요 그대로)', (tester) async {
      await _pump(tester);
      await tester.tap(_photo(0));
      await tester.pumpAndSettle();
      expect(find.byType(AlbumGangneungScreen), findsOneWidget);
      expect(_gridLiked(tester)[0], isTrue);
      expect(_gridLiked(tester)[3], isFalse);
    });

    testWidgets(
      '사진 #4 더블탭 → 2x2 @ r1c2 로 리플로우, 7행 → 인용 카드·최대 스크롤이 76.6 밀린다 (도중엔 사이)',
      (tester) async {
        await _pump(tester);
        final position = _position(tester);
        final maxBefore = position.maxScrollExtent;
        final cardBefore = tester.getRect(find.byType(QuoteCard)).top;
        final quoteExtra = _quoteWrapExtra(tester);
        expect(maxBefore - quoteExtra, closeTo(_maxScroll, _tol));

        await _doubleTap(tester, _photo(3));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 60));
        final cardMid = tester.getRect(find.byType(QuoteCard)).top;
        expect(cardMid, greaterThan(cardBefore + _tol));
        expect(cardMid, lessThan(cardBefore + _step - _tol));
        final mid = tester.getRect(_photo(3));
        expect(mid.width, greaterThan(_cell + _tol));
        expect(mid.width, lessThan(_featured - _tol));

        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
        expect(_gridLiked(tester)[3], isTrue);
        _expectRect(
          tester.getRect(_photo(3)),
          6 + 2 * _step,
          399 + _step,
          _featured,
          _featured,
        );

        _expectRect(
          tester.getRect(_photo(13)),
          6,
          399 + 4 * _step,
          _featured,
          _featured,
        );
        expect(
          tester.getRect(find.byType(QuoteCard)).top,
          closeTo(cardBefore + _step, _tol),
        );
        expect(position.maxScrollExtent, closeTo(maxBefore + _step, _tol));

        await _doubleTap(tester, _photo(3));
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
        _expectRect(tester.getRect(_photo(3)), 312.4, 399, _cell, _cell);
        expect(position.maxScrollExtent, closeTo(maxBefore, _tol));
      },
    );

    testWidgets('모션 감소: 더블탭 → 즉시 새 배치 (리플로우 없음)', (tester) async {
      await _pump(tester, disableAnimations: true);
      await _doubleTap(tester, _photo(3));
      await tester.pump();
      _expectRect(
        tester.getRect(_photo(3)),
        6 + 2 * _step,
        399 + _step,
        _featured,
        _featured,
      );
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
    });

    testWidgets(
      '데모 (?demo=1, spec §5): 1500 #4 좋아요 · 4000 #9 좋아요 · 6500 #4 취소',
      (tester) async {
        _setScreen(tester);
        await tester.pumpWidget(_harness(demo: true));
        bool liked(int n) => _gridLiked(tester)[n - 1];
        await tester.pump(const Duration(milliseconds: 1400));
        expect(liked(4), isFalse);
        await tester.pump(const Duration(milliseconds: 100));
        expect(liked(4), isTrue);

        await tester.pump(const Duration(milliseconds: 60));
        expect(tester.getRect(_photo(3)).width, greaterThan(_cell + _tol));
        await tester.pump(const Duration(milliseconds: 2440));
        expect(liked(9), isTrue);
        await tester.pump(const Duration(milliseconds: 2500));
        expect(liked(4), isFalse);
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
        expect(
          [
            for (var n = 1; n <= 24; n++)
              if (liked(n)) n,
          ],
          [1, 9, 14],
        );

        expect(tester.getRect(_photo(8)).width, closeTo(_featured, _tol));
      },
    );

    testWidgets('데모 없이는 타임라인이 돌지 않는다 · 도중 dispose 시 타이머가 남지 않는다', (
      tester,
    ) async {
      _setScreen(tester);
      await tester.pumpWidget(_harness());
      await tester.pump(const Duration(seconds: 7));
      expect(_gridLiked(tester).where((v) => v).length, 2);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(_harness(demo: true));
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 8));
      expect(tester.takeException(), isNull);
    });

    testWidgets('뒤로 → 라우트 pop', (tester) async {
      _setScreen(tester);
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: _screen,
            padding: _safeArea,
            viewPadding: _safeArea,
          ),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Navigator(
              key: navigator,
              onGenerateRoute: (_) => PageRouteBuilder<void>(
                pageBuilder: (_, _, _) => const SizedBox.expand(),
              ),
            ),
          ),
        ),
      );
      navigator.currentState!.push(
        PageRouteBuilder<void>(
          pageBuilder: (_, _, _) => const AlbumGangneungScreen(),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.byType(AlbumGangneungScreen), findsOneWidget);
      await tester.tap(find.byType(GlassIconButton));
      await tester.pumpAndSettle();
      expect(find.byType(AlbumGangneungScreen), findsNothing);
    });
  });
}
