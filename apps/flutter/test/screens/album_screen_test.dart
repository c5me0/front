// Regression coverage for album screen. Preserve behavior, layout, and interaction
// expectations.

import 'package:cameo/components/album_hero.dart';
import 'package:cameo/components/album_section.dart';
import 'package:cameo/components/call_history_card.dart';
import 'package:cameo/components/call_history_list.dart';
import 'package:cameo/components/meta_row.dart';
import 'package:cameo/components/nav_bar.dart';
import 'package:cameo/components/photo_grid.dart';
import 'package:cameo/components/text_header.dart';
import 'package:cameo/content/lab.g.dart';
import 'package:cameo/design_system/design_system.dart';
import 'package:cameo/navigation/navigation.dart';
import 'package:cameo/screens/album/album_screen.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const double _w = 393;
const double _h = 852;
const double _safeTop = 59;
const double _safeBottom = 34;
const double _eps = 1e-3;

const double _contentHeight = 2002.4;
const double _maxScroll = _contentHeight - _h;

void _iphone16(WidgetTester tester, {bool disableAnimations = false}) {
  tester.view.physicalSize = const Size(_w, _h);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(
    top: _safeTop,
    bottom: _safeBottom,
  );
  tester.view.viewPadding = const FakeViewPadding(
    top: _safeTop,
    bottom: _safeBottom,
  );
  addTearDown(tester.view.reset);
  if (disableAnimations) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }
}

Widget _app({double? initialScroll, List<String>? pushed, bool demo = false}) {
  return WidgetsApp(
    color: CameoColors.backgroundCanvasBase,
    textStyle: CameoTextStyles.bodyMd,
    onGenerateInitialRoutes: (_) => [
      CameoPageRoute<void>(
        builder: (_) => const ColoredBox(
          key: ValueKey('below'),
          color: CameoColors.backgroundCanvasBase,
        ),
      ),
      CameoPageRoute<void>(
        builder: (_) => AlbumScreen(initialScroll: initialScroll, demo: demo),
      ),
    ],
    onGenerateRoute: (settings) {
      pushed?.add(settings.name ?? '?');
      return CameoPageRoute<void>(
        settings: settings,
        builder: (_) =>
            const ColoredBox(color: CameoColors.backgroundCanvasBase),
      );
    },
  );
}

Future<void> _pumpSettled(
  WidgetTester tester, {
  double? initialScroll,
  List<String>? pushed,
}) async {
  await tester.pumpWidget(_app(initialScroll: initialScroll, pushed: pushed));
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpAndSettle();
}

void _expectRect(Rect actual, Rect expected, [String? what]) {
  final w = what == null ? '' : '$what ';
  expect(actual.left, closeTo(expected.left, _eps), reason: '${w}left');
  expect(actual.top, closeTo(expected.top, _eps), reason: '${w}top');
  expect(actual.width, closeTo(expected.width, _eps), reason: '${w}width');
  expect(actual.height, closeTo(expected.height, _eps), reason: '${w}height');
}

Rect _rect(WidgetTester tester, Finder f) => tester.getRect(f);

Finder _section(AlbumSectionBackground bg) =>
    find.byWidgetPredicate((w) => w is AlbumSection && w.background == bg);

Finder _card(String nodeId) => find.byKey(ValueKey(nodeId));

Finder _photoIn(Finder grid, int i) => find.descendant(
  of: grid,
  matching: find.byKey(ValueKey('photoGrid.photo.$i')),
);

Finder get _sungsuGrid => find.byKey(const ValueKey('photoGrid')).first;
Finder get _section3Grid => find.byKey(const ValueKey('photoGrid')).last;

List<bool> _likedOf(WidgetTester tester, Finder grid) => tester
    .widget<PhotoGrid>(
      find.ancestor(of: grid, matching: find.byType(PhotoGrid)),
    )
    .liked;

