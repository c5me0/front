// Regression coverage for transcript v6. Preserve behavior, layout, and interaction
// expectations.

import 'dart:ui' show ImageFilter;

import 'package:cameo/components/highlight_card_v6.dart';
import 'package:cameo/components/karaoke_text.dart';
import 'package:cameo/components/outside_shadow.dart';
import 'package:cameo/components/playback_controller.dart';
import 'package:cameo/components/player_bar_v6.dart';
import 'package:cameo/components/scrim_pill.dart';
import 'package:cameo/components/solid_button.dart';
import 'package:cameo/components/inline_photo_v6.dart';
import 'package:cameo/components/transcript_nav_v6.dart';
import 'package:cameo/components/transcript_v6_layout.dart';
import 'package:cameo/components/transcript_v6_line.dart';
import 'package:cameo/components/transcript_v6_title.dart';
import 'package:cameo/content/app.g.dart';
import 'package:cameo/content/lab.g.dart';
import 'package:cameo/design_system/design_system.dart';
import 'package:cameo/navigation/navigation.dart';
import 'package:cameo/screens/call/call_screen.dart';
import 'package:cameo/screens/transcript/stagger_in.dart';
import 'package:cameo/screens/transcript/transcript_route.dart';
import 'package:cameo/screens/transcript/transcript_screen.dart';
import 'package:cameo/screens/transcript/transcript_timeline.dart';
import 'package:cameo/state/session.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

import '../../navigation/app_harness.dart';

const Size _figma = Size(402, 874);
const Size _legacy = Size(393, 852);
const EdgeInsets _insets = EdgeInsets.only(top: 62, bottom: 34);
const double _tol = 0.01;

int _indexOf(String id) => labTranscriptV5.lines.indexWhere((l) => l.id == id);

