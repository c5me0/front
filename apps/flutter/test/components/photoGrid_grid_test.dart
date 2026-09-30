// ignore_for_file: file_names
// Regression coverage for photoGrid grid. Preserve behavior, layout, and interaction
// expectations.

import 'dart:convert';
import 'dart:io';

import 'package:cameo/components/photo_grid.dart';
import 'package:cameo/content/lab.g.dart';
import 'package:cameo/design_system/design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const double _screenWidth = 393;

const double _tol = 0.001;

final _sungsu = labAlbumDay.sections.firstWhere((s) => s.id == 'sungsu');
final _section3 = labAlbumDay.sections.firstWhere((s) => s.id == 'section-3');

List<String> _images(List<GridPhotoContent> photos) => [
  for (final p in photos) p.image,
];

Map<String, Map<String, dynamic>> _frameCases() {
  final json =
      jsonDecode(
            File(
              '../../design-system/tests/photo-grid-layout.vectors.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  return {
    for (final c in (json['frameCases'] as List).cast<Map<String, dynamic>>())
      c['name'] as String: c,
  };
}

List<Rect> _expectedRects(Map<String, dynamic> frameCase) => [
  for (final f
      in ((frameCase['expected'] as Map<String, dynamic>)['frames'] as List)
          .cast<Map<String, dynamic>>())
    Rect.fromLTWH(
      (f['x'] as num).toDouble(),
      (f['y'] as num).toDouble(),
      (f['w'] as num).toDouble(),
      (f['h'] as num).toDouble(),
    ),
];

double _expectedHeight(Map<String, dynamic> frameCase) =>
    ((frameCase['expected'] as Map<String, dynamic>)['height'] as num)
        .toDouble();

Future<void> _pump(WidgetTester tester, Widget widget) {
  tester.view
    ..physicalSize = const Size(_screenWidth, 852)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  return tester.pumpWidget(widget);
}

Widget _harness(Widget child, {bool disableAnimations = false}) {
  return MediaQuery(
    data: MediaQueryData(
      size: const Size(_screenWidth, 852),
      disableAnimations: disableAnimations,
    ),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: _screenWidth, child: child),
      ),
    ),
  );
}

PhotoGrid _sungsuGrid({bool animateIn = false}) => PhotoGrid(
  variant: PhotoGridVariant.bordered,
  photos: _images(_sungsu.grid!.photos),
  liked: photoGridInitialLikes(_sungsu.grid!.photos),
  animateIn: animateIn,
);

PhotoGrid _gangneungGrid({bool animateIn = false, Widget? footer}) => PhotoGrid(
  variant: PhotoGridVariant.gangneung,
  photos: _images(labAlbumGangneung.grid.photos),
  liked: photoGridInitialLikes(labAlbumGangneung.grid.photos),
  animateIn: animateIn,
  footer: footer,
);

Finder _photo(int i) => find.byKey(ValueKey('photoGrid.photo.$i'));
final Finder _grid = find.byKey(const ValueKey('photoGrid'));

void _expectRect(Rect actual, Rect expected, [String what = '']) {
  expect(actual.left, closeTo(expected.left, _tol), reason: '$what x');
  expect(actual.top, closeTo(expected.top, _tol), reason: '$what y');
  expect(actual.width, closeTo(expected.width, _tol), reason: '$what w');
  expect(actual.height, closeTo(expected.height, _tol), reason: '$what h');
}

BorderRadius _radiusOf(WidgetTester tester, Finder cell) =>
    tester
            .widget<ClipRRect>(
              find.descendant(of: cell, matching: find.byType(ClipRRect)),
            )
            .borderRadius
        as BorderRadius;

double _opacityOf(WidgetTester tester, Finder target) => tester
    .widget<Opacity>(
      find.descendant(of: target, matching: find.byType(Opacity)).first,
    )
    .opacity;

double _riseOf(WidgetTester tester, Finder target) => tester
    .widget<Transform>(
      find.descendant(of: target, matching: find.byType(Transform)).first,
    )
    .transform
    .getTranslation()
    .y;

