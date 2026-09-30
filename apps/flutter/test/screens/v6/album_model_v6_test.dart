// Regression coverage for album model v6. Preserve behavior, layout, and interaction
// expectations.

import 'package:cameo/components/photo_grid_v5_model.dart';
import 'package:cameo/components/photo_grid_v6.dart';
import 'package:cameo/content/lab.g.dart';
import 'package:cameo/design_system/design_system.dart';
import 'package:cameo/screens/home_timeline/album_timeline_model.dart';
import 'package:cameo/state/album_store.dart';
import 'package:flutter_test/flutter_test.dart';

const double _w = 402;
const double _h = 874;

void main() {
  group('모드 상태 기계 (notes §1)', () {
    test(
      'timeline 에서만 select · liked · deleted 로 · 그 셋은 close 로만 timeline · empty = 어디서든 timeline',
      () {
        for (final e in [
          (AlbumModeEvent.select, AlbumMode.select),
          (AlbumModeEvent.liked, AlbumMode.liked),
          (AlbumModeEvent.deleted, AlbumMode.deleted),
          (AlbumModeEvent.close, AlbumMode.timeline),
          (AlbumModeEvent.empty, AlbumMode.timeline),
        ]) {
          expect(albumModeAfter(AlbumMode.timeline, e.$1), e.$2);
        }
        for (final m in [
          AlbumMode.select,
          AlbumMode.liked,
          AlbumMode.deleted,
        ]) {
          expect(albumModeAfter(m, AlbumModeEvent.close), AlbumMode.timeline);
          expect(albumModeAfter(m, AlbumModeEvent.empty), AlbumMode.timeline);
          for (final e in [
            AlbumModeEvent.select,
            AlbumModeEvent.liked,
            AlbumModeEvent.deleted,
          ]) {
            expect(albumModeAfter(m, e), m, reason: '$m + $e');
          }
          expect(isSelectionMode(m), isTrue);
          expect(albumModeProgressTarget(m), 1);
        }
        expect(isSelectionMode(AlbumMode.timeline), isFalse);
        expect(albumModeProgressTarget(AlbumMode.timeline), 0);
      },
    );

    test(
      '내비 크롬 · pill 수: timeline 선택 + main 3 · select/liked close + selection 3 · deleted close + restore 1',
      () {
        expect(albumNavChrome(AlbumMode.timeline), (
          left: AlbumNavLeft.select,
          right: AlbumNavRight.main,
        ));
        expect(albumNavChrome(AlbumMode.select).right, AlbumNavRight.selection);
        expect(albumNavChrome(AlbumMode.liked).right, AlbumNavRight.selection);
        expect(albumNavChrome(AlbumMode.deleted), (
          left: AlbumNavLeft.close,
          right: AlbumNavRight.restore,
        ));
        expect(albumNavPillCount(AlbumNavRight.main), 3);
        expect(albumNavPillCount(AlbumNavRight.restore), 1);
      },
    );

    test(
      '배치 좋아요 · 뱃지 규칙 · 하트 표시 (F8 — 선택 모드도 2×2 유지 · 좋아요 보기 모든 칸 · 삭제 없음)',
      () {
        const liked = [true, false, true];
        expect(layoutLikes(liked, AlbumMode.timeline), liked);
        expect(layoutLikes(liked, AlbumMode.select), liked);
        expect(layoutLikes(liked, AlbumMode.liked), [false, false, false]);
        expect(layoutLikes(liked, AlbumMode.deleted), [false, false, false]);
        expect(gridBadgeOf(AlbumMode.timeline), GridBadge.tile);
        expect(gridBadgeOf(AlbumMode.select), GridBadge.tile);
        expect(gridBadgeOf(AlbumMode.liked), GridBadge.every);
        expect(gridBadgeOf(AlbumMode.deleted), GridBadge.none);
        bool shown(GridBadge b, bool tile, bool sel, bool exit) =>
            cellHeartShown(b, tile: tile, selected: sel, exiting: exit);
        expect(shown(GridBadge.tile, true, false, false), isTrue);
        expect(shown(GridBadge.tile, false, false, false), isFalse);
        expect(shown(GridBadge.tile, true, true, false), isFalse);
        expect(shown(GridBadge.every, false, false, false), isTrue);
        expect(shown(GridBadge.every, false, false, true), isFalse);
        expect(shown(GridBadge.none, true, false, false), isFalse);
      },
    );

    test('선택 heart: 모두 좋아요면 해제 · 아니면 모두 좋아요 · 빈 선택 null', () {
      expect(selectionHeartTarget(const []), isNull);
      expect(selectionHeartTarget(const [true, true]), isFalse);
      expect(selectionHeartTarget(const [true, false]), isTrue);
      expect(selectionHeartTarget(const [false]), isTrue);
    });

    test('데모 선택: 타임라인 · 선택 = 2×2 건너뛰고 앞 n · 보기 = 앞 n 칸', () {
      final photos = [
        const AlbumPhoto(id: 'a', image: 'a', liked: true),
        const AlbumPhoto(id: 'b', image: 'b'),
        const AlbumPhoto(id: 'c', image: 'c'),
        const AlbumPhoto(id: 'd', image: 'd'),
      ];
      expect(demoSelectionIds(photos, AlbumMode.select, 3), ['b', 'c', 'd']);
      expect(demoSelectionIds(photos, AlbumMode.liked, 2), ['a', 'b']);
      expect(demoSelectionIds(photos, AlbumMode.deleted, 0), isEmpty);
    });
  });

  group('섹션 계획 v6 (notes §6)', () {
    test(
      '사진 + 통화 @402: 히어로 402 (제목 326 · 메타 368) · 카드 p8 gap8 = 260 · 그리드 p8 · photo 톤 section/tint',
      () {
        final p = resolveSectionPlan(
          kind: AlbumSectionKind.photosCalls,
          hasHero: true,
          callCount: 3,
          photoCount: 27,
          width: _w,
        );
        expect(p.header, SectionHeaderKind.hero);
        expect(p.headerHeight, 402);
        expect(p.titleTop, 326);
        expect(p.metaTop, 368);
        expect(p.cards.height, 260);
        expect(p.grid.has, isTrue);
        expect(p.tone, AlbumTone.photo);
        expect(p.tint, 'section/tint');
        expect(lastSectionInset(p), 94);
      },
    );

    test(
      '통화만: 텍스트 헤더 124 (제목 48 · 메타 90) · 목록 pt8 px8 pb16 = 184 · light 톤 background/canvas/neutral/base',
      () {
        final p = resolveSectionPlan(
          kind: AlbumSectionKind.callsOnly,
          hasHero: false,
          callCount: 2,
          photoCount: 0,
          width: _w,
        );
        expect(p.header, SectionHeaderKind.text);
        expect([p.headerHeight, p.titleTop, p.metaTop], [124, 48, 90]);
        expect(p.cards.height, 184);
        expect(p.grid.has, isFalse);
        expect(p.tone, AlbumTone.light);
        expect(p.tint, 'background/canvas/neutral/base');
        expect(lastSectionInset(p), 86);
      },
    );

    test('@393 폭 규칙: 히어로 393 · 제목 317 · 메타 359 · 셀 73.8 · 타일 149.6', () {
      expect(heroSize(393), 393);
      expect(heroTitleTop(393), 317);
      expect(heroMetaTop(393), 359);
      expect(gridCellSize(393), closeTo(73.8, 1e-9));
      expect(likedTileSize(393), closeTo(149.6, 1e-9));
    });

    test(
      'content 높이 @402: 1141.6 + 308 + 587.6 = 2037.2 (RN verify-album 과 같다)',
      () {
        final store = AlbumStore();
        addTearDown(store.dispose);
        final heights = <double>[];
        final sections = store.sections;
        for (var i = 0; i < sections.length; i++) {
          final s = sections[i];
          final plan = resolveSectionPlan(
            kind: s.kind,
            hasHero: s.heroImage != null,
            callCount: s.calls.length,
            photoCount: s.photos.length,
            width: _w,
          );
          final rows = s.photos.isEmpty
              ? 0
              : gridV5Boxes(
                  [for (final p in s.photos) p.id],
                  layoutLikes([
                    for (final p in s.photos) p.liked,
                  ], AlbumMode.timeline),
                  photoGridV6Metrics,
                  _w,
                ).rows;
          heights.add(
            sectionHeight(plan, rows, _w, isLast: i == sections.length - 1),
          );
        }
        expect(heights[0], closeTo(1141.6, 1e-6));
        expect(heights[1], closeTo(308, 1e-6));
        expect(heights[2], closeTo(587.6, 1e-6));
        expect(heights.reduce((a, b) => a + b), closeTo(2037.2, 1e-6));
      },
    );

    test(
      'v6 그리드 상자: 정사각 셀 75.6 · 2×2 타일 153.2 (F4) · 27 장 + 타일 = 6 행 · 높이 479.6 · 가장자리 r4',
      () {
        final ids = [for (var i = 0; i < 27; i++) 'p$i'];
        final g = gridV5Boxes(
          ids,
          [for (var i = 0; i < 27; i++) i == 0],
          photoGridV6Metrics,
          _w,
        );
        final t = g.boxes['p0']!;
        expect([t.x, t.y], [8, 8]);
        expect(t.w, closeTo(153.2, 1e-9));
        expect(t.h, closeTo(153.2, 1e-9));
        expect(g.boxes['p1']!.w, closeTo(75.6, 1e-9));
        expect(g.boxes['p1']!.h, closeTo(75.6, 1e-9));
        expect(g.rows, 6);
        expect(g.height, closeTo(479.6, 1e-9));
        expect([t.rl, t.rr], [4, 0]);
      },
    );

    test('슬롯 (접힘 = 카드 슬롯이 머리 높이 · 그리드가 카드만큼 올라온다)', () {
      final p = resolveSectionPlan(
        kind: AlbumSectionKind.photosCalls,
        hasHero: true,
        callCount: 3,
        photoCount: 27,
        width: _w,
      );
      final open = sectionSlotTops(p, 6, _w);
      expect(open.take(5), [326, 368, 410, 494, 578]);
      expect(open[5], 662 + 8);
      final collapsed = sectionSlotTops(p, 6, _w, cardsCollapsed: true);
      expect(collapsed.sublist(2, 5), [402, 402, 402]);
      expect(collapsed[5], 402 + 8);
      expect(firstRowSlot(p), 5);
    });

    test(
      '경계 밴드: 이전 바탕 → 투명 짝 (section/tint → section/tint-clear · 캔버스 → effect/linear/subtle) · 섹션 0 없음',
      () {
        expect(boundaryBlendOf(0, 'section/tint'), isNull);
        expect(boundaryBlendOf(1, 'section/tint'), (
          height: 48.0,
          from: 'section/tint',
          to: 'section/tint-clear',
        ));
        expect(
          boundaryBlendOf(2, 'background/canvas/neutral/base')!.to,
          'effect/linear/subtle',
        );
      },
    );
  });

  group('톤 (notes §7) · 데모 스크롤', () {
    test('샘플: 내비 85 · 탭바 H − 62 (874 → 812) · 가운데 0.5 에서 이산 톤 · 글리프 · 배경', () {
      expect(navToneSampleY, 85);
      expect(tabBarToneSampleY(_h), 812);
      expect(toneOfProgress(0.49), AlbumTone.photo);
      expect(toneOfProgress(0.5), AlbumTone.light);
      expect(toneStatusGlyphsLight(AlbumTone.photo), isTrue);
      expect(toneStatusGlyphsLight(AlbumTone.light), isFalse);
      expect(
        toneBackdropOf(AlbumTone.photo),
        GlassBackdropTone.fromToken('default'),
      );
      expect(
        toneBackdropOf(AlbumTone.light),
        GlassBackdropTone.fromToken('light'),
      );
      final bands = [
        ToneBand.of(0, 1141.6, AlbumTone.photo),
        ToneBand.of(1141.6, 308, AlbumTone.light),
        ToneBand.of(1449.6, 587.6, AlbumTone.photo),
      ];
      expect(toneAtY(bands, -10), AlbumTone.photo);
      expect(toneAtY(bands, 1200), AlbumTone.light);
      expect(toneAtY(bands, 5000), AlbumTone.photo);
      expect(toneAtY(const [], 10), AlbumTone.photo);
    });

    test('데모 스크롤 정거장: 섹션 위 − 헤더 118 (0 · 최대로 자름) → 끝 → 0', () {
      expect(demoScrollAnchorY, 118);
      expect(demoScrollStops([0, 1141.6, 1449.6], 2037.2, _h), [
        closeTo(1023.6, 1e-6),
        closeTo(1163.2, 1e-6),
        0,
      ]);
    });
  });

  group('사진 보기 v6 (notes §9)', () {
    test(
      '카드 3:4 394 × 525.33 @ (4, 122) · 스트립 663.33 · 날짜 790 · 이동 108 / 96 / 210.67 · 넘김 W',
      () {
        final card = viewerCardRectV6(_w);
        expect(card.left, 4);
        expect(card.top, 122);
        expect(card.width, 394);
        expect(card.height, closeTo(525.3333, 1e-3));
        expect(viewerStripTop(_w), closeTo(663.3333, 1e-3));
        expect(viewerDatePillTop(_h), 790);
        final t = viewerChromeTravel(_w, _h);
        expect(t.top, 108);
        expect(t.date, 96);
        expect(t.strip, closeTo(210.6667, 1e-3));
        expect(viewerPageStep(_w), 402);
      },
    );

    test(
      '스트립 가운데: pos 0 → 172 (Figma 가운데 칸 172 – 230) · pos 2 → 48 · 점프 출발 = 목표 옆',
      () {
        expect(stripOffsetX(0, _w), 172);
        expect(stripOffsetX(2, _w), 48);
        expect(stripJumpStart(3, 4), 3);
        expect(stripJumpStart(3, 2), 3);
        expect(stripJumpStart(0, 5), 4);
        expect(stripJumpStart(6, 1), 2);
      },
    );

    test('끌기 · 넘김 수식 (v5 규칙 — v6 카드 높이)', () {
      final h = viewerCardRectV6(_w).height;
      expect(viewerShouldDismiss(0.2 * h, 0, h), isTrue);
      expect(viewerShouldDismiss(0.1 * h, 0, h), isFalse);
      expect(viewerShouldDismiss(0, 800, h), isTrue);
      final look = viewerDragLook(0, 0.2 * h, h);
      expect(
        look.scale,
        closeTo(1 - (1 - CameoMotion.viewerDragMinScale) * 0.2, 1e-9),
      );
      expect(look.dim, closeTo(0.5, 1e-9));
      expect(viewerPageTarget(1, 5, -0.6 * _w, 0, _w), 2);
      expect(viewerPageTarget(1, 5, -0.3 * _w, 0, _w), 1);
      expect(viewerPageWindow(0, 3), [0, 1]);
    });
  });

  group('빈 앨범 · 보기 섹션', () {
    test('묶음 위 (H − 232) / 2 = 321 · 등장 지연 원 0 · 80 → 제목 160 · CTA 220', () {
      expect(emptyColumnTop(_h), 321);
      final d = emptyEntranceDelays(2);
      expect(d.avatars, const [Duration.zero, Duration(milliseconds: 80)]);
      expect(d.title, const Duration(milliseconds: 160));
      expect(d.cta, const Duration(milliseconds: 220));
      expect(emptyFloatY(0, 0), closeTo(0, 1e-9));
    });

    test(
      '모드별 섹션: 타임라인 · 선택 = 그대로 · 좋아요 = 좋아요 섹션 · 삭제 = 지운 섹션 · 없으면 첫 히어로 섹션 사진 0 장',
      () {
        final store = AlbumStore();
        addTearDown(store.dispose);
        List<AlbumSection> of(AlbumMode m) => albumSectionsForMode(
          sections: store.sections,
          liked: store.likedSections,
          deleted: store.deletedSections,
          mode: m,
        );
        expect(of(AlbumMode.timeline), hasLength(3));
        expect(of(AlbumMode.select), hasLength(3));
        expect(of(AlbumMode.liked).single.photos, hasLength(1));
        final fallback = of(AlbumMode.deleted).single;
        expect(fallback.id, store.sections.first.id);
        expect(fallback.photos, isEmpty);
        expect(fallback.heroImage, isNotNull);
        store.deletePhotos([store.sections.last.photos.first.id]);
        expect(of(AlbumMode.deleted).single.id, store.sections.last.id);
        expect(
          albumSectionsForMode(
            sections: const [],
            liked: const [],
            deleted: const [],
            mode: AlbumMode.liked,
          ),
          isEmpty,
        );
      },
    );
  });
}
