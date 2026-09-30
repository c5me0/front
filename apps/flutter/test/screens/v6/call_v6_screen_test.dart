// Regression coverage for call v6 screen. Preserve behavior, layout, and interaction
// expectations.

import 'package:cameo/components/aod_v6.dart';
import 'package:cameo/components/call_bar_v6.dart';
import 'package:cameo/components/caller_block.dart' show ExactLineBox;
import 'package:cameo/components/captured_card.dart';
import 'package:cameo/components/photo_sheet.dart';
import 'package:cameo/components/scrim_button.dart';
import 'package:cameo/components/toast_v6.dart';
import 'package:cameo/components/volume_slider.dart';
import 'package:cameo/content/lab.g.dart';
import 'package:cameo/design_system/design_system.dart';
import 'package:cameo/navigation/navigation.dart';
import 'package:cameo/screens/call/call_entrance.dart';
import 'package:cameo/screens/call/call_screen.dart';
import 'package:cameo/screens/camera_v6/camera_v6_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

import '../../navigation/app_harness.dart';

CallScreenState _call(WidgetTester tester) =>
    tester.state<CallScreenState>(find.byType(CallScreen, skipOffstage: false));

Future<void> _open(WidgetTester tester, String query) =>
    pumpCameoApp(tester, '/call?session=member$query', size: kIPhone17Pro);

Future<void> _frames(WidgetTester tester, Duration total) async {
  var t = Duration.zero;
  while (t < total) {
    await tester.pump(kFrame);
    t += kFrame;
  }
}

Future<void> _tapSlot(WidgetTester tester, CallBarSlot slot) async {
  await tester.tap(find.byKey(CallBarV6.slotKey(slot)));
  await tester.pump();
}

Color _slotIcon(WidgetTester tester, CallBarSlot slot) => tester
    .widget<CameoIcon>(
      find.descendant(
        of: find.byKey(CallBarV6.slotKey(slot)),
        matching: find.byType(CameoIcon),
      ),
    )
    .color!;

void _expectNoFadeOverGlass(WidgetTester tester) {
  for (final e in find.byType(LiquidGlass).evaluate()) {
    e.visitAncestorElements((a) {
      final w = a.widget;
      if (w is Opacity) expect(w.opacity, 1, reason: '글래스 조상 Opacity');
      return true;
    });
  }
}

