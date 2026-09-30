// ignore_for_file: file_names
// Regression coverage for albumHero widgets. Preserve behavior, layout, and interaction
// expectations.

import 'package:cameo/components/album_hero.dart';
import 'package:cameo/components/album_section.dart';
import 'package:cameo/components/meta_row.dart';
import 'package:cameo/components/text_header.dart';
import 'package:cameo/content/lab.g.dart';
import 'package:cameo/design_system/design_system.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const double _w = CameoLayout.screenWidth;
const double _eps = 1e-6;

final AlbumSectionContent _sungsu = labAlbumDay.sections[0];
final AlbumSectionContent _emptyPhoto = labAlbumDay.sections[1];
final AlbumSectionContent _section3 = labAlbumDay.sections[2];

Widget _host(Widget child, {bool disableAnimations = false}) => MediaQuery(
  data: MediaQueryData(
    size: const Size(_w, CameoLayout.screenHeight),
    disableAnimations: disableAnimations,
  ),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: _w, child: child),
    ),
  ),
);

void _expectRect(Rect actual, Rect expected) {
  expect(actual.left, closeTo(expected.left, _eps), reason: 'left');
  expect(actual.top, closeTo(expected.top, _eps), reason: 'top');
  expect(actual.width, closeTo(expected.width, _eps), reason: 'width');
  expect(actual.height, closeTo(expected.height, _eps), reason: 'height');
}

Finder _icon(CameoIconName name) =>
    find.byWidgetPredicate((w) => w is CameoIcon && w.name == name);

Finder _dot() => find.byWidgetPredicate(
  (w) =>
      w is SizedBox &&
      w.width == CameoLayout.metaRowDotSize &&
      w.height == CameoLayout.metaRowDotSize,
);

Finder _countGroup(CameoIconName name) =>
    find.ancestor(of: _icon(name), matching: find.byType(Row)).first;

Color? _textColor(WidgetTester tester, String text) =>
    tester.widget<CameoText>(find.widgetWithText(CameoText, text)).color;

Color _dotColor(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(
    find.descendant(of: _dot(), matching: find.byType(DecoratedBox)),
  );
  return (box.decoration as BoxDecoration).color!;
}

