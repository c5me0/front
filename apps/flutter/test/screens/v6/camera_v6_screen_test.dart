// Regression coverage for camera v6 screen. Preserve behavior, layout, and interaction
// expectations.

import 'package:cameo/components/camera_viewfinder.dart';
import 'package:cameo/components/review_overlay.dart';
import 'package:cameo/components/shot.dart';
import 'package:cameo/components/tab_bar_v6.dart';
import 'package:cameo/components/toast_v6.dart';
import 'package:cameo/content/lab.g.dart';
import 'package:cameo/design_system/design_system.dart';
import 'package:cameo/navigation/navigation.dart';
import 'package:cameo/screens/camera_v6/camera_v6_screen.dart';
import 'package:cameo/screens/instant_viewer/instant_subject.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

import '../../navigation/app_harness.dart';

CameraV6ScreenState _camera(WidgetTester tester) =>
    tester.state<CameraV6ScreenState>(find.byType(CameraV6Screen).first);

Future<void> _open(
  WidgetTester tester,
  String route, {
  bool settle = true,
}) async {
  await pumpCameoApp(tester, route, size: kIPhone17Pro, settle: settle);
  if (!settle) {
    await settleApp(tester, quiet: const Duration(milliseconds: 300));
  }
}

Future<void> _frames(WidgetTester tester, Duration total) async {
  var t = Duration.zero;
  while (t < total) {
    await tester.pump(kFrame);
    t += kFrame;
  }
}

Future<void> _shoot(WidgetTester tester) async {
  await tester.tap(find.byKey(CameraV6Screen.shutterKey));
  await tester.pump();
  await _frames(tester, const Duration(milliseconds: 1200));
}