void _screenSize(WidgetTester tester, [Size size = _figma]) {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget _host(
  Widget child, {
  Size size = _figma,
  EdgeInsets insets = _insets,
  bool disableAnimations = false,
}) => MediaQuery(
  data: MediaQueryData(
    size: size,
    padding: insets,
    viewPadding: insets,
    disableAnimations: disableAnimations,
  ),
  child: Directionality(textDirection: TextDirection.ltr, child: child),
);

TranscriptV5Content _figmaShaped() {
  final c = labTranscriptV5;
  String shaped(String id) => switch (id) {
    'l3' => '가나\n다라',
    'l4' => '가나\n다라\n마바',
    _ => '가나다',
  };
  return TranscriptV5Content(
    screenNodeId: c.screenNodeId,
    variantNodeIds: c.variantNodeIds,
    title: '가나다',
    date: c.date,
    navActions: c.navActions,
    lines: [
      for (final l in c.lines)
        TranscriptV5LineContent(
          id: l.id,
          nodeId: l.nodeId,
          text: shaped(l.id),
          side: l.side,
          inHighlight: l.inHighlight,
          current: l.current,
        ),
    ],
    inlinePhoto: c.inlinePhoto,
    player: c.player,
  );
}

Future<void> _advance(WidgetTester tester, Duration total) async {
  const step = Duration(milliseconds: 16);
  var left = total;
  while (left > Duration.zero) {
    final d = left < step ? left : step;
    await tester.pump(d);
    left -= d;
  }
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
}

void _expectRect(Rect actual, Rect expected, {double tol = _tol}) {
  expect(actual.left, closeTo(expected.left, tol), reason: 'left $actual');
  expect(actual.top, closeTo(expected.top, tol), reason: 'top $actual');
  expect(actual.width, closeTo(expected.width, tol), reason: 'width $actual');
  expect(
    actual.height,
    closeTo(expected.height, tol),
    reason: 'height $actual',
  );
}

PlaybackController _playback(WidgetTester tester) =>
    tester.widget<PlayerBarV6>(find.byType(PlayerBarV6)).playback;

double _ink(WidgetTester tester, String id) => tester
    .state<TranscriptTextV6State>(find.byKey(TranscriptTextV6.keyFor(id)))
    .ink;

Color _inkColor(WidgetTester tester, String id) => tester
    .widget<KeepAllText>(
      find.descendant(
        of: find.byKey(TranscriptTextV6.keyFor(id)),
        matching: find.byType(KeepAllText),
      ),
    )
    .color;

String _currentId(WidgetTester tester) => tester
    .widgetList<TranscriptTextV6>(find.byType(TranscriptTextV6))
    .singleWhere((t) => t.current)
    .key
    .toString();

String _keyString(String id) => TranscriptTextV6.keyFor(id).toString();

BoxDecoration _deco(WidgetTester tester, Key k) =>
    tester.widget<DecoratedBox>(find.byKey(k)).decoration as BoxDecoration;

void _expectGlassNeverFaded(WidgetTester tester) {
  final glass = find.byType(LiquidGlass, skipOffstage: false);
  expect(glass, findsWidgets);
  for (final e in glass.evaluate()) {
    e.visitAncestorElements((a) {
      final w = a.widget;
      if (w is Opacity) expect(w.opacity, 1, reason: 'Liquid Glass 조상 Opacity');
      if (w is FadeTransition) {
        expect(w.opacity.value, 1, reason: 'Liquid Glass 조상 FadeTransition');
      }
      return true;
    });
  }
}

void main() {
  group('transcriptV6Layout (순수 기하 — RN transcriptV6Layout.ts 가 같은 식으로)', () {
    test(
      '내용 1070 (118 + 92 + 52 + 52 + 296 + 460) · 카드 332 · 줄 36 · 스크롤 196 = 1070 − 874',
      () {
        expect(transcriptV6LineHeight, 36);

        expect(
          2 * CameoLayout.transcriptV6CardPaddingY +
              (3 + 4) * transcriptV6LineHeight +
              4 * CameoLayout.transcriptV6CardGap,
          CameoLayout.transcriptV6CardHeight,
        );
        final h = transcriptV6ContentHeight(
          outside: [1, 1, 2],
          photoAfter: 2,
          card: [3, 1, 1, 1, 1],
        );
        expect(h, 1070);
        expect(h, CameoLayout.transcriptV6ContentHeight);
        expect(
          transcriptV6MaxScroll(h, CameoLayout.screenV6Height),
          CameoLayout.transcriptV6MaxScroll,
        );
        expect(transcriptV6MaxScroll(h, 1200), 0);

        expect(
          2 * CameoLayout.transcriptV6LinePaddingY + transcriptV6LineHeight,
          CameoLayout.transcriptV6LineHeight,
        );

        final c = labTranscriptV5;
        expect(c.lines, hasLength(8));
        expect(c.lines.where((l) => l.inHighlight), hasLength(5));
        expect(c.inlinePhoto.afterLineId, 'l3');
        expect(c.lines.where((l) => l.current).single.id, 'l5');
      },
    );

    test('사진 정렬 = 화자 쪽 (RN inlinePhotoAlignV6)', () {
      expect(inlinePhotoAlignV6(LabAlign.left), Alignment.centerLeft);
      expect(inlinePhotoAlignV6(LabAlign.right), Alignment.centerRight);
    });

    test(
      '플레이어: 컨테이너 122 = 12 + 64 + 12 + 34 · pill 64 = 1 + 4 + 54 + 4 + 1 · 여백 16 / 4 / 4 · 폭 W − 32 · '
      '트랙 156 = 370 − 2 − 20 − 36 − 80 − 2 × 38 · 마커 ≈ 75 / 112 (16) · '
      '진행 ≈ 47 · thumb 중심 = 진행 끝 · top −9',
      () {
        expect(playerV6ContainerHeight(), 122);
        expect(
          playerV6ContainerHeight(),
          CameoLayout.transcriptV6PlayerContainerHeight,
        );
        expect(playerV6PillHeight(), CameoLayout.transcriptV6PlayerPillHeight);
        final insets = playerV6PillInsets();
        expect((insets.left, insets.right, insets.y), (16, 4, 4));
        expect(playerV6PillWidth(402), CameoLayout.transcriptV6PlayerPillWidth);
        expect(playerV6PillWidth(393), 361);
        expect(
          playerV6TrackWidth(402, 38),
          CameoLayout.transcriptV6PlayerTrackWidth,
        );
        const w = CameoLayout.transcriptV6PlayerTrackWidth;
        final markers = labTranscriptV5.player.markers;
        for (var i = 0; i < 2; i++) {
          final f = playerV6MarkerFrame(markers[i], w);
          expect(
            f.left,

            closeTo(CameoLayout.transcriptV6PlayerMarkerLefts[i], 1),
          );
          expect(
            f.width,
            closeTo(CameoLayout.transcriptV6PlayerMarkerWidth, 0.2),
          );
        }
        final p = labTranscriptV5.player.progress;
        expect(
          p * w,
          closeTo(CameoLayout.transcriptV6PlayerProgressSampleWidth, 0.5),
        );
        expect(
          playerV6ThumbLeft(p, w),
          closeTo(CameoLayout.transcriptV6PlayerThumbSampleLeft, 0.5),
        );
        expect(playerV6ThumbTop(), -9);
      },
    );

    test('탭 목표: 마커 안 → 마커 시작 · 밖 → 그 분수 · 0..1 밖 · NaN → null', () {
      final markers = labTranscriptV5.player.markers;
      final m = markers[0];
      expect(playerV6TapTarget(m.start + m.width / 2, markers), m.start);
      expect(playerV6TapTarget(markers[1].start, markers), markers[1].start);
      expect(playerV6TapTarget(0.2, markers), 0.2);
      expect(playerV6TapTarget(-0.01, markers), isNull);
      expect(playerV6TapTarget(1.01, markers), isNull);
      expect(playerV6TapTarget(double.nan, markers), isNull);
    });

    test(
      '잉크 색: 0 = foreground/neutral/subtle · 1 = foreground/neutral/base · 사이 = 보간 · 넘침은 자른다',
      () {
        const c = CameoPalette.light;
        expect(transcriptV6InkColor(c, 0), CameoColors.foregroundNeutralSubtle);
        expect(transcriptV6InkColor(c, 1), CameoColors.foregroundNeutralBase);
        expect(
          transcriptV6InkColor(c, 1.02),
          CameoColors.foregroundNeutralBase,
        );
        expect(
          transcriptV6InkColor(c, -0.02),
          CameoColors.foregroundNeutralSubtle,
        );
        final mid = transcriptV6InkColor(c, 0.5);
        expect(mid.a, greaterThan(CameoColors.foregroundNeutralSubtle.a));
        expect(mid.a, lessThan(CameoColors.foregroundNeutralBase.a));
      },
    );
  });

  group('통화 기록 v6 화면 (2295:11674)', () {
    testWidgets(
      '기하 @ 402 × 874: 헤더 118 · 닫기 (16, 62) 46 · pill (290, 62) 96 × 46 · 제목 블록 118 (제목 134) · 줄 210 / 262 (52) · '
      'l3 + 사진 314 (296 — 사진 150 × 200 @ (16, 402)) · 카드 386 × 332 @ (8, 618) · 내용 1070 / 스크롤 196 · '
      '플레이어 752 – 874 (122) · pill 370 × 64 @ (16, 764) · 일시정지 80 × 54 @ (301, 769)',
      (tester) async {
        _screenSize(tester);
        await tester.pumpWidget(
          _host(TranscriptScreen(content: _figmaShaped())),
        );

        await _advance(tester, const Duration(seconds: 2));
        _expectRect(
          tester.getRect(find.byKey(TranscriptScreen.headerKey)),
          const Rect.fromLTWH(0, 0, 402, 118),
        );
        _expectRect(
          tester.getRect(find.byKey(TranscriptNavV6.closeKey)),
          const Rect.fromLTWH(16, 62, 46, 46),
        );
        _expectRect(
          tester.getRect(find.byKey(TranscriptNavV6.actionsKey)),
          const Rect.fromLTWH(290, 62, 96, 46),
        );
        _expectRect(
          tester.getRect(find.byKey(TranscriptScreen.titleKey)),
          const Rect.fromLTWH(0, 118, 402, 92),
        );
        expect(
          tester.getRect(find.byKey(TranscriptTitleV6.titleKey)).top,
          closeTo(134, _tol),
        );
        expect(
          tester.getRect(find.byKey(TranscriptTitleV6.dateKey)).top,
          closeTo(176, _tol),
        );
        _expectRect(
          tester.getRect(find.byKey(TranscriptScreen.rowKey('l1'))),
          const Rect.fromLTWH(0, 210, 402, 52),
        );
        _expectRect(
          tester.getRect(find.byKey(TranscriptScreen.rowKey('l2'))),
          const Rect.fromLTWH(0, 262, 402, 52),
        );

        final l1 = tester.getRect(find.byKey(TranscriptScreen.lineKey('l1')));
        expect(l1.left, closeTo(16, _tol));
        expect(l1.height, closeTo(36, _tol));
        expect(
          tester.getRect(find.byKey(TranscriptScreen.lineKey('l2'))).right,
          closeTo(386, _tol),
        );

        _expectRect(
          tester.getRect(find.byKey(TranscriptScreen.photoBlockKey)),
          const Rect.fromLTWH(0, 314, 402, 296),
        );
        final l3 = tester.getRect(find.byKey(TranscriptScreen.lineKey('l3')));
        expect(l3.top, closeTo(322, _tol));
        expect(l3.height, closeTo(72, _tol));
        _expectRect(
          tester.getRect(find.byKey(InlinePhotoV6.cardKey)),
          const Rect.fromLTWH(16, 402, 150, 200),
        );

        _expectRect(
          tester.getRect(find.byType(HighlightCardV6)),
          const Rect.fromLTWH(0, 610, 402, 460),
        );
        _expectRect(
          tester.getRect(find.byKey(HighlightCardV6.cardKey)),
          const Rect.fromLTWH(8, 618, 386, 332),
        );

        final l4 = tester.getRect(find.byKey(TranscriptScreen.lineKey('l4')));
        expect(l4.top, closeTo(634, _tol));
        expect(l4.height, closeTo(108, _tol));
        expect(
          tester.getRect(find.byKey(TranscriptScreen.lineKey('l5'))).top,
          closeTo(634 + 108 + 12, _tol),
        );

        final scroll = tester.widget<SingleChildScrollView>(
          find.byKey(TranscriptScreen.scrollKey),
        );
        expect(scroll.padding, const EdgeInsets.only(top: 118));
        final state = tester.state<ScrollableState>(
          find.descendant(
            of: find.byKey(TranscriptScreen.scrollKey),
            matching: find.byType(Scrollable),
          ),
        );
        expect(
          state.position.maxScrollExtent,
          closeTo(CameoLayout.transcriptV6MaxScroll, _tol),
        );
        expect(
          state.position.maxScrollExtent + 874,
          closeTo(CameoLayout.transcriptV6ContentHeight, _tol),
        );

        _expectRect(
          tester.getRect(find.byKey(PlayerBarV6.containerKey)),
          const Rect.fromLTWH(0, 752, 402, 122),
        );
        _expectRect(
          tester.getRect(find.byKey(PlayerBarV6.pillKey)),
          const Rect.fromLTWH(16, 764, 370, 64),
        );
        _expectRect(
          tester.getRect(find.byKey(PlayerBarV6.buttonKey)),
          const Rect.fromLTWH(301, 769, 80, 54),
        );
        await _unmount(tester);
      },
    );

    testWidgets(
      '플레이어 행: 시각 (x 33 = 16 + 1 + 16) · gap 12 · 트랙 = 370 − 2 − 20 − 36 − 80 − 두 라벨 · 트랙 가운데 796 · 진행 · 마커 · thumb 규칙',
      (tester) async {
        _screenSize(tester);
        await tester.pumpWidget(_host(const TranscriptScreen()));
        await tester.pump();
        final current = tester.getRect(find.byKey(PlayerBarV6.currentTimeKey));
        final duration = tester.getRect(find.byKey(PlayerBarV6.durationKey));
        final track = tester.getRect(find.byKey(PlayerBarV6.trackKey));
        expect(current.left, closeTo(33, _tol));
        expect(track.left - current.right, closeTo(12, _tol));
        expect(duration.left - track.right, closeTo(12, _tol));
        expect(301 - duration.right, closeTo(12, _tol));

        expect(current.width, closeTo(duration.width, _tol));
        expect(
          track.width,
          closeTo(playerV6TrackWidth(402, current.width), _tol),
        );
        expect(track.height, closeTo(10, _tol));
        expect(track.center.dy, closeTo(796, _tol));
        final w = track.width;
        final p = labTranscriptV5.player.progress;
        expect(
          tester.getRect(find.byKey(PlayerBarV6.progressKey)).right,
          closeTo(track.left + p * w, 0.5),
        );
        for (var i = 0; i < 2; i++) {
          final m = tester.getRect(find.byKey(PlayerBarV6.markerKey(i)));
          final content = labTranscriptV5.player.markers[i];
          expect(m.left, closeTo(track.left + content.start * w, _tol));
          expect(m.width, closeTo(content.width * w, _tol));
          expect(m.height, closeTo(10, _tol));
        }
        final thumb = tester.getRect(find.byKey(PlayerBarV6.thumbKey));
        expect(thumb.width, closeTo(28, _tol));
        expect(thumb.top, closeTo(track.top - 9, _tol));
        expect(thumb.center.dx, closeTo(track.left + p * w, 0.5));
        await _unmount(tester);
      },
    );

    testWidgets(
      '폭 규칙 @ 393 × 852: 카드 377 · 플레이어 pill 361 · 내비 pill x 281 · 닫기 16',
      (tester) async {
        _screenSize(tester, _legacy);
        await tester.pumpWidget(
          _host(
            TranscriptScreen(content: _figmaShaped()),
            size: _legacy,
            insets: const EdgeInsets.only(top: 59, bottom: 34),
          ),
        );
        await _advance(tester, const Duration(seconds: 2));
        expect(
          tester.getRect(find.byKey(HighlightCardV6.cardKey)).width,
          closeTo(377, _tol),
        );
        _expectRect(
          tester.getRect(find.byKey(PlayerBarV6.pillKey)),
          const Rect.fromLTWH(16, 852 - 122 + 12, 361, 64),
        );
        expect(
          tester.getRect(find.byKey(TranscriptNavV6.actionsKey)).left,
          closeTo(281, _tol),
        );
        expect(
          tester.getRect(find.byKey(TranscriptNavV6.closeKey)).left,
          closeTo(16, _tol),
        );
        await _unmount(tester);
      },
    );

    testWidgets(
      '역할: 캔버스 background/canvas/neutral/strong · 헤더 topLinear (블러 없음) · 카드 background/canvas/elevated/base (블러 · 테두리 없음) · '
      '사진 30 % 테두리 없음 · 줄 subtle / 현재 줄 (l5) base · 카라오케 없음 · 글래스 배경 톤 light',
      (tester) async {
        _screenSize(tester);
        await tester.pumpWidget(_host(const TranscriptScreen()));
        await tester.pump();
        expect(
          tester
              .widget<ColoredBox>(
                find.descendant(
                  of: find.byKey(const ValueKey('transcript.layer.canvas')),
                  matching: find.byType(ColoredBox),
                ),
              )
              .color,
          CameoColors.backgroundCanvasNeutralStrong,
        );
        expect(
          _deco(tester, TranscriptScreen.headerKey).gradient,
          CameoGradients.topLinear,
        );
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('transcript.layer.header')),
            matching: find.byType(BackdropFilter),
          ),
          findsNothing,
        );

        final card =
            tester
                    .widget<DecoratedBox>(find.byKey(HighlightCardV6.cardKey))
                    .decoration
                as ShapeDecoration;
        expect(card.color, CameoColors.backgroundCanvasElevatedBase);
        expect((card.shape as RoundedSuperellipseBorder).side, BorderSide.none);
        expect(
          find.descendant(
            of: find.byKey(HighlightCardV6.cardKey),
            matching: find.byType(BackdropFilter),
          ),
          findsNothing,
        );

        expect(
          tester.widget<Opacity>(find.byKey(InlinePhotoV6.imageKey)).opacity,
          CameoLayout.transcriptV6PhotoOpacity,
        );
        expect(
          find.descendant(
            of: find.byKey(InlinePhotoV6.cardKey),
            matching: find.byType(DecoratedBox),
          ),
          findsNothing,
        );

        expect(
          tester
              .widget<KeepAllText>(find.byKey(TranscriptTitleV6.titleKey))
              .color,
          CameoColors.foregroundNeutralBase,
        );
        expect(
          tester
              .widget<KeepAllText>(find.byKey(TranscriptTitleV6.dateKey))
              .color,
          CameoColors.foregroundNeutralMuted,
        );

        expect(_currentId(tester), _keyString('l5'));
        for (final l in labTranscriptV5.lines) {
          expect(
            _inkColor(tester, l.id),
            l.id == 'l5'
                ? CameoColors.foregroundNeutralBase
                : CameoColors.foregroundNeutralSubtle,
            reason: l.id,
          );
          expect(
            tester
                .widget<KeepAllText>(
                  find.descendant(
                    of: find.byKey(TranscriptTextV6.keyFor(l.id)),
                    matching: find.byType(KeepAllText),
                  ),
                )
                .style,
            CameoTextStyles.transcriptLineV6,
          );
        }
        expect(find.byType(KaraokeText), findsNothing);
        expect(
          GlassBackdrop.of(
            tester.element(find.byKey(TranscriptScreen.rootKey)),
          ),
          GlassBackdropTone.light,
        );
        await _unmount(tester);
      },
    );

    testWidgets(
      '플레이어 역할: 컨테이너 bottomLinear + BG blur 12 · pill = Liquid Glass (scrim/base · 1 border/scrim · scrim 그림자 바깥) · '
      '트랙 fill/neutral/strong · 진행 inverted · 마커 critical · thumb static/white/base + Shadow · 일시정지 interaction + blur + scrim 그림자',
      (tester) async {
        _screenSize(tester);
        await tester.pumpWidget(_host(const TranscriptScreen()));
        await tester.pump();
        expect(
          _deco(tester, PlayerBarV6.fadeKey).gradient,
          CameoGradients.bottomLinear,
        );
        final blur = tester.widget<BackdropFilter>(
          find.descendant(
            of: find.byKey(const ValueKey('playerBarV6.layer.fade')),
            matching: find.byType(BackdropFilter),
          ),
        );
        expect(
          blur.filter,
          ImageFilter.blur(
            sigmaX: CameoBlur.blur.sigma,
            sigmaY: CameoBlur.blur.sigma,
          ),
        );
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('playerBarV6.layer.fade')),
            matching: find.byType(IgnorePointer),
          ),
          findsWidgets,
        );
        // pill = Liquid Glass
        expect(
          find.descendant(
            of: find.byKey(PlayerBarV6.pillKey),
            matching: find.byType(LiquidGlass),
          ),
          findsOneWidget,
        );
        final surface = tester.widget<GlassSurface>(
          find
              .descendant(
                of: find.byKey(PlayerBarV6.pillKey),
                matching: find.byType(GlassSurface),
              )
              .first,
        );
        expect(surface.tint, CameoColors.backgroundFillScrimBase);
        expect(surface.border, CameoColors.borderScrim);
        expect(surface.borderWidth, 1);
        expect(surface.blur, CameoBlur.scrim);
        expect(
          tester
              .widget<OutsideShadow>(find.byKey(PlayerBarV6.shadowKey))
              .shadow,
          CameoPalette.light.shadows.scrim,
        );
        expect(
          _deco(tester, PlayerBarV6.progressKey).color,
          CameoColors.backgroundFillNeutralInverted,
        );
        expect(
          _deco(tester, PlayerBarV6.markerKey(0)).color,
          CameoColors.backgroundSystemCriticalBase,
        );
        final thumb = _deco(tester, PlayerBarV6.thumbKey);
        expect(thumb.color, CameoColors.staticWhiteBase);
        expect(thumb.boxShadow, [CameoPalette.light.shadows.shadow]);

        expect(
          find.descendant(
            of: find.byKey(PlayerBarV6.trackKey),
            matching: find.byWidgetPredicate(
              (w) =>
                  w is DecoratedBox &&
                  w.decoration is BoxDecoration &&
                  (w.decoration as BoxDecoration).color ==
                      CameoColors.backgroundFillNeutralStrong,
            ),
          ),
          findsOneWidget,
        );

        final button = tester.widget<BlurSurface>(
          find.byKey(PlayerBarV6.buttonSurfaceKey),
        );
        expect(button.tint, CameoColors.backgroundFillNeutralInteraction);
        expect(button.blur, CameoBlur.blur);
        expect(
          find.descendant(
            of: find.byKey(PlayerBarV6.buttonKey),
            matching: find.byType(LiquidGlass),
          ),
          findsNothing,
        );
        final icons = tester.widgetList<CameoIcon>(
          find.descendant(
            of: find.byKey(PlayerBarV6.buttonKey),
            matching: find.byType(CameoIcon),
          ),
        );
        expect(icons.map((i) => i.name).toSet(), {
          CameoIconName.playerPauseFilled,
          CameoIconName.playerPlayFilled,
        });
        for (final i in icons) {
          expect(i.color, CameoColors.foregroundNeutralBase);
          expect(i.size, 22);
        }

        expect(
          tester.widget<CameoText>(find.byKey(PlayerBarV6.durationKey)).color,
          CameoColors.foregroundNeutralMuted,
        );
        expect(
          tester.widget<CameoText>(find.byKey(PlayerBarV6.durationKey)).text,
          labTranscriptV5.player.duration,
        );
        await _unmount(tester);
      },
    );

    testWidgets(
      '색 스프링: 일시정지 → 마커 1 탭 (l5 → l6) — l6 subtle → base · l5 base → subtle 이 중간값을 지나 정착 (lineColorSpring)',
      (tester) async {
        _screenSize(tester);
        await tester.pumpWidget(_host(const TranscriptScreen()));
        await tester.pump();
        await tester.tap(find.byKey(PlayerBarV6.buttonKey));
        await tester.pump();
        expect(_playback(tester).playing, isFalse);
        expect(_ink(tester, 'l5'), 1);
        expect(_ink(tester, 'l6'), 0);
        await tester.tap(find.byKey(PlayerBarV6.markerKey(0)));
        await tester.pump();

        expect(_currentId(tester), _keyString('l6'));
        final newInk = <double>[];
        final oldInk = <double>[];
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          newInk.add(_ink(tester, 'l6'));
          oldInk.add(_ink(tester, 'l5'));
        }

        expect(newInk.where((v) => v > 0.02 && v < 0.98), isNotEmpty);
        expect(oldInk.where((v) => v > 0.02 && v < 0.98), isNotEmpty);
        expect(newInk.last, greaterThan(newInk.first));
        expect(oldInk.last, lessThan(oldInk.first));
        final mid = _inkColor(tester, 'l6');
        expect(mid.a, greaterThan(CameoColors.foregroundNeutralSubtle.a));

        await _advance(tester, const Duration(seconds: 1));
        expect(_ink(tester, 'l6'), 1);
        expect(_ink(tester, 'l5'), 0);
        expect(_inkColor(tester, 'l6'), CameoColors.foregroundNeutralBase);
        expect(_inkColor(tester, 'l5'), CameoColors.foregroundNeutralSubtle);
        await _unmount(tester);
      },
    );

    testWidgets('색 스프링 끊김 없음: 움직이는 도중 다른 줄로 가면 지금 값에서 되돌아간다', (tester) async {
      _screenSize(tester);
      await tester.pumpWidget(_host(const TranscriptScreen()));
      await tester.pump();
      await tester.tap(find.byKey(PlayerBarV6.buttonKey));
      await tester.pump();
      await tester.tap(find.byKey(PlayerBarV6.markerKey(0)));
      await tester.pump();
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final before = _ink(tester, 'l6');
      expect(before, inExclusiveRange(0, 1));

      await tester.tap(find.byKey(TranscriptScreen.lineKey('l1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect((_ink(tester, 'l6') - before).abs(), lessThan(0.25));
      expect(_currentId(tester), _keyString('l1'));
      await _advance(tester, const Duration(seconds: 1));
      expect(_ink(tester, 'l6'), 0);
      expect(_ink(tester, 'l1'), 1);
      await _unmount(tester);
    });

    testWidgets('모션 감소: 줄 전환 색이 즉시 (중간값 없음)', (tester) async {
      _screenSize(tester);
      await tester.pumpWidget(
        _host(const TranscriptScreen(), disableAnimations: true),
      );
      await tester.pump();
      await tester.tap(find.byKey(PlayerBarV6.buttonKey));
      await tester.pump();
      await tester.tap(find.byKey(PlayerBarV6.markerKey(0)));
      await tester.pump();
      expect(_ink(tester, 'l6'), 1);
      expect(_ink(tester, 'l5'), 0);
      expect(_inkColor(tester, 'l6'), CameoColors.foregroundNeutralBase);

      expect(
        _playback(tester).position.value,
        closeTo(labTranscriptV5.player.markers[0].start, 1e-6),
      );
      await _unmount(tester);
    });

    testWidgets(
      '재생 중 경계 통과: 시계가 l5 끝(158.56 s)을 넘으면 l6 이 현재 줄 (재생 흐름으로도 같은 색 스프링)',
      (tester) async {
        _screenSize(tester);
        await tester.pumpWidget(_host(const TranscriptScreen()));
        await tester.pump();
        final t = buildTranscriptTimelineV5(
          labTranscriptV5.lines,
          labTranscriptV5.player,
          anchorFraction: 0,
        );
        final l6 = _indexOf('l6');

        _playback(
          tester,
        ).seekTo((t.ranges[l6].start - 1) / t.durationSec, animated: false);
        await tester.pump();
        expect(_currentId(tester), _keyString('l5'));
        await _advance(tester, const Duration(milliseconds: 1500));
        expect(_currentId(tester), _keyString('l6'));
        await _advance(tester, const Duration(seconds: 1));
        expect(_ink(tester, 'l6'), 1);
        await _unmount(tester);
      },
    );

    testWidgets('줄 탭 → 그 줄 시작으로 탐색 (l1 = 0 s · 카드 l4)', (tester) async {
      _screenSize(tester);
      final shaped = _figmaShaped();
      await tester.pumpWidget(_host(TranscriptScreen(content: shaped)));
      await _advance(tester, const Duration(seconds: 2));
      await tester.tap(find.byKey(TranscriptScreen.lineKey('l1')));
      await tester.pump();
      expect(_playback(tester).seconds, closeTo(0, 0.1));
      expect(_currentId(tester), _keyString('l1'));

      final t = buildTranscriptTimelineV5(
        shaped.lines,
        shaped.player,
        anchorFraction: 0,
      );
      await tester.tap(find.byKey(TranscriptScreen.lineKey('l4')));
      await tester.pump();
      expect(
        _playback(tester).seconds,
        closeTo(t.ranges[_indexOf('l4')].start, 0.1),
      );
      expect(_currentId(tester), _keyString('l4'));
      await _unmount(tester);
    });

    testWidgets('일시정지 버튼 → 재생 멈춤 · 다시 → 재생 (아이콘 교차)', (tester) async {
      _screenSize(tester);
      await tester.pumpWidget(_host(const TranscriptScreen()));
      await tester.pump();
      expect(_playback(tester).playing, isTrue);
      await tester.tap(find.byKey(PlayerBarV6.buttonKey));
      await tester.pump();
      expect(_playback(tester).playing, isFalse);
      final paused = _playback(tester).seconds;
      await _advance(tester, const Duration(seconds: 1));
      expect(_playback(tester).seconds, paused);
      await tester.tap(find.byKey(PlayerBarV6.buttonKey));
      await tester.pump();
      expect(_playback(tester).playing, isTrue);
      await _advance(tester, const Duration(seconds: 1));
      expect(_playback(tester).seconds, greaterThan(paused + 0.5));
      await _unmount(tester);
    });

    testWidgets('마커 탭 → 마커 시작 · 트랙 탭 → 그 분수 · thumb 드래그 → 손가락 1:1', (
      tester,
    ) async {
      _screenSize(tester);
      await tester.pumpWidget(_host(const TranscriptScreen()));
      await tester.pump();
      await tester.tap(find.byKey(PlayerBarV6.buttonKey));
      await tester.pump();
      final markers = labTranscriptV5.player.markers;
      await tester.tap(find.byKey(PlayerBarV6.markerKey(1)));
      await tester.pump();
      expect(_playback(tester).seconds, closeTo(markers[1].start * 443, 0.2));
      expect(_currentId(tester), _keyString('l7'));
      await _advance(tester, const Duration(seconds: 1));

      final track = tester.getRect(find.byKey(PlayerBarV6.trackKey));
      await tester.tapAt(
        Offset(track.left + 0.1 * track.width, track.center.dy),
      );
      await tester.pump();
      expect(_playback(tester).seconds, closeTo(0.1 * 443, 1));
      await _advance(tester, const Duration(seconds: 1));

      final from = _playback(tester).position.value;
      final thumb = tester.getRect(find.byKey(PlayerBarV6.thumbKey)).center;
      await tester.dragFrom(thumb, Offset(0.2 * track.width, 0));
      await tester.pump();
      expect(_playback(tester).position.value, closeTo(from + 0.2, 0.02));
      await _advance(tester, const Duration(seconds: 1));
      await _unmount(tester);
    });

    testWidgets(
      '내비: 닫기 = solid.button.md gray x · pill = ScrimPill gray [phone-call · heart] · 하트 토글 (켜짐 · 꺼짐)',
      (tester) async {
        _screenSize(tester);
        await tester.pumpWidget(_host(const TranscriptScreen()));
        await tester.pump();
        final close = tester.widget<SolidButton>(
          find.byKey(TranscriptNavV6.closeKey),
        );
        expect(close.size, SolidButtonSize.md);
        expect(close.variant, SolidButtonVariant.gray);
        expect(close.icon, CameoIconName.x);
        ScrimPill pill() =>
            tester.widget<ScrimPill>(find.byKey(TranscriptNavV6.actionsKey));
        expect(pill().tone, ScrimPillTone.gray);
        expect(pill().items.map((i) => i.icon), [
          CameoIconName.phoneCall,
          CameoIconName.heart,
        ]);

        expect(close.semanticLabel, appContent.v6.album.closeLabel);
        expect(pill().items[0].semanticLabel, appContent.v6.tabBar.callLabel);
        expect(pill().items[1].active, isFalse);
        expect(pill().items[1].semanticLabel, appContent.v6.album.likeLabel);
        await tester.tap(find.byKey(ScrimPill.itemKey(1)));
        await tester.pump();
        expect(pill().items[1].active, isTrue);
        expect(pill().items[1].semanticLabel, appContent.v6.album.unlikeLabel);
        await tester.tap(find.byKey(ScrimPill.itemKey(1)));
        await tester.pump();
        expect(pill().items[1].active, isFalse);
        await _unmount(tester);
      },
    );

    testWidgets(
      '등장 스태거: 푸시가 끝난 뒤 l1 0 · l2 1 · l3 2 · 사진 3 · 카드 4 (불투명 요소만) · 플레이어 · 내비는 스태거 없음 · 글래스 페이드 없음',
      (tester) async {
        _screenSize(tester);
        await tester.pumpWidget(_host(const TranscriptScreen()));
        await tester.pump();
        final staggers = tester
            .widgetList<StaggerIn>(find.byType(StaggerIn))
            .toList();
        expect(staggers.map((s) => s.index), [0, 1, 2, 3, 4]);
        expect(
          find.ancestor(
            of: find.byKey(InlinePhotoV6.cardKey),
            matching: find.byWidgetPredicate(
              (w) => w is StaggerIn && w.index == 3,
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.ancestor(
            of: find.byKey(HighlightCardV6.cardKey),
            matching: find.byWidgetPredicate(
              (w) => w is StaggerIn && w.index == 4,
            ),
          ),
          findsOneWidget,
        );
        for (final t in [PlayerBarV6, TranscriptNavV6]) {
          expect(
            find.ancestor(of: find.byType(t), matching: find.byType(StaggerIn)),
            findsNothing,
          );
        }
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          _expectGlassNeverFaded(tester);
        }
        await _unmount(tester);
      },
    );

    testWidgets(
      '데모 (?demo=1): 1.5 s 일시정지 → 3 s 마커 1 (l6) → 4.5 s 재생 → 6.5 s 줄 1 (l1) → 8 s 하트 켜짐',
      (tester) async {
        _screenSize(tester);
        await tester.pumpWidget(_host(const TranscriptScreen(demo: true)));
        await tester.pump();
        const after = Duration(milliseconds: 100);
        await _advance(tester, TranscriptDemoV6.pause + after);
        expect(_playback(tester).playing, isFalse);
        await _advance(
          tester,
          TranscriptDemoV6.seekMarker - TranscriptDemoV6.pause,
        );
        expect(_currentId(tester), _keyString('l6'));
        await _advance(
          tester,
          TranscriptDemoV6.play - TranscriptDemoV6.seekMarker,
        );
        expect(_playback(tester).playing, isTrue);
        await _advance(
          tester,
          TranscriptDemoV6.tapLine - TranscriptDemoV6.play,
        );
        expect(_currentId(tester), _keyString('l1'));
        await _advance(
          tester,
          TranscriptDemoV6.like - TranscriptDemoV6.tapLine,
        );
        expect(
          tester
              .widget<ScrimPill>(find.byKey(TranscriptNavV6.actionsKey))
              .items[1]
              .active,
          isTrue,
        );
        await _unmount(tester);
      },
    );
  });

  group('통화 기록 v6 라우트 · 앱', () {
    setUp(FlowDemo.resetForTesting);
    tearDown(FlowDemo.resetForTesting);

    test('버전: 기본 v6 · v=3 만 v3 · 상태바 v6 어두운 글리프 / v3 밝은 글리프', () {
      expect(TranscriptVersion.tryParse(null), TranscriptVersion.v6);
      expect(TranscriptVersion.tryParse('5'), TranscriptVersion.v6);
      expect(TranscriptVersion.tryParse('3'), TranscriptVersion.v3);
      Widget build(String name) =>
          transcriptScreenFor(CameoLocation.parse(name));
      expect(build('/transcript?theme=dark'), isA<TranscriptScreen>());
      expect(build('/transcript?theme=photo'), isA<TranscriptScreen>());
      expect(build('/transcript'), isA<TranscriptScreen>());
      expect(build('/transcript?theme=dark&v=3'), isA<TranscriptV3Screen>());
      expect((build('/transcript?demo=1') as TranscriptScreen).demo, isTrue);
      expect(build('/transcript').key, const ValueKey('v6'));
      CameoStatusBarStyle bar(String n) {
        final l = CameoLocation.parse(n);
        return CameoRoutes.table[l.path]!.statusBar(l);
      }

      expect(bar('/transcript'), CameoStatusBarStyle.darkContent);
      expect(bar('/transcript?theme=dark'), CameoStatusBarStyle.darkContent);
      expect(
        bar('/transcript?theme=dark&v=3'),
        CameoStatusBarStyle.lightContent,
      );
      expect(
        bar('/transcript?theme=photo&v=3'),
        CameoStatusBarStyle.lightContent,
      );
    });

    testWidgets(
      '앱: /transcript?session=member → v6 (탭바는 루트 스택 아래에 덮인다) · phone-call → 통화 모달 · X → 뒤로',
      (tester) async {
        await pumpCameoApp(
          tester,
          '/transcript?theme=dark',
          stored: devSessionOf(DevSessionKind.member),
        );
        expect(find.byType(TranscriptScreen), findsOneWidget);
        expect(find.byType(TabBarV6), findsNothing);
        await tester.tap(find.byKey(ScrimPill.itemKey(0)));
        await settleApp(tester);
        expect(find.byType(CallScreen), findsOneWidget);
        CameoNav.pop(tester.element(find.byType(CallScreen)));
        await settleApp(tester);
        expect(find.byType(CallScreen), findsNothing);
        await tester.tap(find.byKey(TranscriptNavV6.closeKey));
        await settleApp(tester);
        expect(find.byType(TranscriptScreen), findsNothing);
        await disposeApp(tester);
      },
    );
  });
}