void main() {
  group('albumHeroScrollTransform (motion.hero)', () {
    test('위로 스크롤: 이미지 패럴랙스 = offset × parallax, 레이어 그대로', () {
      final t = albumHeroScrollTransform(100, _w);
      expect(t.parallaxY, 100 * CameoMotion.heroParallax);
      expect(t.translateY, 0);
      expect(t.scale, 1);
    });

    test('당겨 내림: 위쪽 기준 scale = 1 + over × stretch / 높이, 빈틈을 덮는다', () {
      final t = albumHeroScrollTransform(-60, _w);
      expect(t.parallaxY, 0);
      expect(t.translateY, -60);
      expect(
        t.scale,
        closeTo(1 + 60 * CameoMotion.heroOverscrollStretch / _w, _eps),
      );

      expect(t.translateY + _w * t.scale, closeTo(_w, _eps));
    });

    test('높이 0 (레이아웃 전) 은 scale 1', () {
      expect(albumHeroScrollTransform(-60, 0).scale, 1);
    });
  });

  group('AlbumHero 16-6 (2042:2792)', () {
    testWidgets(
      '393 정사각 · 제목 (16, 317) h34 · MetaRow (16, 359) 361×18 · gap 8 · p16',
      (tester) async {
        await tester.pumpWidget(
          _host(
            AlbumHero(
              cover: _sungsu.cover!,
              title: _sungsu.title,
              subtitle: _sungsu.subtitle,
              stats: _sungsu.stats,
            ),
          ),
        );
        expect(tester.getSize(find.byType(AlbumHero)), const Size(393, 393));
        _expectRect(
          tester.getRect(find.text(_sungsu.title)),
          Rect.fromLTWH(
            16,
            317,
            tester.getSize(find.text(_sungsu.title)).width,
            34,
          ),
        );
        _expectRect(
          tester.getRect(find.byType(MetaRow)),
          const Rect.fromLTWH(16, 359, 361, 18),
        );

        expect(tester.getBottomLeft(find.text(_sungsu.title)).dy + 8, 359);
        expect(tester.getBottomLeft(find.byType(MetaRow)).dy, 393 - 16);
        expect(
          _textColor(tester, _sungsu.title),
          CameoColors.foregroundNeutralInverseBase,
        );

        _expectRect(
          tester.getRect(find.byType(Image)),
          const Rect.fromLTWH(0, 0, 393, 393),
        );
        final fill = tester.widget<DecoratedBox>(
          find.descendant(
            of: find.byType(AlbumHero),
            matching: find.byWidgetPredicate(
              (w) =>
                  w is DecoratedBox &&
                  w.decoration is BoxDecoration &&
                  (w.decoration as BoxDecoration).gradient != null,
            ),
          ),
        );
        expect(
          (fill.decoration as BoxDecoration).gradient,
          CameoGradients.albumHero,
        );
      },
    );

    testWidgets('섹션 3 그라데이션 (2042:2880)', (tester) async {
      await tester.pumpWidget(
        _host(
          AlbumHero(
            cover: _section3.cover!,
            title: _section3.title,
            subtitle: _section3.subtitle,
            stats: _section3.stats,
            gradient: AlbumHeroGradient.albumHeroSection3,
          ),
        ),
      );
      final boxes = tester.widgetList<DecoratedBox>(find.byType(DecoratedBox));
      expect(
        boxes.any(
          (b) =>
              (b.decoration as BoxDecoration).gradient ==
              CameoGradients.albumHeroSection3,
        ),
        isTrue,
      );
      _expectRect(
        tester.getRect(find.byType(MetaRow)),
        const Rect.fromLTWH(16, 359, 361, 18),
      );
    });
  });

  group('AlbumHero 16-3 (2001:1128)', () {
    testWidgets(
      '제목 (16, 317) h34 · gap 4 · 날짜 (16, 355) h22 bodyLg inverse/muted',
      (tester) async {
        await tester.pumpWidget(
          _host(
            AlbumHero(
              cover: labAlbumGangneung.cover,
              title: labAlbumGangneung.title,
              subtitle: labAlbumGangneung.date,
              gradient: AlbumHeroGradient.albumHeroGangneung,
            ),
          ),
        );
        expect(tester.getSize(find.byType(AlbumHero)), const Size(393, 393));
        expect(find.byType(MetaRow), findsNothing);
        final title = tester.getRect(find.text(labAlbumGangneung.title));
        final date = tester.getRect(find.text(labAlbumGangneung.date));
        expect(title.left, 16);
        expect(title.top, closeTo(317, _eps));
        expect(title.height, closeTo(34, _eps));
        expect(date.left, 16);
        expect(date.top, closeTo(355, _eps));
        expect(date.height, closeTo(22, _eps));
        expect(
          date.top - title.bottom,
          closeTo(CameoLayout.albumHeroGangneungGap, _eps),
        );
        expect(date.bottom, closeTo(393 - 16, _eps));
        final dateText = tester.widget<CameoText>(
          find.widgetWithText(CameoText, labAlbumGangneung.date),
        );
        expect(dateText.style, CameoTextStyles.bodyLg);
        expect(dateText.color, CameoColors.foregroundNeutralInverseMuted);
      },
    );

    testWidgets('onPress 없음 → 버튼 아님 (PressScale 없음, 기존 동작)', (tester) async {
      await tester.pumpWidget(
        _host(
          AlbumHero(
            cover: labAlbumGangneung.cover,
            title: labAlbumGangneung.title,
            subtitle: labAlbumGangneung.date,
            gradient: AlbumHeroGradient.albumHeroGangneung,
          ),
        ),
      );
      expect(find.byType(PressScale), findsNothing);
    });

    testWidgets(
      'onPress → 히어로 전체가 PressScale 버튼: 누르면 수축, 놓으면 탭 · 라벨 (v3 홈 히어로 → 앨범)',
      (tester) async {
        var taps = 0;
        await tester.pumpWidget(
          _host(
            AlbumHero(
              cover: labAlbumGangneung.cover,
              title: labAlbumGangneung.title,
              subtitle: labAlbumGangneung.date,
              gradient: AlbumHeroGradient.albumHeroGangneung,
              onPress: () => taps += 1,
              accessibilityLabel: '강릉, 날짜별 앨범 열기',
            ),
          ),
        );
        final press = find.byType(PressScale);
        expect(press, findsOneWidget);
        expect(
          tester.widget<PressScale>(press).accessibilityLabel,
          '강릉, 날짜별 앨범 열기',
        );

        expect(tester.getSize(find.byType(AlbumHero)), const Size(393, 393));
        final gesture = await tester.startGesture(const Offset(196, 196));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));
        final scale = tester
            .widget<ScaleTransition>(
              find.descendant(
                of: press,
                matching: find.byType(ScaleTransition),
              ),
            )
            .scale
            .value;
        expect(scale, lessThan(1));
        await gesture.up();
        await tester.pumpAndSettle();
        expect(taps, 1);

        await tester.pumpWidget(
          _host(
            AlbumHero(
              cover: labAlbumGangneung.cover,
              title: labAlbumGangneung.title,
              subtitle: labAlbumGangneung.date,
              onPress: () {},
            ),
          ),
        );
        expect(
          tester.widget<PressScale>(find.byType(PressScale)).accessibilityLabel,
          labAlbumGangneung.title,
        );
      },
    );
  });

  group('AlbumHero 스크롤 효과 (plan §4.3)', () {
    Widget hero(ValueListenable<double> offset, {bool reduce = false}) => _host(
      AlbumHero(
        cover: _sungsu.cover!,
        title: _sungsu.title,
        subtitle: _sungsu.subtitle,
        stats: _sungsu.stats,
        scrollOffset: offset,
      ),
      disableAnimations: reduce,
    );

    testWidgets('패럴랙스: offset 100 → 이미지 +50 (클립 안), 제목은 그대로', (tester) async {
      final offset = ValueNotifier<double>(0);
      await tester.pumpWidget(hero(offset));
      _expectRect(
        tester.getRect(find.byType(Image)),
        const Rect.fromLTWH(0, 0, 393, 393),
      );
      offset.value = 100;
      await tester.pump();
      _expectRect(
        tester.getRect(find.byType(Image)),
        Rect.fromLTWH(0, 100 * CameoMotion.heroParallax, 393, 393),
      );
      expect(
        tester.getTopLeft(find.text(_sungsu.title)).dy,
        closeTo(317, _eps),
      );
    });

    testWidgets('당겨 내림: offset −60 → 레이어가 [−60, 393] 을 위쪽 기준 확대로 덮는다', (
      tester,
    ) async {
      final offset = ValueNotifier<double>(0);
      await tester.pumpWidget(hero(offset));
      offset.value = -60;
      await tester.pump();
      const scaled = 393 + 60.0; // 393 × (1 + 60/393)
      _expectRect(
        tester.getRect(find.byType(Image)),
        const Rect.fromLTWH((393 - scaled) / 2, -60, scaled, scaled),
      );
      expect(tester.getSize(find.byType(AlbumHero)), const Size(393, 393));
    });

    testWidgets('모션 감소: 스크롤과 무관하게 정지', (tester) async {
      final offset = ValueNotifier<double>(-60);
      await tester.pumpWidget(hero(offset, reduce: true));
      _expectRect(
        tester.getRect(find.byType(Image)),
        const Rect.fromLTWH(0, 0, 393, 393),
      );
      offset.value = 100;
      await tester.pump();
      _expectRect(
        tester.getRect(find.byType(Image)),
        const Rect.fromLTWH(0, 0, 393, 393),
      );
    });

    test('ScrollOffsetListenable: 클라이언트 없으면 0 · controller 로 동등', () {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      expect(ScrollOffsetListenable(controller).value, 0);
      expect(
        ScrollOffsetListenable(controller),
        ScrollOffsetListenable(controller),
      );
      expect(
        ScrollOffsetListenable(controller).hashCode,
        ScrollOffsetListenable(controller).hashCode,
      );
    });

    testWidgets('ScrollOffsetListenable(ScrollController) 로 실제 스크롤 뷰 연결', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(_w, CameoLayout.screenHeight)),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(
              width: _w,
              height: CameoLayout.screenHeight,
              child: SingleChildScrollView(
                controller: controller,
                physics: const BouncingScrollPhysics(),
                child: AlbumSection(
                  background: AlbumSectionBackground.section1,
                  children: [
                    AlbumHero(
                      cover: _sungsu.cover!,
                      title: _sungsu.title,
                      subtitle: _sungsu.subtitle,
                      stats: _sungsu.stats,
                      scrollOffset: ScrollOffsetListenable(controller),
                    ),
                    const SizedBox(height: CameoLayout.screenHeight),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      controller.jumpTo(80);
      await tester.pump();
      final heroTop = tester.getTopLeft(find.byType(AlbumHero)).dy;
      expect(heroTop, closeTo(-80, _eps));
      expect(
        tester.getTopLeft(find.byType(Image)).dy - heroTop,
        closeTo(80 * CameoMotion.heroParallax, _eps),
      );
    });
  });

  group('MetaRow (2042:2794 / 2859)', () {
    Future<void> pumpRow(WidgetTester tester, LabTone tone) =>
        tester.pumpWidget(
          _host(
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: CameoLayout.screenGutter,
              ),
              child: MetaRow(
                label: _sungsu.subtitle,
                stats: _sungsu.stats,
                tone: tone,
              ),
            ),
          ),
        );

    testWidgets('361×18 · 라벨 fill · gap 8 · 아이콘 14 + gap 6 · 점 2 · 오른쪽 끝 정렬', (
      tester,
    ) async {
      await pumpRow(tester, LabTone.dark);
      final row = tester.getRect(find.byType(MetaRow));
      _expectRect(row, const Rect.fromLTWH(16, 0, 361, 18));

      final label = tester.getRect(find.text(_sungsu.subtitle));
      final photoGroup = tester.getRect(_countGroup(CameoIconName.photo));
      final phoneGroup = tester.getRect(_countGroup(CameoIconName.phone));
      final dot = tester.getRect(_dot());
      final photoIcon = tester.getRect(_icon(CameoIconName.photo));
      final phoneIcon = tester.getRect(_icon(CameoIconName.phone));
      final photos = tester.getRect(find.text(_sungsu.stats.photos));
      final calls = tester.getRect(find.text(_sungsu.stats.calls));

      expect(label.left, 16);
      expect(
        photoGroup.left - label.right,
        closeTo(CameoLayout.metaRowGap, _eps),
      );
      expect(
        dot.left - photoGroup.right,
        closeTo(CameoLayout.metaRowGap, _eps),
      );
      expect(
        phoneGroup.left - dot.right,
        closeTo(CameoLayout.metaRowGap, _eps),
      );
      expect(phoneGroup.right, closeTo(row.right, _eps));

      expect(photoIcon.size, const Size(14, 14));
      expect(phoneIcon.size, const Size(14, 14));
      expect(
        photos.left - photoIcon.right,
        closeTo(CameoLayout.metaRowCountGap, _eps),
      );
      expect(
        calls.left - phoneIcon.right,
        closeTo(CameoLayout.metaRowCountGap, _eps),
      );

      expect(photoIcon.top, closeTo(2, _eps));
      expect(dot.size, const Size(2, 2));
      expect(dot.top, closeTo(8, _eps));
      expect(photos.height, closeTo(18, _eps));
    });

    testWidgets('dark 톤 역할: 텍스트·아이콘 inverse/muted, 점 static/white', (
      tester,
    ) async {
      await pumpRow(tester, LabTone.dark);
      expect(
        _textColor(tester, _sungsu.subtitle),
        CameoColors.foregroundNeutralInverseMuted,
      );
      expect(
        _textColor(tester, _sungsu.stats.photos),
        CameoColors.foregroundNeutralInverseMuted,
      );
      expect(
        tester.widget<CameoIcon>(_icon(CameoIconName.photo)).color,
        CameoColors.foregroundNeutralInverseMuted,
      );
      expect(_dotColor(tester), CameoColors.staticWhite);
      expect(
        tester
            .widget<CameoText>(find.widgetWithText(CameoText, _sungsu.subtitle))
            .style,
        CameoTextStyles.bodyMd,
      );
    });

    testWidgets('light 톤 역할: 텍스트·아이콘 muted, 점 background/neutral/inverse', (
      tester,
    ) async {
      await pumpRow(tester, LabTone.light);
      expect(
        _textColor(tester, _sungsu.subtitle),
        CameoColors.foregroundNeutralMuted,
      );
      expect(
        tester.widget<CameoIcon>(_icon(CameoIconName.phone)).color,
        CameoColors.foregroundNeutralMuted,
      );
      expect(_dotColor(tester), CameoColors.backgroundNeutralInverse);
    });

    testWidgets('스크린리더: 한 문장 한국어 라벨', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpRow(tester, LabTone.dark);
      expect(
        find.bySemanticsLabel('2026년 8월 20일, 6시간, 사진 30장, 통화 3건'),
        findsOneWidget,
      );
      semantics.dispose();
    });
  });

  group('TextHeader (2042:2857)', () {
    testWidgets('393×124 · 제목 (16, 48) h34 · MetaRow (16, 90) 361×18 light', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          TextHeader(
            title: _emptyPhoto.title,
            subtitle: _emptyPhoto.subtitle,
            stats: _emptyPhoto.stats,
          ),
        ),
      );
      expect(tester.getSize(find.byType(TextHeader)), const Size(393, 124));
      final title = tester.getRect(find.text(_emptyPhoto.title));
      expect(title.topLeft, const Offset(16, 48));
      expect(title.height, closeTo(34, _eps));
      _expectRect(
        tester.getRect(find.byType(MetaRow)),
        const Rect.fromLTWH(16, 90, 361, 18),
      );
      expect(
        _textColor(tester, _emptyPhoto.title),
        CameoColors.foregroundNeutralBase,
      );
      expect(tester.widget<MetaRow>(find.byType(MetaRow)).tone, LabTone.light);
      expect(_dotColor(tester), CameoColors.backgroundNeutralInverse);
    });
  });

  group('AlbumSection', () {
    testWidgets('배경 역할 · 자식 세로 쌓기 · 폭 fill', (tester) async {
      await tester.pumpWidget(
        _host(
          AlbumSection(
            background: AlbumSectionBackground.canvasMuted,
            children: [
              TextHeader(
                title: _emptyPhoto.title,
                subtitle: _emptyPhoto.subtitle,
                stats: _emptyPhoto.stats,
              ),
              const SizedBox(height: CameoLayout.spacerHeight),
            ],
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(AlbumSection)),
        const Size(393, 124 + CameoLayout.spacerHeight),
      );
      expect(tester.getTopLeft(find.byType(TextHeader)), Offset.zero);
      final box = tester.widget<ColoredBox>(
        find
            .descendant(
              of: find.byType(AlbumSection),
              matching: find.byType(ColoredBox),
            )
            .first,
      );
      expect(box.color, CameoColors.backgroundCanvasMuted);
    });

    test('배경 → 역할 · 색 · 히어로 그라데이션', () {
      for (final palette in [CameoPalette.light, CameoPalette.dark]) {
        for (final b in AlbumSectionBackground.values) {
          expect(palette.byRole[b.role], b.colorIn(palette));
        }
      }
      expect(
        AlbumSectionBackground.section1.colorIn(CameoPalette.light),
        CameoColors.albumSection1,
      );
      expect(
        AlbumSectionBackground.section3.colorIn(CameoPalette.light),
        CameoColors.albumSection3,
      );
      expect(
        AlbumSectionBackground.section1.heroGradient,
        AlbumHeroGradient.albumHero,
      );
      expect(
        AlbumSectionBackground.section3.heroGradient,
        AlbumHeroGradient.albumHeroSection3,
      );
      expect(AlbumSectionBackground.canvasMuted.heroGradient, isNull);
    });
  });
}
