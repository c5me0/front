// ignore_for_file: file_names
// Regression coverage for callCard card. Preserve behavior, layout, and interaction
// expectations.

import 'package:cameo/components/call_history_card.dart';
import 'package:cameo/content/lab.g.dart';
import 'package:cameo/design_system/design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const double _screenWidth = 393;
const double _cardWidth = 377;

const double _tol = 0.001;

final _sungsu = labAlbumDay.sections.firstWhere((s) => s.id == 'sungsu');
final _emptyPhoto = labAlbumDay.sections.firstWhere(
  (s) => s.id == 'empty-photo',
);

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
        child: SizedBox(width: _cardWidth, child: child),
      ),
    ),
  );
}

void main() {
  final cases = <(String, CallCardContent, CallHistoryCardTone?, _Expect)>[
    (
      'onPhoto 발신 (2042:2804)',
      _sungsu.callCards[0],
      null,
      _Expect(
        fill: CameoColors.albumCardTranslucent,
        title: CameoColors.foregroundNeutralInverseBase,
        subtitle: CameoColors.foregroundNeutralInverseMuted,
        icon: CameoIconName.arrowUpRight,
        label: '성수 데이트 코스에 대한 대화, 12시 20분, 발신 통화 21분 17초',
      ),
    ),
    (
      'onPhoto 수신 (2042:2809)',
      _sungsu.callCards[1],
      CallHistoryCardTone.onPhoto,
      _Expect(
        fill: CameoColors.albumCardTranslucent,
        title: CameoColors.foregroundNeutralInverseBase,
        subtitle: CameoColors.foregroundNeutralInverseMuted,
        icon: CameoIconName.arrowDownLeft,
        label: '아침 인사, 8시 12분, 수신 통화 5분 10초',
      ),
    ),
    (
      'missed 부재중 (2042:2814, 기본 톤 = direction)',
      _sungsu.callCards[2],
      null,
      _Expect(
        fill: CameoColors.backgroundCriticalBase,
        title: CameoColors.foregroundNeutralInverseBase,
        subtitle: CameoColors.foregroundNeutralInverseMuted,
        icon: CameoIconName.arrowDownLeft,
        label: '이주영 빨리 일어나..!!, 8시 10분, 부재중',
      ),
    ),
    (
      'light 발신 (2042:2869)',
      _emptyPhoto.callCards[0],
      CallHistoryCardTone.light,
      _Expect(
        fill: CameoColors.backgroundNeutralSubtle,
        title: CameoColors.foregroundNeutralBase,
        subtitle: CameoColors.foregroundNeutralMuted,
        icon: CameoIconName.arrowUpRight,
        label: '자긴 전 대화, 23시 10분, 발신 통화 21분 17초',
      ),
    ),
    (
      'light 수신 (2042:2874)',
      _emptyPhoto.callCards[1],
      CallHistoryCardTone.light,
      _Expect(
        fill: CameoColors.backgroundNeutralSubtle,
        title: CameoColors.foregroundNeutralBase,
        subtitle: CameoColors.foregroundNeutralMuted,
        icon: CameoIconName.arrowDownLeft,
        label: '아침 인사, 08시 00분, 수신 통화 5분 10초',
      ),
    ),
  ];

  group('CallHistoryCard — Figma 수치', () {
    for (final (name, card, tone, expected) in cases) {
      testWidgets(name, (tester) async {
        final handle = tester.ensureSemantics();
        CallCardContent? pressed;
        await tester.pumpWidget(
          _harness(
            CallHistoryCard(
              card: card,
              tone: tone,
              onPress: (c) => pressed = c,
            ),
          ),
        );

        final surfaceFinder = find.byType(BlurSurface);
        final surfaceSize = tester.getSize(surfaceFinder);
        expect(surfaceSize.width, _cardWidth);
        expect(surfaceSize.height, closeTo(CameoLayout.callCardHeight, _tol));
        expect(
          CameoLayout.callCardPaddingY * 2 +
              CameoLayout.callCardHeaderHeight +
              CameoLayout.callCardGap +
              CameoLayout.callCardSubtitleHeight,
          CameoLayout.callCardHeight,
        );
        final surface = tester.widget<BlurSurface>(surfaceFinder);
        expect(surface.radius, CameoLayout.callCardRadius);
        expect(surface.radius, 14);
        expect(surface.blur, isNull); // → CameoBlur.backgroundBlur (σ 2.5)
        expect(CameoBlur.backgroundBlur.sigma, 2.5);
        expect(surface.border, isNull);
        expect(surface.tint, expected.fill);
        final origin = tester.getTopLeft(surfaceFinder);

        final title = find.byType(CameoText);
        expect(tester.getTopLeft(title) - origin, const Offset(18, 16));
        expect(
          tester.getSize(title),
          const Size(307, 22),
        ); // flex-1 = 341 − 12 − 22
        final titleWidget = tester.widget<CameoText>(title);
        expect(titleWidget.text, card.title);
        expect(titleWidget.style, CameoTextStyles.bodyLgStrong);
        expect(titleWidget.color, expected.title);
        expect(titleWidget.maxLines, isNull);

        final iconFinder = find.byType(CameoIcon);
        expect(tester.getSize(iconFinder), const Size(22, 22));
        expect(tester.getTopLeft(iconFinder) - origin, const Offset(337, 16));
        final icon = tester.widget<CameoIcon>(iconFinder);
        expect(icon.name, expected.icon);
        expect(icon.color, expected.title);

        final subtitleFinder = find.byWidgetPredicate(
          (w) => w is RichText && w.maxLines == 1 && w.softWrap == false,
        );
        final subtitleTopLeft = tester.getTopLeft(subtitleFinder) - origin;
        expect(subtitleTopLeft.dx, 18);
        expect(subtitleTopLeft.dy, 46);
        expect(
          tester.getSize(subtitleFinder).height,
          closeTo(CameoLayout.callCardSubtitleHeight, _tol),
        );

        final spans = <TextSpan>[];
        tester.widget<RichText>(subtitleFinder).text.visitChildren((s) {
          if (s is TextSpan && s.text != null) spans.add(s);
          return true;
        });
        expect(
          spans.map((s) => s.text).join(),
          card.subtitle.map((s) => s.text).join(),
        );
        expect(
          spans.first.style!.fontWeight,
          CameoTextStyles.bodySmStrong.fontWeight,
        );
        expect(spans.first.style!.fontSize, 12);
        expect(spans.last.style!.fontWeight, CameoTextStyles.bodySm.fontWeight);
        for (final s in spans) {
          expect(s.style!.color, expected.subtitle);
        }

        expect(find.bySemanticsLabel(expected.label), findsOneWidget);
        await tester.tap(surfaceFinder);
        await tester.pumpAndSettle();
        expect(pressed, same(card));
        handle.dispose();
      });
    }
  });

  group('CallHistoryCard — 줄바꿈·접근성', () {
    testWidgets('긴 제목은 줄바꿈 → 카드 높이 = 76 + 22 × (줄 수 − 1), 아이콘은 헤더 세로 가운데', (
      tester,
    ) async {
      final base = _sungsu.callCards[0];
      final long = CallCardContent(
        nodeId: base.nodeId,
        direction: base.direction,
        icon: base.icon,
        title: List.filled(4, base.title).join(' '),
        subtitle: base.subtitle,
      );
      await tester.pumpWidget(_harness(CallHistoryCard(card: long)));
      final surface = find.byType(BlurSurface);
      final origin = tester.getTopLeft(surface);
      final title = find.byType(CameoText);
      final lines =
          tester.getSize(title).height / CameoLayout.callCardHeaderHeight;
      expect(lines, greaterThan(1));
      expect(lines, closeTo(lines.roundToDouble(), _tol));
      expect(
        tester.getSize(surface).height,
        closeTo(
          CameoLayout.callCardHeight +
              CameoLayout.callCardHeaderHeight * (lines.round() - 1),
          _tol,
        ),
      );
      final headerHeight = tester.getSize(title).height;
      expect(
        (tester.getTopLeft(find.byType(CameoIcon)) - origin).dy,
        closeTo(
          CameoLayout.callCardPaddingY +
              (headerHeight - CameoLayout.callCardHeaderIconSize) / 2,
          _tol,
        ),
      );
    });

    testWidgets('onPress 없음 → 버튼 아님, 라벨만 (눌림 수축 없음)', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _harness(CallHistoryCard(card: _sungsu.callCards[0])),
      );
      expect(find.byType(PressScale), findsNothing);
      final node = tester.getSemantics(
        find.bySemanticsLabel('성수 데이트 코스에 대한 대화, 12시 20분, 발신 통화 21분 17초'),
      );
      expect(node.flagsCollection.isButton, isFalse);
      expect(node.flagsCollection.hasEnabledState, isFalse);
      handle.dispose();
    });

    testWidgets('accessibilityLabel 재정의', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _harness(
          CallHistoryCard(
            card: _sungsu.callCards[0],
            onPress: (_) {},
            accessibilityLabel: '통화 기록 열기',
          ),
        ),
      );
      final node = tester.getSemantics(find.bySemanticsLabel('통화 기록 열기'));
      expect(node.flagsCollection.isButton, isTrue);
      handle.dispose();
    });
  });

  group('CallHistoryCard — 누름·등장 모션', () {
    testWidgets('PressScale: 누르면 0.96 으로 수축 → 놓으면 1', (tester) async {
      await tester.pumpWidget(
        _harness(CallHistoryCard(card: _sungsu.callCards[0], onPress: (_) {})),
      );
      final scale = find.byType(ScaleTransition);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(BlurSurface)),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<ScaleTransition>(scale).scale.value,
        closeTo(CameoMotion.pressScale, _tol),
      );
      await gesture.up();
      await tester.pumpAndSettle();
      expect(
        tester.widget<ScaleTransition>(scale).scale.value,
        closeTo(1, _tol),
      );
    });

    testWidgets('appearIndex 없음 → 즉시 표시 (불투명·이동 없음)', (tester) async {
      await tester.pumpWidget(
        _harness(CallHistoryCard(card: _sungsu.callCards[0])),
      );
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
      expect(tester.getTopLeft(find.byType(BlurSurface)), Offset.zero);
    });

    testWidgets('appearIndex 2 → 80ms 지연 후 rise 12 에서 스프링 상승', (tester) async {
      await tester.pumpWidget(
        _harness(CallHistoryCard(card: _sungsu.callCards[0], appearIndex: 2)),
      );

      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 0);
      expect(
        tester.getTopLeft(find.byType(BlurSurface)).dy,
        CameoMotion.staggerRise,
      );

      await tester.pump(
        CameoMotion.staggerItem * 2 - const Duration(milliseconds: 1),
      );
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 0);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 100));
      final mid = tester.getTopLeft(find.byType(BlurSurface)).dy;
      expect(mid, lessThan(CameoMotion.staggerRise));
      expect(mid, greaterThan(0));
      await tester.pumpAndSettle();
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
      expect(tester.getTopLeft(find.byType(BlurSurface)).dy, closeTo(0, _tol));
    });

    testWidgets('마운트 후 appearIndex 변경은 무시 (RN 과 동일)', (tester) async {
      await tester.pumpWidget(
        _harness(CallHistoryCard(card: _sungsu.callCards[0], appearIndex: 3)),
      );
      await tester.pump(CameoMotion.staggerItem);

      await tester.pumpWidget(
        _harness(CallHistoryCard(card: _sungsu.callCards[0], appearIndex: 0)),
      );
      await tester.pump(const Duration(milliseconds: 1));
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 0);
      await tester.pumpAndSettle();
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        _harness(CallHistoryCard(card: _sungsu.callCards[1])),
      );
      await tester.pumpWidget(
        _harness(CallHistoryCard(card: _sungsu.callCards[1], appearIndex: 2)),
      );
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
      expect(tester.getTopLeft(find.byType(BlurSurface)), Offset.zero);
    });

    testWidgets('지연·스프링 도중 언마운트 → 타이머·컨트롤러 정리', (tester) async {
      await tester.pumpWidget(
        _harness(CallHistoryCard(card: _sungsu.callCards[0], appearIndex: 5)),
      );
      await tester.pump(CameoMotion.staggerItem);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        _harness(CallHistoryCard(card: _sungsu.callCards[0], appearIndex: 0)),
      );
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('모션 감소 → 상승 없이 durationBase 페이드', (tester) async {
      await tester.pumpWidget(
        _harness(
          CallHistoryCard(card: _sungsu.callCards[0], appearIndex: 0),
          disableAnimations: true,
        ),
      );
      expect(tester.getTopLeft(find.byType(BlurSurface)), Offset.zero);
      await tester.pump(CameoMotion.durationBase ~/ 2);
      final o = tester.widget<Opacity>(find.byType(Opacity)).opacity;
      expect(o, greaterThan(0));
      expect(o, lessThan(1));
      expect(tester.getTopLeft(find.byType(BlurSurface)), Offset.zero);
      await tester.pump(CameoMotion.durationBase);
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
    });
  });
}

class _Expect {
  const _Expect({
    required this.fill,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.label,
  });

  final Color fill;
  final Color title;
  final Color subtitle;
  final CameoIconName icon;
  final String label;
}