void main() {
  const dark = CameoPalette.dark;
  const light = CameoPalette.light;

  setUp(() {
    FlowDemo.resetForTesting();
    ViewerSource.clear();
  });
  tearDown(FlowDemo.resetForTesting);

  testWidgets(
    '기하 (2295:15614 @ 402 × 874): 바탕 canvas + 사진 20 % + callBackgroundV6 · 내비 light scrim md 46 @ (16, 62) / (340, 62) · Yurim 118–207.6 · 00:04 207.6–233.6 · 바 (16, 782) 370 × 58 · 슬롯 선택 없음 · 타이머가 흐른다',
    (tester) async {
      await _open(tester, '');
      final root = tester.widget<ColoredBox>(find.byKey(CallScreen.rootKey));
      expect(root.color, dark.backgroundCanvasBase);
      final photoOpacity = tester.widget<Opacity>(
        find
            .descendant(
              of: find.byKey(CallScreen.backgroundKey),
              matching: find.byType(Opacity),
            )
            .first,
      );
      expect(photoOpacity.opacity, CameoLayout.callV6BackgroundPhotoOpacity);
      final gradient =
          (tester
                      .widget<DecoratedBox>(find.byKey(CallScreen.gradientKey))
                      .decoration
                  as BoxDecoration)
              .gradient;
      expect(gradient, dark.gradients.callBackgroundV6);
      expect(
        tester.getRect(find.byKey(CallScreen.minimizeKey)),
        const Rect.fromLTWH(16, 62, 46, 46),
      );
      expect(
        tester.getRect(find.byKey(CallScreen.moonKey)),
        const Rect.fromLTWH(340, 62, 46, 46),
      );
      for (final k in [CallScreen.minimizeKey, CallScreen.moonKey]) {
        final b = tester.widget<ScrimButton>(find.byKey(k));
        expect((b.size, b.tone), (ScrimButtonSize.md, ScrimButtonTone.light));
      }
      expect(
        tester.widget<ScrimButton>(find.byKey(CallScreen.minimizeKey)).icon,
        CameoIconName.chevronDown,
      );
      expect(
        tester.widget<ScrimButton>(find.byKey(CallScreen.moonKey)).icon,
        CameoIconName.moon,
      );
      final name = tester.getRect(find.byKey(CallScreen.nameKey));
      expect(name.top, closeTo(118, 0.01));
      expect(name.height, closeTo(89.6, 0.01));
      final timer = tester.getRect(find.byKey(CallScreen.timerKey));
      expect(timer.top, closeTo(207.6, 0.01));
      expect(timer.bottom, closeTo(233.6, 0.01));
      expect(
        tester.getRect(find.byKey(CallBarV6.barKey)),
        const Rect.fromLTWH(16, 782, 370, 58),
      );
      expect(
        tester.getRect(find.byKey(CallBarV6.containerKey)),
        const Rect.fromLTWH(0, 770, 402, 104),
      );
      for (final s in CallBarSlot.values.where((s) => s != CallBarSlot.end)) {
        expect(
          _slotIcon(tester, s),
          dark.foregroundNeutralSubtle,
          reason: s.name,
        );
      }
      expect(find.text('00:04'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('00:06'), findsOneWidget);
      expect(find.byType(VolumeSlider), findsNothing);
      expect(find.byKey(AodV6EndButton.buttonKey), findsNothing);
      _expectNoFadeOverGlass(tester);
      await disposeApp(tester);
    },
  );

  testWidgets(
    '볼륨 (2295:15817): 슬롯 → 슬라이더 pill (76, 714) 250 × 44 · 볼륨 슬롯 = 흰 아이콘 (선택) · 썸 = 시스템 볼륨 · 끌기 → 볼륨 · 하드웨어 반영 · 2.5 s 뒤 숨김 → 대기 아이콘 · 다시 탭 = 닫기',
    (tester) async {
      await _open(tester, '');
      simulatedVolume.simulateHardware(0.5);
      await _tapSlot(tester, CallBarSlot.volume);
      await _frames(tester, const Duration(milliseconds: 1500));
      expect(_call(tester).slider, CallSlider.shown);
      expect(
        tester.getRect(find.byKey(VolumeSlider.pillKey)),
        const Rect.fromLTWH(76, 714, 250, 44),
      );
      expect(_slotIcon(tester, CallBarSlot.volume), dark.foregroundNeutralBase);
      double thumbX() =>
          tester.getRect(find.byKey(VolumeSlider.thumbKey)).center.dx;
      expect(thumbX(), closeTo(93 + 0.5 * 216, 0.01));
      final g = await tester.startGesture(const Offset(93 + 216 * 0.3, 736));
      await tester.pump(kFrame);
      await g.moveTo(const Offset(93 + 216 * 0.25, 736));
      await tester.pump(kFrame);
      expect(simulatedVolume.value, closeTo(0.25, 1e-6));
      await g.up();
      await _frames(tester, const Duration(milliseconds: 400));
      expect(thumbX(), closeTo(93 + 0.25 * 216, 0.01));
      simulatedVolume.simulateHardware(0.8);
      await tester.pump();
      await tester.pump();
      expect(thumbX(), closeTo(93 + 0.8 * 216, 0.01));
      await tester.pump(const Duration(milliseconds: 2000));
      expect(_call(tester).slider, CallSlider.shown);
      await tester.pump(const Duration(milliseconds: 200));
      await _frames(tester, const Duration(milliseconds: 800));
      expect(_call(tester).slider, CallSlider.hidden);
      expect(
        _slotIcon(tester, CallBarSlot.volume),
        dark.foregroundNeutralSubtle,
      );
      await _tapSlot(tester, CallBarSlot.volume);
      await _frames(tester, const Duration(milliseconds: 500));
      expect(_call(tester).slider, CallSlider.shown);
      await _tapSlot(tester, CallBarSlot.volume);
      expect(_call(tester).slider, CallSlider.exiting);
      await _frames(tester, const Duration(milliseconds: 800));
      expect(_call(tester).slider, CallSlider.hidden);
      await disposeApp(tester);
    },
  );

  testWidgets(
    '하이라이트 (2295:15893): rewind-15 → flat 토스트 42 (716–758, 테두리 · 그림자 없음) \'전후 15초 하이라이트가 저장됐어요!\' · ⓘ static/black/base · 보이는 동안 rewind 슬롯 = 흰 아이콘 · 슬라이더는 숨는다 · 햅틱',
    (tester) async {
      await _open(tester, '');
      await _tapSlot(tester, CallBarSlot.volume);
      await _frames(tester, const Duration(milliseconds: 500));
      await _tapSlot(tester, CallBarSlot.highlight);
      await _frames(tester, const Duration(milliseconds: 1500));
      expect(_call(tester).slider, isNot(CallSlider.shown));
      expect(find.text(labV6.call.highlightToast.text), findsOneWidget);
      final icon = tester.widget<CameoIcon>(
        find.descendant(
          of: find.byKey(ToastV6Pill.pillKey),
          matching: find.byType(CameoIcon),
        ),
      );
      expect(icon.name, CameoIconName.infoCircle);
      expect(icon.color, dark.staticBlackBase);
      final pill = tester.getRect(find.byKey(ToastV6Pill.pillKey));
      expect(pill.top, closeTo(716, 0.05));
      expect(pill.height, 42);
      expect(pill.center.dx, closeTo(201, 0.01));
      final deco =
          tester.widget<Container>(find.byKey(ToastV6Pill.pillKey)).decoration
              as BoxDecoration;
      expect(deco.border, isNull);
      expect(deco.boxShadow, isNull);
      expect(
        _slotIcon(tester, CallBarSlot.highlight),
        dark.foregroundNeutralBase,
      );
      expect(_call(tester).barSelected, contains(CallBarSlot.highlight));

      await _frames(tester, const Duration(milliseconds: 2600));
      expect(_call(tester).barSelected, isNot(contains(CallBarSlot.highlight)));
      await disposeApp(tester);
    },
  );

  testWidgets(
    '취침 → AOD v6 (2295:16742): moon → 파트너 토스트 없음 · 볼륨 3 s 선형 → 0.0625 · 밝기 0 · dim/scrim 1.2 s · 바탕 그라데이션 걷힘 · 이름 흰색 그대로 · 내비 −108 · 바 +104 (이동만) · \'취침모드 종료\' @ 774 · AOD 탭 = 아무 일 없음 · 종료 → 밝기 · 볼륨 · 크롬 복원',
    (tester) async {
      await _open(tester, '&state=media-1x1');
      expect(simulatedVolume.value, 1);
      expect(find.byType(CapturedCard), findsOneWidget);
      await tester.tap(find.byKey(CallScreen.moonKey));
      await tester.pump();
      expect(_call(tester).sleep, CallSleep.aod);
      expect(simulatedBrightness.value, 0);
      expect(simulatedVolume.isFading, isTrue);
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text(labInCallV5.toasts.sleep.text), findsNothing);
      expect(_call(tester).barSelected, isNot(contains(CallBarSlot.highlight)));
      await tester.pump(const Duration(milliseconds: 900));
      expect(
        simulatedVolume.value,
        closeTo((1 + CameoMotion.sleepVolumeTarget) / 2, 0.02),
      );
      final dim = tester.widget<Opacity>(find.byKey(AodV6Dim.layerKey));
      expect(dim.opacity, 1);
      expect(
        tester
            .widget<ColoredBox>(
              find.descendant(
                of: find.byKey(AodV6Dim.layerKey),
                matching: find.byType(ColoredBox),
              ),
            )
            .color,
        dark.dimScrim,
      );
      final gradientFade = tester.widget<Opacity>(
        find
            .ancestor(
              of: find.byKey(CallScreen.gradientKey),
              matching: find.byType(Opacity),
            )
            .first,
      );
      expect(gradientFade.opacity, 0);
      await _frames(tester, const Duration(milliseconds: 1600));
      expect(simulatedVolume.value, CameoMotion.sleepVolumeTarget);
      expect(
        tester.getRect(find.byKey(CallScreen.minimizeKey)).top,
        closeTo(62 - 108, 0.5),
      );
      expect(
        tester.getRect(find.byKey(CallBarV6.barKey)).top,
        closeTo(782 + 104, 0.5),
      );

      expect(find.byType(CapturedCard), findsNothing);

      expect(
        tester.widget<ExactLineBox>(find.byKey(CallScreen.nameKey)).color,
        dark.staticWhiteBase,
      );
      expect(
        tester.widget<ExactLineBox>(find.byKey(CallScreen.timerKey)).color,
        dark.staticWhiteMuted,
      );
      final end = tester.getRect(find.byKey(AodV6EndButton.buttonKey));
      expect(end.top, closeTo(774, 0.01));
      expect(end.height, 54);
      expect(end.center.dx, closeTo(201, 0.5));
      expect(find.text(labV6.call.sleepEnd.label), findsOneWidget);
      _expectNoFadeOverGlass(tester);

      await tester.tapAt(const Offset(201, 450));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_call(tester).sleep, CallSleep.aod);
      expect(simulatedBrightness.value, 0);
      await tester.tap(find.byKey(AodV6EndButton.buttonKey));
      await tester.pump();
      expect(_call(tester).sleep, CallSleep.off);
      expect(simulatedBrightness.overridden, isFalse);
      await _frames(tester, const Duration(milliseconds: 1400));
      expect(simulatedVolume.value, 1);
      expect(
        tester.getRect(find.byKey(CallScreen.minimizeKey)).top,
        closeTo(62, 0.01),
      );
      expect(find.byKey(AodV6EndButton.buttonKey), findsNothing);
      expect(
        tester.widget<ScrimButton>(find.byKey(CallScreen.moonKey)).icon,
        CameoIconName.moon,
      );
      await disposeApp(tester);
    },
  );

  testWidgets(
    '사진 시트 A (2295:14936): 카메라 슬롯 → 시트 (8, 197) 386 × 573 light · 카메라 슬롯 = 흰 아이콘 · 실시간 칸 127.33 × 256.67 · 칸 = Figma 순서 · 사진 탭 → 공유함 + 시트 닫힘 + 세로 카드 (27.75, 308) 346.5 × 462 · 다시 열면 체크',
    (tester) async {
      await _open(tester, '&sheet=instant');
      expect(_call(tester).sheetOpen, isTrue);
      await tester.tap(find.byKey(PhotoSheet.closeKey));
      await settleApp(tester);
      expect(_call(tester).sheetOpen, isFalse);
      await _tapSlot(tester, CallBarSlot.camera);
      await settleApp(tester);
      expect(_call(tester).sheetOpen, isTrue);
      expect(
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
      expect(_slotIcon(tester, CallBarSlot.camera), dark.foregroundNeutralBase);
      final live = tester.getRect(find.byKey(PhotoSheet.liveKey));
      expect(live.topLeft, const Offset(8, 267));
      expect(live.width, closeTo(127.333, 0.001));
      expect(live.height, closeTo(256.667, 0.001));
      Image cellImage(int i) => tester.widget<Image>(
        find.descendant(
          of: find.byKey(PhotoSheet.cellKey(i)),
          matching: find.byType(Image),
        ),
      );
      final order = sheetPhotosOf(lastAlbum);
      final figma = [for (final p in labInCallV5.photoSheet.photos) p.image];
      for (var i = 0; i < 3; i++) {
        expect(order[i].image, figma[i], reason: '칸 $i');
        expect(cellImage(i).image, AssetImage(figma[i]), reason: '칸 $i');
      }
      final r3c2 = order.indexWhere(
        (p) => p.image == LabImages.albumSungsuGridR3c2,
      );
      State barEntrance() => tester.state(
        find.ancestor(
          of: find.byKey(CallBarV6.slotKey(CallBarSlot.camera)),
          matching: find.byType(CallEntrance),
        ),
      );
      State sheetState() => tester.state(find.byType(PhotoSheet));
      final bar0 = barEntrance();
      final sheet0 = sheetState();

      await tester.tap(find.byKey(PhotoSheet.cellKey(r3c2)));
      await tester.pump();
      expect(_call(tester).sheetOpen, isFalse);
      expect(identical(barEntrance(), bar0), isTrue);
      expect(identical(sheetState(), sheet0), isTrue);
      final shared = lastAlbum.photoByImage(LabImages.albumSungsuGridR3c2)!;
      expect(shared.shared, isTrue);
      expect(_call(tester).cardItems.single.key, shared.id);
      await settleApp(tester);
      final card = tester.getRect(find.byKey(CapturedCard.photoKey));
      expect(card.left, closeTo(27.75, 0.01));
      expect(card.top, closeTo(308, 0.01));
      expect(card.width, closeTo(346.5, 0.01));
      expect(card.height, closeTo(462, 0.01));
      expect(
        tester.getRect(find.byKey(CapturedCard.closeKey)).topLeft,
        const Offset(38, 318),
      );
      await _tapSlot(tester, CallBarSlot.camera);
      await settleApp(tester);
      final dim = tester.widget<AnimatedOpacity>(
        find.descendant(
          of: find.byKey(PhotoSheet.cellKey(r3c2)),
          matching: find.byType(AnimatedOpacity),
        ),
      );
      expect(dim.opacity, CameoLayout.controlSelectedImageOpacity);
      await tester.tapAt(const Offset(201, 150));
      await settleApp(tester);
      expect(_call(tester).sheetOpen, isFalse);
      expect(
        _slotIcon(tester, CallBarSlot.camera),
        dark.foregroundNeutralSubtle,
      );
      await tester.tap(find.byKey(CapturedCard.closeKey));
      await settleApp(tester);
      expect(find.byType(CapturedCard), findsNothing);
      expect(identical(barEntrance(), bar0), isTrue);
      expect(identical(sheetState(), sheet0), isTrue);
      await disposeApp(tester);
    },
  );

  testWidgets(
    '사진 시트 B (multi 딥링크): Figma 에서 골라진 두 칸 · \'공유 2\' (solid default 검정) · 한 장 더 → \'공유 3\' · 공유 → 여러 장 카드 (넘김 + 점)',
    (tester) async {
      await _open(tester, '&sheet=multi');
      final call = _call(tester);
      expect(call.sheetOpen, isTrue);
      expect(call.picked, hasLength(2));
      expect(find.text('공유 2'), findsOneWidget);
      await tester.tap(find.byKey(PhotoSheet.cellKey(2)));
      await settleApp(tester);
      expect(find.text('공유 3'), findsOneWidget);
      await tester.tap(find.byKey(PhotoSheet.shareKey));
      await settleApp(tester);
      expect(call.sheetOpen, isFalse);
      expect(call.cardItems, hasLength(3));
      expect(find.byKey(CapturedCard.pagesKey), findsOneWidget);
      await disposeApp(tester);
    },
  );

  testWidgets(
    '실시간 칸 → 카메라 v6 (통화 모드 — 검토 없음, F13) → 셔터 → 통화로 돌아와 카드 (시뮬레이터 = 뷰파인더 placeholder)',
    (tester) async {
      await _open(tester, '');
      await _tapSlot(tester, CallBarSlot.camera);
      await settleApp(tester);
      await tester.tap(find.byKey(PhotoSheet.liveKey));
      await settleApp(tester);
      final camera = tester.widget<CameraV6Screen>(find.byType(CameraV6Screen));
      expect(camera.mode, CameraV6Mode.call);
      expect(_call(tester).sheetOpen, isFalse);
      await tester.tap(find.byKey(CameraV6Screen.shutterKey));
      await settleApp(tester);
      expect(find.byType(CameraV6Screen), findsNothing);
      final card = tester.widget<CapturedCard>(find.byType(CapturedCard));
      expect(card.visible, isTrue);
      expect(card.items.single.image, AssetImage(labV6.camera.viewfinder));
      await disposeApp(tester);
    },
  );

  testWidgets(
    '딥링크: media-16x9 = 세로 카드 (Figma 5c375, 아래 770) · media-4x3 = 가로 346.5 × 259.875 @ top 510.125 · volume = 슬라이더 고정 (자동 숨김 없음) · highlight = 토스트 고정 · aod = 진입 뒤 AOD',
    (tester) async {
      await _open(tester, '&state=media-16x9');
      var card = tester.widget<CapturedCard>(find.byType(CapturedCard));
      expect(
        card.items.single.image,
        AssetImage(labInCallV5.capturedCard.image),
      );
      var rect = tester.getRect(find.byKey(CapturedCard.photoKey));
      expect(rect.height, closeTo(462, 0.01));
      expect(rect.bottom, closeTo(770, 0.01));
      await disposeApp(tester);
      await _open(tester, '&state=media-4x3');
      card = tester.widget<CapturedCard>(find.byType(CapturedCard));
      expect(
        card.items.single.image,
        AssetImage(LabImages.albumSungsuGridR2c2),
      );
      rect = tester.getRect(find.byKey(CapturedCard.photoKey));
      expect(rect.top, closeTo(510.125, 0.01));
      expect(rect.width, closeTo(346.5, 0.01));
      expect(rect.height, closeTo(259.875, 0.01));
      await disposeApp(tester);
      await _open(tester, '&state=volume');
      await _frames(tester, const Duration(milliseconds: 600));
      expect(_call(tester).slider, CallSlider.shown);
      await _frames(tester, const Duration(milliseconds: 3500));
      expect(_call(tester).slider, CallSlider.shown);
      expect(_slotIcon(tester, CallBarSlot.volume), dark.foregroundNeutralBase);
      await disposeApp(tester);
      await _open(tester, '&state=highlight');
      await _frames(tester, const Duration(milliseconds: 3500));
      expect(find.text(labV6.call.highlightToast.text), findsOneWidget);
      expect(
        _slotIcon(tester, CallBarSlot.highlight),
        dark.foregroundNeutralBase,
      );
      await disposeApp(tester);
      await _open(tester, '&state=aod');
      await _frames(tester, const Duration(milliseconds: 2500));
      expect(_call(tester).aod, isTrue);
      expect(find.byKey(AodV6EndButton.buttonKey), findsOneWidget);
      expect(simulatedBrightness.value, 0);
      await disposeApp(tester);
    },
  );

  testWidgets(
    '흐름 데모 동작 (탭과 같은 핸들러 · settle): call.volume · call.highlight · call.camera · call.closeCard · call.sleep (AOD 진행 멈춤) · aod.end (복원 멈춤) · call.endCall',
    (tester) async {
      await _open(tester, '&state=media-1x1');
      Future<void> runUntilSettled(FlowDemoAction action) async {
        final before = FlowDemo.settleCount(action);
        expect(FlowDemo.run(action), isTrue, reason: action.id);
        for (var i = 0; i < 400; i++) {
          await tester.pump(kFrame);
          if (FlowDemo.settleCount(action) > before) return;
        }
        fail('${action.id} settle 없음');
      }

      await runUntilSettled(FlowDemoAction.callVolume);
      expect(simulatedVolume.writes, isNotEmpty);
      expect(_call(tester).slider, CallSlider.shown);
      await runUntilSettled(FlowDemoAction.callHighlight);
      await runUntilSettled(FlowDemoAction.callCamera);
      expect(_call(tester).sheetOpen, isTrue);
      expect(FlowDemo.run(FlowDemoAction.callCamera), isFalse);
      await tester.tap(find.byKey(PhotoSheet.closeKey));
      await settleApp(tester);
      await runUntilSettled(FlowDemoAction.callCloseCard);
      expect(find.byType(CapturedCard), findsNothing);
      await runUntilSettled(FlowDemoAction.callCloseCard);
      expect(FlowDemo.run(FlowDemoAction.aodEnd), isFalse);
      await runUntilSettled(FlowDemoAction.callSleep);
      final aod = _call(tester).aodProgress;
      expect((aod.dim.value, aod.ui.value), (1.0, 1.0));
      expect(FlowDemo.run(FlowDemoAction.callSleep), isFalse);
      await runUntilSettled(FlowDemoAction.aodEnd);
      expect(_call(tester).sleep, CallSleep.off);
      expect((aod.dim.value, aod.ui.value), (0.0, 0.0));
      expect(simulatedBrightness.overridden, isFalse);
      expect(FlowDemo.run(FlowDemoAction.callEndCall), isTrue);
      await settleApp(tester);
      expect(find.byType(CallScreen), findsNothing);
      await disposeApp(tester);
    },
  );

  testWidgets('잠든 채 닫히면 (라우트 닫기) 밝기 · 볼륨을 되돌린다', (tester) async {
    await _open(tester, '');
    simulatedVolume.simulateHardware(0.7);
    await tester.tap(find.byKey(CallScreen.moonKey));
    await tester.pump(const Duration(milliseconds: 500));
    expect(simulatedBrightness.value, 0);
    expect(FlowDemo.run(FlowDemoAction.back), isTrue);
    await settleApp(tester);
    expect(find.byType(CallScreen), findsNothing);
    expect(simulatedBrightness.overridden, isFalse);
    expect(simulatedVolume.value, 0.7);
    await disposeApp(tester);
  });

  testWidgets(
    '?demo=1 (callDemoV6): 슬라이더 (1.5 s) → 하이라이트 (5 s) → 시트 (8 s) → 사진 (9.5 s, 카드) → 카드 닫기 (13.5 s) → 취침 (15 s) → 취침모드 종료 (20 s)',
    (tester) async {
      await _open(tester, '&demo=1');
      final call = _call(tester);
      await tester.pump(const Duration(milliseconds: 1600));
      expect(call.slider, CallSlider.shown);
      await tester.pump(const Duration(milliseconds: 3500)); // 5.1 s
      expect(find.text(labV6.call.highlightToast.text), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 3000)); // 8.1 s
      expect(call.sheetOpen, isTrue);
      await tester.pump(const Duration(milliseconds: 1500)); // 9.6 s
      expect(call.sheetOpen, isFalse);
      expect(
        call.cardItems.single.image,
        AssetImage(LabImages.albumSungsuGridR3c2),
      );
      await _frames(tester, const Duration(milliseconds: 4000)); // 13.6 s
      expect(call.cardVisible, isFalse);
      await tester.pump(const Duration(milliseconds: 1500)); // 15.1 s
      expect(call.sleep, CallSleep.aod);
      await tester.pump(const Duration(milliseconds: 5000)); // 20.1 s
      expect(call.sleep, CallSleep.off);
      await disposeApp(tester);
    },
  );
}
