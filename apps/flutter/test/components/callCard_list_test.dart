// ignore_for_file: file_names
// Regression coverage for callCard list. Preserve behavior, layout, and interaction
// expectations.

import 'package:cameo/components/call_history_card.dart';
import 'package:cameo/components/call_history_list.dart';
import 'package:cameo/content/lab.g.dart';
import 'package:cameo/design_system/design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const double _screenWidth = 393;

const double _tol = 0.001;

final _sungsu = labAlbumDay.sections.firstWhere((s) => s.id == 'sungsu');
final _emptyPhoto = labAlbumDay.sections.firstWhere(
  (s) => s.id == 'empty-photo',
);

Widget _harness(Widget child) {
  return MediaQuery(
    data: const MediaQueryData(size: Size(_screenWidth, 852)),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: _screenWidth, child: child),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'onPhoto 목록 (2042:2803): 393 x 260, p8 gap8, 카드 377 x 76 @ y 8/92/176',
    (tester) async {
      await tester.pumpWidget(
        _harness(CallHistoryList(cards: _sungsu.callCards)),
      );

      final list = find.byType(CallHistoryList);
      expect(tester.getSize(list).width, _screenWidth);
      expect(tester.getSize(list).height, closeTo(260, _tol));

      final surfaces = find.byType(BlurSurface);
      expect(surfaces, findsNWidgets(3));
      const ys = [8.0, 92.0, 176.0];
      for (var i = 0; i < 3; i++) {
        final at = surfaces.at(i);
        expect(tester.getTopLeft(at).dx, CameoLayout.callHistoryListPadding);
        expect(tester.getTopLeft(at).dy, closeTo(ys[i], _tol));
        expect(tester.getSize(at).width, 377);
        expect(
          tester.getSize(at).height,
          closeTo(CameoLayout.callCardHeight, _tol),
        );
      }

      final cards = tester
          .widgetList<CallHistoryCard>(find.byType(CallHistoryCard))
          .toList();
      expect(cards.map((c) => c.tone), [
        CallHistoryCardTone.onPhoto,
        CallHistoryCardTone.onPhoto,
        CallHistoryCardTone.missed,
      ]);
      final tints = tester
          .widgetList<BlurSurface>(surfaces)
          .map((s) => s.tint)
          .toList();
      expect(tints, [
        CameoColors.albumCardTranslucent,
        CameoColors.albumCardTranslucent,
        CameoColors.backgroundCriticalBase,
      ]);

      expect(cards.map((c) => c.appearIndex), [null, null, null]);
    },
  );

  testWidgets('light 목록 (2042:2868): 393 x 184, pt8 px8 pb16, 카드 @ y 8/92', (
    tester,
  ) async {
    CallCardContent? pressed;
    await tester.pumpWidget(
      _harness(
        CallHistoryList(
          cards: _emptyPhoto.callCards,
          tone: CallHistoryListTone.light,
          onPress: (c) => pressed = c,
        ),
      ),
    );

    final list = find.byType(CallHistoryList);
    expect(tester.getSize(list).width, _screenWidth);
    expect(tester.getSize(list).height, closeTo(184, _tol));

    final surfaces = find.byType(BlurSurface);
    expect(surfaces, findsNWidgets(2));
    const ys = [8.0, 92.0];
    for (var i = 0; i < 2; i++) {
      final at = surfaces.at(i);
      expect(
        tester.getTopLeft(at).dx,
        CameoLayout.callHistoryListLightPaddingX,
      );
      expect(tester.getTopLeft(at).dy, closeTo(ys[i], _tol));
      expect(tester.getSize(at).width, 377);
      expect(tester.getSize(at).height, closeTo(76, _tol));
    }

    final lastBottom = tester.getBottomLeft(surfaces.at(1)).dy;
    expect(
      tester.getSize(list).height - lastBottom,
      closeTo(CameoLayout.callHistoryListLightPaddingBottom, _tol),
    );

    final tones = tester
        .widgetList<CallHistoryCard>(find.byType(CallHistoryCard))
        .map((c) => c.tone);
    expect(tones, [CallHistoryCardTone.light, CallHistoryCardTone.light]);
    final tints = tester.widgetList<BlurSurface>(surfaces).map((s) => s.tint);
    expect(tints, [
      CameoColors.backgroundNeutralSubtle,
      CameoColors.backgroundNeutralSubtle,
    ]);

    await tester.tap(surfaces.at(1));
    await tester.pumpAndSettle();
    expect(pressed, same(_emptyPhoto.callCards[1]));
  });

  testWidgets('appearIndex 3 → 카드 i 순번 3 + i, 모두 정착 후 제자리', (tester) async {
    await tester.pumpWidget(
      _harness(CallHistoryList(cards: _sungsu.callCards, appearIndex: 3)),
    );
    final cards = tester.widgetList<CallHistoryCard>(
      find.byType(CallHistoryCard),
    );
    expect(cards.map((c) => c.appearIndex), [3, 4, 5]);

    final surfaces0 = find.byType(BlurSurface);
    expect(
      tester.getTopLeft(surfaces0.at(0)).dy,
      closeTo(8 + CameoMotion.staggerRise, _tol),
    );

    await tester.pump(CameoMotion.staggerItem * 5);
    await tester.pumpAndSettle();
    final surfaces = find.byType(BlurSurface);
    const ys = [8.0, 92.0, 176.0];
    for (var i = 0; i < 3; i++) {
      expect(tester.getTopLeft(surfaces.at(i)).dy, closeTo(ys[i], _tol));
    }
  });

  test('callHistoryCardToneFor: 부재중은 섹션과 무관하게 missed', () {
    expect(
      callHistoryCardToneFor(
        CallHistoryListTone.onPhoto,
        CallDirection.outgoing,
      ),
      CallHistoryCardTone.onPhoto,
    );
    expect(
      callHistoryCardToneFor(CallHistoryListTone.light, CallDirection.incoming),
      CallHistoryCardTone.light,
    );
    expect(
      callHistoryCardToneFor(CallHistoryListTone.light, CallDirection.missed),
      CallHistoryCardTone.missed,
    );
  });

  test('레이아웃 합계: 260 = 8 + 3·76 + 2·8 + 8 · 184 = 8 + 2·76 + 8 + 16', () {
    expect(
      CameoLayout.callHistoryListPadding * 2 +
          CameoLayout.callCardHeight * 3 +
          CameoLayout.callHistoryListGap * 2,
      260,
    );
    expect(
      CameoLayout.callHistoryListLightPaddingTop +
          CameoLayout.callCardHeight * 2 +
          CameoLayout.callHistoryListGap +
          CameoLayout.callHistoryListLightPaddingBottom,
      184,
    );
  });
}
