// Regression coverage for flow demo v6. Preserve behavior, layout, and interaction
// expectations.

import 'package:cameo/components/captured_card.dart';
import 'package:cameo/components/review_overlay.dart';
import 'package:cameo/content/lab.g.dart';
import 'package:cameo/design_system/design_system.dart';
import 'package:cameo/navigation/navigation.dart';
import 'package:cameo/screens/camera_v6/camera_v6_screen.dart';
import 'package:cameo/screens/home_timeline/home_timeline_screen.dart';
import 'package:cameo/screens/welcome/welcome_screen.dart';
import 'package:cameo/state/session.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_harness.dart';

int _step(FlowDemoAction action, [int nth = 0]) {
  var seen = 0;
  for (var i = 0; i < flowDemoTimeline.length; i++) {
    if (flowDemoTimeline[i].action != action) continue;
    if (seen++ == nth) return i;
  }
  return -1;
}

void main() {
  setUp(() {
    FlowDemo.resetForTesting();
    ZoomSource.clear();
    ViewerSource.clear();
  });
  tearDown(FlowDemo.resetForTesting);

  testWidgets(
    '40 단계 전부 수행 (pending · 건너뛰기 없음 · 전송 검토 → send → 공유 토스트) — 끝 = 웰컴 · 세션 guest · 기기 서비스는 시뮬레이트',
    (tester) async {
      await withDebugPrintLogs((logs) async {
        final system = FakeSystemPermissions();
        final session = await pumpCameoApp(
          tester,
          CameoRoutes.flowDemo,

          stored: devSessionOf(DevSessionKind.member),
          permissions: system,
          settle: false,
        );
        expect(session.session, Session.guest);
        expect(find.byType(WelcomeScreen), findsOneWidget);

        final steps = flowDemoTimeline;
        expect(steps, hasLength(40));
        expect(
          steps.where((step) => step.pending),
          isEmpty,
          reason: 'v6 완료 검증에서는 미구현 단계를 건너뛰어 통과할 수 없다',
        );
        final deliveredAt = <int, Duration>{};
        var elapsed = Duration.zero;
        final checked = <String>{};
        const limit = Duration(seconds: 230);
        bool warned() =>
            logs.any((l) => l.contains('멈춘다') || l.contains('받지 않았다'));
        bool arrivedAfter(int i) =>
            deliveredAt.containsKey(i) && !deliveredAt.containsKey(i + 1);
        while (!logs.contains('[cameo] flow demo: 끝') && elapsed < limit) {
          await tester.pump(kFrame);
          elapsed += kFrame;
          for (var i = 0; i < steps.length; i++) {
            if (deliveredAt.containsKey(i)) continue;
            final line =
                "[cameo] flow demo: ${i + 1}/${steps.length} '${steps[i].action.id}' → ${steps[i].to.name}";
            if (logs.contains(line)) deliveredAt[i] = elapsed;
          }
          final snapshot = FlowDemo.stackSnapshot();

          if (!checked.contains('home') &&
              arrivedAfter(7) &&
              snapshot.top == FlowDemoScreen.home &&
              snapshot.idle) {
            checked.add('home');
            expect(session.session.status, SessionStatus.member);
            expect(session.session.partner, isNotNull);
            for (final kind in PermissionKind.values) {
              expect(
                session.session.permissionOf(kind),
                PermissionState.granted,
              );
            }
            expect(system.requests, isEmpty);
            expect(FlowDemo.isActive, isTrue);
          }

          final like = _step(FlowDemoAction.viewerLike);
          if (!checked.contains('like') &&
              arrivedAfter(like) &&
              snapshot.idle) {
            checked.add('like');
            final photos = lastAlbum.sections.first.photos;
            expect(photos[HomeTimelineDemo.openPhotoIndex + 1].liked, isTrue);
            expect(photos[HomeTimelineDemo.openPhotoIndex].liked, isFalse);
            expect(photos.first.liked, isTrue);
          }

          final toggle = _step(FlowDemoAction.selectToggle);
          if (!checked.contains('select') && arrivedAfter(toggle)) {
            checked.add('select');

            expect(appTabs(tester)!.tabBarHidden, isFalse);
            expect(appTabs(tester)!.tabBarModeShown, TabBarV6Mode.mini);
          }

          final volume = _step(FlowDemoAction.callVolume);
          if (!checked.contains('volume') && arrivedAfter(volume + 1)) {
            checked.add('volume');
            expect(simulatedVolume.writes, isNotEmpty);
          }

          final shutter = _step(FlowDemoAction.cameraShutter);
          if (!checked.contains('card') &&
              arrivedAfter(shutter) &&
              snapshot.top == FlowDemoScreen.call &&
              snapshot.idle) {
            checked.add('card');
            final card = tester.widget<CapturedCard>(find.byType(CapturedCard));
            expect(card.visible, isTrue);
            expect(
              card.items.single.image,
              AssetImage(labV6.camera.viewfinder),
            );
          }

          final sleep = _step(FlowDemoAction.callSleep);
          if (!checked.contains('sleep') &&
              arrivedAfter(sleep) &&
              simulatedVolume.writes.length > 2) {
            checked.add('sleep');
            expect(simulatedBrightness.value, 0);
            expect(simulatedVolume.isFading, isTrue);
            expect(
              simulatedVolume.value,
              lessThan(simulatedVolume.writes.first),
            );
          }

          final wake = _step(FlowDemoAction.aodEnd);
          if (!checked.contains('wake') && arrivedAfter(wake + 1)) {
            checked.add('wake');
            expect(simulatedBrightness.overridden, isFalse);
          }

          final review = _step(FlowDemoAction.cameraShutter, 1);
          if (!checked.contains('review') &&
              arrivedAfter(review) &&
              FlowDemo.settleCount(FlowDemoAction.cameraShutter) > 0) {
            checked.add('review');
            final overlay = tester.widget<ReviewOverlay>(
              find.byType(ReviewOverlay),
            );
            expect(overlay.phase, ReviewPhase.review);
            expect(appTabs(tester)!.tabBarHidden, isTrue);
          }

          final send = _step(FlowDemoAction.reviewSend);
          if (!checked.contains('send') &&
              arrivedAfter(send) &&
              FlowDemo.settleCount(FlowDemoAction.reviewSend) > 0) {
            checked.add('send');
            final latest = lastAlbum.latestCapture!;
            expect(lastAlbum.sections.first.photos.first, latest);
            expect(
              tester
                  .state<CameraV6ScreenState>(find.byType(CameraV6Screen))
                  .thumbnailKey,
              latest.id,
            );
            expect(appTabs(tester)!.tabBarHidden, isFalse);
          }
          if (warned()) break;
        }
        expect(
          logs.where((l) => l.contains('멈춘다') || l.contains('받지 않았다')),
          isEmpty,
        );
        expect(logs, contains('[cameo] flow demo: 시작'));
        expect(logs, contains('[cameo] flow demo: 끝'));
        expect(logs.where((line) => line.contains('pending')), isEmpty);
        expect(FlowDemo.runner?.skipped, isEmpty);
        expect(deliveredAt.keys.toList()..sort(), [
          for (var i = 0; i < steps.length; i++) i,
        ]);
        expect(checked, {
          'home',
          'like',
          'select',
          'volume',
          'card',
          'sleep',
          'wake',
          'review',
          'send',
        });

        for (var i = 1; i < steps.length; i++) {
          expect(
            deliveredAt[i]! - deliveredAt[i - 1]!,
            greaterThanOrEqualTo(Duration(milliseconds: steps[i].afterMs)),
            reason: '${i + 1} ${steps[i].action.id}',
          );
        }

        expect(elapsed, lessThan(const Duration(seconds: 170)));
        await settleApp(tester);
        expect(find.byType(WelcomeScreen), findsOneWidget);
        expect(session.session, Session.guest);
        expect(FlowDemo.isActive, isFalse);
        expect(rootNavigator(tester).canPop(), isFalse);

        expect(simulatedBrightness.overridden, isFalse);
        await disposeApp(tester);
      });
    },
  );

  testWidgets(
    '설정 \'흐름 데모 보기\' (FlowDemo.restart): 확인 없이 세션 guest + 앨범 되돌림 + 웰컴 + 실행기 시작 · 앱 루트가 사라지면 해제',
    (tester) async {
      await withDebugPrintLogs((logs) async {
        final session = await pumpCameoApp(tester, '/settings?session=member');
        final firstId = lastAlbum.sections.first.photos.first.id;
        lastAlbum.deletePhotos([firstId]);
        expect(lastAlbum.photoById(firstId), isNull);
        await tester.tap(find.byKey(const ValueKey('settings.flowDemo')));
        expect(session.session, Session.guest);
        expect(lastAlbum.photoById(firstId), isNotNull);
        expect(FlowDemo.isActive, isTrue);
        await settleApp(tester, quiet: const Duration(milliseconds: 500));
        expect(find.byType(WelcomeScreen), findsOneWidget);
        for (var i = 0; i < 20; i++) {
          await tester.pump(kFrame);
        }
        expect(logs, contains('[cameo] flow demo: 시작'));
        await tester.pumpWidget(const SizedBox());
        expect(FlowDemo.isActive, isFalse);
        await tester.pump(const Duration(seconds: 5));
        expect(logs.where((l) => l.contains('1/40')), isEmpty);
      });
    },
  );

  test(
    '표의 모든 동작은 받을 화면이 있다 (화면 · 통화 · 카메라 · 설정 · 탭 컨테이너 · 앱 루트) 또는 pending — back 은 등록 없이 잎 pop',
    () {
      const owners = {
        'welcome.start': 'WelcomeScreen',
        'phone.type': 'PhoneScreen',
        'phone.submit': 'PhoneScreen',
        'verify.autofill': 'VerifyScreen',
        'profile.type': 'ProfileScreen',
        'profile.submit': 'ProfileScreen',
        'partner.type': 'PartnerScreen',
        'permissions.allow': 'PermissionsScreen',
        'home.scroll': 'HomeTimelineScreen',
        'home.openPhoto': 'HomeTimelineScreen',
        'viewer.strip': '(pending — album: 사진 보기 v6 스트립)',
        'viewer.like': 'PhotoViewerScreen',
        'back': '(잎 pop)',
        'home.liked': '(pending — album: 좋아요 보기)',
        'liked.close': '(pending — album)',
        'home.deleted': '(pending — album: 삭제 보기)',
        'deleted.close': '(pending — album)',
        'home.select': 'HomeTimelineScreen',
        'select.toggle': 'HomeTimelineScreen',
        'select.close': 'HomeTimelineScreen',
        'home.call': 'AppTabs (통화 버튼) · HomeTimelineScreen (v5)',
        'call.volume': 'CallScreen',
        'call.highlight': 'CallScreen',
        'call.camera': 'CallScreen',
        'sheet.live': 'CallScreen',
        'camera.shutter': 'CameraV6Screen (call → 통화 카드 · tab → 전송 검토)',
        'call.closeCard': 'CallScreen',
        'call.sleep': 'CallScreen',
        'aod.end': 'CallScreen',
        'call.endCall': 'CallScreen',
        'home.openCallCard': 'HomeTimelineScreen',
        'tabs.camera': 'AppTabs',
        'review.send': 'CameraV6Screen(tab)',
        'camera.openShared': 'CameraV6Screen(tab)',
        'tabs.settings': 'AppTabs',
        'settings.logout': 'SettingsScreen',
        'sheet.confirm': 'SettingsScreen',
      };
      for (final s in flowDemoTimeline) {
        expect(owners.containsKey(s.action.id), isTrue, reason: s.action.id);
        if (s.pending) {
          expect(owners[s.action.id], contains('pending'), reason: s.action.id);
        }
      }
      expect(CameoMotion.instantPartnerDelay.inMilliseconds, lessThan(3200));
    },
  );
}
