// Regression coverage for v6 call camera. Preserve behavior, layout, and interaction
// expectations.

import 'package:cameo/components/aod_v6.dart';
import 'package:cameo/components/call_bar_v6.dart';
import 'package:cameo/components/call_camera_geometry.dart';
import 'package:cameo/components/captured_card.dart';
import 'package:cameo/components/controls.dart';
import 'package:cameo/components/photo_sheet.dart';
import 'package:cameo/components/review_overlay.dart';
import 'package:cameo/components/scrim_button.dart';
import 'package:cameo/components/shot.dart';
import 'package:cameo/components/solid_button.dart';
import 'package:cameo/components/tab_bar_v6.dart';
import 'package:cameo/components/volume_slider.dart';
import 'package:cameo/content/lab.g.dart';
import 'package:cameo/design_system/design_system.dart';
import 'package:cameo/state/device_services.dart';
import 'package:cameo/state/session.dart' show PhotoSheetVariant;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

const Size _screen = Size(402, 874);
const Duration _frame = Duration(milliseconds: 16);

Future<void> _pump(
  WidgetTester tester,
  List<Widget> children, {
  DeviceServices? services,
  bool reduceMotion = false,
  Size size = _screen,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: MediaQueryData(size: size, disableAnimations: reduceMotion),
        child: DeviceServicesScope(
          services: services ?? DeviceServices.simulated(),
          child: CameoTheme(
            mode: CameoColorMode.dark,
            child: Stack(fit: StackFit.expand, children: children),
          ),
        ),
      ),
    ),
  );
}

void _expectNoOpacityOverGlass(WidgetTester tester) {
  for (final e in find.byType(LiquidGlass).evaluate()) {
    e.visitAncestorElements((a) {
      final w = a.widget;
      if (w is Opacity) expect(w.opacity, 1, reason: '글래스 조상 Opacity');
      if (w is FadeTransition) {
        expect(w.opacity.value, 1, reason: '글래스 조상 FadeTransition');
      }
      return true;
    });
  }
}

Future<void> _settle(WidgetTester tester, [int frames = 120]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(_frame);
  }
}

void _rectClose(Rect actual, Rect expected, {double eps = 0.01}) {
  expect(actual.left, closeTo(expected.left, eps), reason: 'left $actual');
  expect(actual.top, closeTo(expected.top, eps), reason: 'top $actual');
  expect(actual.width, closeTo(expected.width, eps), reason: 'w $actual');
  expect(actual.height, closeTo(expected.height, eps), reason: 'h $actual');
}

Color _iconColor(WidgetTester tester, Finder of) => tester
    .widget<CameoIcon>(
      find.descendant(of: of, matching: find.byType(CameoIcon)),
    )
    .color!;

