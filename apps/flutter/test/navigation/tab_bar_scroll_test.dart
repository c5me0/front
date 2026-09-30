// Regression coverage for tab bar scroll. Preserve behavior, layout, and interaction
// expectations.

import 'package:cameo/navigation/navigation.dart';
import 'package:cameo/screens/home_timeline/home_timeline_screen.dart';
import 'package:cameo/screens/photo_viewer/photo_viewer_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_harness.dart';

void main() {
  setUp(FlowDemo.resetForTesting);
  tearDown(FlowDemo.resetForTesting);

  test(
    'browsing stays compact through reversals and pauses; rest at top restores',
    () {
      final state = TabBarScrollState();
      state.begin(0, 0, 1000);
      expect(state.update(10, 0, 1000), isFalse);
      expect(state.minimized, isFalse);
      expect(state.update(160, 0, 1000), isTrue);
      expect(state.minimized, isTrue);
      expect(state.update(80, 0, 1000), isFalse);
      expect(state.end(), isFalse);
      expect(state.minimized, isTrue);
      state.begin(80, 0, 1000);
      expect(state.update(6, 0, 1000), isFalse);
      expect(state.minimized, isTrue, reason: 'still moving at the top');
      expect(state.end(), isTrue);
      expect(state.minimized, isFalse);
    },
  );

  test(
    'neither boundary bounce nor a partial upward scroll expands the bar',
    () {
      final state = TabBarScrollState()..begin(900, 0, 1000);
      state.update(960, 0, 1000);
      expect(state.minimized, isTrue);
      for (final y in [1000.0, 1020.0, 1010.0, 1000.0]) {
        state.update(y, 0, 1000);
        expect(state.minimized, isTrue);
      }
      expect(state.update(800, 0, 1000), isFalse);
      expect(state.minimized, isTrue);
      state.update(-15, 0, 1000);
      expect(state.minimized, isTrue);
      state.update(5, 0, 1000);
      expect(state.minimized, isTrue);
      state.end();
      expect(state.minimized, isFalse);
    },
  );

  test(
    'explicit navigation expansion lasts until browsing resumes in either direction',
    () {
      final state = TabBarScrollState()..restore(300, 0, 1000);
      expect(state.minimized, isTrue);
      expect(state.expand(), isTrue);
      expect(state.update(300, 0, 1000), isFalse);
      state.begin(300, 0, 1000);
      state.update(292, 0, 1000);
      expect(state.minimized, isFalse);
      state.update(306, 0, 1000);
      expect(state.minimized, isFalse);
      state.update(296, 0, 1000);
      expect(state.minimized, isTrue);
    },
  );

  test('programmatic browsing and restoration use viewport position too', () {
    final state = TabBarScrollState();
    expect(state.update(300, 0, 1000), isTrue);
    expect(state.update(120, 0, 1000), isFalse);
    expect(state.minimized, isTrue);
    expect(state.update(0, 0, 1000), isTrue);
    expect(state.minimized, isFalse);
    state.restore(200, 0, 1000);
    expect(state.minimized, isTrue);
    state.restore(0, 0, 0);
    expect(state.minimized, isFalse);
  });

  Future<void> dragAlbum(WidgetTester tester, double delta) async {
    final g = await tester.startGesture(const Offset(201, 300));

    for (var i = 0; i < 4; i++) {
      await g.moveBy(Offset(0, delta / 4));
      await tester.pump(kFrame);
    }
    await tester.pump(const Duration(milliseconds: 100));
    await g.up();
    await settleApp(tester);
  }

  testWidgets(
    'album: browsing remains compact after reversing or pausing; tab tap requests navigation',
    (tester) async {
      await pumpCameoApp(tester, '/?session=member', size: kIPhone17Pro);
      final glass = tester.element(find.byKey(TabBarV6.pillKey));
      expect(appTabs(tester)!.tabBarModeShown, TabBarV6Mode.full);
      await dragAlbum(tester, -180);
      expect(appTabs(tester)!.tabBarModeShown, TabBarV6Mode.mini);
      expect(
        tester.getSize(find.byKey(TabBarV6.pillKey)).width,
        closeTo(190, 0.01),
      );
      expect(
        identical(glass, tester.element(find.byKey(TabBarV6.pillKey))),
        isTrue,
      );
      await dragAlbum(tester, 70);
      expect(appTabs(tester)!.tabBarModeShown, TabBarV6Mode.mini);
      await tester.pump(const Duration(seconds: 5));
      expect(appTabs(tester)!.tabBarModeShown, TabBarV6Mode.mini);
      await dragAlbum(tester, -100);
      expect(appTabs(tester)!.tabBarModeShown, TabBarV6Mode.mini);
      await tester.tap(find.byKey(TabBarV6.tabKey(0)));
      await settleApp(tester);
      expect(appTabs(tester)!.tabBarModeShown, TabBarV6Mode.full);
      expect(
        identical(glass, tester.element(find.byKey(TabBarV6.pillKey))),
        isTrue,
      );
      await disposeApp(tester);
    },
  );

  testWidgets(
    'album: programmatic browsing and closing selection mid-album remain compact',
    (tester) async {
      await pumpCameoApp(tester, '/?session=member', size: kIPhone17Pro);
      final scrollable = tester.state<ScrollableState>(
        find.descendant(
          of: find.byKey(HomeTimelineScreen.scrollKey),
          matching: find.byType(Scrollable),
        ),
      );
      scrollable.position.jumpTo(300);
      await settleApp(tester);
      expect(appTabs(tester)!.tabBarModeShown, TabBarV6Mode.mini);
      await tester.tap(find.byKey(HomeTimelineScreen.selectKey));
      await settleApp(tester);
      await dragAlbum(tester, 70);
      expect(appTabs(tester)!.tabBarModeShown, TabBarV6Mode.mini);
      await tester.tap(find.byKey(TabBarV6.tabKey(0)));
      await settleApp(tester);
      expect(appTabs(tester)!.tabBarModeShown, TabBarV6Mode.mini);
      await tester.tap(find.byKey(HomeTimelineScreen.selectCloseKey));
      await settleApp(tester);
      expect(appTabs(tester)!.tabBarModeShown, TabBarV6Mode.mini);
      scrollable.position.jumpTo(0);
      await settleApp(tester);
      expect(appTabs(tester)!.tabBarModeShown, TabBarV6Mode.full);
      await disposeApp(tester);
    },
  );

  testWidgets('album: returning fully to the top restores the original bar', (
    tester,
  ) async {
    await pumpCameoApp(tester, '/?session=member', size: kIPhone17Pro);
    await dragAlbum(tester, -180);
    expect(appTabs(tester)!.tabBarModeShown, TabBarV6Mode.mini);
    await dragAlbum(tester, 300);
    expect(appTabs(tester)!.tabBarModeShown, TabBarV6Mode.full);
    expect(
      tester.getSize(find.byKey(TabBarV6.pillKey)).width,
      closeTo(308, 0.01),
    );
    await disposeApp(tester);
  });

  testWidgets('album becoming empty restores the full bar', (tester) async {
    await pumpCameoApp(tester, '/?session=member', size: kIPhone17Pro);
    await dragAlbum(tester, -180);
    expect(appTabs(tester)!.tabBarModeShown, TabBarV6Mode.mini);
    lastAlbum.setEmptyMode(true);
    await settleApp(tester);
    expect(find.byKey(HomeTimelineScreen.emptyKey), findsOneWidget);
    expect(appTabs(tester)!.tabBarModeShown, TabBarV6Mode.full);
    await disposeApp(tester);
  });

  testWidgets('closing selection at the top returns to the default state', (
    tester,
  ) async {
    await pumpCameoApp(
      tester,
      '/?session=member&view=select',
      size: kIPhone17Pro,
    );
    expect(appTabs(tester)!.tabBarModeShown, TabBarV6Mode.mini);
    await tester.tap(find.byKey(HomeTimelineScreen.selectCloseKey));
    await settleApp(tester);
    expect(appTabs(tester)!.tabBarModeShown, TabBarV6Mode.full);
    await disposeApp(tester);
  });

  testWidgets(
    'viewing a photo resumes browsing after explicitly expanding navigation',
    (tester) async {
      await pumpCameoApp(tester, '/?session=member', size: kIPhone17Pro);
      final scrollable = tester.state<ScrollableState>(
        find.descendant(
          of: find.byKey(HomeTimelineScreen.scrollKey),
          matching: find.byType(Scrollable),
        ),
      );
      scrollable.position.jumpTo(400);
      await settleApp(tester);
      await tester.tap(find.byKey(TabBarV6.tabKey(0)));
      await settleApp(tester);
      expect(appTabs(tester)!.tabBarModeShown, TabBarV6Mode.full);
      final photo = lastAlbum.sections.first.photos[1];
      await tester.tap(find.byKey(HomeTimelineScreen.cellKey(photo.id)));

      await tester.pump(const Duration(milliseconds: 400));
      await settleApp(tester);
      expect(find.byType(PhotoViewerScreen), findsOneWidget);
      await tester.tap(find.byKey(PhotoViewerScreen.closeKey));
      await settleApp(tester);
      expect(appTabs(tester)!.tabBarModeShown, TabBarV6Mode.mini);
      await disposeApp(tester);
    },
  );
}
