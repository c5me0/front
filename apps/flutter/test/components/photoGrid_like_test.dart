// ignore_for_file: file_names
// Regression coverage for photoGrid like. Preserve behavior, layout, and interaction
// expectations.

import 'dart:convert';
import 'dart:io';

import 'package:cameo/components/heart_burst.dart';
import 'package:cameo/components/photo_grid.dart';
import 'package:cameo/content/lab.g.dart';
import 'package:cameo/design_system/design_system.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const double _w = 393;
const double _tol = 0.001;

List<String> _images(List<GridPhotoContent> photos) => [
  for (final p in photos) p.image,
];

final _sungsu = labAlbumDay.sections.firstWhere((s) => s.id == 'sungsu');

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

List<Rect> _rectsOf(Map<String, dynamic> frameCase) => [
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

double _heightOf(Map<String, dynamic> frameCase) =>
    ((frameCase['expected'] as Map<String, dynamic>)['height'] as num)
        .toDouble();

class _Harness extends StatefulWidget {
  const _Harness({
    required this.variant,
    required this.photos,
    required this.initial,
  });

  final PhotoGridVariant variant;
  final List<String> photos;
  final List<bool> initial;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  late List<bool> liked = widget.initial;
  final List<int> toggles = [];

  void toggle(int index) {
    toggles.add(index);
    setState(() => liked = photoGridToggleLike(liked, index));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PhotoGrid(
          variant: widget.variant,
          photos: widget.photos,
          liked: liked,
          onToggleLike: toggle,
        ),

        const SizedBox(key: ValueKey('below'), height: 10),
      ],
    );
  }
}

Future<void> _mount(
  WidgetTester tester, {
  required PhotoGridVariant variant,
  required List<GridPhotoContent> photos,
  bool disableAnimations = false,
}) async {
  tester.view
    ..physicalSize = const Size(_w, 852)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: const Size(_w, 852),
        disableAnimations: disableAnimations,
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: _w,
            child: _Harness(
              variant: variant,
              photos: _images(photos),
              initial: photoGridInitialLikes(photos),
            ),
          ),
        ),
      ),
    ),
  );
}

List<Key?> _paintTail(WidgetTester tester, int n) {
  final stack = tester.widget<Stack>(
    find.descendant(of: _grid, matching: find.byType(Stack)).first,
  );
  final keys = [for (final c in stack.children) c.key];
  return keys.sublist(keys.length - n);
}

Future<void> _mountGangneung(
  WidgetTester tester, {
  bool disableAnimations = false,
}) => _mount(
  tester,
  variant: PhotoGridVariant.gangneung,
  photos: labAlbumGangneung.grid.photos,
  disableAnimations: disableAnimations,
);

_HarnessState _harness(WidgetTester tester) =>
    tester.state<_HarnessState>(find.byType(_Harness));

Finder _photo(int i) => find.byKey(ValueKey('photoGrid.photo.$i'));
final Finder _grid = find.byKey(const ValueKey('photoGrid'));
final Finder _burst = find.byKey(const ValueKey('photoGrid.burst'));

Future<void> _doubleTap(WidgetTester tester, Finder target) async {
  await tester.tap(target);
  await tester.pump(kDoubleTapMinTime * 2);
  await tester.tap(target);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 2));
  await tester.pumpAndSettle();
}

void _expectRect(Rect actual, Rect expected, [String what = '']) {
  expect(actual.left, closeTo(expected.left, _tol), reason: '$what x');
  expect(actual.top, closeTo(expected.top, _tol), reason: '$what y');
  expect(actual.width, closeTo(expected.width, _tol), reason: '$what w');
  expect(actual.height, closeTo(expected.height, _tol), reason: '$what h');
}

void _expectBetween(Rect actual, Rect a, Rect b) {
  void between(double v, double x, double y, String what) {
    if ((x - y).abs() < _tol) {
      expect(v, closeTo(x, _tol), reason: what);
      return;
    }
    final lo = x < y ? x : y;
    final hi = x < y ? y : x;
    expect(v, greaterThan(lo + _tol), reason: '$what > $lo');
    expect(v, lessThan(hi - _tol), reason: '$what < $hi');
  }

  between(actual.left, a.left, b.left, 'x');
  between(actual.top, a.top, b.top, 'y');
  between(actual.width, a.width, b.width, 'w');
  between(actual.height, a.height, b.height, 'h');
}

