// Regression coverage for album card. Preserve behavior, layout, and interaction
// expectations.

import 'package:cameo/components/album_card.dart';
import 'package:cameo/components/album_hero.dart';
import 'package:cameo/content/app.g.dart';
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

Widget _host(List<Widget> cards) => MediaQuery(
  data: const MediaQueryData(size: _screen),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: CameoTheme(
      mode: CameoColorMode.light,
      child: Stack(
        children: [
          Positioned(
            left: 16,
            right: 16,
            top: 134,
            child: Column(
              spacing: CameoLayout.homeScreenCardGap,
              children: cards,
            ),
          ),
        ],
      ),
    ),
  ),
);

void main() {
  test('albumCardDataFor: 강릉 = 16-3 히어로 · 성수 = 16-6 섹션 0 히어로', () {
    final albums = appContent.home.albums;
    final g = albumCardDataFor(albums[0]);
    expect(g.cover, labAlbumGangneung.cover);
    expect(g.title, labAlbumGangneung.title);
    expect(g.subtitle, labAlbumGangneung.date);
    expect(g.stats, isNull);
    expect(g.gradient, AlbumHeroGradient.albumHeroGangneung);
    final s = albumCardDataFor(albums[1]);
    final s0 = labAlbumDay.sections[0];
    expect(s.cover, s0.cover);
    expect(s.title, s0.title);
    expect(s.subtitle, s0.subtitle);
    expect(s.stats, same(s0.stats));
    expect(s.gradient, AlbumHeroGradient.albumHero);
    expect(
      () => albumCardDataFor(
        const AppContentHomeAlbum(id: 'x', source: 'nope', route: 'x'),
      ),
      throwsArgumentError,
    );
  });

  testWidgets(
    '카드 361 × 361 @ (16, 134) · AlbumHero 를 393 으로 그려 361/393 축소 (원점 왼쪽 위) · 반경 26 RSuperellipse 클립 · effect.shadow',
    (tester) async {
      _screenSize(tester);
      final data = albumCardDataFor(appContent.home.albums[0]);
      await tester.pumpWidget(_host([AlbumCard(data: data, onPress: (_) {})]));
      expect(
        tester.getRect(find.byKey(AlbumCard.cardKey)),
        const Rect.fromLTWH(16, 134, 361, 361),
      );

      final hero = tester.renderObject<RenderBox>(find.byType(AlbumHero));
      expect(hero.size, const Size(393, 393));

      expect(
        tester.getRect(find.byType(AlbumHero)),
        const Rect.fromLTWH(16, 134, 361, 361),
      );
      final fitted = tester.widget<FittedBox>(find.byKey(AlbumCard.heroKey));
      expect(fitted.alignment, Alignment.topLeft);

      final heroWidget = tester.widget<AlbumHero>(find.byType(AlbumHero));
      expect(heroWidget.cover, labAlbumGangneung.cover);
      expect(heroWidget.title, '강릉');
      expect(heroWidget.gradient, AlbumHeroGradient.albumHeroGangneung);
      expect(heroWidget.scrollOffset, isNull);
      expect(heroWidget.onPress, isNull);

      final clip = tester.widget<ClipRSuperellipse>(
        find.byKey(AlbumCard.clipKey),
      );
      expect(
        clip.borderRadius,
        BorderRadius.circular(CameoLayout.albumCardRadius),
      );
      final shadowBox = tester.widget<DecoratedBox>(
        find
            .ancestor(
              of: find.byKey(AlbumCard.clipKey),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final deco = shadowBox.decoration as ShapeDecoration;
      expect(deco.shadows, [CameoShadows.shadow]);
      expect(
        (deco.shape as RoundedSuperellipseBorder).borderRadius,
        BorderRadius.circular(26),
      );

      const s = 361 / 393;
      final heroTitle = tester.getTopLeft(
        find.byWidgetPredicate((w) => w is CameoText && w.text == '강릉'),
      );
      expect(
        heroTitle.dx,
        closeTo(16 + CameoLayout.albumHeroPadding * s, 1e-6),
      );
    },
  );

  test('albumCardScaledRect: 가운데 기준 축소 (RN scaledRect 와 같은 식)', () {
    const r = Rect.fromLTWH(16, 134, 361, 361);
    expect(albumCardScaledRect(r, 1), r);
    final s = albumCardScaledRect(r, 0.96);
    expect(s.center.dx, closeTo(r.center.dx, 1e-9));
    expect(s.center.dy, closeTo(r.center.dy, 1e-9));
    expect(s.width, closeTo(361 * 0.96, 1e-9));
    expect(s.left, closeTo(16 + 361 * 0.02, 1e-9));
    expect(s.top, closeTo(134 + 361 * 0.02, 1e-9));
  });

  testWidgets(
    '누름 → PressScale (0.96) → onPress(창 좌표 rect — 누른 순간 그려진 카드 = 레이아웃 상자를 누름 스케일로 가운데 기준 축소, Z2)',
    (tester) async {
      _screenSize(tester);
      final rects = <Rect>[];
      await tester.pumpWidget(
        _host([
          AlbumCard(
            data: albumCardDataFor(appContent.home.albums[0]),
            onPress: rects.add,
          ),
          AlbumCard(
            key: const ValueKey('second'),
            data: albumCardDataFor(appContent.home.albums[1]),
            onPress: rects.add,
          ),
        ]),
      );
      const layout = Rect.fromLTWH(16, 134, 361, 361);
      final card = tester.state<AlbumCardState>(find.byType(AlbumCard).first);
      expect(card.drawnRect, layout);
      final g = await tester.startGesture(
        tester.getCenter(find.byKey(AlbumCard.cardKey).first),
      );
      await tester.pumpAndSettle();
      final scale = tester
          .widget<ScaleTransition>(
            find.descendant(
              of: find.byKey(AlbumCard.cardKey).first,
              matching: find.byType(ScaleTransition),
            ),
          )
          .scale
          .value;
      expect(scale, closeTo(CameoMotion.pressScale, 1e-3));
      expect(card.drawnRect, _rectCloseTo(albumCardScaledRect(layout, scale)));
      await g.up();
      await tester.pump();
      expect(rects, hasLength(1));
      expect(rects.single, _rectCloseTo(albumCardScaledRect(layout, scale)));

      expect(
        AlbumCard.globalRectOf(
          tester.element(find.byKey(AlbumCard.cardKey).first),
        ),
        layout,
      );
      await tester.pumpAndSettle();
      expect(card.drawnRect, _rectCloseTo(layout));

      final g2 = await tester.startGesture(
        tester.getCenter(find.byKey(AlbumCard.cardKey).first),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      final partial = tester
          .widget<ScaleTransition>(
            find.descendant(
              of: find.byKey(AlbumCard.cardKey).first,
              matching: find.byType(ScaleTransition),
            ),
          )
          .scale
          .value;
      expect(partial, inExclusiveRange(CameoMotion.pressScale, 1));
      await g2.up();
      expect(rects.last, _rectCloseTo(albumCardScaledRect(layout, partial)));
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(200, 134 + 361 + 16 + 100));
      await tester.pumpAndSettle();
      expect(
        rects.last,
        _rectCloseTo(const Rect.fromLTWH(16, 134 + 361 + 16, 361, 361)),
      );
    },
  );

  testWidgets('Semantics: button · "{title} 앨범 열기"', (tester) async {
    _screenSize(tester);
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host([
        AlbumCard(
          data: albumCardDataFor(appContent.home.albums[1]),
          onPress: (_) {},
        ),
      ]),
    );
    final node = tester.getSemantics(find.bySemanticsLabel('성수 → 한남 앨범 열기'));
    expect(node.flagsCollection.isButton, isTrue);
    handle.dispose();
  });
}

Matcher _rectCloseTo(Rect r) => predicate<Rect>(
  (a) =>
      (a.left - r.left).abs() < 1e-6 &&
      (a.top - r.top).abs() < 1e-6 &&
      (a.width - r.width).abs() < 1e-6 &&
      (a.height - r.height).abs() < 1e-6,
  'rect ≈ $r',
);
