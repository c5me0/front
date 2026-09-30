// Regression coverage for session gate. Preserve behavior, layout, and interaction
// expectations.

import 'dart:ui' show lerpDouble;

import 'package:cameo/content/app.g.dart';
import 'package:cameo/content/lab.g.dart';
import 'package:cameo/design_system/design_system.dart';
import 'package:cameo/navigation/navigation.dart';
import 'package:cameo/screens/album/album_screen.dart';
import 'package:cameo/screens/call/call_screen.dart';
import 'package:cameo/screens/camera_v6/camera_v6_screen.dart';
import 'package:cameo/screens/home_timeline/home_timeline_screen.dart';
import 'package:cameo/screens/partner/partner_screen.dart';
import 'package:cameo/screens/permissions/permissions_screen.dart';
import 'package:cameo/screens/profile/profile_screen.dart';
import 'package:cameo/screens/settings/settings_screen.dart';
import 'package:cameo/screens/transcript/transcript_screen.dart';
import 'package:cameo/screens/verify/verify_screen.dart';
import 'package:cameo/screens/welcome/welcome_screen.dart';
import 'package:cameo/state/session.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_harness.dart';

List<String> _stack(String location, Session session) =>
    initialLocationsFor(CameoLocation.parse(location), session);

void main() {
  setUp(() {
    FlowDemo.resetForTesting();
    ZoomSource.clear();
  });
  tearDown(FlowDemo.resetForTesting);

  group('시작 스택 (initialLocationsFor)', () {
    const guest = Session.guest;
    final onboarding = devSessionOf(DevSessionKind.onboarding);
    final member = devSessionOf(DevSessionKind.member);

    test('signedOut: 첫 화면 = 웰컴 · 인증 스택 · 앱/온보딩 경로는 웰컴으로', () {
      expect(entryLocationsFor(guest), ['/welcome']);
      expect(_stack('/', guest), ['/welcome']);
      expect(_stack('/welcome', guest), ['/welcome']);
      expect(_stack('/phone', guest), ['/welcome', '/phone']);
      expect(_stack('/verify?phone=01012345678', guest), [
        '/welcome',
        '/phone',
        '/verify?phone=01012345678',
      ]);
      for (final wrong in [
        '/settings',
        '/albums/gangneung',
        '/connect',
        '/profile',
      ]) {
        expect(_stack(wrong, guest), ['/welcome'], reason: wrong);
      }
    });

    test(
      'onboarding: 재개 단계까지 (이름 없음 → 프로필 · 이름 → + 상대 · 건너뜀/연결 → + 권한) · 요청한 단계까지',
      () {
        expect(entryLocationsFor(onboarding), ['/profile']);
        expect(_stack('/', onboarding), ['/profile']);
        expect(_stack('/welcome', onboarding), ['/profile']);
        final named = onboarding.copyWith(name: '주영');
        expect(_stack('/', named), ['/profile', '/partner']);
        expect(_stack('/settings', named.copyWith(partnerSkipped: true)), [
          '/profile',
          '/partner',
          '/permissions',
        ]);

        expect(_stack('/partner', onboarding), ['/profile', '/partner']);
        expect(_stack('/permissions', onboarding), [
          '/profile',
          '/partner',
          '/permissions',
        ]);
      },
    );

    test('member: 탭 컨테이너 한 라우트 · /connect = [홈, 연결] · 인증/온보딩 경로는 홈으로', () {
      expect(entryLocationsFor(member), ['/']);
      expect(_stack('/', member), ['/']);
      expect(_stack('/settings', member), ['/settings']);
      expect(_stack('/albums/gangneung', member), ['/albums/gangneung']);
      expect(_stack('/connect', member), ['/', '/connect']);
      for (final wrong in ['/welcome', '/phone', '/profile', '/permissions']) {
        expect(_stack(wrong, member), ['/'], reason: wrong);
      }
    });

    test('가드 없는 화면 = 그 상태의 첫 스택 위 · 모르는 경로 = 첫 스택', () {
      expect(_stack('/album', guest), ['/welcome', '/album']);
      expect(_stack('/transcript?theme=dark', member), [
        '/',
        '/transcript?theme=dark',
      ]);
      expect(_stack('/call', onboarding), ['/profile', '/call']);
      expect(_stack('/camera', member), ['/', '/camera']);
      expect(_stack('/lab', guest), ['/welcome', '/lab']);
      expect(_stack('/nope', member), ['/']);
    });
  });

  group('딥링크 (CAMEO_ROUTE 와 같은 문자열 → 앱)', () {
    testWidgets(
      '/?session=member → 홈 타임라인 (탭 0) · 저장 · 탭바 v6 (history 선택 · 풀 — 아바타 탭은 v6 에 없다)',
      (tester) async {
        final session = await pumpCameoApp(tester, '/?session=member');
        expect(find.byType(HomeTimelineScreen), findsOneWidget);
        expect(appTabs(tester)!.selectedTab, CameoTabs.albums);
        final bar = tester.widget<TabBarV6>(find.byType(TabBarV6));
        expect(bar.selected, CameoTabs.albums);
        expect(bar.mode, TabBarV6Mode.full);
        expect(session.session.status, SessionStatus.member);
        expect(rootNavigator(tester).canPop(), isFalse);
        await disposeApp(tester);
      },
    );

    testWidgets('/settings?session=member → 설정 탭', (tester) async {
      await pumpCameoApp(tester, '/settings?session=member');
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.byType(HomeTimelineScreen), findsNothing);
      expect(appTabs(tester)!.selectedTab, CameoTabs.settings);
      await disposeApp(tester);
    });

    testWidgets(
      '/?session=member&partner=none → 빈 앨범 (상대 연결하기) · /?session=member&album=empty → 빈 앨범 v6 (사진 불러오기)',
      (tester) async {
        final session = await pumpCameoApp(
          tester,
          '/?session=member&partner=none',
        );
        expect(session.session.partner, isNull);
        expect(find.byKey(HomeTimelineScreen.emptyKey), findsOneWidget);
        expect(
          find.text(appContent.v6.emptyAlbum.ctaNoPartner),
          findsOneWidget,
        );
        await disposeApp(tester);
        await pumpCameoApp(tester, '/?session=member&album=empty');
        expect(lastAlbum.emptyMode, isTrue);
        expect(find.byKey(HomeTimelineScreen.emptyKey), findsOneWidget);
        expect(find.text(labV6.emptyAlbum.cta), findsOneWidget);
        await disposeApp(tester);
      },
    );

    testWidgets('/album (가드 없음, 로그아웃 상태) → 16-6 · 뒤로 → 웰컴', (tester) async {
      await pumpCameoApp(tester, '/album');
      expect(find.byType(AlbumScreen), findsOneWidget);
      rootNavigator(tester).pop();
      await settleApp(tester);
      expect(find.byType(WelcomeScreen), findsOneWidget);
      await disposeApp(tester);
    });

    testWidgets('/transcript?theme=dark · /call · /camera → 그 화면 (루트 스택)', (
      tester,
    ) async {
      await pumpCameoApp(tester, '/transcript?theme=dark');
      expect(
        tester.widget<TranscriptScreen>(find.byType(TranscriptScreen)).theme,
        TranscriptTheme.dark,
      );
      await disposeApp(tester);
      await pumpCameoApp(
        tester,
        '/call',
        stored: devSessionOf(DevSessionKind.member),
      );
      expect(find.byType(CallScreen), findsOneWidget);
      expect(find.byType(AppTabs, skipOffstage: false), findsOneWidget);
      await disposeApp(tester);
      await pumpCameoApp(tester, '/camera');
      expect(
        tester.widget<CameraV6Screen>(find.byType(CameraV6Screen)).mode,
        CameraV6Mode.call,
      );
      await disposeApp(tester);
    });

    testWidgets('/verify?session=guest&phone= → [웰컴 · 전화번호 · 인증]', (
      tester,
    ) async {
      await pumpCameoApp(tester, '/verify?session=guest&phone=01012345678');
      expect(
        tester.widget<VerifyScreen>(find.byType(VerifyScreen)).phone,
        '01012345678',
      );
      rootNavigator(tester).pop();
      await settleApp(tester);
      rootNavigator(tester).pop();
      await settleApp(tester);
      expect(find.byType(WelcomeScreen), findsOneWidget);
      await disposeApp(tester);
    });

    testWidgets('다시 열면 저장된 세션 (member → 홈) · 잘못된 상태 시작은 그 상태의 첫 화면', (
      tester,
    ) async {
      await pumpCameoApp(
        tester,
        '/',
        stored: devSessionOf(DevSessionKind.member),
      );
      expect(find.byType(HomeTimelineScreen), findsOneWidget);
      await disposeApp(tester);

      await pumpCameoApp(
        tester,
        '/phone',
        stored: devSessionOf(DevSessionKind.member),
      );
      expect(find.byType(HomeTimelineScreen), findsOneWidget);
      await disposeApp(tester);

      await pumpCameoApp(tester, '/settings');
      expect(find.byType(WelcomeScreen), findsOneWidget);
      await disposeApp(tester);

      await pumpCameoApp(
        tester,
        '/',
        stored: devSessionOf(DevSessionKind.onboarding).copyWith(name: '주영'),
      );
      expect(find.byType(PartnerScreen), findsOneWidget);
      rootNavigator(tester).pop();
      await settleApp(tester);
      expect(find.byType(ProfileScreen), findsOneWidget);
      await disposeApp(tester);
    });
  });

  group('세션 전이 = 스택 교체 (D7)', () {
    testWidgets('인증 완료 → 프로필: 일반 푸시 (오른쪽에서) · 끝나면 인증 스택이 없다', (tester) async {
      final session = await pumpCameoApp(
        tester,
        '/verify?session=guest&phone=01012345678',
      );
      session.completeVerification('01012345678');
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final profileLeft = tester.getTopLeft(find.byType(ProfileScreen)).dx;
      expect(profileLeft, inExclusiveRange(0, kIPhone16.width));
      expect(find.byType(VerifyScreen), findsOneWidget);
      await settleApp(tester);
      expect(find.byType(VerifyScreen), findsNothing);
      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(rootNavigator(tester).canPop(), isFalse);
      await disposeApp(tester);
    });

    testWidgets(
      '앱 진입 (온보딩 → member): 탭 컨테이너가 페이드 0 → 1 · 스케일 0.94 → 1, 나가는 화면은 그대로',
      (tester) async {
        final session = await pumpCameoApp(
          tester,
          '/permissions?session=onboarding',
        );
        final permissionsLeft = tester.getTopLeft(
          find.byType(PermissionsScreen),
        );
        session.completeOnboarding();
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));
        final route = CameoRouteActivity.rootTop!;
        expect(route, isA<CameoShellRoute<dynamic>>());
        final p = route.animation!.value;
        expect(p, inExclusiveRange(0, 1));
        final opacity = tester.widget<Opacity>(
          find.byKey(const ValueKey('enterApp.opacity')),
        );
        expect(opacity.opacity, closeTo(p, 1e-9));
        final scale = tester.widget<Transform>(
          find.byKey(const ValueKey('enterApp.scale')),
        );
        expect(
          scale.transform.entry(0, 0),
          closeTo(
            lerpDouble(CameoMotion.transitionEnterAppScaleFrom, 1, p)!,
            1e-6,
          ),
        );
        expect(
          tester.getTopLeft(find.byType(PermissionsScreen)),
          permissionsLeft,
        );
        await settleApp(tester);
        expect(find.byType(PermissionsScreen), findsNothing);
        expect(find.byType(HomeTimelineScreen), findsOneWidget);
        expect(rootNavigator(tester).canPop(), isFalse);
        await disposeApp(tester);
      },
    );

    testWidgets(
      '로그아웃: 웰컴 페이드 인 + 탭 컨테이너 1 → 1.04 (= 탭이 커지며 사라져 웰컴을 드러냄) · 끝나면 웰컴만',
      (tester) async {
        final session = await pumpCameoApp(tester, '/settings?session=member');
        session.signOut();
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));
        final welcome = CameoRouteActivity.rootTop!;
        expect(welcome, isA<CameoPageRoute<dynamic>>());
        expect((welcome as CameoPageRoute<dynamic>).entry, CameoPageEntry.fade);
        final s = welcome.animation!.value;
        expect(s, inExclusiveRange(0, 1));

        final welcomeOpacity = tester.widget<Opacity>(
          find
              .ancestor(
                of: find.byType(WelcomeScreen),
                matching: find.byType(Opacity),
              )
              .last,
        );
        expect(welcomeOpacity.opacity, closeTo(s, 1e-9));
        expect(tester.getTopLeft(find.byType(WelcomeScreen)).dx, 0);

        final shellScale = tester.widget<Transform>(
          find.byKey(const ValueKey('enterApp.scale')),
        );
        expect(
          shellScale.transform.entry(0, 0),
          closeTo(
            lerpDouble(1, CameoMotion.transitionEnterAppExitScaleTo, s)!,
            1e-6,
          ),
        );
        await settleApp(tester);
        expect(find.byType(AppTabs, skipOffstage: false), findsNothing);
        expect(find.byType(WelcomeScreen), findsOneWidget);
        expect(rootNavigator(tester).canPop(), isFalse);
        await disposeApp(tester);
      },
    );

    testWidgets('Lab 앱 흐름 항목 (CameoNav.openLocation): 세션 적용 + 스택 교체', (
      tester,
    ) async {
      final session = await pumpCameoApp(tester, '/lab');
      final lab = tester.element(find.text('cameo lab'));
      CameoNav.openLocation(lab, '/settings?session=member');
      await settleApp(tester);
      expect(session.session.status, SessionStatus.member);
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(rootNavigator(tester).canPop(), isFalse);
      final settings = tester.element(find.byType(SettingsScreen));
      CameoNav.openLocation(settings, '/?session=member&partner=none');
      await settleApp(tester);
      expect(find.byKey(HomeTimelineScreen.emptyKey), findsOneWidget);

      lastAlbum.deletePhotos([lastAlbum.sections.first.photos.first.id]);
      final home = tester.element(find.byType(HomeTimelineScreen));
      CameoNav.openLocation(home, '/?session=member&album=empty');
      await settleApp(tester);
      expect(lastAlbum.emptyMode, isTrue);
      expect(find.byKey(HomeTimelineScreen.emptyKey), findsOneWidget);
      final empty = tester.element(find.byType(HomeTimelineScreen));
      CameoNav.openLocation(empty, '/?session=member');
      await settleApp(tester);
      expect(lastAlbum.emptyMode, isFalse);
      expect(
        lastAlbum.sections.first.photos.length,
        labAlbumV5.sections.first.grid!.photos.length,
      );
      expect(find.byKey(HomeTimelineScreen.emptyKey), findsNothing);
      await disposeApp(tester);
    });
  });
}