void main() {
  final frameCases = _frameCases();

  group('bordered (16-6 2042:2819 / 2028:620)', () {
    testWidgets(
      '393 폭: 그리드 393 x 468.8 · 30장 = 벡터 프레임 (셀 73.8, x 8 + c·75.8)',
      (tester) async {
        await _pump(tester, _harness(_sungsuGrid()));
        final c = frameCases['bordered none-liked-30 @393']!;
        _expectRect(tester.getRect(_grid), Rect.fromLTWH(0, 0, 393, 468.8));
        expect(tester.getSize(_grid).height, closeTo(_expectedHeight(c), _tol));
        final rects = _expectedRects(c);
        expect(rects, hasLength(30));
        for (var i = 0; i < 30; i++) {
          _expectRect(tester.getRect(_photo(i)), rects[i], 'photo $i');
        }

        _expectRect(
          tester.getRect(_photo(29)),
          const Rect.fromLTWH(8 + 4 * 75.8, 8 + 5 * 75.8, 73.8, 73.8),
        );
        expect(find.byKey(const ValueKey('photoGrid.badge')), findsNothing);
      },
    );

    testWidgets('셀 테두리 1.5 stroke/neutral/base, inside(셀 크기 그대로 이미지 위)', (
      tester,
    ) async {
      await _pump(tester, _harness(_sungsuGrid()));
      final stroke = find.descendant(
        of: _photo(12),
        matching: find.byKey(const ValueKey('photoGrid.stroke')),
      );
      final border =
          (tester.widget<DecoratedBox>(stroke).decoration as BoxDecoration)
                  .border!
              as Border;
      expect(border.top.width, CameoLayout.photoGridCellBorderWidth);
      expect(border.left.width, 1.5);
      expect(border.top.color, CameoColors.strokeNeutralBase);
      expect(border.top.strokeAlign, BorderSide.strokeAlignInside);
      _expectRect(tester.getRect(stroke), tester.getRect(_photo(12)));
    });

    testWidgets('그리드 바깥 모서리(열 0 왼쪽 · 열 4 오른쪽)에 닿는 쪽만 r4 (Figma 행 클립)', (
      tester,
    ) async {
      await _pump(tester, _harness(_sungsuGrid()));
      const r4 = Radius.circular(CameoLayout.photoGridRowRadius);
      expect(
        _radiusOf(tester, _photo(0)),
        const BorderRadius.horizontal(left: r4),
      );
      expect(_radiusOf(tester, _photo(2)), BorderRadius.zero);
      expect(
        _radiusOf(tester, _photo(4)),
        const BorderRadius.horizontal(right: r4),
      );
      expect(
        _radiusOf(tester, _photo(25)),
        const BorderRadius.horizontal(left: r4),
      );
    });

    testWidgets(
      '섹션 3 (2042:2891) 2장: 같은 엔진 — 그리드 89.8, 셀 73.8 왼쪽 정렬, 셀2 오른쪽 모서리 각짐',
      (tester) async {
        await _pump(
          tester,
          _harness(
            PhotoGrid(
              variant: PhotoGridVariant.bordered,
              photos: _images(_section3.grid!.photos),
              liked: photoGridInitialLikes(_section3.grid!.photos),
            ),
          ),
        );
        _expectRect(
          tester.getRect(_grid),
          const Rect.fromLTWH(0, 0, 393, 89.8),
        );
        _expectRect(
          tester.getRect(_photo(0)),
          const Rect.fromLTWH(8, 8, 73.8, 73.8),
        );
        _expectRect(
          tester.getRect(_photo(1)),
          const Rect.fromLTWH(83.8, 8, 73.8, 73.8),
        );
        expect(_photo(2), findsNothing);
        const r4 = Radius.circular(CameoLayout.photoGridRowRadius);
        expect(
          _radiusOf(tester, _photo(0)),
          const BorderRadius.horizontal(left: r4),
        );
        expect(_radiusOf(tester, _photo(1)), BorderRadius.zero);
      },
    );
  });

  group('gangneung (16-3 2001:1131 / 2026:202)', () {
    testWidgets(
      '초기 = Figma: 2x2 A #1 (6,6) · B #14 (82.6,235.8) 151.2 · 24장 벡터 프레임 · 그리드 469.6',
      (tester) async {
        await _pump(tester, _harness(_gangneungGrid()));
        final c =
            frameCases['gangneung-figma-initial @393 (A 6,6 · B 82.6,235.8 · 151.2)']!;
        final rects = _expectedRects(c);
        expect(rects, hasLength(24));
        for (var i = 0; i < 24; i++) {
          _expectRect(tester.getRect(_photo(i)), rects[i], 'photo $i');
        }
        _expectRect(
          tester.getRect(_photo(0)),
          const Rect.fromLTWH(6, 6, 151.2, 151.2),
        );
        _expectRect(
          tester.getRect(_photo(13)),
          const Rect.fromLTWH(82.6, 235.8, 151.2, 151.2),
        );
        // 6 + 6·74.6 + 5·2 + 6
        _expectRect(
          tester.getRect(_grid),
          const Rect.fromLTWH(0, 0, 393, 469.6),
        );

        for (final i in [0, 1, 4, 13, 23]) {
          expect(
            _radiusOf(tester, _photo(i)),
            BorderRadius.circular(CameoLayout.photoGridGangneungCellRadius),
          );
        }
        expect(find.byKey(const ValueKey('photoGrid.stroke')), findsNothing);
      },
    );

    testWidgets(
      '하트 뱃지 = 좋아요한 2x2 (#1 · #14): 12 @ 오른쪽·아래 inset 4, heart-filled xxs icon/on-dark',
      (tester) async {
        await _pump(tester, _harness(_gangneungGrid()));
        final badges = find.byKey(const ValueKey('photoGrid.badge'));
        expect(badges, findsNWidgets(2));
        for (final i in [0, 13]) {
          final tile = _photo(i);
          final badge = find.descendant(of: tile, matching: badges);
          expect(badge, findsOneWidget);
          final tileRect = tester.getRect(tile);
          _expectRect(
            tester.getRect(badge),
            Rect.fromLTWH(
              tileRect.right - CameoLayout.photoGridGangneungBadgeInset - 12,
              tileRect.bottom - 4 - CameoLayout.photoGridGangneungBadgeSize,
              12,
              12,
            ),
            'badge $i',
          );
          final icon = tester.widget<CameoIcon>(
            find.descendant(of: badge, matching: find.byType(CameoIcon)),
          );
          expect(icon.name, CameoIconName.heartFilled);
          expect(icon.size, CameoIconTokens.sizeXxs);
          expect(icon.color, CameoColors.iconOnDark);
        }
      },
    );

    testWidgets('footer (2015:1954): 마지막 행 아래 gap 2 → y 465.6, 폭 381', (
      tester,
    ) async {
      const footerKey = ValueKey('footer');
      await _pump(
        tester,
        _harness(
          _gangneungGrid(footer: const SizedBox(key: footerKey, height: 156)),
        ),
      );
      _expectRect(
        tester.getRect(find.byKey(footerKey)),
        const Rect.fromLTWH(6, 465.6, 381, 156),
      );
      // 465.6 + 156 + 6
      _expectRect(tester.getRect(_grid), const Rect.fromLTWH(0, 0, 393, 627.6));
    });
  });

  group('접근성', () {
    testWidgets('사진 라벨 = 사진 {n}(, 좋아요) · 탭 액션 = 좋아요 토글 요청', (tester) async {
      final semantics = tester.ensureSemantics();
      final toggled = <int>[];
      await _pump(
        tester,
        _harness(
          PhotoGrid(
            variant: PhotoGridVariant.gangneung,
            photos: _images(labAlbumGangneung.grid.photos),
            liked: photoGridInitialLikes(labAlbumGangneung.grid.photos),
            onToggleLike: toggled.add,
          ),
        ),
      );
      expect(find.bySemanticsLabel('사진 1, 좋아요'), findsOneWidget);
      expect(find.bySemanticsLabel('사진 2'), findsOneWidget);
      expect(find.bySemanticsLabel('사진 14, 좋아요'), findsOneWidget);
      tester.semantics.tap(find.semantics.byLabel('사진 4'));
      await tester.pump();
      expect(toggled, [3]);
      semantics.dispose();
    });
  });

  group('등장 모션 (motion.stagger)', () {
    testWidgets('animateIn=false: 즉시 표시', (tester) async {
      await _pump(tester, _harness(_sungsuGrid()));
      expect(_opacityOf(tester, _photo(29)), 1);
      expect(_riseOf(tester, _photo(29)), 0);
    });

    testWidgets('animateIn=true: 초기 배치 row-major 스태거 페이드+상승(rise 12) → 정착', (
      tester,
    ) async {
      await _pump(tester, _harness(_gangneungGrid(animateIn: true)));

      expect(_opacityOf(tester, _photo(1)), 0);
      expect(_riseOf(tester, _photo(1)), CameoMotion.staggerRise);

      await tester.pump(const Duration(milliseconds: 80));
      await tester.pump(const Duration(milliseconds: 320));
      expect(_opacityOf(tester, _photo(1)), greaterThan(0));
      expect(_riseOf(tester, _photo(1)), lessThan(CameoMotion.staggerRise));
      expect(_opacityOf(tester, _photo(0)), greaterThan(0));
      expect(_opacityOf(tester, _photo(23)), 0);
      expect(_riseOf(tester, _photo(23)), CameoMotion.staggerRise);

      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      for (final i in [1, 23, 13]) {
        expect(_opacityOf(tester, _photo(i)), 1);
        expect(_riseOf(tester, _photo(i)), closeTo(0, _tol));
      }
    });

    testWidgets('모션 감소: 상승 없이 페이드만', (tester) async {
      await _pump(
        tester,
        _harness(_sungsuGrid(animateIn: true), disableAnimations: true),
      );
      expect(_opacityOf(tester, _photo(0)), 0);
      expect(_riseOf(tester, _photo(0)), 0);
      await tester.pump(const Duration(milliseconds: 100));
      expect(_opacityOf(tester, _photo(0)), greaterThan(0));
      expect(_riseOf(tester, _photo(0)), 0);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(_opacityOf(tester, _photo(29)), 1);
    });
  });
}
