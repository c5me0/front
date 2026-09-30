// Regression coverage for photo grid v5 model. Preserve behavior, layout, and
// interaction expectations.

import 'package:cameo/components/photo_grid_v5_model.dart';
import 'package:cameo/design_system/design_system.dart';
import 'package:cameo/screens/home_timeline/album_timeline_model.dart';
import 'package:flutter_test/flutter_test.dart';

const double _w = CameoLayout.screenWidth;
const _full = GridV5Metrics.album(paddingTop: 8, paddingX: 8, paddingBottom: 8);

void main() {
  final ids = [for (var i = 0; i < 27; i++) 'p$i'];
  final liked = [for (var i = 0; i < 27; i++) i == 0];
  final g = gridV5Boxes(ids, liked, _full, _w);

  test(
    '2×2 타일 (8, 8, 149.6 × 150) 왼쪽 r4 · 다음 셀 (159.6, 8) · 열 4 오른쪽 r4 · 6 행 · 높이 468.8',
    () {
      final t = g.boxes['p0']!;
      expect([t.x, t.y], [8, 8]);
      expect(t.w, closeTo(149.6, 1e-9));
      expect(t.h, closeTo(150, 1e-9));
      expect([t.rl, t.rr, t.row], [4, 0, 0]);
      final c1 = g.boxes['p1']!;
      expect(c1.x, closeTo(159.6, 1e-9));
      expect(c1.y, 8);
      expect(c1.w, closeTo(73.8, 1e-9));
      expect([c1.rl, c1.rr], [0, 0]);
      final c3 = g.boxes['p3']!;
      expect(c3.x, closeTo(311.2, 1e-9));
      expect(c3.rr, 4);
      expect(g.rows, 6);
      expect(g.height, closeTo(468.8, 1e-9));
    },
  );

  test(
    '좋아요 · 삭제 보기 (v6) = 배치 좋아요 모두 false → 타일이 셀 73.8 · 6 행 / 몇 장 (few) 고정 셀 왼쪽 정렬 · 높이 181.8',
    () {
      final sel = gridV5Boxes(
        ids,
        layoutLikes(liked, AlbumMode.liked),
        _full,
        _w,
      );
      expect(sel.boxes['p0']!.w, closeTo(73.8, 1e-9));
      expect(sel.boxes['p0']!.h, closeTo(73.8, 1e-9));
      expect(sel.rows, 6);
      final f = gridV5Boxes(
        ['a', 'b'],
        [false, false],
        const GridV5Metrics.album(
          paddingTop: 8,
          paddingX: 8,
          paddingBottom: 100,
        ),
        _w,
      );
      expect(f.boxes['a']!.x, 8);
      expect(f.boxes['b']!.x, closeTo(83.8, 1e-9));
      expect(f.boxes['a']!.rl, 4);
      expect(f.boxes['b']!.rr, 0);
      expect(f.height, closeTo(181.8, 1e-9));
    },
  );

  test(
    'id 리플로우: 지움 diff · 촬영 diff · 머무는 셀 보간 · 나가는 셀 제자리 1 − t (오버슈트 자름) · 들어오는 셀 t',
    () {
      final after = gridV5Boxes(
        [
          for (final id in ids)
            if (id != 'p1' && id != 'p2') id,
        ],
        liked.sublist(0, 25),
        _full,
        _w,
      );
      final diff = gridV5Diff(ids, after.ids);
      expect(diff.entering, isEmpty);
      expect(diff.exiting, ['p1', 'p2']);
      final capture = gridV5Diff(['a'], ['n', 'a']);
      expect(capture.entering, ['n']);
      expect(capture.exiting, isEmpty);
      final moving = gridV5CellLook(g, after, 'p3', 0.5, false)!;
      expect(
        moving.box.x,
        closeTo((g.boxes['p3']!.x + after.boxes['p3']!.x) / 2, 1e-9),
      );
      final exit = gridV5CellLook(g, after, 'p1', 0.5, true)!;
      expect(
        [exit.box.x, exit.scale, exit.opacity],
        [g.boxes['p1']!.x, 0.5, 0.5],
      );
      final over = gridV5CellLook(g, after, 'p1', 1.1, true)!;
      expect([over.scale, over.opacity], [0, 0]);
      final enter = gridV5CellLook(
        gridV5Boxes(['a'], [false], _full, _w),
        gridV5Boxes(['n', 'a'], [false, false], _full, _w),
        'n',
        0.25,
        false,
      )!;
      expect([enter.box.x, enter.scale], [8, 0.25]);
    },
  );

  test(
    '재목표 출발점: 나가던 셀은 버리고 머무는 셀은 보간 · t = 1 이면 목적지 그대로 · 가로 가두기 (오버슈트 x ≥ 8)',
    () {
      final after = gridV5Boxes(
        [
          for (final id in ids)
            if (id != 'p1' && id != 'p2') id,
        ],
        liked.sublist(0, 25),
        _full,
        _w,
      );
      final cur = gridV5Current(g, after, 0.5);
      expect(cur.boxes['p1'], isNull);
      expect(cur.boxes['p3'], isNotNull);
      expect(identical(gridV5Current(g, after, 1), after), isTrue);
      const a = GridV5Box(
        x: 311.2,
        y: 8,
        w: 73.8,
        h: 73.8,
        rl: 0,
        rr: 4,
        row: 0,
      );
      const b = GridV5Box(
        x: 8,
        y: 83.8,
        w: 73.8,
        h: 73.8,
        rl: 4,
        rr: 0,
        row: 1,
      );
      expect(lerpGridV5Box(a, b, 1.15, _w, 8).x, 8);
    },
  );
}