double _opacityOf(WidgetTester tester, Finder target) => tester
    .widget<Opacity>(
      find.descendant(of: target, matching: find.byType(Opacity)).first,
    )
    .opacity;

double _burstOpacity(WidgetTester tester) => _opacityOf(tester, _burst);

double _scaleX(Transform t) => t.transform.entry(0, 0);

double _burstScale(WidgetTester tester) => _scaleX(
  tester.widget<Transform>(
    find.descendant(of: _burst, matching: find.byType(Transform)).first,
  ),
);

double? _badgeScale(WidgetTester tester, int i) {
  final badge = find.descendant(
    of: _photo(i),
    matching: find.byKey(const ValueKey('photoGrid.badge')),
  );
  if (badge.evaluate().isEmpty) return null;
  return _scaleX(
    tester.widget<Transform>(
      find.ancestor(of: badge, matching: find.byType(Transform)).first,
    ),
  );
}

double _pressScale(WidgetTester tester, int i) => tester
    .widget<ScaleTransition>(
      find.descendant(of: _photo(i), matching: find.byType(ScaleTransition)),
    )
    .scale
    .value;

void main() {
  final frameCases = _frameCases();
  final initialRects = _rectsOf(
    frameCases['gangneung-figma-initial @393 (A 6,6 · B 82.6,235.8 · 151.2)']!,
  );
  final like4 = frameCases['gangneung-demo-like-#4 @393']!;
  final like4Rects = _rectsOf(like4);

  group('트리거', () {
    testWidgets('더블탭 → onToggleLike(index) · 싱글탭 → 토글 없음(누름 피드백만)', (
      tester,
    ) async {
      await _mountGangneung(tester);
      await tester.tap(_photo(3));
      await tester.pump(kDoubleTapTimeout * 2);
      expect(_harness(tester).toggles, isEmpty);

      await _doubleTap(tester, _photo(3));
      expect(_harness(tester).toggles, [3]);
      await _settle(tester);
    });

    testWidgets('누름 피드백: 포인터 다운 즉시 press 수축 → 떼면 chewy 복귀 (더블탭 대기와 무관)', (
      tester,
    ) async {
      await _mountGangneung(tester);
      final gesture = await tester.startGesture(tester.getCenter(_photo(5)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(_pressScale(tester, 5), lessThan(1));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(_pressScale(tester, 5), 1);
      expect(_harness(tester).toggles, isEmpty);
    });

    testWidgets('드래그(kTouchSlop 초과)면 누름이 풀린다 — 스크롤과 공존', (tester) async {
      await _mountGangneung(tester);
      final gesture = await tester.startGesture(tester.getCenter(_photo(5)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(_pressScale(tester, 5), lessThan(1));
      await gesture.moveBy(const Offset(0, kTouchSlop * 2));
      await tester.pumpAndSettle();
      expect(_pressScale(tester, 5), 1);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(_harness(tester).toggles, isEmpty);
    });
  });

  group('좋아요 ON → 2x2 리플로우 (reflowSpring)', () {
    testWidgets(
      '#4 좋아요: 정착 후 = 벡터 gangneung-demo-like-#4 (#4 2x2 @ r1c2, #14 → r4c0, 7행)',
      (tester) async {
        await _mountGangneung(tester);
        await _doubleTap(tester, _photo(3));
        await _settle(tester);
        for (var i = 0; i < 24; i++) {
          _expectRect(tester.getRect(_photo(i)), like4Rects[i], 'photo $i');
        }
        _expectRect(
          tester.getRect(_photo(3)),
          const Rect.fromLTWH(159.2, 82.6, 151.2, 151.2),
        );
        _expectRect(
          tester.getRect(_photo(13)),
          const Rect.fromLTWH(6, 312.4, 151.2, 151.2),
        );

        expect(tester.getSize(_grid).height, closeTo(_heightOf(like4), _tol));
        expect(
          tester.getRect(find.byKey(const ValueKey('below'))).top,
          closeTo(546.2, _tol),
        );
      },
    );

    testWidgets('도중: 모든 셀 = 이전과 새 프레임 사이 (하나의 진행값), 그리드 높이도 사이', (
      tester,
    ) async {
      await _mountGangneung(tester);
      await _doubleTap(tester, _photo(3));
      await tester.pump();

      _expectRect(tester.getRect(_photo(3)), initialRects[3], 'start');
      await tester.pump(const Duration(milliseconds: 60));
      final t = (tester.getRect(_photo(3)).width - 74.6) / (151.2 - 74.6);
      expect(t, greaterThan(0.1));
      expect(t, lessThan(0.9));
      for (final i in [3, 4, 13, 23]) {
        final rect = tester.getRect(_photo(i));
        _expectBetween(rect, initialRects[i], like4Rects[i]);

        expect(
          rect.left,
          closeTo(
            initialRects[i].left +
                (like4Rects[i].left - initialRects[i].left) * t,
            1e-6,
          ),
        );
      }
      final h = tester.getSize(_grid).height;
      expect(h, closeTo(469.6 + (546.2 - 469.6) * t, 1e-6));
      await _settle(tester);
    });

    testWidgets('chewy 오버슈트: 정착 전 2x2 가 151.2 를 넘었다가 돌아온다', (tester) async {
      await _mountGangneung(tester);
      await _doubleTap(tester, _photo(3));
      await tester.pump();
      var maxW = 0.0;
      for (var k = 0; k < 40; k++) {
        await tester.pump(const Duration(milliseconds: 16));
        final w = tester.getRect(_photo(3)).width;
        if (w > maxW) maxW = w;
      }
      expect(maxW, greaterThan(151.2 + 1));
      await _settle(tester);
      expect(tester.getRect(_photo(3)).width, closeTo(151.2, _tol));
    });

    testWidgets('하트 버스트: 사진 가운데 72 · bouncy 팝 → hold 450ms → 페이드+확대 퇴장', (
      tester,
    ) async {
      await _mountGangneung(tester);
      expect(_burstOpacity(tester), 0);
      await _doubleTap(tester, _photo(3));
      await tester.pump();
      expect(tester.widget<HeartBurst>(find.byType(HeartBurst)).trigger, 1);
      _expectRect(
        tester.getRect(_burst),
        Rect.fromCenter(
          center: tester.getCenter(_photo(3)),
          width: CameoMotion.likeBurstSize,
          height: CameoMotion.likeBurstSize,
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(_burstOpacity(tester), 1);
      expect(_burstScale(tester), greaterThan(0.5));

      expect(
        tester.getCenter(_burst).dx,
        closeTo(tester.getCenter(_photo(3)).dx, _tol),
      );
      expect(
        tester.getCenter(_burst).dy,
        closeTo(tester.getCenter(_photo(3)).dy, _tol),
      );

      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_burstOpacity(tester), lessThan(1));
      await tester.pump(const Duration(milliseconds: 200));
      expect(_burstOpacity(tester), 0);
      await _settle(tester);
      _expectRect(
        tester.getRect(_burst).center & Size.zero,
        tester.getRect(_photo(3)).center & Size.zero,
      );
    });

    testWidgets(
      '뱃지: badgeDelay(120ms) 동안 0 → badgeSpring 팝 → 정착 1, 타일 오른쪽 아래 inset 4',
      (tester) async {
        await _mountGangneung(tester);
        expect(_badgeScale(tester, 3), isNull);
        await _doubleTap(tester, _photo(3));
        await tester.pump();
        expect(_badgeScale(tester, 3), 0);
        await tester.pump(const Duration(milliseconds: 100));
        expect(_badgeScale(tester, 3), 0);
        await tester.pump(const Duration(milliseconds: 40));
        await tester.pump(const Duration(milliseconds: 80));
        expect(_badgeScale(tester, 3), greaterThan(0));
        await _settle(tester);
        expect(_badgeScale(tester, 3), 1);
        final tile = tester.getRect(_photo(3));
        final badge = tester.getRect(
          find.descendant(
            of: _photo(3),
            matching: find.byKey(const ValueKey('photoGrid.badge')),
          ),
        );
        expect(tile.right - badge.right, closeTo(4, _tol));
        expect(tile.bottom - badge.bottom, closeTo(4, _tol));
        expect(badge.size, const Size(12, 12));
      },
    );

    testWidgets('햅틱: 좋아요 medium · 취소 light', (tester) async {
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          calls.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await _mountGangneung(tester);
      await _doubleTap(tester, _photo(3));
      await tester.pump();
      await _settle(tester);
      await _doubleTap(tester, _photo(3));
      await tester.pump();
      await _settle(tester);
      final haptics = calls
          .where((c) => c.method == 'HapticFeedback.vibrate')
          .map((c) => c.arguments)
          .toList();
      expect(haptics, [
        'HapticFeedbackType.mediumImpact',
        'HapticFeedbackType.lightImpact',
      ]);
    });

    testWidgets('좋아요한 사진을 위에, 방금 좋아요한 사진을 맨 위에 그린다 (Stack 마지막)', (
      tester,
    ) async {
      await _mountGangneung(tester);
      await _doubleTap(tester, _photo(3));
      await tester.pump();

      expect(_paintTail(tester, 4), const [
        ValueKey('photoGrid.photo.0'),
        ValueKey('photoGrid.photo.13'),
        ValueKey('photoGrid.photo.3'),
        ValueKey('photoGrid.burst'),
      ]);
      await _settle(tester);
    });

    testWidgets('방금 취소한 사진도 맨 위에 그린다 (좋아요 여부가 아니라 마지막 토글)', (tester) async {
      await _mountGangneung(tester);
      await _doubleTap(tester, _photo(3));
      await _settle(tester);
      await _doubleTap(tester, _photo(3));
      await tester.pump();
      expect(_paintTail(tester, 4), const [
        ValueKey('photoGrid.photo.0'),
        ValueKey('photoGrid.photo.13'),
        ValueKey('photoGrid.photo.3'),
        ValueKey('photoGrid.burst'),
      ]);
      await _settle(tester);

      await _doubleTap(tester, _photo(8));
      await tester.pump();
      final tail = _paintTail(tester, 4);
      expect(tail.last, const ValueKey('photoGrid.burst'));
      expect(tail[tail.length - 2], const ValueKey('photoGrid.photo.8'));
      expect(tail, isNot(contains(const ValueKey('photoGrid.photo.3'))));
      await _settle(tester);
    });
  });

  group('오버슈트 가로 가두기', () {
    testWidgets(
      'bordered #5 좋아요: 모든 프레임에서 셀이 [8, 385] 안 · 2x2 는 왼쪽에 멈춘 채 크기만 오버슈트',
      (tester) async {
        await _mount(
          tester,
          variant: PhotoGridVariant.bordered,
          photos: _sungsu.grid!.photos,
        );
        await _doubleTap(tester, _photo(4));
        await tester.pump();
        const left = CameoLayout.photoGridPadding;
        const right = _w - CameoLayout.photoGridPadding;
        var maxW = 0.0;
        var pinnedWhileOver = false;
        for (var k = 0; k < 60; k++) {
          await tester.pump(const Duration(milliseconds: 16));
          for (var i = 0; i < 30; i++) {
            final r = tester.getRect(_photo(i));
            expect(
              r.left,
              greaterThanOrEqualTo(left - 1e-9),
              reason: 'f$k #$i',
            );
            expect(r.right, lessThanOrEqualTo(right + 1e-9), reason: 'f$k #$i');
          }
          final tile = tester.getRect(_photo(4));
          if (tile.width > maxW) maxW = tile.width;
          if (tile.width > 149.6 + 1 && (tile.left - left).abs() < 1e-9) {
            pinnedWhileOver = true;
          }
        }
        expect(maxW, greaterThan(149.6 + 1), reason: '크기 오버슈트는 남는다');
        expect(pinnedWhileOver, isTrue, reason: '오버슈트 정점에서 왼쪽 가장자리에 멈춤');
        await _settle(tester);
        _expectRect(
          tester.getRect(_photo(4)),
          const Rect.fromLTWH(8, 83.8, 149.6, 149.6),
        );
      },
    );
  });

  group('좋아요 OFF · 연타', () {
    testWidgets(
      '취소: 뱃지 즉시 축소(press) → 타일 2x2 → 1x1, 리플로우 역방향 (초기 배치로), 버스트 없음',
      (tester) async {
        await _mountGangneung(tester);
        await _doubleTap(tester, _photo(3));
        await _settle(tester);
        await _doubleTap(tester, _photo(3));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(_badgeScale(tester, 3), lessThan(1));
        _expectBetween(
          tester.getRect(_photo(3)),
          like4Rects[3],
          initialRects[3],
        );
        expect(_burstOpacity(tester), 0);
        expect(tester.widget<HeartBurst>(find.byType(HeartBurst)).trigger, 1);
        await _settle(tester);
        for (var i = 0; i < 24; i++) {
          _expectRect(tester.getRect(_photo(i)), initialRects[i], 'photo $i');
        }
        expect(_badgeScale(tester, 3), isNull);
        expect(tester.getSize(_grid).height, closeTo(469.6, _tol));
      },
    );

    testWidgets('연타: 도중에 다시 토글하면 현재 보간 프레임에서 끊김 없이 재목표', (tester) async {
      await _mountGangneung(tester);
      await _doubleTap(tester, _photo(3));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final before = tester.getRect(_photo(3));
      final beforeOther = tester.getRect(_photo(13));
      final beforeHeight = tester.getSize(_grid).height;

      _harness(tester).toggle(3);
      expect(_harness(tester).toggles, [3, 3]);
      await tester.pump(Duration.zero);

      _expectRect(tester.getRect(_photo(3)), before, 'retarget #4');
      _expectRect(tester.getRect(_photo(13)), beforeOther, 'retarget #14');
      expect(tester.getSize(_grid).height, closeTo(beforeHeight, _tol));
      await tester.pump(const Duration(milliseconds: 30));

      expect(tester.getRect(_photo(3)).width, lessThan(before.width));
      await _settle(tester);
      for (var i = 0; i < 24; i++) {
        _expectRect(tester.getRect(_photo(i)), initialRects[i], 'photo $i');
      }
    });
  });

  group('모션 감소', () {
    testWidgets('즉시 새 배치 + 바뀐 셀만 짧은 페이드 (durationFast), 버스트는 팝 없이 페이드', (
      tester,
    ) async {
      await _mountGangneung(tester, disableAnimations: true);
      await _doubleTap(tester, _photo(3));
      await tester.pump();
      for (var i = 0; i < 24; i++) {
        _expectRect(tester.getRect(_photo(i)), like4Rects[i], 'photo $i');
      }
      expect(tester.getSize(_grid).height, closeTo(546.2, _tol));

      expect(_opacityOf(tester, _photo(3)), 0);
      expect(_opacityOf(tester, _photo(13)), 0);
      expect(_opacityOf(tester, _photo(1)), 1);
      await tester.pump(const Duration(milliseconds: 75));
      expect(_opacityOf(tester, _photo(3)), greaterThan(0));
      expect(_opacityOf(tester, _photo(3)), lessThan(1));
      expect(_burstScale(tester), 1);
      await tester.pump(CameoMotion.durationFast);
      expect(_opacityOf(tester, _photo(3)), 1);
      await _settle(tester);
      expect(_badgeScale(tester, 3), 1);
    });

    testWidgets('연속 토글: 정착한 출발점은 목표 그대로 — 움직이지 않은 셀은 페이드하지 않는다', (
      tester,
    ) async {
      await _mount(
        tester,
        variant: PhotoGridVariant.bordered,
        photos: _sungsu.grid!.photos,
        disableAnimations: true,
      );
      final before = tester.getRect(_photo(6));
      for (final photo in [0, 0]) {
        await _doubleTap(tester, _photo(photo));
        await _settle(tester);
      }
      await _doubleTap(tester, _photo(7));
      await tester.pump();
      expect(_harness(tester).toggles, [0, 0, 7]);
      _expectRect(tester.getRect(_photo(6)), before, '#7 그대로');
      expect(_opacityOf(tester, _photo(6)), 1);

      expect(_opacityOf(tester, _photo(7)), 0);
      await _settle(tester);
    });
  });

  group('bordered (16-6)', () {
    testWidgets(
      '#5 (r0c4) 좋아요 → 2x2 @ r1c0 (벡터 like-last-column), 테두리 유지, 바깥 모서리 r4',
      (tester) async {
        await _mount(
          tester,
          variant: PhotoGridVariant.bordered,
          photos: _sungsu.grid!.photos,
        );
        await _doubleTap(tester, _photo(4));
        await _settle(tester);
        final c = frameCases['bordered like-last-column (#5) @393']!;
        final rects = _rectsOf(c);
        for (var i = 0; i < 30; i++) {
          _expectRect(tester.getRect(_photo(i)), rects[i], 'photo $i');
        }
        _expectRect(
          tester.getRect(_photo(4)),
          const Rect.fromLTWH(8, 83.8, 149.6, 149.6),
        );
        expect(tester.getSize(_grid).height, closeTo(_heightOf(c), _tol));

        expect(
          find.descendant(
            of: _photo(4),
            matching: find.byKey(const ValueKey('photoGrid.stroke')),
          ),
          findsOneWidget,
        );
        const r4 = Radius.circular(CameoLayout.photoGridRowRadius);
        expect(
          tester
              .widget<ClipRRect>(
                find.descendant(
                  of: _photo(4),
                  matching: find.byType(ClipRRect),
                ),
              )
              .borderRadius,
          const BorderRadius.horizontal(left: r4),
        );
        expect(_badgeScale(tester, 4), 1);
      },
    );
  });
}