void main() {
  const dark = CameoPalette.dark;
  const light = CameoPalette.light;

  group('기하 (call_camera_geometry — RN callCameraGeometry 와 같은 수식 · W/H 규칙)', () {
    test(
      '통화: bottom-nav 104 @ 770 · 바 370 · 칸 72.4 · 내비 (16, 62) / (340, 62) 46 — 393 × 852 에서도 같은 규칙',
      () {
        expect(callBottomNavHeight(), 104);
        expect(callBottomNavTop(874), 770);
        expect(callBarWidth(402), 370);
        expect(callBarItemWidth(402), closeTo(72.4, 1e-9));
        final nav = callNavButtons(402);
        expect((nav.top, nav.size, nav.leftX, nav.rightX), (62, 46, 16, 340));
        expect(callBarWidth(393), 361);
        expect(callBarItemWidth(393), closeTo(70.6, 1e-9));
        expect(callNavButtons(393).rightX, 331);
        expect(callBottomNavTop(852), 748);
      },
    );

    test(
      '촬영 카드: 아래 기준 770 · 세로 346.5 × 462 @ (27.75, 308) · 가로 4:3 같은 폭 × 259.875 @ top 510.125 · 닫기 (10.25, 10)',
      () {
        final p = capturedCardRect(CapturedOrientation.portrait, 402, 874);
        expect(p, const Rect.fromLTWH(27.75, 308, 346.5, 462));
        final l = capturedCardRect(CapturedOrientation.landscape, 402, 874);
        expect(l, const Rect.fromLTWH(27.75, 510.125, 346.5, 259.875));
        expect(l.width / l.height, closeTo(4 / 3, 1e-9));
        expect(p.bottom, 770);
        expect(l.bottom, 770);

        expect(
          capturedCardRect(CapturedOrientation.portrait, 393, 852),
          const Rect.fromLTWH(23.25, 286, 346.5, 462),
        );
        expect(capturedCardClipBottom(), 104);
        expect(capturedCardCloseOffset, const Offset(10.25, 10));
        expect(p.topLeft + capturedCardCloseOffset, const Offset(38, 318));
        expect(
          capturedCardOrientation(640, 480),
          CapturedOrientation.landscape,
        );
        expect(capturedCardOrientation(480, 640), CapturedOrientation.portrait);
        expect(capturedCardOrientation(500, 500), CapturedOrientation.portrait);
        expect(capturedCardOrientation(0, 0), CapturedOrientation.portrait);
        expect(
          capturedCardOrientationOf(const [Size(640, 480), Size(480, 640)]),
          CapturedOrientation.landscape,
        );
        final t0 = capturedCardTransform(0);
        expect(t0.translateY, CameoMotion.capturedCardEnterOffset);
        expect(t0.scale, CameoMotion.capturedCardEnterScale);
        expect(t0.opacity, 0);
        final t1 = capturedCardTransform(1);
        expect((t1.translateY, t1.scale, t1.opacity), (0.0, 1.0, 1.0));
        expect(capturedCardTransform(1.08).opacity, 1);
        expect(capturedCardPageAt(346.5 * 1.6, 346.5, 3), 2);
        expect(capturedCardDotActive(1.5, 1), 0.5);
      },
    );

    test(
      '슬라이더 v6: pill 250 × 44 가운데 (x 76) · 트랙 216 · 트랙 안쪽 17 (테두리 1 + p 16) · Figma 샘플 채움 47 · 썸 left 32.5',
      () {
        expect(sliderPillLeft(402), 76);
        expect(sliderTrackInset, 17);
        expect(sliderFigmaSampleValue, closeTo(46.5 / 216, 1e-12));
        expect(sliderThumbLeft(sliderFigmaSampleValue), closeTo(32.5, 1e-9));
        expect(sliderFillWidth(sliderFigmaSampleValue), closeTo(47, 1e-9));
        expect(sliderFillWidth(0), 0.5);
        expect(sliderThumbCenter(1), 216);
        expect(sliderValueAt(108), closeTo(0.5, 1e-9));
        expect(sliderValueAt(-20), 0);
        expect(sliderValueAt(400), 1);
        final t0 = sliderPillTransform(0);
        expect(t0.translateY, CameoMotion.sliderEnterOffset);
        expect(t0.scaleX, CameoMotion.sliderEnterScale);
        expect(t0.scaleY, CameoMotion.transitionZoomChromeScaleFrom);
        final t1 = sliderPillTransform(1);
        expect((t1.translateY, t1.scaleX, t1.scaleY), (0.0, 1.0, 1.0));
      },
    );

    test(
      '셔터 링: 상자 88 · 각도 = 녹화 시간 / 15 s × 360 (Figma 252° = 10.5 s) · 길이 m:ss',
      () {
        expect(shotRingBox(), 88);
        expect(
          shotRingSweepDeg(const Duration(milliseconds: 10500)),
          closeTo(CameoLayout.shotV6RingSampleSweepDeg, 1e-9),
        );
        expect(shotRingSweepDeg(const Duration(seconds: 30)), 360);
        expect(shotRingCircumference(), closeTo(2 * 3.14159265 * 41, 1e-3));
        expect(recordingLabel(const Duration(milliseconds: 3400)), '0:03');
        expect(recordingLabel(const Duration(seconds: 75)), '1:15');
      },
    );

    test(
      '취침 AOD: 볼륨 3 s 선형 → 0.0625 · 어둠 1.2 s easing.standard · 내비 −108 · 바 +104 · 종료 버튼 150 × 54 @ (126, 774) · 버튼 등장 24',
      () {
        expect(
          sleepVolumeAt(const Duration(milliseconds: 1500), 1),
          closeTo((1 + CameoMotion.sleepVolumeTarget) / 2, 1e-9),
        );
        expect(aodOverlayAt(Duration.zero), 0);
        expect(aodOverlayAt(CameoMotion.sleepAod), 1);
        expect(aodControlOffsets.nav, -108);
        expect(aodControlOffsets.bar, 104);
        expect(aodButtonRect(402, 874), const Rect.fromLTWH(126, 774, 150, 54));
        expect(aodButtonRect(393, 852).top, 752);
        final b0 = aodButtonTransform(0);
        expect((b0.translateY, b0.opacity), (24.0, 0.0));
        final b1 = aodButtonTransform(1.1);
        expect(b1.opacity, 1);
        expect(b1.translateY, closeTo(-2.4, 1e-9));
      },
    );

    test(
      '사진 시트 v6: (8, 197) 386 × 573 (아래 770) · 칸 정사각 127.33 · 실시간 칸 127.33 × 256.67 · 그리드 503 · 숨김 677 · 닫기 판정 = 반 (286.5)',
      () {
        expect(photoSheetRect(402, 874), const Rect.fromLTWH(8, 197, 386, 573));
        expect(photoSheetCellSize(402), closeTo(127.333333, 1e-6));
        final live = photoSheetLiveCell(402);
        expect(live.width, closeTo(127.333333, 1e-6));
        expect(live.height, closeTo(256.666667, 1e-6));
        expect(photoSheetGridHeight(874), 503);
        const step = 127.333333 + 2;
        final c0 = photoSheetCellFrame(0, 402);
        expect((c0.row, c0.col), (0, 1));
        expect(c0.x, closeTo(step, 1e-5));
        expect(c0.size, closeTo(127.333333, 1e-6));
        final c4 = photoSheetCellFrame(4, 402);
        expect((c4.row, c4.col, c4.x), (2, 0, 0.0));
        expect(c4.y, closeTo(2 * step, 1e-5));

        expect(photoSheetContentHeight(10, 402), closeTo(515.333, 0.001));
        expect(photoSheetHiddenOffset(874), 677);
        expect(photoSheetShouldClose(286.5, 0, 573), isTrue);
        expect(photoSheetShouldClose(120, 0, 573), isFalse);
        expect(photoSheetShouldClose(20, 900, 573), isTrue);
        expect(photoSheetRect(393, 852).width, 377);
      },
    );

    test('사진 시트 순서: 오늘 촬영 → Figma 시트 순서 (같은 파일은 처음 것만) → 나머지', () {
      PhotoSheetCandidate<String> p(
        String id,
        String? file, {
        bool today = false,
      }) => (photo: id, id: id, file: file, today: today);
      final order = photoSheetOrder(
        [
          p('s1/a', 'a'),
          p('s1/x', 'x'),
          p('s1/c', 'c'),
          p('s2/a', 'a'),
          p('capture-1', null, today: true),
          p('s2/b', 'b'),
        ],
        ['c', 'b', 'a'],
      );
      expect(order, ['capture-1', 's1/c', 's2/b', 's1/a', 's1/x', 's2/a']);
    });

    test(
      '카메라 · 전송: 뷰파인더 (4, 66) 394 × 700.44 · 셔터 (201, 704) · 썸네일 (16, 785) 54 · 동작 행 784 (trash 16 · send 340) · send 비행 = 썸네일 가운데 × 0.15',
      () {
        final vf = cameraViewfinderRect(402);
        _rectClose(vf, const Rect.fromLTWH(4, 66, 394, 700.444444));
        expect(cameraShotCenter(402).dx, 201);
        expect(cameraShotCenter(402).dy, closeTo(704, 1e-6));
        expect(cameraThumbnailRect(874), const Rect.fromLTWH(16, 785, 54, 54));
        final row = reviewActions(402, 874);
        expect(
          (row.top, row.size, row.trashLeft, row.sendLeft),
          (784.0, 46.0, 16.0, 340.0),
        );
        final d = reviewSendDelta(402, 874);
        expect(d.dx, closeTo(-158, 1e-9));
        expect(d.dy, closeTo(812 - (66 + 700.444444 / 2), 1e-5));
        final t = reviewSendTransform(1, d);
        expect(t.scale, closeTo(CameoMotion.reviewV6SendScale, 1e-12));
        expect(
          vf.center + Offset(t.translateX, t.translateY),
          cameraThumbnailRect(874).center,
        );
        final q = reviewDiscardTransform(1);
        expect((q.scale, q.opacity), (CameoMotion.reviewV6DiscardScale, 0.0));
        final a0 = reviewActionsTransform(0);
        expect(a0.translateY, CameoMotion.reviewV6ActionsOffsetY);
        expect(a0.scale, CameoMotion.transitionZoomChromeScaleFrom);

        expect(cameraViewfinderRect(393).width, 385);
        expect(reviewActions(393, 852).sendLeft, 331);
      },
    );
  });

  group('상태 기계 (RN callCameraGeometry §11 과 같은 표)', () {
    test(
      '취침: off + moon → aod · aod + end → off · 그 밖 = 거부 (AOD 탭은 사건이 아니다)',
      () {
        expect(
          sleepTransition(SleepPhase.off, SleepEvent.moon),
          SleepPhase.aod,
        );
        expect(sleepTransition(SleepPhase.aod, SleepEvent.end), SleepPhase.off);
        expect(sleepTransition(SleepPhase.aod, SleepEvent.moon), isNull);
        expect(sleepTransition(SleepPhase.off, SleepEvent.end), isNull);
      },
    );

    test(
      '전송 검토: none → review → send | discard → none · 떠나는 중에는 거부 · 탭바는 review 동안만 숨김',
      () {
        expect(
          reviewTransition(ReviewStage.none, ReviewEvent.capture),
          ReviewStage.review,
        );
        expect(
          reviewTransition(ReviewStage.review, ReviewEvent.send),
          ReviewStage.send,
        );
        expect(
          reviewTransition(ReviewStage.review, ReviewEvent.discard),
          ReviewStage.discard,
        );
        expect(
          reviewTransition(ReviewStage.send, ReviewEvent.exited),
          ReviewStage.none,
        );
        expect(
          reviewTransition(ReviewStage.discard, ReviewEvent.exited),
          ReviewStage.none,
        );
        for (final stage in [
          ReviewStage.review,
          ReviewStage.send,
          ReviewStage.discard,
        ]) {
          expect(reviewTransition(stage, ReviewEvent.capture), isNull);
        }
        expect(reviewTransition(ReviewStage.send, ReviewEvent.send), isNull);
        expect(reviewTransition(ReviewStage.none, ReviewEvent.send), isNull);
        expect(
          reviewTransition(ReviewStage.review, ReviewEvent.exited),
          isNull,
        );
        expect(ReviewStage.values.where(reviewHidesTabBar), [
          ReviewStage.review,
        ]);
      },
    );

    test(
      '파트너 토스트 타이머 = 탭 · 포커스 · 아직 안 뜸 · 검토 없음 · 바 선택 = 슬라이더 · 시트 · 토스트 · 음소거 · /call?state= → 할 일',
      () {
        expect(
          partnerToastArmed(
            tab: true,
            focused: true,
            shown: false,
            stage: ReviewStage.none,
          ),
          isTrue,
        );
        expect(
          partnerToastArmed(
            tab: true,
            focused: true,
            shown: false,
            stage: ReviewStage.review,
          ),
          isFalse,
        );
        expect(
          partnerToastArmed(
            tab: false,
            focused: true,
            shown: false,
            stage: ReviewStage.none,
          ),
          isFalse,
        );
        expect(
          partnerToastArmed(
            tab: true,
            focused: false,
            shown: false,
            stage: ReviewStage.none,
          ),
          isFalse,
        );
        expect(
          partnerToastArmed(
            tab: true,
            focused: true,
            shown: true,
            stage: ReviewStage.none,
          ),
          isFalse,
        );
        final sel = callBarSelection(
          sliderShown: true,
          sheetOpen: false,
          toastVisible: true,
          muted: false,
        );
        expect(
          (sel.volume, sel.camera, sel.highlight, sel.microphone),
          (true, false, true, false),
        );
        expect(
          callInitialFlags('media-16x9').card,
          CapturedOrientation.portrait,
        );
        expect(
          callInitialFlags('media-1x1').card,
          CapturedOrientation.portrait,
        );
        expect(
          callInitialFlags('media-4x3').card,
          CapturedOrientation.landscape,
        );
        expect(callInitialFlags('volume').slider, isTrue);
        expect(callInitialFlags('highlight').highlight, isTrue);
        expect(callInitialFlags('aod').sleep, isTrue);
        expect(callInitialFlags('sleep-toast').sleep, isTrue);
        final base = callInitialFlags('base');
        expect(
          (base.card, base.slider, base.highlight, base.sleep),
          (null, false, false, false),
        );
      },
    );
  });

  group('CallBarV6 (bottom-nav 2295:15623 — dark)', () {
    testWidgets(
      '컨테이너 402 × 104 @ 770 · 바 (16, 782) 370 × 58 · 칸 5 × 72.4 × 50 · 선택 = 흰 아이콘 (채움 없음) · 종료 = system/red · 누름 → 칸 · 페이드 sectionFadeBottomV6 + blur',
      (tester) async {
        final pressed = <CallBarSlot>[];
        Future<void> build(Set<CallBarSlot> selected) => _pump(tester, [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: CallBarV6(selected: selected, onPress: pressed.add),
          ),
        ]);
        await build({CallBarSlot.volume});
        expect(
          tester.getRect(find.byKey(CallBarV6.containerKey)),
          const Rect.fromLTWH(0, 770, 402, 104),
        );
        expect(
          tester.getRect(find.byKey(CallBarV6.barKey)),
          const Rect.fromLTWH(16, 782, 370, 58),
        );
        for (final (i, s) in callBarV6Slots.indexed) {
          final r = tester.getRect(find.byKey(CallBarV6.slotKey(s.slot)));
          expect(r.width, closeTo(72.4, 0.01));
          expect(r.height, 50);
          expect(r.left, closeTo(20 + i * 72.4, 0.01));
          expect(r.top, 786);
        }
        expect(callBarV6Slots.map((s) => s.icon.key), labV6.call.barIcons);
        Color icon(CallBarSlot s) =>
            _iconColor(tester, find.byKey(CallBarV6.slotKey(s)));
        expect(icon(CallBarSlot.volume), dark.foregroundNeutralBase);
        expect(icon(CallBarSlot.camera), dark.foregroundNeutralSubtle);
        expect(icon(CallBarSlot.end), dark.staticWhiteBase);

        await build({CallBarSlot.camera});
        await tester.pump(const Duration(milliseconds: 60));
        final mid = icon(CallBarSlot.camera);
        expect(mid, isNot(dark.foregroundNeutralSubtle));
        expect(mid, isNot(dark.foregroundNeutralBase));
        await _settle(tester, 20);
        expect(icon(CallBarSlot.camera), dark.foregroundNeutralBase);
        expect(icon(CallBarSlot.volume), dark.foregroundNeutralSubtle);
        Color? slotFill(CallBarSlot slot) {
          final boxes = tester
              .widgetList<DecoratedBox>(
                find.descendant(
                  of: find.byKey(CallBarV6.slotKey(slot)),
                  matching: find.byType(DecoratedBox),
                ),
              )
              .map((d) => d.decoration)
              .whereType<ShapeDecoration>()
              .map((d) => d.color)
              .whereType<Color>();
          return boxes.isEmpty ? null : boxes.first;
        }

        expect(slotFill(CallBarSlot.end), dark.systemRed);
        for (final s in [
          CallBarSlot.volume,
          CallBarSlot.microphone,
          CallBarSlot.camera,
          CallBarSlot.highlight,
        ]) {
          expect(slotFill(s), isNull, reason: s.name);
        }
        final glass = tester.widget<GlassSurface>(find.byKey(CallBarV6.barKey));
        expect(glass.tint, dark.backgroundFillScrimBase);
        expect(glass.border, dark.borderScrim);
        expect(glass.borderWidth, 1);
        expect(glass.radius, 32);
        expect(find.byType(LiquidGlass), findsOneWidget);
        expect(find.byType(BackdropFilter), findsOneWidget);
        final grad =
            (tester
                        .widget<DecoratedBox>(find.byKey(CallBarV6.fadeKey))
                        .decoration
                    as BoxDecoration)
                .gradient;
        expect(grad, dark.gradients.sectionFadeBottomV6);
        for (final s in callBarV6Slots) {
          await tester.tap(find.byKey(CallBarV6.slotKey(s.slot)));
          await tester.pump(const Duration(milliseconds: 300));
        }
        expect(pressed, [for (final s in callBarV6Slots) s.slot]);
        _expectNoOpacityOverGlass(tester);
      },
    );
  });

  group('VolumeSlider v6 (2295:15817 — dark ↔ 시스템 볼륨 서비스)', () {
    Future<SimulatedVolumeService> pumpSlider(
      WidgetTester tester, {
      bool visible = true,
      double initial = 0.5,
      VoidCallback? onShown,
      VoidCallback? onHidden,
      ValueChanged<VolumeSliderInteraction>? onInteraction,
    }) async {
      final services = DeviceServices.simulated(volume: initial);
      await _pump(tester, [
        Positioned(
          left: 0,
          right: 0,
          bottom: callBottomNavHeight(),
          child: VolumeSlider(
            visible: visible,
            onShown: onShown,
            onHidden: onHidden,
            onInteraction: onInteraction,
          ),
        ),
      ], services: services);
      return services.volume as SimulatedVolumeService;
    }

    double thumbCenterX(WidgetTester tester) =>
        tester.getRect(find.byKey(VolumeSlider.thumbKey)).center.dx;

    testWidgets(
      '컨테이너 702–770 · pill (76, 714) 250 × 44 (dark 글래스 · 테두리 1 안쪽) · 트랙 (93, 731) 216 × 10 · 썸 = 서비스 값 · 하드웨어 변화를 따른다 · onShown',
      (tester) async {
        var shown = 0;
        final volume = await pumpSlider(
          tester,
          initial: sliderFigmaSampleValue,
          onShown: () => shown++,
        );
        await _settle(tester);
        expect(shown, 1);
        _rectClose(
          tester.getRect(find.byKey(VolumeSlider.pillKey)),
          const Rect.fromLTWH(76, 714, 250, 44),
        );
        _rectClose(
          tester.getRect(find.byKey(VolumeSlider.trackKey)),
          const Rect.fromLTWH(93, 731, 216, 10),
        );

        _rectClose(
          tester.getRect(find.byKey(VolumeSlider.thumbKey)),
          const Rect.fromLTWH(125.5, 722, 28, 28),
        );
        expect(
          tester.getRect(find.byKey(VolumeSlider.fillKey)).width,
          closeTo(47, 1e-6),
        );
        final glass = tester.widget<GlassSurface>(
          find.descendant(
            of: find.byKey(VolumeSlider.pillKey),
            matching: find.byType(GlassSurface),
          ),
        );
        expect(glass.tint, dark.backgroundFillScrimBase);
        expect(glass.border, dark.borderScrim);
        expect(glass.borderWidth, 1);
        Color fillOf(Key key) =>
            ((tester
                        .widget<DecoratedBox>(
                          find
                              .descendant(
                                of: find.byKey(key),
                                matching: find.byType(DecoratedBox),
                              )
                              .first,
                        )
                        .decoration)
                    as ShapeDecoration)
                .color!;
        expect(
          fillOf(VolumeSlider.fillKey),
          dark.backgroundFillNeutralInverted,
        );
        final track = tester
            .widgetList<DecoratedBox>(
              find.descendant(
                of: find.byKey(VolumeSlider.trackKey),
                matching: find.byType(DecoratedBox),
              ),
            )
            .first;
        expect(
          (track.decoration as ShapeDecoration).color,
          dark.backgroundFillNeutralBase,
        );
        volume.simulateHardware(0.75);
        await tester.pump();
        await tester.pump();
        expect(thumbCenterX(tester), closeTo(93 + 0.75 * 216, 1e-6));
        expect(find.byType(LiquidGlass), findsOneWidget);
        _expectNoOpacityOverGlass(tester);
      },
    );

    testWidgets(
      '끌기 → volume.set ((x − 17) / 216 — 테두리 안) · 썸 grabScale · 조작 start / end · 트랙 밖 = 1',
      (tester) async {
        final phases = <VolumeSliderInteraction>[];
        final volume = await pumpSlider(tester, onInteraction: phases.add);
        await _settle(tester);
        final g = await tester.startGesture(const Offset(93 + 216 * 0.2, 736));
        await tester.pump(_frame);
        expect(volume.value, closeTo(0.2, 1e-6));
        expect(phases, [VolumeSliderInteraction.start]);
        await g.moveTo(const Offset(93 + 216 * 0.9, 740));
        await _settle(tester, 30);
        expect(volume.value, closeTo(0.9, 1e-6));
        expect(thumbCenterX(tester), closeTo(93 + 216 * 0.9, 0.01));
        await g.moveTo(const Offset(500, 740));
        await tester.pump(_frame);
        expect(volume.value, 1);
        await g.up();
        await _settle(tester, 30);
        expect(phases, [
          VolumeSliderInteraction.start,
          VolumeSliderInteraction.end,
        ]);
      },
    );

    testWidgets('등장 = 스프링 (bouncy) · visible false → 퇴장 끝에 onHidden', (
      tester,
    ) async {
      var hidden = 0;
      Future<void> build(bool visible) => _pump(tester, [
        Positioned(
          left: 0,
          right: 0,
          bottom: 104,
          child: VolumeSlider(visible: visible, onHidden: () => hidden++),
        ),
      ]);
      await build(true);
      final state = tester.state<VolumeSliderState>(find.byType(VolumeSlider));
      expect(state.appear, 0);
      await tester.pump(const Duration(milliseconds: 100));
      expect(state.appear, greaterThan(0));
      await _settle(tester);
      expect(state.appear, 1);
      await build(false);
      await _settle(tester);
      expect(state.appear, 0);
      expect(hidden, 1);
    });
  });

  group('Shot v6 (2295:15992 — 바탕 light 톤)', () {
    testWidgets(
      '88 상자 · 바탕 76 = light scrim 글래스 (#f7f7fb80) + scrim 그림자 · 원판 64 · 링 system/red · 대기 = 링 없음 · 탭 = 사진 · 꾹 = 녹화 (252° = 10.5 s)',
      (tester) async {
        var photos = 0;
        var starts = 0;
        final ends = <Duration>[];
        await _pump(tester, [
          Positioned(
            left: 201 - 44,
            top: 704 - 44,
            child: Shot(
              buttonKey: const ValueKey('shot.button'),
              onPhoto: () => photos++,
              onRecordStart: () => starts++,
              onRecordEnd: ends.add,
            ),
          ),
        ]);
        final state = tester.state<ShotState>(find.byType(Shot));
        expect(tester.getSize(find.byType(Shot)), const Size(88, 88));
        expect(
          tester.getCenter(find.byKey(Shot.discKey)),
          const Offset(201, 704),
        );
        expect(tester.getSize(find.byKey(Shot.discKey)), const Size(64, 64));
        expect(tester.getSize(find.byKey(Shot.baseKey)), const Size(76, 76));
        final glass = tester.widget<GlassSurface>(
          find.descendant(
            of: find.byKey(Shot.baseKey),
            matching: find.byType(GlassSurface),
          ),
        );
        expect(glass.tint, light.backgroundFillScrimBase);
        expect(glass.blur, CameoBlur.scrim);
        expect(find.byType(LiquidGlass), findsOneWidget);
        CustomPaint ring() =>
            tester.widget<CustomPaint>(find.byKey(Shot.ringKey));
        expect(shotRingPainterWidth(ring()), 0);
        expect(shotRingPainterColor(ring()), dark.systemRed);
        await tester.tap(find.byKey(const ValueKey('shot.button')));
        await _settle(tester, 30);
        expect(photos, 1);
        final g = await tester.startGesture(const Offset(201, 704));
        await tester.pump(const Duration(milliseconds: 450));
        expect(state.recording, isTrue);
        expect(starts, 1);
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 1000));
        }
        await tester.pump(const Duration(milliseconds: 500));
        expect(shotRingPainterSweepDeg(ring()), closeTo(252, 1.5));
        expect(shotRingPainterWidth(ring()), closeTo(6, 0.01));
        await g.up();
        await tester.pump(_frame);
        expect(ends.single.inMilliseconds, closeTo(10500, 60));
        await _settle(tester, 90);
        expect(shotRingPainterWidth(ring()), 0);
        _expectNoOpacityOverGlass(tester);
      },
    );

    testWidgets('disabled = 누름 없음 (전송 검토 동안)', (tester) async {
      var photos = 0;
      await _pump(tester, [
        Positioned(
          left: 0,
          top: 0,
          child: Shot(
            disabled: true,
            buttonKey: const ValueKey('shot.button'),
            onPhoto: () => photos++,
          ),
        ),
      ]);
      await tester.tap(find.byKey(const ValueKey('shot.button')));
      await _settle(tester, 10);
      expect(photos, 0);
    });
  });

  group('PhotoSheet v6 (통화.사진 공유 2295:14936 — light)', () {
    final images = [
      for (final p in labInCallV5.photoSheet.photos) AssetImage(p.image),
    ];
    List<PhotoSheetItem> items(Set<int> checked) => [
      for (var i = 0; i < images.length; i++)
        PhotoSheetItem(
          id: 'p$i',
          image: images[i],
          checked: checked.contains(i),
        ),
    ];

    Future<void> pumpSheet(
      WidgetTester tester, {
      required bool open,
      PhotoSheetVariant variant = PhotoSheetVariant.instant,
      Set<int> checked = const {},
      int selected = 0,
      List<String>? log,
    }) => _pump(tester, [
      Positioned.fill(
        child: PhotoSheet(
          open: open,
          variant: variant,
          items: items(checked),
          selectedCount: selected,
          onTapPhoto: (item, i) => log?.add('tap $i'),
          onShare: () => log?.add('share'),
          onLive: () => log?.add('live'),
          onClose: () => log?.add('close'),
          onOpened: () => log?.add('opened'),
          onClosed: () => log?.add('closed'),
          cameraListLoader: () async => const [],
        ),
      ),
    ]);

    testWidgets(
      '(8, 197) 386 × 573 r26 · 채움 background/canvas/neutral/base · 닫기 = solid md gray 46 @ (20, 209) · 실시간 칸 127.33 × 256.67 @ (8, 267) · 칸 정사각 127.33 · 아래 (677) 에서 올라온다',
      (tester) async {
        final log = <String>[];
        await pumpSheet(tester, open: false, log: log);
        final sheet = tester.state<PhotoSheetState>(find.byType(PhotoSheet));
        expect(sheet.offset, 677);
        await pumpSheet(tester, open: true, log: log);
        await tester.pump(const Duration(milliseconds: 60));
        expect(sheet.offset, inExclusiveRange(0, 677));
        await _settle(tester);
        expect(sheet.offset, 0);
        expect(log, ['opened']);
        _rectClose(
          tester.getRect(find.byKey(PhotoSheet.sheetKey)),
          const Rect.fromLTWH(8, 197, 386, 573),
        );
        final fill =
            (tester
                        .widget<DecoratedBox>(
                          find
                              .descendant(
                                of: find.byKey(PhotoSheet.sheetKey),
                                matching: find.byType(DecoratedBox),
                              )
                              .first,
                        )
                        .decoration
                    as ShapeDecoration)
                .color;
        expect(fill, light.backgroundCanvasNeutralBase);
        expect(
          tester.getRect(find.byKey(PhotoSheet.closeKey)),
          const Rect.fromLTWH(20, 209, 46, 46),
        );
        expect(
          tester.widget<SolidButton>(find.byKey(PhotoSheet.closeKey)).variant,
          SolidButtonVariant.gray,
        );
        final title = tester.widget<CameoText>(
          find.ancestor(
            of: find.text(labInCallV5.photoSheet.title),
            matching: find.byType(CameoText),
          ),
        );
        expect(title.color, light.foregroundNeutralBase);
        expect(title.style, CameoTextStyles.headingSmStrong);
        _rectClose(
          tester.getRect(find.byKey(PhotoSheet.liveKey)),
          const Rect.fromLTWH(8, 267, 127.333333, 256.666667),
        );
        _rectClose(
          tester.getRect(find.byKey(PhotoSheet.cellKey(0))),
          const Rect.fromLTWH(8 + 129.333333, 267, 127.333333, 127.333333),
        );
        _rectClose(
          tester.getRect(find.byKey(PhotoSheet.cellKey(4))),
          const Rect.fromLTWH(8, 267 + 2 * 129.333333, 127.333333, 127.333333),
        );
        await tester.tap(find.byKey(PhotoSheet.liveKey));
        await tester.tap(find.byKey(PhotoSheet.cellKey(2)));
        await tester.pump(const Duration(milliseconds: 300));
        expect(log, ['opened', 'live', 'tap 2']);
      },
    );

    testWidgets(
      'A: 체크 = 공유함 (사진 0.3 + 원판) · 아니면 1 px 링 · 공유 버튼 없음 / B: 고른 수 > 0 → solid md default \'공유 N\' (검정 — light 시트 위)',
      (tester) async {
        await pumpSheet(tester, open: true, checked: {0});
        await _settle(tester);
        final opacities = tester
            .widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity))
            .map((w) => w.opacity)
            .toList();
        expect(opacities.first, CameoLayout.controlSelectedImageOpacity);
        expect(find.byKey(SelectControl.discKey), findsOneWidget);
        expect(find.byKey(PhotoSheet.shareKey), findsNothing);
        await pumpSheet(
          tester,
          open: true,
          variant: PhotoSheetVariant.multi,
          checked: {0, 1},
          selected: 2,
        );
        await _settle(tester);
        expect(find.text('공유 2'), findsOneWidget);
        final share = tester.widget<SolidButton>(
          find.byKey(PhotoSheet.shareKey),
        );
        expect(share.variant, SolidButtonVariant.defaultVariant);
        final r = tester.getRect(find.byKey(PhotoSheet.shareKey));
        expect(r.right, closeTo(8 + 386 - 12, 0.01));
        expect(r.top, closeTo(197 + 12, 0.01));
        expect(r.height, 46);
      },
    );

    testWidgets(
      '헤더를 아래로 끌기: 조금 = 제자리 · 반 이상 = onClose · 그리드 맨 위에서 아래로 = 시트가 따라 내려온다',
      (tester) async {
        final log = <String>[];
        await pumpSheet(tester, open: true, log: log);
        await _settle(tester);
        final sheet = tester.state<PhotoSheetState>(find.byType(PhotoSheet));
        final g = await tester.startGesture(
          tester.getCenter(find.byKey(PhotoSheet.headerKey)),
        );
        for (var i = 0; i < 5; i++) {
          await g.moveBy(const Offset(0, 20));
          await tester.pump(_frame);
        }
        expect(sheet.offset, closeTo(100, 0.01));
        await g.up();
        await _settle(tester);
        expect(sheet.offset, 0);
        final g2 = await tester.startGesture(const Offset(200, 520));
        for (var i = 0; i < 10; i++) {
          await g2.moveBy(const Offset(0, 20));
          await tester.pump(_frame);
        }
        expect(sheet.offset, greaterThan(100));
        await g2.up();
        await _settle(tester);
        expect(sheet.offset, 0);
        expect(log.where((l) => l == 'close'), isEmpty);
        await tester.timedDrag(
          find.byKey(PhotoSheet.headerKey),
          const Offset(0, 320),
          const Duration(seconds: 1),
        );
        await tester.pump(_frame);
        expect(log.last, 'close');
      },
    );
  });

  group('CapturedCard v6 (통화.사진 오버레이 2295:15479)', () {
    CapturedCardItem item(String key, double w, double h, {Duration? video}) =>
        CapturedCardItem(
          key: key,
          image: AssetImage(labInCallV5.capturedCard.image),
          width: w,
          height: h,
          video: video,
        );

    testWidgets(
      '등장: bottom-nav 뒤 (y 770 에서 잘림) 에서 올라오며 0.85 → 1 (chewy) · 제자리 (27.75, 308) 346.5 × 462 · 닫기 light scrim md 46 @ (38, 318) · 닫힘 → onHidden',
      (tester) async {
        var shown = 0;
        var hidden = 0;
        var closes = 0;
        Future<void> build(bool visible) => _pump(tester, [
          Positioned.fill(
            child: CapturedCard(
              items: [item('a', 1179, 1572)],
              visible: visible,
              onClose: () => closes++,
              onShown: () => shown++,
              onHidden: () => hidden++,
            ),
          ),
        ]);
        await build(true);
        final state = tester.state<CapturedCardState>(
          find.byType(CapturedCard),
        );
        expect(
          tester.getRect(find.byType(ClipRect).first),
          const Rect.fromLTWH(0, 0, 402, 770),
        );
        await tester.pump(const Duration(milliseconds: 50));
        final early = tester.getRect(find.byKey(CapturedCard.photoKey));
        expect(early.top, greaterThan(308));
        expect(early.bottom, greaterThan(770));
        var maxP = 0.0;
        for (var i = 0; i < 90; i++) {
          await tester.pump(_frame);
          if (state.progress > maxP) maxP = state.progress;
        }
        expect(maxP, greaterThan(1));
        expect(state.progress, 1);
        expect(shown, 1);
        _rectClose(
          tester.getRect(find.byKey(CapturedCard.photoKey)),
          const Rect.fromLTWH(27.75, 308, 346.5, 462),
        );
        _rectClose(
          tester.getRect(find.byKey(CapturedCard.closeKey)),
          const Rect.fromLTWH(38, 318, 46, 46),
        );
        expect(
          tester.widget<ScrimButton>(find.byKey(CapturedCard.closeKey)).tone,
          ScrimButtonTone.light,
        );
        _expectNoOpacityOverGlass(tester);
        await tester.tap(find.byKey(CapturedCard.closeKey));
        expect(closes, 1);
        await build(false);
        await _settle(tester);
        expect(state.progress, 0);
        expect(hidden, 1);
      },
    );

    testWidgets(
      '가로 → 4:3 346.5 × 259.875 아래 기준 (top 510.125) · 여러 장 → 넘김 + 점 · 동영상 → light sm 배지 38 (오른쪽 위 거울 자리)',
      (tester) async {
        await _pump(tester, [
          Positioned.fill(
            child: CapturedCard(
              items: [item('a', 640, 480), item('b', 480, 640)],
              visible: true,
              appearInstantly: true,
              onClose: () {},
            ),
          ),
        ]);
        await tester.pump();
        _rectClose(
          tester.getRect(find.byKey(CapturedCard.photoKey)),
          const Rect.fromLTWH(27.75, 510.125, 346.5, 259.875),
        );
        expect(find.byKey(CapturedCard.pagesKey), findsOneWidget);
        await _pump(tester, [
          Positioned.fill(
            child: CapturedCard(
              key: const ValueKey('video'),
              items: [item('v', 480, 640, video: const Duration(seconds: 7))],
              visible: true,
              appearInstantly: true,
              onClose: () {},
            ),
          ),
        ]);
        await tester.pump();
        expect(find.text('0:07'), findsOneWidget);
        final badge = tester.getRect(find.byKey(CapturedCard.badgeKey));
        expect(badge.right, closeTo(27.75 + 346.5 - 10.25, 0.01));
        expect(badge.top, closeTo(308 + 10, 0.01));
        expect(badge.height, 38);
        final glass = tester.widget<GlassSurface>(
          find.descendant(
            of: find.byKey(CapturedCard.badgeKey),
            matching: find.byType(GlassSurface),
          ),
        );
        expect(glass.tint, light.backgroundFillScrimBase);
        expect(
          _iconColor(tester, find.byKey(CapturedCard.badgeKey)),
          light.foregroundNeutralBase,
        );
      },
    );
  });

  group('AodV6 (AOD 2295:16742)', () {
    testWidgets(
      '잠듦: dim 1.2 s easing.standard 0 → 1 · ui 스프링 · 버튼 스프링 (24 아래에서) → onSettled(true) 한 번 · 종료: dim 400 ms · ui chewy → onSettled(false) · 버튼 = dark solid lg (흰 채움 · 검정 내용) @ 774 · 잠든 동안만 누름',
      (tester) async {
        final settled = <bool>[];
        var ends = 0;
        await _pump(tester, [
          Positioned.fill(
            child: _AodHarness(onSettled: settled.add, onEnd: () => ends++),
          ),
        ]);
        final harness = tester.state<_AodHarnessState>(
          find.byType(_AodHarness),
        );
        final p = harness.progress;
        expect((p.dim.value, p.ui.value, p.button.value), (0.0, 0.0, 0.0));

        expect(find.byKey(AodV6EndButton.buttonKey), findsNothing);
        harness.setAsleep(true);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        expect(
          p.dim.value,
          closeTo(aodOverlayAt(const Duration(milliseconds: 600)), 0.03),
        );
        await tester.pump(const Duration(milliseconds: 700));
        expect(p.dim.value, 1);
        await _settle(tester);
        expect(p.ui.value, 1);
        expect(p.button.value, 1);
        expect(settled, [true]);
        final dim = tester.widget<ColoredBox>(
          find.descendant(
            of: find.byKey(AodV6Dim.layerKey),
            matching: find.byType(ColoredBox),
          ),
        );
        expect(dim.color, dark.dimScrim);
        final button = tester.getRect(find.byKey(AodV6EndButton.buttonKey));
        expect(button.top, 774);
        expect(button.height, 54);
        expect(button.center.dx, closeTo(201, 0.01));
        expect(find.text(labV6.call.sleepEnd.label), findsOneWidget);
        final colors = solidButtonColors(
          CameoPalette.dark,
          SolidButtonVariant.defaultVariant,
        );
        expect(colors.fill, dark.backgroundFillNeutralInverted);
        expect(colors.content, dark.foregroundInvertedBase);
        await tester.tap(find.byKey(AodV6EndButton.buttonKey));
        expect(ends, 1);
        harness.setAsleep(false);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 420));
        expect(p.dim.value, 0);
        await _settle(tester);
        expect(p.ui.value, closeTo(0, 1e-3));
        expect(p.button.value, closeTo(0, 1e-3));
        expect(settled, [true, false]);
      },
    );

    testWidgets('모션 감소: 즉시 + onSettled 바로', (tester) async {
      final settled = <bool>[];
      await _pump(tester, [
        Positioned.fill(
          child: _AodHarness(onSettled: settled.add, onEnd: () {}),
        ),
      ], reduceMotion: true);
      final harness = tester.state<_AodHarnessState>(find.byType(_AodHarness));
      harness.setAsleep(true);
      await tester.pump();
      expect(harness.progress.dim.value, 1);
      expect(harness.progress.ui.value, 1);
      expect(settled, [true]);
    });
  });

  group('ReviewOverlay (전송 2295:16034)', () {
    const photo = ReviewPhoto(
      key: 'r1',
      image: AssetImage(LabImages.cameraViewfinderV5),
    );

    Future<List<String>> pumpReview(
      WidgetTester tester,
      ReviewPhase phase, {
      List<String>? log,
    }) async {
      final events = log ?? <String>[];
      await _pump(tester, [
        Positioned.fill(
          child: ReviewOverlay(
            key: const ValueKey('review'),
            photo: photo,
            phase: phase,
            onSend: () => events.add('send'),
            onDiscard: () => events.add('discard'),
            onEntered: () => events.add('entered'),
            onLanded: () => events.add('landed'),
            onExited: () => events.add('exited'),
          ),
        ),
      ]);
      return events;
    }

    testWidgets(
      '검토: dim/scrim (0 → 1, 250 ms) · 사진 = 뷰파인더 rect (4, 66) 394 × 700.44 · 동작 행 784: trash light scrim md @ 16 · send 흰 원 46 @ 340 (arrow-up 검정) · 등장이 멈추면 onEntered · 버튼 → 콜백',
      (tester) async {
        final log = await pumpReview(tester, ReviewPhase.review);
        final state = tester.state<ReviewOverlayState>(
          find.byType(ReviewOverlay),
        );
        expect(state.dim, 0);
        await tester.pump(const Duration(milliseconds: 125));
        expect(state.dim, inExclusiveRange(0, 1));
        await _settle(tester);
        expect(state.dim, 1);
        expect(log, ['entered']);
        _rectClose(
          tester.getRect(find.byKey(ReviewOverlay.photoKey)),
          const Rect.fromLTWH(4, 66, 394, 700.444444),
        );
        expect(
          tester.getRect(find.byKey(ReviewOverlay.discardKey)),
          const Rect.fromLTWH(16, 784, 46, 46),
        );
        expect(
          tester.getRect(find.byKey(ReviewOverlay.sendKey)),
          const Rect.fromLTWH(340, 784, 46, 46),
        );
        expect(
          tester.widget<ScrimButton>(find.byKey(ReviewOverlay.discardKey)).tone,
          ScrimButtonTone.light,
        );
        final send = tester.widget<DecoratedBox>(
          find
              .descendant(
                of: find.byKey(ReviewOverlay.sendKey),
                matching: find.byWidgetPredicate(
                  (widget) =>
                      widget is DecoratedBox &&
                      widget.decoration is BoxDecoration &&
                      (widget.decoration as BoxDecoration).shape ==
                          BoxShape.circle,
                ),
              )
              .first,
        );
        expect((send.decoration as BoxDecoration).color, dark.staticWhiteBase);
        final arrow = tester.widget<CameoIcon>(
          find.descendant(
            of: find.byKey(ReviewOverlay.sendKey),
            matching: find.byType(CameoIcon),
          ),
        );
        expect(arrow.name, CameoIconName.arrowUp);
        expect(arrow.color, dark.staticBlackBase);
        final dim = tester.widget<ColoredBox>(
          find.descendant(
            of: find.byKey(ReviewOverlay.dimKey),
            matching: find.byType(ColoredBox),
          ),
        );
        expect(dim.color, dark.dimScrim);
        expect(find.byType(BackdropFilter), findsOneWidget);
        await tester.tap(find.byKey(ReviewOverlay.discardKey));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.byKey(ReviewOverlay.sendKey));
        await tester.pump(const Duration(milliseconds: 300));
        expect(log, ['entered', 'discard', 'send']);
        _expectNoOpacityOverGlass(tester);
      },
    );

    testWidgets(
      'send: 사진이 썸네일 가운데로 (sendSpring chewy) 0.15 까지 → 처음 닿을 때 onLanded → 사진 페이드 · dim · 동작 행 끝 → onExited (한 번)',
      (tester) async {
        final log = await pumpReview(tester, ReviewPhase.review);
        await _settle(tester);
        await pumpReview(tester, ReviewPhase.send, log: log);
        final state = tester.state<ReviewOverlayState>(
          find.byType(ReviewOverlay),
        );
        await tester.pump(const Duration(milliseconds: 60));
        expect(state.fly, inExclusiveRange(0, 1));
        expect(log, ['entered']);
        await _settle(tester, 150);
        expect(state.landed, isTrue);
        expect(log, ['entered', 'landed', 'exited']);
        expect(state.dim, 0);
        final photo = tester.getRect(find.byKey(ReviewOverlay.photoKey));
        expect(
          photo.center.dx,
          closeTo(cameraThumbnailRect(874).center.dx, 0.5),
        );
        expect(
          photo.center.dy,
          closeTo(cameraThumbnailRect(874).center.dy, 0.5),
        );
        expect(photo.width, closeTo(394 * 0.15, 0.5));
      },
    );

    testWidgets(
      'discard: 사진이 0.9 로 줄며 사라지고 dim · 동작 행이 걷히면 onExited (착지 없음) · 떠나는 동안 터치는 통과',
      (tester) async {
        final log = await pumpReview(tester, ReviewPhase.review);
        await _settle(tester);
        await pumpReview(tester, ReviewPhase.discard, log: log);
        final ignore = tester.widget<IgnorePointer>(
          find.byKey(ReviewOverlay.rootKey),
        );
        expect(ignore.ignoring, isTrue);
        await _settle(tester);
        expect(log, ['entered', 'exited']);
      },
    );
  });

  group('TabBarThumbnail (카메라 썸네일 2295:15976 — 팝 층)', () {
    testWidgets(
      '54 · 테두리 1.5 · 처음 키는 튀지 않는다 · 새 popKey = 새 층이 0 → 1 (heartPop) · 이전 사진은 밑에 남았다가 팝이 멈추면 치움 + onPopSettled · 동영상 글리프 · 같은 키 = 그냥 바꿈',
      (tester) async {
        var settled = 0;
        Future<void> build(String key, String image, {bool video = false}) =>
            _pump(tester, [
              Positioned(
                left: 16,
                top: 785,
                child: TabBarThumbnail(
                  image: AssetImage(image),
                  popKey: key,
                  video: video,
                  onPopSettled: () => settled++,
                  semanticLabel: '마지막 사진 보기',
                ),
              ),
            ]);
        await build('a', LabImages.albumSungsuGridR5c4Hires);
        final state = tester.state<TabBarThumbnailState>(
          find.byType(TabBarThumbnail),
        );
        expect(
          tester.getRect(find.byType(TabBarThumbnail)),
          const Rect.fromLTWH(16, 785, 54, 54),
        );
        expect(state.popScale, 1);
        expect(find.byType(Image), findsOneWidget);
        await build('b', LabImages.cameraViewfinderV5, video: true);
        await tester.pump(_frame);
        expect(state.hasBelow, isTrue);
        expect(find.byType(Image), findsNWidgets(2));
        expect(state.popScale, lessThan(1));
        await _settle(tester, 90);
        expect(state.hasBelow, isFalse);
        expect(find.byType(Image), findsOneWidget);
        expect(settled, 1);
        expect(find.byKey(TabBarThumbnail.videoKey), findsOneWidget);
        await build('b', LabImages.albumSungsuGridR5c4Hires);
        await tester.pump(_frame);
        expect(state.hasBelow, isFalse);
        expect(settled, 1);
      },
    );
  });
}

class _AodHarness extends StatefulWidget {
  const _AodHarness({required this.onSettled, required this.onEnd});

  final ValueChanged<bool> onSettled;
  final VoidCallback onEnd;

  @override
  State<_AodHarness> createState() => _AodHarnessState();
}

class _AodHarnessState extends State<_AodHarness>
    with TickerProviderStateMixin {
  late final AodV6Progress progress = AodV6Progress(
    vsync: this,
    onSettled: widget.onSettled,
  );
  bool _asleep = false;

  void setAsleep(bool asleep) {
    setState(() => _asleep = asleep);
    progress.update(
      asleep,
      reduceMotion: MediaQuery.maybeDisableAnimationsOf(context) ?? false,
    );
  }

  @override
  void dispose() {
    progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      AodV6Dim(dim: progress.dim),
      AodV6EndButton(
        button: progress.button,
        asleep: _asleep,
        onEnd: widget.onEnd,
      ),
    ],
  );
}
