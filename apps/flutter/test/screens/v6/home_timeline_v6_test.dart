// Regression coverage for home timeline v6. Preserve behavior, layout, and interaction
// expectations.

import 'package:cameo/components/album_nav_v6.dart';
import 'package:cameo/components/album_section_v6.dart';
import 'package:cameo/components/confirm_sheet.dart';
import 'package:cameo/components/controls.dart';
import 'package:cameo/components/empty_album_v6.dart';
import 'package:cameo/components/photo_grid_v6.dart';
import 'package:cameo/components/scrim_button.dart';
import 'package:cameo/components/scrim_pill.dart';
import 'package:cameo/content/lab.g.dart';
import 'package:cameo/design_system/design_system.dart';
import 'package:cameo/navigation/navigation.dart';
import 'package:cameo/screens/home_timeline/album_timeline_model.dart';
import 'package:cameo/screens/home_timeline/home_timeline_screen.dart';
import 'package:cameo/screens/partner/partner_screen.dart';
import 'package:cameo/state/album_store.dart';
import 'package:cameo/state/captured_photo.dart';
import 'package:cameo/state/photo_picker_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../navigation/app_harness.dart';
import 'album_v6_harness.dart';

HomeTimelineScreenState _home(WidgetTester tester) =>
    tester.state<HomeTimelineScreenState>(find.byType(HomeTimelineScreen));

PhotoGridV6State _grid(WidgetTester tester, String sectionId) =>
    tester.state<PhotoGridV6State>(
      find.descendant(
        of: find.byKey(HomeTimelineScreen.sectionKey(sectionId)),
        matching: find.byType(PhotoGridV6),
      ),
    );

ScrollableState _scrollable(WidgetTester tester) =>
    tester.state<ScrollableState>(
      find.descendant(
        of: find.byKey(HomeTimelineScreen.scrollKey),
        matching: find.byType(Scrollable),
      ),
    );

Finder _pillItem(Key pill, int i) => find.descendant(
  of: find.byKey(pill),
  matching: find.byKey(ScrimPill.itemKey(i)),
);

Future<void> _tapPill(WidgetTester tester, Key pill, int i) async {
  await tester.tap(_pillItem(pill, i));
  await settleApp(tester);
}

