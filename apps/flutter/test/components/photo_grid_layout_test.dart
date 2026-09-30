// Regression coverage for photo grid layout. Preserve behavior, layout, and interaction
// expectations.

import 'dart:convert';
import 'dart:io';

import 'package:cameo/components/photo_grid_layout.dart';
import 'package:cameo/content/lab.g.dart';
import 'package:cameo/design_system/design_system.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _readJson(String relativeToRepo) =>
    jsonDecode(File('../../$relativeToRepo').readAsStringSync())
        as Map<String, dynamic>;

double _num(Object? v) => (v as num).toDouble();

List<bool> _liked(Object? v) => (v as List).cast<bool>();

PhotoGridLayout _expectedLayout(Map<String, dynamic> e) => PhotoGridLayout(
  placements: [
    for (final p in (e['placements'] as List).cast<Map<String, dynamic>>())
      PhotoGridPlacement(
        row: p['row'] as int,
        col: p['col'] as int,
        span: p['span'] as int,
      ),
  ],
  rows: e['rows'] as int,
);

void main() {
  final vectors = _readJson(
    'design-system/tests/photo-grid-layout.vectors.json',
  );
  final tol = _num(vectors['tolerance']);
  final cases = (vectors['cases'] as List).cast<Map<String, dynamic>>();
  final frameCases = (vectors['frameCases'] as List)
      .cast<Map<String, dynamic>>();

  group('layoutPhotoGrid — 벡터', () {
    for (final c in cases) {
      test(c['name'], () {
        final got = layoutPhotoGrid(_liked(c['liked']), c['columns'] as int);
        final want = _expectedLayout(c['expected'] as Map<String, dynamic>);
        expect(got.placements, want.placements);
        expect(got.rows, want.rows);
      });
    }

    test('columns < 2 → ArgumentError', () {
      expect(() => layoutPhotoGrid(const [true], 1), throwsArgumentError);
    });

    test('입력 순서 = placements 순서, 빈 입력 → rows 0', () {
      final empty = layoutPhotoGrid(const [], CameoLayout.photoGridColumns);
      expect(empty.placements, isEmpty);
      expect(empty.rows, 0);
    });
  });

  group('photoGridFrames — 벡터', () {
    const tokenMetrics = <String, PhotoGridMetrics>{
      'bordered': PhotoGridMetrics(
        columns: CameoLayout.photoGridColumns,
        padding: CameoLayout.photoGridPadding,
        gap: CameoLayout.photoGridGap,
      ),
      'gangneung': PhotoGridMetrics(
        columns: CameoLayout.photoGridColumns,
        padding: CameoLayout.photoGridGangneungPadding,
        gap: CameoLayout.photoGridGangneungGap,
      ),
    };

    for (final c in frameCases) {
      test(c['name'], () {
        final m = c['metrics'] as Map<String, dynamic>;
        final metrics = PhotoGridMetrics(
          columns: m['columns'] as int,
          padding: _num(m['padding']),
          gap: _num(m['gap']),
        );
        final token = tokenMetrics[c['variant']]!;
        expect(metrics.columns, token.columns, reason: '벡터 metrics = 토큰');
        expect(metrics.padding, token.padding, reason: '벡터 metrics = 토큰');
        expect(metrics.gap, token.gap, reason: '벡터 metrics = 토큰');

        final got = photoGridFrames(
          layoutPhotoGrid(_liked(c['liked']), metrics.columns),
          metrics,
          _num(c['width']),
        );
        final e = c['expected'] as Map<String, dynamic>;
        expect(got.cellSize, closeTo(_num(e['cellSize']), tol));
        expect(got.contentHeight, closeTo(_num(e['contentHeight']), tol));
        expect(got.height, closeTo(_num(e['height']), tol));
        final frames = (e['frames'] as List).cast<Map<String, dynamic>>();
        expect(got.frames.length, frames.length);
        for (var i = 0; i < frames.length; i++) {
          final f = got.frames[i];
          expect(f.x, closeTo(_num(frames[i]['x']), tol), reason: 'frame $i x');
          expect(f.y, closeTo(_num(frames[i]['y']), tol), reason: 'frame $i y');
          expect(f.w, closeTo(_num(frames[i]['w']), tol), reason: 'frame $i w');
          expect(f.h, closeTo(_num(frames[i]['h']), tol), reason: 'frame $i h');
        }
      });
    }
  });

  group('PhotoGridFrame.containX — 벡터', () {
    const tokenPadding = <String, double>{
      'bordered': CameoLayout.photoGridPadding,
      'gangneung': CameoLayout.photoGridGangneungPadding,
    };
    PhotoGridFrame frame(Object? v) {
      final m = v as Map<String, dynamic>;
      return PhotoGridFrame(
        x: _num(m['x']),
        y: _num(m['y']),
        w: _num(m['w']),
        h: _num(m['h']),
      );
    }

    final containCases = (vectors['containCases'] as List)
        .cast<Map<String, dynamic>>();
    test('벡터가 있다', () => expect(containCases, isNotEmpty));
    for (final c in containCases) {
      test(c['name'], () {
        final padding = _num(c['padding']);
        expect(padding, tokenPadding[c['variant']], reason: '벡터 padding = 토큰');
        final got = PhotoGridFrame.lerp(
          frame(c['a']),
          frame(c['b']),
          _num(c['t']),
        ).containX(padding, _num(c['width']));
        final e = frame(c['expected']);
        expect(got.x, closeTo(e.x, tol), reason: 'x');
        expect(got.y, closeTo(e.y, tol), reason: 'y');
        expect(got.w, closeTo(e.w, tol), reason: 'w');
        expect(got.h, closeTo(e.h, tol), reason: 'h');
      });
    }
  });

  group('PhotoGridFrame.lerp', () {
    const a = PhotoGridFrame(x: 6, y: 6, w: 74.6, h: 74.6);
    const b = PhotoGridFrame(x: 82.6, y: 235.8, w: 151.2, h: 151.2);

    test('t=0 → a, t=1 → b', () {
      expect(PhotoGridFrame.lerp(a, b, 0), a);
      expect(PhotoGridFrame.lerp(a, b, 1), b);
    });

    test('t>1 은 외삽 (reflowSpring 오버슈트)', () {
      final over = PhotoGridFrame.lerp(a, b, 1.1);
      expect(over.x, closeTo(82.6 + 0.1 * (82.6 - 6), 1e-9));
      expect(over.w, closeTo(151.2 + 0.1 * (151.2 - 74.6), 1e-9));
    });

    test('toRect', () {
      expect(b.toRect().left, b.x);
      expect(b.toRect().top, b.y);
    });
  });

  group('콘텐츠 → 엔진', () {
    test('16-3: layoutPhotoGrid(grid.photos) 의 2x2 = Figma 추천 타일 위치·사진', () {
      final g = labAlbumGangneung;
      final photos = g.grid.photos;
      final result = layoutPhotoGrid([
        for (final p in photos) p.liked,
      ], g.grid.columns);
      final liked = [
        for (var i = 0; i < photos.length; i++)
          if (photos[i].liked) (photos[i].image, result.placements[i]),
      ];
      final figma = [
        for (final t in g.featured)
          (
            t.image,
            PhotoGridPlacement(row: t.row - 1, col: t.col - 1, span: t.rowSpan),
          ),
      ];
      expect(liked, figma);
      expect(result.rows, g.grid.rows.length);
    });

    test('16-3: 보이는 칸의 사진이 Figma 셀과 같다 (덮인 6칸만 빠진다)', () {
      final g = labAlbumGangneung;
      final result = layoutPhotoGrid([
        for (final p in g.grid.photos) p.liked,
      ], g.grid.columns);
      final byCell = <(int, int), String>{
        for (var i = 0; i < g.grid.photos.length; i++)
          (result.placements[i].row, result.placements[i].col):
              g.grid.photos[i].image,
      };
      final covered = <(int, int)>{
        for (final t in g.featured)
          for (var dr = 0; dr < t.rowSpan; dr++)
            for (var dc = 0; dc < t.colSpan; dc++)
              if (dr != 0 || dc != 0) (t.row - 1 + dr, t.col - 1 + dc),
      };
      expect(covered, hasLength(6));
      for (var r = 0; r < g.grid.rows.length; r++) {
        for (var c = 0; c < g.grid.rows[r].length; c++) {
          if (covered.contains((r, c))) continue;
          expect(
            byCell[(r, c)],
            g.grid.rows[r][c],
            reason: 'r${r + 1}c${c + 1}',
          );
        }
      }
    });

    test(
      '16-3: liked 순서 = photo_grid_layout_ref.py gangneung_initial() (24장, #1·#14)',
      () {
        final ref = cases.firstWhere(
          (c) => (c['name'] as String).startsWith('gangneung-figma-initial'),
        );
        expect([
          for (final p in labAlbumGangneung.grid.photos) p.liked,
        ], _liked(ref['liked']));
      },
    );

    test('16-6: photos = rows row-major, liked 없음', () {
      for (final s in labAlbumDay.sections) {
        final grid = s.grid;
        if (grid == null) continue;
        expect(
          [for (final p in grid.photos) p.image],
          [for (final row in grid.rows) ...row],
          reason: s.id,
        );
        expect(grid.photos.any((p) => p.liked), isFalse, reason: s.id);
      }
    });
  });
}