Future<void> _doubleTap(WidgetTester tester, Finder target) async {
  await tester.tap(target);
  await tester.pump(const Duration(milliseconds: 80));
  await tester.tap(target);
}

ScrollPosition _position(WidgetTester tester) => tester
    .state<ScrollableState>(
      find.descendant(
        of: find.byKey(AlbumScreen.scrollKey),
        matching: find.byType(Scrollable),
      ),
    )
    .position;

double _opacityIn(WidgetTester tester, Finder f) => tester
    .widget<Opacity>(
      find.descendant(of: f, matching: find.byType(Opacity)).first,
    )
    .opacity;

SystemUiOverlayStyle? _statusBarStyle(WidgetTester tester) {
  final layer = tester.binding.renderViews.first.debugLayer!;
  return layer.find<SystemUiOverlayStyle>(const Offset(_w / 2, _safeTop / 2));
}

GlassIconButtonGroupItem _heartItem(WidgetTester tester) => tester
    .widget<GlassIconButtonGroup>(find.byType(GlassIconButtonGroup))
    .items
    .first;

void main() {
  final sungsu = labAlbumDay.sections[0];
  final emptyPhoto = labAlbumDay.sections[1];
  final section3 = labAlbumDay.sections[2];

  test('content sections in plan order', () {
    expect(sungsu.id, 'sungsu');
    expect(emptyPhoto.id, 'empty-photo');
    expect(section3.id, 'section-3');
  });

  group('Figma 2028:435 (393 × 852) · 2028:764 y/크기', () {
    testWidgets('고정 내비: 뒤로 56 @ (16, 62) · 하트/히스토리 pill 106 × 56 @ (271, 62)', (
      tester,
    ) async {
      _iphone16(tester);
      await _pumpSettled(tester);

      _expectRect(
        _rect(tester, find.byType(GlassIconButton)),
        const Rect.fromLTWH(16, 62, 56, 56),
        'back',
      );
      _expectRect(
        _rect(tester, find.byType(GlassIconButtonGroup)),
        const Rect.fromLTWH(_w - 16 - 106, 62, 106, 56),
        'pill',
      );

      _position(tester).jumpTo(600);
      await tester.pump();
      _expectRect(
        _rect(tester, find.byType(GlassIconButton)),
        const Rect.fromLTWH(16, 62, 56, 56),
        'back after scroll',
      );
    });

    testWidgets(
      '섹션 1: 히어로 0…393 · 제목 317 · 메타 359 · 카드 401/485/569 · 그리드 653…1121.8',
      (tester) async {
        _iphone16(tester);
        await _pumpSettled(tester);

        _expectRect(
          _rect(tester, _section(AlbumSectionBackground.section1)),
          const Rect.fromLTWH(0, 0, _w, 1121.8),
          'section 1',
        );
        _expectRect(
          _rect(tester, find.byType(AlbumHero).first),
          const Rect.fromLTWH(0, 0, _w, 393),
          'hero',
        );
        final title = _rect(tester, find.text(sungsu.title));
        expect(title.left, closeTo(16, _eps));
        expect(title.top, closeTo(317, _eps));
        expect(title.height, closeTo(34, _eps));
        _expectRect(
          _rect(tester, find.byType(MetaRow).first),
          const Rect.fromLTWH(16, 359, 361, 18),
          'meta',
        );

        const cardTops = [401.0, 485.0, 569.0];
        for (final (i, card) in sungsu.callCards.indexed) {
          _expectRect(
            _rect(tester, _card(card.nodeId)),
            Rect.fromLTWH(8, cardTops[i], 377, 76),
            'card ${card.nodeId}',
          );
        }

        final grid = find.byKey(const ValueKey('photoGrid')).first;
        _expectRect(
          _rect(tester, grid),
          const Rect.fromLTWH(0, 653, _w, 468.8),
          'grid',
        );
        _expectRect(
          _rect(tester, _photoIn(grid, 0)),
          const Rect.fromLTWH(8, 661, 73.8, 73.8),
          'photo #1',
        );
        _expectRect(
          _rect(tester, _photoIn(grid, 29)),
          const Rect.fromLTWH(8 + 4 * 75.8, 661 + 5 * 75.8, 73.8, 73.8),
          'photo #30',
        );
        expect(
          find.descendant(
            of: grid,
            matching: find.byWidgetPredicate(
              (w) =>
                  w.key is ValueKey<String> &&
                  (w.key! as ValueKey<String>).value.startsWith(
                    'photoGrid.photo.',
                  ),
            ),
          ),
          findsNWidgets(30),
        );
      },
    );

    testWidgets(
      "'empty photo': 1121.8…1429.8 · 헤더 124 · 제목 1169.8 · 카드 1253.8/1337.8",
      (tester) async {
        _iphone16(tester);
        await _pumpSettled(tester);

        _expectRect(
          _rect(tester, _section(AlbumSectionBackground.canvasMuted)),
          const Rect.fromLTWH(0, 1121.8, _w, 308),
          'section 2',
        );
        _expectRect(
          _rect(tester, find.byType(TextHeader)),
          const Rect.fromLTWH(0, 1121.8, _w, 124),
          'text header',
        );
        final title = _rect(
          tester,
          find.descendant(
            of: find.byType(TextHeader),
            matching: find.text(emptyPhoto.title),
          ),
        );
        expect(title.top, closeTo(1121.8 + 48, _eps));
        expect(title.height, closeTo(34, _eps));
        _expectRect(
          _rect(
            tester,
            find.descendant(
              of: find.byType(TextHeader),
              matching: find.byType(MetaRow),
            ),
          ),
          const Rect.fromLTWH(16, 1121.8 + 90, 361, 18),
          'meta',
        );
        const cardTops = [1253.8, 1337.8];
        for (final (i, card) in emptyPhoto.callCards.indexed) {
          _expectRect(
            _rect(tester, _card(card.nodeId)),
            Rect.fromLTWH(8, cardTops[i], 377, 76),
            'card ${card.nodeId}',
          );
        }
      },
    );

    testWidgets(
      '섹션 3: 1429.8…2002.4 · 히어로 393 · 고정 셀 2 @ 1830.8 · 빈 프레임 89.8',
      (tester) async {
        _iphone16(tester);
        await _pumpSettled(tester);

        _expectRect(
          _rect(tester, _section(AlbumSectionBackground.section3)),
          const Rect.fromLTWH(0, 1429.8, _w, 572.6),
          'section 3',
        );
        _expectRect(
          _rect(tester, find.byType(AlbumHero).last),
          const Rect.fromLTWH(0, 1429.8, _w, 393),
          'hero 3',
        );

        final title = _rect(
          tester,
          find.descendant(
            of: find.byType(AlbumHero).last,
            matching: find.text(section3.title),
          ),
        );
        expect(title.left, closeTo(16, _eps));
        expect(title.top, closeTo(1429.8 + 317, _eps));
        expect(title.height, closeTo(34, _eps));
        _expectRect(
          _rect(
            tester,
            find.descendant(
              of: find.byType(AlbumHero).last,
              matching: find.byType(MetaRow),
            ),
          ),
          const Rect.fromLTWH(16, 1429.8 + 359, 361, 18),
          'meta 3',
        );
        final grid = find.byKey(const ValueKey('photoGrid')).last;
        _expectRect(
          _rect(tester, grid),
          const Rect.fromLTWH(0, 1822.8, _w, 89.8),
          'grid 3',
        );
        _expectRect(
          _rect(tester, _photoIn(grid, 0)),
          const Rect.fromLTWH(8, 1830.8, 73.8, 73.8),
          'photo #1',
        );
        _expectRect(
          _rect(tester, _photoIn(grid, 1)),
          const Rect.fromLTWH(83.8, 1830.8, 73.8, 73.8),
          'photo #2',
        );
        _expectRect(
          _rect(tester, find.byKey(AlbumScreen.spacerKey)),
          const Rect.fromLTWH(0, 1912.6, _w, 89.8),
          'spacer',
        );
        expect(_position(tester).maxScrollExtent, closeTo(_maxScroll, _eps));
      },
    );
  });

  testWidgets(
    'Figma 에 있는 요소만: 섹션 3 · 히어로 2 · 텍스트 헤더 1 · 카드 5 · 그리드 2(셀 32) · 내비 아이콘',
    (tester) async {
      _iphone16(tester);
      await _pumpSettled(tester);

      expect(
        tester
            .widgetList<AlbumSection>(find.byType(AlbumSection))
            .map((s) => s.background),
        [
          AlbumSectionBackground.section1,
          AlbumSectionBackground.canvasMuted,
          AlbumSectionBackground.section3,
        ],
      );
      final heroes = tester
          .widgetList<AlbumHero>(find.byType(AlbumHero))
          .toList();
      expect(heroes.map((h) => h.cover), [sungsu.cover, section3.cover]);
      expect(heroes.map((h) => h.gradient), [
        AlbumHeroGradient.albumHero,
        AlbumHeroGradient.albumHeroSection3,
      ]);
      expect(heroes.map((h) => h.stats), [sungsu.stats, section3.stats]);
      expect(find.byType(TextHeader), findsOneWidget);

      final lists = tester
          .widgetList<CallHistoryList>(find.byType(CallHistoryList))
          .toList();
      expect(lists.map((l) => l.tone), [
        CallHistoryListTone.onPhoto,
        CallHistoryListTone.light,
      ]);
      expect(lists.map((l) => l.cards), [
        sungsu.callCards,
        emptyPhoto.callCards,
      ]);
      expect(find.byType(CallHistoryCard), findsNWidgets(5));

      final grids = tester
          .widgetList<PhotoGrid>(find.byType(PhotoGrid))
          .toList();
      expect(grids.map((g) => g.variant), [
        PhotoGridVariant.bordered,
        PhotoGridVariant.bordered,
      ]);
      expect(grids.map((g) => g.photos), [
        [for (final p in sungsu.grid!.photos) p.image],
        [for (final p in section3.grid!.photos) p.image],
      ]);

      expect(grids.map((g) => g.liked.contains(true)), [false, false]);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>).value.startsWith('photoGrid.photo.'),
        ),
        findsNWidgets(32),
      );

      final navBar = tester.widget<NavBar>(find.byType(NavBar));
      expect(navBar.variant, NavBarVariant.regular);
      expect(navBar.tone, NavBarTone.dark);
      expect(navBar.leading.icon, CameoIconName.chevronLeft);
      expect(
        tester.widget<GlassIconButton>(find.byType(GlassIconButton)).icon,
        CameoIconName.chevronLeft,
      );
      expect(
        tester
            .widget<GlassIconButtonGroup>(find.byType(GlassIconButtonGroup))
            .items
            .map((i) => i.icon),
        [CameoIconName.heart, CameoIconName.history],
      );
    },
  );

  group('initialScroll (개발용)', () {
    testWidgets('1150.4 = 2028:764 의 바닥이 화면 바닥에 맞는다 (애니메이션 없음)', (
      tester,
    ) async {
      _iphone16(tester);
      await tester.pumpWidget(_app(initialScroll: _maxScroll));
      expect(_position(tester).pixels, closeTo(_maxScroll, _eps));
      await _pumpSettled(tester, initialScroll: _maxScroll);
      _expectRect(
        _rect(tester, find.byKey(AlbumScreen.spacerKey)),
        const Rect.fromLTWH(0, _h - 89.8, _w, 89.8),
        'spacer',
      );
      expect(
        _rect(tester, find.byKey(const ValueKey('photoGrid')).last).top,
        closeTo(1822.8 - _maxScroll, _eps),
      );
    });

    testWidgets('범위를 넘으면 첫 프레임에 최대 스크롤로 클램프 (되튐 없음)', (tester) async {
      _iphone16(tester);
      await tester.pumpWidget(_app(initialScroll: 5000));
      expect(_position(tester).pixels, closeTo(_maxScroll, _eps));
      await tester.pump(const Duration(milliseconds: 16));
      expect(_position(tester).pixels, closeTo(_maxScroll, _eps));
      await tester.pumpAndSettle();
      expect(_position(tester).pixels, closeTo(_maxScroll, _eps));
    });

    testWidgets('없으면 맨 위', (tester) async {
      _iphone16(tester);
      await _pumpSettled(tester);
      expect(_position(tester).pixels, 0);
    });
  });

  group('히어로 스크롤 (plan §4.3)', () {
    Finder heroImage() => find.descendant(
      of: find.byType(AlbumHero).first,
      matching: find.byType(Image),
    );

    testWidgets('위로 스크롤: 이미지 패럴랙스 = offset × motion.hero.parallax', (
      tester,
    ) async {
      _iphone16(tester);

      await tester.pumpWidget(_app(initialScroll: 100));
      expect(
        _rect(tester, heroImage()).top -
            _rect(tester, find.byType(AlbumHero).first).top,
        closeTo(100 * CameoMotion.heroParallax, _eps),
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      final hero = _rect(tester, find.byType(AlbumHero).first);
      expect(hero.top, closeTo(-100, _eps));
      expect(
        _rect(tester, heroImage()).top - hero.top,
        closeTo(100 * CameoMotion.heroParallax, _eps),
      );

      expect(
        find.byWidgetPredicate((w) => w is AlbumHero && w.scrollOffset != null),
        findsOneWidget,
      );
    });

    testWidgets('당겨 내림: 히어로 배경이 위쪽 기준으로 늘어나 화면 맨 위(0)까지 덮는다', (tester) async {
      _iphone16(tester);
      await _pumpSettled(tester);
      final gesture = await tester.startGesture(const Offset(_w / 2, 200));
      for (var i = 0; i < 6; i++) {
        await gesture.moveBy(const Offset(0, 30));
        await tester.pump();
      }
      final over = -_position(tester).pixels;
      expect(over, greaterThan(20));
      final hero = _rect(tester, find.byType(AlbumHero).first);
      expect(hero.top, closeTo(over, _eps));
      final image = _rect(tester, heroImage());
      expect(image.top, closeTo(0, _eps));
      expect(image.height, closeTo(393 + over, _eps));

      await gesture.up();
      await tester.pumpAndSettle();
      expect(_position(tester).pixels, 0);
    });

    testWidgets('모션 감소: 늘어나지 않고, 드러난 틈은 album/section-1 색 배경', (tester) async {
      _iphone16(tester, disableAnimations: true);
      await _pumpSettled(tester);
      final gesture = await tester.startGesture(const Offset(_w / 2, 200));
      for (var i = 0; i < 6; i++) {
        await gesture.moveBy(const Offset(0, 30));
        await tester.pump();
      }
      final over = -_position(tester).pixels;
      expect(over, greaterThan(20));
      final hero = _rect(tester, find.byType(AlbumHero).first);
      expect(_rect(tester, heroImage()).top, closeTo(hero.top, _eps));

      final boxes = tester
          .widgetList<ColoredBox>(
            find.descendant(
              of: find.byKey(AlbumScreen.backdropKey),
              matching: find.byType(ColoredBox),
            ),
          )
          .toList();
      expect(boxes.map((b) => b.color), [
        AlbumSectionBackground.section1.colorIn(CameoPalette.light),
        AlbumSectionBackground.section3.colorIn(CameoPalette.light),
      ]);
      final top = find
          .descendant(
            of: find.byKey(AlbumScreen.backdropKey),
            matching: find.byType(ColoredBox),
          )
          .first;
      _expectRect(
        _rect(tester, top),
        const Rect.fromLTWH(0, 0, _w, _h / 2),
        'backdrop top',
      );

      await gesture.up();
      await tester.pumpAndSettle();
    });
  });

  group('첫 등장 (plan §4.3)', () {
    testWidgets('카드 스태거(0…2) → 그리드 셀이 이어서(3…) · 아래 섹션은 정적', (tester) async {
      _iphone16(tester);
      await tester.pumpWidget(_app());

      final lists = tester
          .widgetList<CallHistoryList>(find.byType(CallHistoryList))
          .toList();
      expect(lists[0].appearIndex, 0);
      expect(lists[1].appearIndex, isNull);
      final grids = tester
          .widgetList<PhotoGrid>(find.byType(PhotoGrid))
          .toList();
      expect(grids[0].animateIn, isTrue);
      expect(grids[0].appearIndex, sungsu.callCards.length);
      expect(grids[1].animateIn, isFalse);

      final firstCard = _card(sungsu.callCards[0].nodeId);
      final lastCard = _card(sungsu.callCards[2].nodeId);
      final firstCell = _photoIn(
        find.byKey(const ValueKey('photoGrid')).first,
        0,
      );
      expect(_opacityIn(tester, firstCard), 0);

      await tester.pump(const Duration(milliseconds: 100));
      expect(_opacityIn(tester, firstCard), greaterThan(0));
      expect(_opacityIn(tester, firstCell), 0);

      await tester.pump(const Duration(milliseconds: 40));
      await tester.pump(const Duration(milliseconds: 16));
      expect(_opacityIn(tester, firstCell), greaterThan(0));

      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(_opacityIn(tester, firstCard), 1);
      expect(_opacityIn(tester, lastCard), 1);
      expect(_opacityIn(tester, firstCell), 1);
    });

    testWidgets('스태거 도중 화면을 내려도 타이머·컨트롤러가 남지 않는다', (tester) async {
      _iphone16(tester);
      await tester.pumpWidget(_app());
      await tester.pump(const Duration(milliseconds: 60));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(AlbumScreen), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('인터랙션 (plan §2)', () {
    testWidgets('사진 섹션 카드 → transcript photo (16-12, v3-plan §1 Q2)', (
      tester,
    ) async {
      _iphone16(tester);
      final pushed = <String>[];
      await _pumpSettled(tester, pushed: pushed);
      await tester.tap(_card(sungsu.callCards[0].nodeId));
      await tester.pumpAndSettle();
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      await tester.tap(_card(sungsu.callCards[2].nodeId));
      await tester.pumpAndSettle();
      final photo = CameoRoutes.transcript(theme: TranscriptTheme.photo);
      expect(photo, '/transcript?theme=photo');
      expect(pushed, [photo, photo]);
    });

    testWidgets("'empty photo' 카드 → transcript dark (16-13)", (tester) async {
      _iphone16(tester);
      final pushed = <String>[];
      await _pumpSettled(tester, initialScroll: 1000, pushed: pushed);
      await tester.tap(_card(emptyPhoto.callCards[1].nodeId));
      await tester.pumpAndSettle();
      expect(pushed, ['/transcript?theme=dark']);
    });

    test('섹션 tone → 기록 상세 테마 (RN transcriptThemeForSection 과 같은 표)', () {
      expect(transcriptThemeForSection(LabTone.dark), TranscriptTheme.photo);
      expect(transcriptThemeForSection(LabTone.light), TranscriptTheme.dark);
    });

    testWidgets(
      '흐름 데모 album.openPhotoCard = 사진 섹션 첫 카드 탭과 같은 이동 · dispose 시 해제',
      (tester) async {
        _iphone16(tester);
        final pushed = <String>[];
        await _pumpSettled(tester, pushed: pushed);
        expect(
          FlowDemo.isRegistered(FlowDemoAction.albumOpenPhotoCard),
          isTrue,
        );
        expect(FlowDemo.run(FlowDemoAction.albumOpenPhotoCard), isTrue);
        await tester.pumpAndSettle();
        expect(pushed, ['/transcript?theme=photo']);
        await tester.pumpWidget(const SizedBox());
        expect(
          FlowDemo.isRegistered(FlowDemoAction.albumOpenPhotoCard),
          isFalse,
        );
      },
    );

    testWidgets('하트 토글 · 히스토리는 누름 피드백만 · 뒤로 → pop', (tester) async {
      _iphone16(tester);
      final pushed = <String>[];
      await _pumpSettled(tester, pushed: pushed);

      expect(_heartItem(tester).active, isFalse);
      final pill = find.descendant(
        of: find.byType(GlassIconButtonGroup),
        matching: find.byType(GlassPressable),
      );
      await tester.tap(pill.first);
      await tester.pumpAndSettle();
      expect(_heartItem(tester).active, isTrue);
      expect(_heartItem(tester).activeIcon, CameoIconName.heartFilled);
      await tester.tap(pill.first);
      await tester.pumpAndSettle();
      expect(_heartItem(tester).active, isFalse);

      await tester.tap(pill.last);
      await tester.pumpAndSettle();
      expect(pushed, isEmpty);
      expect(find.byType(AlbumScreen), findsOneWidget);

      await tester.tap(find.byType(GlassIconButton));
      await tester.pumpAndSettle();
      expect(find.byType(AlbumScreen), findsNothing);
      expect(find.byKey(const ValueKey('below')), findsOneWidget);
    });
  });

  group('사진 좋아요 → 2x2 (interaction-spec §1)', () {
    testWidgets(
      '섹션 1 #5 (r0c4) 더블탭 → 2x2 @ r1c0, 7행 → 아래 섹션이 75.8 밀린다 (도중엔 사이) · 다시 더블탭 → 원래대로',
      (tester) async {
        _iphone16(tester);

        await _pumpSettled(tester, initialScroll: 400);
        final emptyPhoto = _section(AlbumSectionBackground.canvasMuted);
        final topBefore = _rect(tester, emptyPhoto).top;
        final maxBefore = _position(tester).maxScrollExtent;
        expect(maxBefore, closeTo(_maxScroll, _eps));
        final photo5 = _photoIn(_sungsuGrid, 4);

        _expectRect(
          _rect(tester, photo5),
          const Rect.fromLTWH(311.2, 261, 73.8, 73.8),
          'photo #5 before',
        );

        await _doubleTap(tester, photo5);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 60));
        final topMid = _rect(tester, emptyPhoto).top;
        expect(topMid, greaterThan(topBefore + _eps));
        expect(topMid, lessThan(topBefore + 75.8 - _eps));
        final mid = _rect(tester, photo5);
        expect(mid.width, greaterThan(73.8 + _eps));
        expect(mid.width, lessThan(149.6 - _eps));

        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
        expect(_likedOf(tester, _sungsuGrid)[4], isTrue);

        _expectRect(
          _rect(tester, photo5),
          const Rect.fromLTWH(8, 261 + 75.8, 149.6, 149.6),
          'photo #5 after',
        );
        expect(_rect(tester, emptyPhoto).top, closeTo(topBefore + 75.8, _eps));
        expect(
          _rect(tester, _section(AlbumSectionBackground.section1)).height,
          closeTo(1121.8 + 75.8, _eps),
        );
        expect(
          _position(tester).maxScrollExtent,
          closeTo(maxBefore + 75.8, _eps),
        );

        expect(
          find.descendant(
            of: photo5,
            matching: find.byKey(const ValueKey('photoGrid.badge')),
          ),
          findsOneWidget,
        );

        await _doubleTap(tester, photo5);
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
        expect(_likedOf(tester, _sungsuGrid)[4], isFalse);
        _expectRect(
          _rect(tester, photo5),
          const Rect.fromLTWH(311.2, 261, 73.8, 73.8),
          'photo #5 unliked',
        );
        expect(_rect(tester, emptyPhoto).top, closeTo(topBefore, _eps));
        expect(_position(tester).maxScrollExtent, closeTo(maxBefore, _eps));
      },
    );

    testWidgets('섹션 3 (고정 셀 2장) #2 더블탭 → 2x2 @ r0c1, 그리드 89.8 → 165.6', (
      tester,
    ) async {
      _iphone16(tester);
      await _pumpSettled(tester, initialScroll: _maxScroll);
      final photo2 = _photoIn(_section3Grid, 1);
      await _doubleTap(tester, photo2);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(_likedOf(tester, _section3Grid), [false, true]);
      final grid = _rect(tester, _section3Grid);

      expect(grid.height, closeTo(165.6, _eps));
      final tile = _rect(tester, photo2);
      expect(tile.left, closeTo(83.8, _eps));
      expect(tile.top - grid.top, closeTo(8, _eps));
      expect(tile.width, closeTo(149.6, _eps));
      expect(tile.height, closeTo(149.6, _eps));
    });
  });

  group('데모 (?demo=1, interaction-spec §5)', () {
    testWidgets(
      '1500 섹션 1 #5 좋아요 · 4000 #12 좋아요 · 6500 #5 취소 — 더블탭과 같은 상태 전이',
      (tester) async {
        _iphone16(tester);
        await tester.pumpWidget(_app(initialScroll: 600, demo: true));
        bool liked(int n) => _likedOf(tester, _sungsuGrid)[n - 1];
        await tester.pump(const Duration(milliseconds: 1400));
        expect(liked(5), isFalse);
        await tester.pump(const Duration(milliseconds: 100));
        expect(liked(5), isTrue);
        await tester.pump(const Duration(milliseconds: 60));
        expect(
          _rect(tester, _photoIn(_sungsuGrid, 4)).width,
          greaterThan(73.8 + _eps),
        );
        await tester.pump(const Duration(milliseconds: 2440));
        expect(liked(12), isTrue);
        await tester.pump(const Duration(milliseconds: 2500));
        expect(liked(5), isFalse);
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
        expect(
          [
            for (var n = 1; n <= 30; n++)
              if (liked(n)) n,
          ],
          [12],
        );
        expect(
          _rect(tester, _photoIn(_sungsuGrid, 11)).width,
          closeTo(149.6, _eps),
        );

        expect(_likedOf(tester, _section3Grid), [false, false]);
      },
    );

    testWidgets('도중에 화면을 내려도 데모 타이머가 남지 않는다', (tester) async {
      _iphone16(tester);
      await tester.pumpWidget(_app(demo: true));
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 8));
      expect(tester.takeException(), isNull);
    });
  });

  group('상태바 글리프 (상태바 가운데를 덮는 섹션)', () {
    Future<SystemUiOverlayStyle?> styleAt(
      WidgetTester tester,
      double scroll,
    ) async {
      _position(tester).jumpTo(scroll);
      await tester.pump();
      return _statusBarStyle(tester);
    }

    testWidgets('사진 섹션 = light · empty photo = dark', (tester) async {
      _iphone16(tester);
      await _pumpSettled(tester);
      expect(_statusBarStyle(tester), SystemUiOverlayStyle.light);

      expect(
        await styleAt(tester, 1121.8 - _safeTop / 2 - 1),
        SystemUiOverlayStyle.light,
      );

      expect(
        await styleAt(tester, 1121.8 - _safeTop / 2 + 1),
        SystemUiOverlayStyle.dark,
      );

      expect(await styleAt(tester, _maxScroll), SystemUiOverlayStyle.dark);

      expect(await styleAt(tester, 900), SystemUiOverlayStyle.light);
    });
  });
}