void main() {
  setUp(() {
    resetAlbumTestState();
    HomeTimelineScreenState.resetLaunchParamsForTesting();
  });
  tearDown(FlowDemo.resetForTesting);

  testWidgets(
    '기하 @402: 섹션 위 0 · 1141.6 · 1449.6 (끝 2037.2) · 히어로 402² (제목 326) · 셀 75.6 정사각 · 2×2 153.2 · 통화만 light · 내비 (16, 62) 60 + pill (240, 62) 146 · 헤더 118',
    (tester) async {
      await pumpCameoAppV6(tester, '/?session=member');
      final home = _home(tester);
      expect(home.mode, AlbumMode.timeline);
      expect(home.sectionTopOf('sungsu'), 0);
      expect(home.sectionTopOf('calls-only'), closeTo(1141.6, 1e-6));
      expect(home.sectionTopOf('section-2'), closeTo(1449.6, 1e-6));
      expect(
        _scrollable(tester).position.maxScrollExtent,
        closeTo(2037.2 - 874, 1e-6),
      );
      expectRect(
        tester.getRect(find.byKey(AlbumSectionV6.heroKey('sungsu'))),
        const Rect.fromLTWH(0, 0, 402, 402),
      );
      expect(
        tester.getTopLeft(find.byKey(AlbumSectionV6.titleKey('sungsu'))),
        const Offset(16, 326),
      );
      expect(
        tester.getTopLeft(find.byKey(AlbumSectionV6.metaKey('sungsu'))),
        const Offset(16, 368),
      );

      expectRect(
        tester.getRect(find.byKey(HomeTimelineScreen.callKey('sungsu', 0))),
        const Rect.fromLTWH(8, 410, 386, 76),
      );

      final first = lastAlbum.sections.first;
      expectRect(
        tester.getRect(
          find.byKey(HomeTimelineScreen.cellKey(first.photos[0].id)),
        ),
        const Rect.fromLTWH(8, 670, 153.2, 153.2),
      );
      expectRect(
        tester.getRect(
          find.byKey(HomeTimelineScreen.cellKey(first.photos[1].id)),
        ),
        const Rect.fromLTWH(163.2, 670, 75.6, 75.6),
      );

      final heart = find.descendant(
        of: find.byKey(HomeTimelineScreen.cellKey(first.photos[0].id)),
        matching: find.byType(HeartControl),
      );
      expect(heart, findsOneWidget);
      expect(
        tester.getBottomRight(heart),
        const Offset(8 + 153.2 - 2, 670 + 153.2 - 2),
      );

      final c = CameoTheme.colorsOf(
        tester.element(find.byType(HomeTimelineScreen)),
      );
      ColoredBox bg(String id) => tester.widget<ColoredBox>(
        find.descendant(
          of: find.byKey(AlbumSectionV6.backgroundKey(id)),
          matching: find.byType(ColoredBox),
        ),
      );
      expect(bg('sungsu').color, c.sectionTint);
      expect(bg('calls-only').color, c.backgroundCanvasNeutralBase);
      expect(bg('section-2').color, c.sectionTint);

      final select = tester.getRect(find.byKey(HomeTimelineScreen.selectKey));
      expect(select.topLeft, const Offset(16, 62));
      expect(select.height, 46);
      expectRect(
        tester.getRect(find.byKey(HomeTimelineScreen.navPillKey)),
        const Rect.fromLTWH(240, 62, 146, 46),
      );
      expectRect(
        tester.getRect(find.byKey(AlbumNavV6.headerKey)),
        const Rect.fromLTWH(0, 0, 402, 118),
      );

      expect(appTabs(tester)!.tabBarModeShown, TabBarV6Mode.full);
      expect(appTabs(tester)!.tabBarTone, TabBarV6Tone.photo);
      await disposeApp(tester);
    },
  );

  testWidgets(
    '선택 모드 (F8): 미니 탭바 · 카드 접힘 · 2×2 유지 · X + [share-2 · heart · trash] (16 / 240) · 칸 탭 = 선택 (체크 · 0.3) · heart = like-all → 선택 비움 · X',
    (tester) async {
      await pumpCameoAppV6(tester, '/?session=member');
      await tester.tap(find.byKey(HomeTimelineScreen.selectKey));
      await settleApp(tester);
      final home = _home(tester);
      expect(home.mode, AlbumMode.select);
      expect(home.modeProgress, closeTo(1, 1e-3));
      expect(appTabs(tester)!.tabBarModeShown, TabBarV6Mode.mini);
      expectRect(
        tester.getRect(find.byKey(HomeTimelineScreen.selectCloseKey)),
        const Rect.fromLTWH(16, 62, 46, 46),
      );
      expectRect(
        tester.getRect(find.byKey(HomeTimelineScreen.selectPillKey)),
        const Rect.fromLTWH(240, 62, 146, 46),
      );

      expect(find.byKey(HomeTimelineScreen.callKey('sungsu', 0)), findsNothing);
      final photos = lastAlbum.sections.first.photos;
      expectRect(
        tester.getRect(find.byKey(HomeTimelineScreen.cellKey(photos[0].id))),
        const Rect.fromLTWH(8, 410, 153.2, 153.2),
        reason: '2×2 타일 유지 (F8)',
      );

      final ids = demoSelectionIds(photos, AlbumMode.select, 3);
      for (final id in ids) {
        await tester.tap(find.byKey(HomeTimelineScreen.cellKey(id)));
        await tester.pump(kFrame);
      }
      await settleApp(tester);
      expect(home.selected, ids.toSet());
      expect(
        find.descendant(
          of: find.byKey(HomeTimelineScreen.cellKey(ids.first)),
          matching: find.byType(SelectControl),
        ),
        findsOneWidget,
      );
      expect(
        tester.getBottomRight(find.byType(SelectControl).first).dx,
        closeTo(
          tester
                  .getRect(find.byKey(HomeTimelineScreen.cellKey(ids.first)))
                  .right -
              3.8,
          1e-3,
        ),
      );

      await _tapPill(tester, HomeTimelineScreen.selectPillKey, 1);
      expect(
        [for (final id in ids) lastAlbum.photoById(id)!.liked],
        [true, true, true],
      );
      expect(home.selected, isEmpty);
      expect(home.mode, AlbumMode.select);

      await tester.tap(find.byKey(HomeTimelineScreen.selectCloseKey));
      await settleApp(tester);
      expect(home.mode, AlbumMode.timeline);
      expect(appTabs(tester)!.tabBarModeShown, TabBarV6Mode.full);
      expect(
        find.byKey(HomeTimelineScreen.callKey('sungsu', 0)),
        findsOneWidget,
      );
      await disposeApp(tester);
    },
  );

  testWidgets(
    '좋아요 보기 (2295:10137): 좋아요 사진만 · 모든 칸 하트 (inset 3.8) · 1×1 · 미니 탭바 · heart = 선택 해제 → 칸이 나간다 · X',
    (tester) async {
      await pumpCameoAppV6(tester, '/?session=member&view=liked&liked=10');
      await settleApp(tester);
      final home = _home(tester);
      expect(home.mode, AlbumMode.liked);
      expect(appTabs(tester)!.tabBarModeShown, TabBarV6Mode.mini);
      final drawn = home.drawnSections;
      expect(drawn.single.id, 'sungsu');
      expect(drawn.single.photos, hasLength(10));

      final p0 = drawn.single.photos[0].id;
      expectRect(
        tester.getRect(find.byKey(HomeTimelineScreen.cellKey(p0))),
        const Rect.fromLTWH(8, 410, 75.6, 75.6),
      );
      final hearts = find.descendant(
        of: find.byKey(HomeTimelineScreen.sectionKey('sungsu')),
        matching: find.byType(HeartControl),
      );
      expect(hearts, findsNWidgets(10));
      expect(
        tester.getBottomRight(
          find.descendant(
            of: find.byKey(HomeTimelineScreen.cellKey(p0)),
            matching: find.byType(HeartControl),
          ),
        ),
        const Offset(8 + 75.6 - 3.8, 410 + 75.6 - 3.8),
      );

      final ids = [drawn.single.photos[0].id, drawn.single.photos[1].id];
      for (final id in ids) {
        await tester.tap(find.byKey(HomeTimelineScreen.cellKey(id)));
        await tester.pump(kFrame);
      }
      expect(home.selected, ids.toSet());

      expect(find.byType(SelectControl), findsNWidgets(2));
      await _tapPill(tester, HomeTimelineScreen.selectPillKey, 1);
      expect(lastAlbum.photoById(ids[0])!.liked, isFalse);
      expect(home.drawnSections.single.photos, hasLength(8));
      expect(find.byKey(HomeTimelineScreen.cellKey(ids[0])), findsNothing);

      final bottom = find.byKey(HomeTimelineScreen.overscrollBottomKey);
      expectRect(tester.getRect(bottom), const Rect.fromLTWH(0, 437, 402, 437));
      expect(
        tester.widget<ColoredBox>(bottom).color,
        CameoTheme.colorsOf(tester.element(bottom)).sectionTint,
      );
      await tester.tap(find.byKey(HomeTimelineScreen.selectCloseKey));
      await tester.pump(kFrame);
      await tester.pump(kFrame);

      double joinOpacity() => tester
          .widget<Opacity>(
            find
                .descendant(
                  of: find.byKey(HomeTimelineScreen.sectionKey('calls-only')),
                  matching: find.byType(Opacity),
                )
                .first,
          )
          .opacity;
      expect(joinOpacity(), lessThan(0.5));
      await settleApp(tester);
      expect(joinOpacity(), 1);
      expect(home.mode, AlbumMode.timeline);
      await disposeApp(tester);
    },
  );

  testWidgets(
    '지움 (소프트) → 삭제 보기 (2295:11367): trash → 확인 시트 (v6 문구) → 타임라인에서 빠짐 · history → 지운 사진 · X + [archive] (340) · archive = 되살림',
    (tester) async {
      await pumpCameoAppV6(tester, '/?session=member&select=2');
      await settleApp(tester);
      final home = _home(tester);
      expect(home.mode, AlbumMode.select);
      final ids = home.selected.toList();
      expect(ids, hasLength(2));
      await _tapPill(tester, HomeTimelineScreen.selectPillKey, 2);
      expect(find.text('지운 사진은 최근 삭제에서\n다시 되돌릴 수 있어요'), findsOneWidget);
      await tester.tap(find.byKey(ConfirmSheet.confirmKey));
      await settleApp(tester);
      for (final id in ids) {
        expect(lastAlbum.photoById(id), isNull);
        expect(lastAlbum.anyPhotoById(id)!.deleted, isTrue);
      }
      expect(home.mode, AlbumMode.select);
      expect(home.selected, isEmpty);
      await tester.tap(find.byKey(HomeTimelineScreen.selectCloseKey));
      await settleApp(tester);

      await _tapPill(tester, HomeTimelineScreen.navPillKey, 2);
      expect(home.mode, AlbumMode.deleted);
      expect({
        for (final p in home.drawnSections.single.photos) p.id,
      }, ids.toSet());
      expectRect(
        tester.getRect(find.byKey(HomeTimelineScreen.restorePillKey)),
        const Rect.fromLTWH(340, 62, 46, 46),
      );
      expect(
        find.descendant(
          of: find.byKey(HomeTimelineScreen.sectionKey('sungsu')),
          matching: find.byType(HeartControl),
        ),
        findsNothing,
        reason: '삭제 보기 = 뱃지 없음',
      );
      await tester.tap(find.byKey(HomeTimelineScreen.cellKey(ids.first)));
      await tester.pump(kFrame);
      await _tapPill(tester, HomeTimelineScreen.restorePillKey, 0);
      expect(lastAlbum.photoById(ids.first), isNotNull);
      expect(home.drawnSections.single.photos.single.id, ids.last);
      await tester.tap(find.byKey(HomeTimelineScreen.selectCloseKey));
      await settleApp(tester);
      expect(home.mode, AlbumMode.timeline);
      await disposeApp(tester);
    },
  );

  testWidgets(
    '여러 칸이 한꺼번에 나갈 때 (선택 6 장 → trash): 나가는 칸은 같은 셀 · 사진 인스턴스로 제자리에서 줄어든다 (RN §15 — 다시 마운트되면 사라진다)',
    (tester) async {
      await pumpCameoAppV6(tester, '/?session=member&select=6');
      await settleApp(tester);
      final home = _home(tester);
      final ids = home.selected.toList();
      expect(ids, hasLength(6));
      Element imageOf(String id) => tester.element(
        find.descendant(
          of: find.byKey(HomeTimelineScreen.cellKey(id)),
          matching: find.byKey(PhotoGridV6.imageKey),
        ),
      );
      final before = {for (final id in ids) id: imageOf(id)};
      final rects = {
        for (final id in ids)
          id: tester.getRect(find.byKey(HomeTimelineScreen.cellKey(id))),
      };
      await _tapPill(tester, HomeTimelineScreen.selectPillKey, 2);
      await tester.tap(find.byKey(ConfirmSheet.confirmKey));
      final grid = _grid(tester, 'sungsu');
      for (var i = 0; i < 30 && grid.exitingIds.isEmpty; i++) {
        await tester.pump(kFrame);
      }
      expect(grid.exitingIds.toSet(), ids.toSet());

      await tester.pump(const Duration(milliseconds: 60));
      expect(grid.reflowProgress, inExclusiveRange(0, 1));
      for (final id in ids) {
        expect(
          identical(imageOf(id), before[id]),
          isTrue,
          reason: '$id 사진 인스턴스',
        );
        final shown = tester.getRect(
          find.byKey(HomeTimelineScreen.cellKey(id)),
        );
        expect(shown.width, inExclusiveRange(0, rects[id]!.width), reason: id);
        expect(shown.center.dx, closeTo(rects[id]!.center.dx, 0.5), reason: id);
        final opacity = tester
            .widgetList<Opacity>(
              find.ancestor(
                of: find.byKey(HomeTimelineScreen.cellKey(id)),
                matching: find.byType(Opacity),
              ),
            )
            .first
            .opacity;
        expect(opacity, greaterThan(0), reason: id);

        expect(
          tester
              .widget<IgnorePointer>(
                find
                    .ancestor(
                      of: find.byKey(HomeTimelineScreen.cellKey(id)),
                      matching: find.byType(IgnorePointer),
                    )
                    .first,
              )
              .ignoring,
          isTrue,
        );
      }
      await settleApp(tester);
      expect(grid.exitingIds, isEmpty);
      for (final id in ids) {
        expect(find.byKey(HomeTimelineScreen.cellKey(id)), findsNothing);
      }
      await disposeApp(tester);
    },
  );

  testWidgets('pill plus → 사진 선택기 → 오늘 섹션 맨 앞 (고른 순서) · 취소 = 그대로', (
    tester,
  ) async {
    final a = CapturedPhoto.placeholder(LabImages.cameraPlaceholder);
    final b = CapturedPhoto.placeholder(LabImages.cameraViewfinderV5);
    await pumpCameoAppV6(
      tester,
      '/?session=member',
      picker: SimulatedPhotoPickerService(result: [a, b]),
    );
    await _tapPill(tester, HomeTimelineScreen.navPillKey, 0);
    expect(lastPicker.requests, [null]);
    final today = lastAlbum.sections.first;
    expect(today.id, todaySectionId);
    expect([for (final p in today.photos) p.capture], [a, b]);
    expect(_home(tester).drawnSections.first.id, todaySectionId);
    lastPicker.result = const [];
    await _tapPill(tester, HomeTimelineScreen.navPillKey, 0);
    expect(lastAlbum.sections.first.photos, hasLength(2));
    await disposeApp(tester);
  });

  testWidgets(
    '빈 앨범 (2295:10719): 밝은 캔버스 · 묶음 (H − 232)/2 = 321 · 아바타 100 겹침 25 · 제목 · CTA gray → 불러오기 · 선택 disabled · 톤 light',
    (tester) async {
      await pumpCameoAppV6(tester, '/?session=member&album=empty');
      expect(find.byKey(HomeTimelineScreen.emptyKey), findsOneWidget);
      expect(tester.getTopLeft(find.byKey(EmptyAlbumV6.columnKey)).dy, 321);
      expectRect(
        tester.getRect(find.byKey(EmptyAlbumV6.meKey)),
        const Rect.fromLTWH(113.5, 321, 100, 100),
      );
      expectRect(
        tester.getRect(find.byKey(EmptyAlbumV6.partnerKey)),
        const Rect.fromLTWH(188.5, 321, 100, 100),
      );
      expect(tester.getTopLeft(find.byKey(EmptyAlbumV6.titleKey)).dy, 445);

      final cta = tester.getRect(find.byKey(EmptyAlbumV6.ctaKey));
      expect(cta.center.dx, closeTo(201, 1e-3));
      expect(cta.top, 499);
      expect(cta.height, 54);
      expect(
        tester
            .widget<ScrimButton>(find.byKey(HomeTimelineScreen.selectKey))
            .disabled,
        isTrue,
      );
      final home = _home(tester);
      expect(home.navTone, AlbumTone.light);
      expect(appTabs(tester)!.tabBarTone, TabBarV6Tone.canvas);
      expect(appTabs(tester)!.tabBarModeShown, TabBarV6Mode.full);
      await tester.tap(find.byKey(EmptyAlbumV6.ctaKey));
      await settleApp(tester);
      expect(find.byKey(HomeTimelineScreen.emptyKey), findsNothing);
      expect(home.drawnSections.single.id, todaySectionId);
      expect(home.navTone, AlbumTone.photo);
      await disposeApp(tester);
    },
  );

  testWidgets(
    '톤 (E13 ④ v6): 통화만 섹션이 내비 아래 → light (글래스 배경 light · 헤더 topLinear) · 탭바 아래 → canvas',
    (tester) async {
      await pumpCameoAppV6(tester, '/?session=member');
      final home = _home(tester);
      expect(home.navTone, AlbumTone.photo);

      _scrollable(tester).position.jumpTo(1141.6 - 85 + 10);
      await settleApp(tester);
      expect(home.navTone, AlbumTone.light);
      expect(home.navBackdrop, GlassBackdropTone.fromToken('light'));
      expect(home.navToneProgress, closeTo(1, 1e-3));

      _scrollable(tester).position.jumpTo(1141.6 - 812 + 10);
      await settleApp(tester);
      expect(home.navTone, AlbumTone.photo);
      expect(home.tabTone, AlbumTone.light);
      expect(appTabs(tester)!.tabBarTone, TabBarV6Tone.canvas);
      await disposeApp(tester);
    },
  );

  testWidgets(
    '흐름 데모 핸들러: home.liked → settle · liked.close · home.deleted (지운 것 없음 → 첫 히어로 섹션 0 장) · deleted.close · home.select · select.toggle (2×2 건너뛴 3 장) · select.close',
    (tester) async {
      await pumpCameoAppV6(tester, '/?session=member');
      final home = _home(tester);
      Future<void> run(FlowDemoAction a, AlbumMode after) async {
        final before = FlowDemo.settleCount(a);
        expect(FlowDemo.run(a), isTrue, reason: a.id);
        await settleApp(tester);
        await tester.pump(const Duration(milliseconds: 600));
        await settleApp(tester);
        expect(home.mode, after, reason: a.id);
        expect(FlowDemo.settleCount(a), before + 1, reason: '${a.id} settle');
      }

      await run(FlowDemoAction.homeLiked, AlbumMode.liked);
      await run(FlowDemoAction.likedClose, AlbumMode.timeline);
      await run(FlowDemoAction.homeDeleted, AlbumMode.deleted);
      expect(home.drawnSections.single.id, 'sungsu');
      expect(home.drawnSections.single.photos, isEmpty);
      expect(find.byKey(AlbumSectionV6.heroKey('sungsu')), findsOneWidget);
      await run(FlowDemoAction.deletedClose, AlbumMode.timeline);
      await run(FlowDemoAction.homeSelect, AlbumMode.select);
      await run(FlowDemoAction.selectToggle, AlbumMode.select);
      expect(
        home.selected,
        demoSelectionIds(
          lastAlbum.sections.first.photos,
          AlbumMode.select,
          3,
        ).toSet(),
      );
      await run(FlowDemoAction.selectClose, AlbumMode.timeline);

      expect(FlowDemo.run(FlowDemoAction.likedClose), isFalse);
      await disposeApp(tester);
    },
  );

  testWidgets(
    '흐름 데모: home.scroll = 섹션마다 멈췄다 맨 위로 → settle · home.openPhoto (맨 위일 때만) · back · home.openCallCard → 통화 기록',
    (tester) async {
      await pumpCameoAppV6(tester, '/?session=member');
      final scroll = _scrollable(tester);
      final before = FlowDemo.settleCount(FlowDemoAction.homeScroll);
      expect(FlowDemo.run(FlowDemoAction.homeScroll), isTrue);
      var maxOffset = 0.0;
      for (var i = 0; i < 500; i++) {
        await tester.pump(kFrame);
        if (scroll.position.pixels > maxOffset) {
          maxOffset = scroll.position.pixels;
        }
        if (FlowDemo.settleCount(FlowDemoAction.homeScroll) > before) break;
      }
      expect(FlowDemo.settleCount(FlowDemoAction.homeScroll), before + 1);
      expect(maxOffset, closeTo(2037.2 - 874, 1));
      expect(scroll.position.pixels, 0);
      expect(FlowDemo.run(FlowDemoAction.homeOpenPhoto), isTrue);
      await settleApp(tester);
      expect(FlowDemo.stackSnapshot().top, FlowDemoScreen.photo);
      expect(FlowDemo.run(FlowDemoAction.homeOpenPhoto), isFalse);
      FlowDemo.run(FlowDemoAction.back);
      await settleApp(tester);
      expect(FlowDemo.run(FlowDemoAction.homeOpenCallCard), isTrue);
      await settleApp(tester);
      expect(FlowDemo.stackSnapshot().top, FlowDemoScreen.transcript);
      await disposeApp(tester);
    },
  );

  testWidgets('상대 미연결 → 빈 앨범: 나 원만 · \'상대 연결하기\' → /connect', (tester) async {
    await pumpCameoAppV6(tester, '/?session=member&partner=none');
    expect(find.byKey(HomeTimelineScreen.emptyKey), findsOneWidget);
    expect(find.byKey(EmptyAlbumV6.meKey), findsOneWidget);
    expect(find.byKey(EmptyAlbumV6.partnerKey), findsNothing);
    expectRect(
      tester.getRect(find.byKey(EmptyAlbumV6.meKey)),
      const Rect.fromLTWH(151, 321, 100, 100),
    );
    await tester.tap(find.byKey(EmptyAlbumV6.ctaKey));
    await settleApp(tester);
    expect(
      tester.widget<PartnerScreen>(find.byType(PartnerScreen)).mode,
      PartnerMode.settings,
    );
    await disposeApp(tester);
  });

  testWidgets('더블 탭 = 좋아요 (타임라인) → 2×2 리플로우 · 칸 탭 = 사진 보기', (tester) async {
    await pumpCameoAppV6(tester, '/?session=member');
    final photos = lastAlbum.sections.first.photos;
    final id = photos[3].id;
    final cell = find.byKey(HomeTimelineScreen.cellKey(id));
    await tester.tap(cell);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(cell);
    await settleApp(tester);
    expect(lastAlbum.photoById(id)!.liked, isTrue);
    expect(
      _grid(tester, 'sungsu').targetBoxes!.boxes[id]!.w,
      closeTo(153.2, 1e-6),
    );
    await disposeApp(tester);
  });
}
