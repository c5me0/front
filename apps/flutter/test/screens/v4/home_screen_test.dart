// Regression coverage for home screen. Preserve behavior, layout, and interaction
// expectations.

import 'package:cameo/components/album_card.dart';
import 'package:cameo/components/empty_state.dart';
import 'package:cameo/components/scroll_edge_fade.dart';
import 'package:cameo/content/app.g.dart';
import 'package:cameo/design_system/design_system.dart';
import 'package:cameo/navigation/navigation.dart';
import 'package:cameo/screens/album_gangneung/album_gangneung_screen.dart';
import 'package:cameo/screens/home/home_screen.dart';
import 'package:cameo/screens/partner/partner_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'v4_harness.dart';

double _edgeOpacity(WidgetTester tester) => tester
    .widget<Opacity>(
      find.descendant(
        of: find.byType(HomeScreen),
        matching: find.byKey(ScrollLinkedEdgeFade.opacityKey),
      ),
    )
    .opacity;

void main() {
  setUp(() {
    FlowDemo.resetForTesting();
    ZoomSource.clear();
  });
  tearDown(FlowDemo.resetForTesting);

  test('scrollEdgeOpacity: 0 (쉼 · 당겨 내림) → 스크롤 / 56 → 1', () {
    expect(scrollEdgeOpacity(-20), 0);
    expect(scrollEdgeOpacity(0), 0);
    expect(scrollEdgeOpacity(28), closeTo(0.5, 1e-9));
    expect(scrollEdgeOpacity(56), 1);
    expect(scrollEdgeOpacity(300), 1);
  });

  testWidgets(
    '배치: 헤더 62…118 · 카드 134 / 511 · 부제 = 상대 · 앨범 수 · 아래 여백 → 최대 스크롤 142',
    (tester) async {
      await pumpCameoApp(tester, '/home-v4?session=member');
      expectRect(
        rectOf(tester, find.byKey(HomeScreen.headerKey)),
        const Rect.fromLTWH(16, 62, 361, 56),
      );
      final title = rectOf(tester, find.byKey(HomeScreen.titleKey));
      final subtitle = rectOf(tester, find.byKey(HomeScreen.subtitleKey));
      expect(title.top, closeTo(62, 0.5));
      expect(subtitle.top - title.bottom, closeTo(4, 0.5));
      expect(
        find.text(
          fillTemplate(appContent.home.subtitle, {
            'partner': 'Yurim',
            'count': 2,
          }),
        ),
        findsOneWidget,
      );
      final cards = find.byType(AlbumCard);
      expect(cards, findsNWidgets(2));
      expectRect(
        rectOf(tester, cards.at(0)),
        const Rect.fromLTWH(16, 134, 361, 361),
      );
      expectRect(
        rectOf(tester, cards.at(1)),
        const Rect.fromLTWH(16, 511, 361, 361),
      );
      final scrollable = tester.state<ScrollableState>(
        find.descendant(
          of: find.byKey(HomeScreen.scrollKey),
          matching: find.byType(Scrollable),
        ),
      );
      // 62 + 56 + 16 + 361 + 16 + 361 + 106 + 16 − 852 = 142
      expect(scrollable.position.maxScrollExtent, closeTo(142, kTol));
      await disposeApp(tester);
    },
  );

  testWidgets(
    '위 가장자리 효과: 높이 safeTop + 72 (131) · 쉬면 0 (헤더를 흐리지 않음) · 스크롤 28 → 0.5 · 56 → 1',
    (tester) async {
      await pumpCameoApp(tester, '/home-v4?session=member');
      expect(
        rectOf(
          tester,
          find.descendant(
            of: find.byType(HomeScreen),
            matching: find.byType(ScrollEdgeFade),
          ),
        ).height,
        closeTo(59 + 56 + 16, kTol),
      );
      expect(_edgeOpacity(tester), 0);
      final scrollable = tester.state<ScrollableState>(
        find.descendant(
          of: find.byKey(HomeScreen.scrollKey),
          matching: find.byType(Scrollable),
        ),
      );
      scrollable.position.jumpTo(28);
      await tester.pump();
      expect(_edgeOpacity(tester), closeTo(0.5, 1e-9));
      scrollable.position.jumpTo(120);
      await tester.pump();
      expect(_edgeOpacity(tester), 1);
      await disposeApp(tester);
    },
  );

  testWidgets('등장 (앱 진입): 헤더 0 → 카드 1 (120 ms) → 카드 2 (240 ms) · 페이드 + 상승', (
    tester,
  ) async {
    await pumpCameoApp(tester, '/home-v4?session=member', settle: false);
    final header = find.byKey(HomeScreen.headerKey);
    final cards = find.byType(AlbumCard);
    expect(entranceOf(tester, header), 0);
    expect(entranceOf(tester, cards.at(0)), 0);
    await pumpFrames(tester, const Duration(milliseconds: 100));
    expect(entranceOf(tester, header), greaterThan(0));
    expect(entranceOf(tester, cards.at(0)), 0);
    await pumpFrames(tester, const Duration(milliseconds: 80)); // 180
    expect(entranceOf(tester, cards.at(0)), greaterThan(0));
    expect(entranceOf(tester, cards.at(1)), 0);
    await pumpFrames(tester, const Duration(milliseconds: 100)); // 280
    expect(entranceOf(tester, cards.at(1)), greaterThan(0));

    final fade = tester.widget<Opacity>(
      find.ancestor(of: cards.at(1), matching: find.byType(Opacity)).first,
    );
    expect(fade.opacity, lessThan(1));
    await settleApp(tester);
    expect(entranceOf(tester, cards.at(1)), 1);
    await disposeApp(tester);
  });

  testWidgets(
    '카드 누름 → 그 순간 그려진(눌린) rect 로 16-3 줌 (Z2) · 흐름 데모 home.openAlbum / openDayAlbum 등록',
    (tester) async {
      await pumpCameoApp(tester, '/home-v4?session=member');
      expect(FlowDemo.isRegistered(FlowDemoAction.homeOpenAlbum), isTrue);
      expect(FlowDemo.isRegistered(FlowDemoAction.homeOpenDayAlbum), isTrue);
      final g = await tester.startGesture(const Offset(196, 300));
      await pumpFrames(tester, const Duration(milliseconds: 300));
      await g.up();
      final rect = ZoomSource.rectOf(ZoomTarget.gangneung)!;
      const layout = Rect.fromLTWH(16, 134, 361, 361);
      expect(rect.width, lessThan(layout.width));
      expect(rect.width, closeTo(361 * CameoMotion.pressScale, 0.5));
      expect(rect.center.dx, closeTo(layout.center.dx, 1e-6));
      expect(rect.center.dy, closeTo(layout.center.dy, 1e-6));
      await settleApp(tester);
      expect(find.byType(AlbumGangneungScreen), findsOneWidget);
      await disposeApp(tester);
    },
  );

  testWidgets(
    '미연결: 빈 상태가 134…730 세로 가운데 · 부제 \'상대를 연결해 주세요\' · CTA → /connect · 카드 데모 거부',
    (tester) async {
      await pumpCameoApp(tester, '/home-v4?session=member&partner=none');
      expect(find.byType(AlbumCard), findsNothing);
      expect(find.text(appContent.home.subtitleEmpty), findsOneWidget);
      final empty = rectOf(tester, find.byType(EmptyState));
      expect(empty.center.dy, closeTo((134 + 730) / 2, 0.5));
      expect(FlowDemo.run(FlowDemoAction.homeOpenAlbum), isFalse);
      await tester.tap(find.byKey(EmptyState.actionKey));
      await settleApp(tester);
      expect(
        tester.widget<PartnerScreen>(find.byType(PartnerScreen)).mode,
        PartnerMode.settings,
      );
      await disposeApp(tester);
    },
  );
}