void main() {
  const dark = CameoPalette.dark;

  setUp(() {
    FlowDemo.resetForTesting();
    ViewerSource.clear();
    resetInstantSubject();
  });
  tearDown(FlowDemo.resetForTesting);

  testWidgets(
    '기하 (2295:15973 @ 402 × 874): 바탕 사진 + dim/scrim · 뷰파인더 9:16 (4, 66) 394 × 700.44 r26 (placeholder — 카메라 없음) · 셔터 (201, 704) · 탭바 = camera 변형 (썸네일 (16, 785) 54 · pill (78, 784) 246 × 56 · 전환 (332, 785)) · 글래스 페이드 없음',
    (tester) async {
      await _open(tester, '/capture?session=member', settle: false);

      await _frames(tester, const Duration(milliseconds: 1200));
      final vf = tester.getRect(find.byKey(CameraV6Screen.viewfinderKey));
      expect(vf.left, 4);
      expect(vf.top, 66);
      expect(vf.width, 394);
      expect(vf.height, closeTo(700.444, 0.001));
      final viewfinder = tester.widget<CameraViewfinder>(
        find.byType(CameraViewfinder),
      );
      expect(viewfinder.radius, CameoLayout.cameraV6ViewfinderRadius);
      expect(viewfinder.placeholder, labV6.camera.viewfinder);
      expect(find.byKey(CameraViewfinder.placeholderKey), findsOneWidget);
      final dim = tester.widgetList<ColoredBox>(find.byType(ColoredBox));
      expect(dim.any((b) => b.color == dark.dimScrim), isTrue);
      expect(tester.getCenter(find.byKey(Shot.discKey)).dx, closeTo(201, 0.01));
      expect(tester.getCenter(find.byKey(Shot.discKey)).dy, closeTo(704, 0.01));
      final tabs = appTabs(tester)!;
      expect(tabs.tabBarVariant, TabBarV6Variant.camera);
      expect(tabs.tabBarHidden, isFalse);
      expect(
        tester.getRect(find.byKey(CameraV6Screen.thumbnailKey)),
        const Rect.fromLTWH(16, 785, 54, 54),
      );
      expect(
        tester.getRect(find.byKey(TabBarV6.pillKey)),
        const Rect.fromLTWH(78, 784, 246, 56),
      );
      expect(
        tester.getRect(find.byKey(TabBarV6.buttonKey)),
        const Rect.fromLTWH(332, 785, 54, 54),
      );
      expect(_camera(tester).thumbnailKey, 'partner-0'); // Figma 54c8c
      expect(find.byType(ReviewOverlay), findsNothing);
      for (final e in find.byType(LiquidGlass).evaluate()) {
        e.visitAncestorElements((a) {
          if (a.widget is Opacity) {
            expect((a.widget as Opacity).opacity, 1);
          }
          return true;
        });
      }
      await disposeApp(tester);
    },
  );

  testWidgets(
    '셔터 → 전송 검토 (2295:16034): 사진이 뷰파인더 자리에 멈춤 · dim/scrim · 탭바는 아래로 숨고 셔터 · 전환 비활성 · send → 오늘 앨범 맨 앞 (누르는 순간) · 탭바 복귀 · 사진이 썸네일로 날아가 착지 → 썸네일 팝',
    (tester) async {
      await _open(tester, '/capture?session=member');
      await _shoot(tester);
      expect(_camera(tester).reviewPhase, ReviewPhase.review);
      final tabs = appTabs(tester)!;
      expect(tabs.tabBarHidden, isTrue);
      expect(tester.widget<Shot>(find.byType(Shot)).disabled, isTrue);
      expect(tabs.tabBarCamera!.flipDisabled, isTrue);
      final photo = tester.getRect(find.byKey(ReviewOverlay.photoKey));
      expect(photo.topLeft, const Offset(4, 66));
      expect(photo.height, closeTo(700.444, 0.001));
      expect(
        tester.getRect(find.byKey(ReviewOverlay.sendKey)),
        const Rect.fromLTWH(340, 784, 46, 46),
      );
      expect(
        tester.getRect(find.byKey(ReviewOverlay.discardKey)),
        const Rect.fromLTWH(16, 784, 46, 46),
      );

      await tester.tapAt(const Offset(201, 704));
      await tester.pump(const Duration(milliseconds: 500));
      expect(lastAlbum.latestCapture, isNull);
      await tester.tap(find.byKey(ReviewOverlay.sendKey));
      await tester.pump();
      final latest = lastAlbum.latestCapture!;
      expect(latest.image, labV6.camera.viewfinder);
      expect(lastAlbum.sections.first.photos.first, latest);
      expect(_camera(tester).reviewPhase, ReviewPhase.send);
      await tester.pump(kFrame);
      expect(tabs.tabBarHidden, isFalse);
      expect(_camera(tester).thumbnailKey, 'partner-0');
      await _frames(tester, const Duration(milliseconds: 2500));
      expect(find.byType(ReviewOverlay), findsNothing);
      expect(_camera(tester).reviewPhase, isNull);
      expect(_camera(tester).thumbnailKey, latest.id);
      expect(
        tester
            .state<TabBarThumbnailState>(find.byType(TabBarThumbnail))
            .hasBelow,
        isFalse,
      );
      expect(tester.widget<Shot>(find.byType(Shot)).disabled, isFalse);
      await disposeApp(tester);
    },
  );

  testWidgets('trash → 버림: 사진이 0.9 로 줄며 사라지고 라이브 카메라로 · 앨범 · 썸네일은 그대로', (
    tester,
  ) async {
    await _open(tester, '/capture?session=member');
    await _shoot(tester);
    expect(_camera(tester).reviewPhase, ReviewPhase.review);
    await tester.tap(find.byKey(ReviewOverlay.discardKey));
    await tester.pump();
    expect(_camera(tester).reviewPhase, ReviewPhase.discard);
    await _frames(tester, const Duration(milliseconds: 1500));
    expect(find.byType(ReviewOverlay), findsNothing);
    expect(lastAlbum.latestCapture, isNull);
    expect(_camera(tester).thumbnailKey, 'partner-0');
    expect(appTabs(tester)!.tabBarHidden, isFalse);
    await disposeApp(tester);
  });

  testWidgets('꾹 = 녹화 (3 s → 링 72°) → 놓으면 포스터 검토 → send → 동영상 (썸네일 재생 글리프)', (
    tester,
  ) async {
    await _open(tester, '/capture?session=member');
    final shot = tester.state<ShotState>(find.byType(Shot));
    final g = await tester.startGesture(
      tester.getCenter(find.byKey(CameraV6Screen.shutterKey)),
    );
    await tester.pump(const Duration(milliseconds: 450));
    expect(shot.recording, isTrue);
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    final ring = tester.widget<CustomPaint>(find.byKey(Shot.ringKey));
    expect(shotRingPainterSweepDeg(ring), closeTo(72, 1.5));
    await g.up();
    await _frames(tester, const Duration(milliseconds: 800));
    expect(_camera(tester).reviewPhase, ReviewPhase.review);
    await tester.tap(find.byKey(ReviewOverlay.sendKey));
    await _frames(tester, const Duration(milliseconds: 2500));
    final latest = lastAlbum.latestCapture!;
    expect(latest.capture!.isVideo, isTrue);
    expect(latest.capture!.videoDuration!.inMilliseconds, closeTo(3000, 60));
    expect(_camera(tester).thumbnailVideo, isTrue);
    expect(find.byKey(TabBarThumbnail.videoKey), findsOneWidget);
    await disposeApp(tester);
  });

  testWidgets(
    '파트너 토스트 (elevated · pill 90) = instantPartnerDelay 뒤 한 번 + 썸네일 팝 (partner-1) · 검토가 뜨면 타이머는 처음부터 · 토스트 전 camera.openShared 거부 · 토스트 → 사진 보기 (파트너 사진)',
    (tester) async {
      await _open(tester, '/capture?session=member', settle: false);
      expect(FlowDemo.run(FlowDemoAction.cameraOpenShared), isFalse);
      await tester.pump(const Duration(milliseconds: 1500));

      await _shoot(tester);
      await tester.tap(find.byKey(ReviewOverlay.discardKey));
      await _frames(tester, const Duration(milliseconds: 1500));
      expect(_camera(tester).partnerShared, isFalse);
      await tester.pump(CameoMotion.instantPartnerDelay);
      await tester.pump(const Duration(milliseconds: 800));
      expect(_camera(tester).partnerShared, isTrue);
      expect(find.text(labV6.camera.partnerToast.text), findsOneWidget);
      final pill = tester.getRect(find.byKey(ToastV6Pill.pillKey));
      expect(pill.top, closeTo(90, 0.5));
      expect(pill.height, closeTo(45, 0.05));
      final icon = tester.widget<CameoIcon>(
        find.descendant(
          of: find.byKey(ToastV6Pill.pillKey),
          matching: find.byType(CameoIcon),
        ),
      );
      expect(icon.name, CameoIconName.infoCircle);
      expect(_camera(tester).thumbnailKey, 'partner-1');
      await _frames(tester, const Duration(milliseconds: 300));
      expect(FlowDemo.run(FlowDemoAction.cameraOpenShared), isTrue);
      await settleApp(tester);
      expect(FlowDemo.stackSnapshot().top, FlowDemoScreen.photo);
      expect(identical(instantSubject, partnerInstant), isTrue);
      await disposeApp(tester);
    },
  );

  testWidgets(
    '썸네일 탭 → 사진 보기 (썸네일 rect r16 에서 줌) · 보기 사진 = 썸네일이 보여 주던 것 (내 촬영 → albumPhotoId)',
    (tester) async {
      await _open(tester, '/capture?session=member');
      await _shoot(tester);
      await tester.tap(find.byKey(ReviewOverlay.sendKey));
      await _frames(tester, const Duration(milliseconds: 2500));
      final latest = lastAlbum.latestCapture!;
      await tester.tap(find.byKey(CameraV6Screen.thumbnailKey));
      await settleApp(tester);
      expect(FlowDemo.stackSnapshot().top, FlowDemoScreen.photo);
      expect(instantSubject.albumPhotoId, latest.id);
      await disposeApp(tester);
    },
  );

  testWidgets(
    '딥링크 /capture?review=1 → 진입 뒤 검토 (placeholder = Figma 전송 사진 0e79c) · 흐름 데모 review.send = send (팝이 멈추면 settle) · camera.shutter (탭) = 검토 등장이 멈추면 settle',
    (tester) async {
      await _open(tester, '/capture?review=1&session=member');
      await _frames(tester, const Duration(milliseconds: 800));
      expect(_camera(tester).reviewPhase, ReviewPhase.review);
      final image = tester.widget<Image>(
        find.descendant(
          of: find.byKey(ReviewOverlay.photoKey),
          matching: find.byType(Image),
        ),
      );
      expect(image.image, AssetImage(labV6.camera.viewfinder));
      Future<void> runUntilSettled(FlowDemoAction action) async {
        final before = FlowDemo.settleCount(action);
        expect(FlowDemo.run(action), isTrue, reason: action.id);
        for (var i = 0; i < 400; i++) {
          await tester.pump(kFrame);
          if (FlowDemo.settleCount(action) > before) return;
        }
        fail('${action.id} settle 없음');
      }

      expect(FlowDemo.run(FlowDemoAction.cameraShutter), isFalse);
      await runUntilSettled(FlowDemoAction.reviewSend);
      expect(_camera(tester).thumbnailKey, lastAlbum.latestCapture!.id);
      expect(FlowDemo.run(FlowDemoAction.reviewSend), isFalse);
      await _frames(tester, const Duration(milliseconds: 600));
      await runUntilSettled(FlowDemoAction.cameraShutter);
      expect(_camera(tester).reviewPhase, ReviewPhase.review);
      await disposeApp(tester);
    },
  );

  testWidgets(
    '통화 모드 (/camera): 이 화면이 camera 변형 탭바를 그린다 (다른 탭 비활성 0.3) · 토스트 없음 · 전환 = 면이 바뀐다 · 셔터 = 검토 없이 결과로 닫힘 (앨범에 넣지 않는다)',
    (tester) async {
      await _open(tester, '/camera?session=member');
      final camera = tester.widget<CameraV6Screen>(find.byType(CameraV6Screen));
      expect(camera.mode, CameraV6Mode.call);
      expect(find.byKey(CameraV6Screen.toastKey), findsNothing);
      final bar = tester.widget<TabBarV6>(
        find.descendant(
          of: find.byKey(CameraV6Screen.barKey),
          matching: find.byType(TabBarV6),
        ),
      );
      expect(bar.tabsDisabled, isTrue);
      expect(bar.variant, TabBarV6Variant.camera);
      expect(bar.selected, CameoTabs.camera);
      await _frames(tester, const Duration(milliseconds: 600));
      expect(
        tester.getRect(find.byKey(CameraV6Screen.thumbnailKey)),
        const Rect.fromLTWH(16, 785, 54, 54),
      );
      await tester.tap(find.byKey(TabBarV6.buttonKey));
      await tester.pump();
      expect(_camera(tester).facing, CameraFacing.front);
      await settleApp(tester);
      await tester.pump(CameoMotion.instantPartnerDelay * 2);
      expect(find.byKey(ToastV6Pill.pillKey), findsNothing);
      expect(FlowDemo.run(FlowDemoAction.cameraShutter), isTrue);
      await settleApp(tester);
      expect(find.byType(CameraV6Screen), findsNothing);
      expect(find.byType(ReviewOverlay), findsNothing);
      expect(lastAlbum.latestCapture, isNull);
      await disposeApp(tester);
    },
  );
}
