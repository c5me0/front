// Regression coverage for navigation. Preserve behavior, layout, and interaction
// expectations.

import 'dart:convert';
import 'dart:io' show File, Platform;

import 'package:cameo/content/lab.g.dart';
import 'package:cameo/design_system/design_system.dart';
import 'package:cameo/main.dart';
import 'package:cameo/navigation/navigation.dart';
import 'package:cameo/screens/album/album_screen.dart';
import 'package:cameo/screens/album_gangneung/album_gangneung_screen.dart';
import 'package:cameo/screens/call/call_screen.dart';
import 'package:cameo/screens/camera/camera_screen.dart';
import 'package:cameo/screens/home/home_screen.dart';
import 'package:cameo/screens/home_timeline/home_timeline_screen.dart';
import 'package:cameo/screens/camera_v6/camera_v6_screen.dart';
import 'package:cameo/screens/photo_viewer/photo_viewer_screen.dart';
import 'package:cameo/screens/instant_viewer/instant_viewer_screen.dart';
import 'package:cameo/screens/lab/glass_v6_harness.dart';
import 'package:cameo/screens/lab/lab_entries.dart';
import 'package:cameo/screens/lab/lab_screen.dart';
import 'package:cameo/screens/partner/partner_screen.dart';
import 'package:cameo/screens/permissions/permissions_screen.dart';
import 'package:cameo/screens/phone/phone_screen.dart';
import 'package:cameo/screens/profile/profile_screen.dart';
import 'package:cameo/screens/settings/settings_screen.dart';
import 'package:cameo/screens/transcript/transcript_screen.dart';
import 'package:cameo/screens/verify/verify_screen.dart';
import 'package:cameo/screens/welcome/welcome_screen.dart';
import 'package:cameo/state/captured_photo.dart';
import 'package:cameo/state/session.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _frame = Duration(milliseconds: 16);

class _Page extends StatelessWidget {
  const _Page(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: ValueKey('page-$label'),
      color: CameoColors.backgroundCanvasBase,
      child: Center(child: Text(label)),
    );
  }
}

Widget _app(GlobalKey<NavigatorState> key, {RouteFactory? onGenerateRoute}) {
  return WidgetsApp(
    navigatorKey: key,
    color: CameoColors.backgroundCanvasBase,
    textStyle: CameoTextStyles.bodyMd,
    onGenerateRoute:
        onGenerateRoute ??
        (s) => CameoPageRoute<void>(
          settings: s,
          builder: (_) => _Page(s.name ?? '?'),
        ),
  );
}

double _left(WidgetTester tester, String label) =>
    tester.getTopLeft(find.byKey(ValueKey('page-$label'))).dx;

double _top(WidgetTester tester, String label) =>
    tester.getTopLeft(find.byKey(ValueKey('page-$label'))).dy;

void main() {
  group('라우트 이름 · 파라미터 (RN 과 같은 문자열)', () {
    test('CameoLocation.parse 정규화', () {
      expect(
        CameoLocation.parse('/transcript?theme=dark'),
        const CameoLocation('/transcript', {'theme': 'dark'}),
      );
      expect(CameoLocation.parse('transcript?theme=dark').path, '/transcript');
      expect(CameoLocation.parse('/album/').path, '/album');
      expect(CameoLocation.parse('').path, '/');
      expect(
        CameoLocation.parse(' /call?state=media-4x3 ').toString(),
        '/call?state=media-4x3',
      );
    });

    test('경로 빌더', () {
      expect(CameoRoutes.transcript(), '/transcript?theme=dark');
      expect(
        CameoRoutes.transcript(theme: TranscriptTheme.dark),
        '/transcript?theme=dark',
      );
      expect(
        CameoRoutes.transcript(theme: TranscriptTheme.photo),
        '/transcript?theme=photo',
      );

      expect(CameoRoutes.home, '/');
      expect(CameoRoutes.lab, '/lab');
      expect(CameoRoutes.camera, '/camera');
      expect(CameoRoutes.flowDemo, '/?demo=flow');
      expect(
        CameoRoutes.flowDemo,
        CameoLocation(CameoRoutes.home, const {
          'demo': CameoRoutes.demoFlow,
        }).toString(),
      );
      expect(CameoRoutes.call(), '/call');
      expect(
        [for (final s in CallState.values) CameoRoutes.call(state: s)],
        [
          '/call',
          '/call?state=media-16x9',
          '/call?state=media-4x3',
          '/call?state=media-1x1',
          '/call?state=sleep-toast',
          '/call?state=volume',
          '/call?state=highlight',
          '/call?state=aod',
        ],
      );

      expect(
        CameoRoutes.verify(phone: '01012345678'),
        '/verify?phone=01012345678',
      );
      expect(
        CameoRoutes.verifyPhoneOf(CameoLocation.parse('/verify?phone=0101')),
        '0101',
      );
      expect(CameoRoutes.table.keys.toSet(), {
        '/welcome',
        '/phone',
        '/verify',
        '/profile',
        '/partner',
        '/permissions',
        '/',
        '/albums/gangneung',
        '/settings',
        '/connect',
        '/payment',
        '/breakup',
        '/lab',
        '/foundation',
        '/album',
        '/album-gangneung',
        '/transcript',
        '/call',
        '/call-v1',
        '/camera',
        '/camera-v3',
        // v5
        '/capture',
        '/photo',
        '/instant',
        '/home-v4',

        '/glass-v6',
      });

      expect(
        CameoRoutes.photo(sectionId: 'sungsu', index: 3),
        '/photo?section=sungsu&index=3',
      );
      expect(
        CameoRoutes.call(sheet: PhotoSheetVariant.multi),
        '/call?sheet=multi',
      );
      expect(
        CameoRoutes.call(
          state: CallState.media4x3,
          sheet: PhotoSheetVariant.instant,
        ),
        '/call?state=media-4x3&sheet=instant',
      );
      final photo = CameoLocation.parse('/photo?section=calls-only&index=x');
      expect(CameoRoutes.photoSectionOf(photo), 'calls-only');
      expect(CameoRoutes.photoIndexOf(photo), 0);
      expect(
        CameoRoutes.photoSectionOf(const CameoLocation('/photo')),
        labAlbumV5.sections.first.id,
      );
      expect(
        CameoRoutes.photoSheetOf(CameoLocation.parse('/call?sheet=multi')),
        PhotoSheetVariant.multi,
      );
      expect(
        CameoRoutes.photoSheetOf(CameoLocation.parse('/call?sheet=nope')),
        isNull,
      );
      expect(
        CameoRoutes.albumEmptyOf(CameoLocation.parse('/?album=empty')),
        isTrue,
      );
      expect(
        CameoRoutes.albumEmptyOf(CameoLocation.parse('/?album=full')),
        isFalse,
      );
      expect(CameoRoutes.albumEmptyOf(const CameoLocation('/')), isNull);
      expect(
        CameoRoutes.withoutDevParams(
          CameoLocation.parse('/capture?session=member&album=empty&x=1'),
        ).toString(),
        '/capture?x=1',
      );
    });

    test('파라미터 파싱 — 없거나 모르는 값은 기본값', () {
      TranscriptTheme theme(String n) =>
          CameoRoutes.transcriptThemeOf(CameoLocation.parse(n));
      CallState state(String n) =>
          CameoRoutes.callStateOf(CameoLocation.parse(n));
      expect(theme('/transcript'), TranscriptTheme.dark);
      expect(theme('/transcript?theme=dark'), TranscriptTheme.dark);
      expect(theme('/transcript?theme=photo'), TranscriptTheme.photo);

      expect(theme('/transcript?theme=light'), TranscriptTheme.dark);
      expect(TranscriptTheme.tryParse('light'), TranscriptTheme.dark);
      expect(theme('/transcript?theme=sepia'), TranscriptTheme.dark);
      expect(TranscriptTheme.tryParse('sepia'), isNull);
      expect(
        [for (final t in TranscriptTheme.values) t.param],
        ['dark', 'photo'],
      );
      expect(state('/call'), CallState.base);
      expect(state('/call?state=media-1x1'), CallState.media1x1);
      expect(state('/call?state=sleep-toast'), CallState.sleepToast);
      expect(state('/call?state=nope'), CallState.base);
    });

    test(
      '?demo=1 — 개발용 데모 스크립트 (interaction-spec §5, RN parseDemo 와 같은 규칙)',
      () {
        bool demo(String n) => CameoRoutes.demoOf(CameoLocation.parse(n));
        for (final n in [
          '/album?demo=1',
          '/album?scroll=600&demo=1',
          '/album-gangneung?demo=1',
          '/transcript?theme=light&demo=1',
          '/call?demo=1',
          '/call?state=media-4x3&demo=1',
        ]) {
          expect(demo(n), isTrue, reason: n);
        }

        for (final n in [
          '/call',
          '/call?demo=0',
          '/call?demo=true',
          '/call?demo=',
          '/transcript?theme=dark',
        ]) {
          expect(demo(n), isFalse, reason: n);
        }

        final l = CameoLocation.parse('/album?scroll=600&demo=1');
        expect(CameoRoutes.initialScrollOf(l), 600);
        expect(
          CameoRoutes.callStateOf(
            CameoLocation.parse('/call?state=media-1x1&demo=1'),
          ),
          CallState.media1x1,
        );
        expect(
          CameoRoutes.transcriptThemeOf(
            CameoLocation.parse('/transcript?theme=dark&demo=1'),
          ),
          TranscriptTheme.dark,
        );

        expect(CameoRoutes.withDemo(CameoRoutes.call()), '/call?demo=1');
        expect(
          CameoRoutes.withDemo(CameoRoutes.call(state: CallState.media4x3)),
          '/call?state=media-4x3&demo=1',
        );
        expect(
          CameoRoutes.withDemo(CameoRoutes.transcript()),
          '/transcript?theme=dark&demo=1',
        );
        expect(
          CameoRoutes.withDemo(CameoRoutes.albumGangneung),
          '/album-gangneung?demo=1',
        );
        expect(
          CameoRoutes.demoOf(
            CameoLocation.parse(CameoRoutes.withDemo(CameoRoutes.album)),
          ),
          isTrue,
        );
      },
    );

    test('?demo=flow — 홈의 전체 흐름 데모 (RN parseFlowDemo 와 같은 규칙)', () {
      bool flow(String n) => CameoRoutes.flowDemoOf(CameoLocation.parse(n));
      expect(flow('/?demo=flow'), isTrue);
      expect(flow(CameoRoutes.flowDemo), isTrue);
      for (final n in [
        '/',
        '/?demo=1',
        '/?demo=Flow',
        '/album?demo=1',
        '/album?demo=flow',
      ]) {
        expect(flow(n), isFalse, reason: n);
      }

      expect(CameoRoutes.demoOf(CameoLocation.parse('/?demo=flow')), isFalse);
    });

    testWidgets(
      'v4 라우트 표 → 화면 생성자 (자리 화면 · 16-3 inTabs · 설정 모드 상대 연결) · 세션 가드',
      (tester) async {
        late BuildContext context;
        await tester.pumpWidget(
          Builder(
            builder: (c) {
              context = c;
              return const SizedBox();
            },
          ),
        );
        Widget build(String name) {
          final l = CameoLocation.parse(name);
          return CameoRoutes.table[l.path]!.builder(context, l);
        }

        expect(build('/welcome'), isA<WelcomeScreen>());
        expect(build('/phone'), isA<PhoneScreen>());
        expect(
          (build('/verify?phone=01012345678') as VerifyScreen).phone,
          '01012345678',
        );
        expect(build('/profile'), isA<ProfileScreen>());
        expect(
          (build('/partner') as PartnerScreen).mode,
          PartnerMode.onboarding,
        );
        expect((build('/connect') as PartnerScreen).mode, PartnerMode.settings);
        expect(build('/permissions'), isA<PermissionsScreen>());
        expect(build('/'), isA<HomeTimelineScreen>());
        expect(build('/home-v4'), isA<HomeScreen>());
        expect((build('/capture') as CameraV6Screen).mode, CameraV6Mode.tab);
        final photo =
            build('/photo?section=sungsu&index=3') as PhotoViewerScreen;
        expect((photo.sectionId, photo.index), ('sungsu', 3));
        expect(build('/instant'), isA<InstantViewerScreen>());
        expect(
          (build('/call?sheet=multi') as CallScreen).sheet,
          PhotoSheetVariant.multi,
        );
        expect((build('/call') as CallScreen).sheet, isNull);
        expect(build('/settings'), isA<SettingsScreen>());
        final inTabs = build('/albums/gangneung') as AlbumGangneungScreen;
        expect(inTabs.inTabs, isTrue);
        final standalone = build('/album-gangneung') as AlbumGangneungScreen;
        expect(standalone.inTabs, isFalse);
        expect(standalone.home, isFalse);
        expect(build('/lab'), isA<LabScreen>());

        SessionStatus? guard(String path) => CameoRoutes.table[path]!.guard;
        for (final p in ['/welcome', '/phone', '/verify']) {
          expect(guard(p), SessionStatus.signedOut, reason: p);
        }
        for (final p in ['/profile', '/partner', '/permissions']) {
          expect(guard(p), SessionStatus.onboarding, reason: p);
        }
        for (final p in [
          '/',
          '/capture',
          '/albums/gangneung',
          '/settings',
          '/connect',
        ]) {
          expect(guard(p), SessionStatus.member, reason: p);
        }
        for (final p in [
          '/album',
          '/album-gangneung',
          '/transcript',
          '/call',
          '/call-v1',
          '/camera',
          '/camera-v3',
          '/lab',
          '/foundation',
          '/glass-v6',
        ]) {
          expect(guard(p), isNull, reason: p);
        }

        expect(CameoRoutes.table['/']!.tab, CameoTabs.albums);
        expect(CameoRoutes.table['/albums/gangneung']!.nested, isTrue);
        expect(CameoRoutes.table['/settings']!.tab, CameoTabs.settings);

        expect(CameoRoutes.table['/capture']!.tab, CameoTabs.camera);

        CameoStatusBarStyle bar(String n) {
          final l = CameoLocation.parse(n);
          return CameoRoutes.table[l.path]!.statusBar(l);
        }

        for (final n in ['/welcome', '/phone', '/settings', '/connect']) {
          expect(bar(n), CameoStatusBarStyle.darkContent, reason: n);
        }
        for (final n in [
          '/albums/gangneung',
          '/',
          '/capture',
          '/photo',
          '/instant',
          '/camera',
        ]) {
          expect(bar(n), CameoStatusBarStyle.lightContent, reason: n);
        }
      },
    );

    testWidgets('?demo=1 → 네 화면 생성자의 demo (다른 파라미터와 함께)', (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      );

      Widget build(String name) {
        final l = CameoLocation.parse(name);
        return CameoRoutes.table[l.path]!.builder(context, l);
      }

      for (final demo in [true, false]) {
        String n(String base) => demo ? CameoRoutes.withDemo(base) : base;
        final album = build(n('/album?scroll=600')) as AlbumScreen;
        expect(album.demo, demo);
        expect(album.initialScroll, 600);
        final gangneung =
            build(n(CameoRoutes.albumGangneung)) as AlbumGangneungScreen;
        expect(gangneung.demo, demo);
        final transcript =
            build(n(CameoRoutes.transcript(theme: TranscriptTheme.dark)))
                as TranscriptScreen;
        expect(transcript.demo, demo);
        expect(transcript.theme, TranscriptTheme.dark);
        final call =
            build(n(CameoRoutes.call(state: CallState.media4x3))) as CallScreen;
        expect(call.demo, demo);
        expect(call.state, CallState.media4x3);
      }
    });

    testWidgets(
      'DemoTimeline — 첫 프레임 뒤부터 예약한 시각에 순서대로 발화, cancel 뒤에는 발화하지 않는다',
      (tester) async {
        final fired = <String>[];
        final timeline = DemoTimeline()
          ..start([
            (at: const Duration(milliseconds: 1500), run: () => fired.add('a')),
            (at: const Duration(milliseconds: 3000), run: () => fired.add('b')),
            (at: const Duration(milliseconds: 4500), run: () => fired.add('c')),
          ]);
        expect(timeline.isActive, isTrue);

        await tester.pump(const Duration(seconds: 2));
        expect(fired, isEmpty);
        expect(timeline.isActive, isTrue);
        await tester.pump(const Duration(milliseconds: 1499));
        expect(fired, isEmpty);
        await tester.pump(const Duration(milliseconds: 1));
        expect(fired, ['a']);
        await tester.pump(const Duration(milliseconds: 1500));
        expect(fired, ['a', 'b']);
        timeline.cancel();
        expect(timeline.isActive, isFalse);
        await tester.pump(const Duration(seconds: 5));
        expect(fired, ['a', 'b']);

        timeline
          ..start([(at: const Duration(seconds: 1), run: () => fired.add('x'))])
          ..start([
            (at: const Duration(seconds: 2), run: () => fired.add('y')),
          ]);
        await tester.pump();
        await tester.pump(const Duration(seconds: 3));
        expect(fired, ['a', 'b', 'y']);
        expect(timeline.isActive, isFalse);

        timeline
          ..start([(at: Duration.zero, run: () => fired.add('z'))])
          ..cancel();
        expect(timeline.isActive, isFalse);
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(fired, ['a', 'b', 'y']);
      },
    );

    test(
      '표시 방식: call · call-v1 · camera = modal, / · /settings · /albums/gangneung = 탭 컨테이너, 나머지 = push',
      () {
        Route<dynamic> gen(String n) =>
            onGenerateCameoRoute(RouteSettings(name: n));
        for (final n in ['/', '/settings', '/albums/gangneung']) {
          expect(gen(n), isA<CameoShellRoute<dynamic>>(), reason: n);
        }

        expect(
          onGenerateCameoTabRoute(
            const RouteSettings(name: '/albums/gangneung'),
          ),
          isA<CameoPageRoute<dynamic>>(),
        );
        expect(
          onGenerateCameoTabRoute(
            const RouteSettings(name: '/album'),
          ).settings.name,
          '/',
        );

        expect(
          (cameoRouteFor<void>(
                    const RouteSettings(name: '/welcome'),
                    entry: CameoPageEntry.fade,
                  )
                  as CameoPageRoute<void>)
              .entry,
          CameoPageEntry.fade,
        );
        for (final n in [
          '/welcome',
          '/phone',
          '/verify?phone=01012345678',
          '/profile',
          '/partner',
          '/permissions',
          '/connect',
          '/lab',
          '/foundation',
          '/album',
          '/album-gangneung',
          '/transcript?theme=dark',
          '/transcript?theme=photo',
        ]) {
          expect(gen(n), isA<CameoPageRoute<dynamic>>(), reason: n);
        }
        for (final n in ['/call?state=media-16x9', '/call-v1', '/camera']) {
          expect(gen(n), isA<CameoModalRoute<dynamic>>(), reason: n);
        }

        for (final n in ['/photo?section=sungsu&index=0', '/instant']) {
          final route = gen(n);
          expect(route, isA<CameoViewerRoute<dynamic>>(), reason: n);
          final viewer = route as CameoViewerRoute<dynamic>;
          expect(viewer.opaque, isFalse, reason: n);
          expect(viewer.source, isNull);
        }
        expect(gen('/capture'), isA<CameoShellRoute<dynamic>>());
        expect(gen('/home-v4'), isA<CameoPageRoute<dynamic>>());

        expect(
          cameoRouteFor<String>(const RouteSettings(name: '/camera')),
          isA<CameoModalRoute<String>>(),
        );

        expect(
          onGenerateCameoRoute(
            const RouteSettings(
              name: '/album',
              arguments: CameoPresentation.modal,
            ),
          ),
          isA<CameoModalRoute<dynamic>>(),
        );
        // settings.arguments = CameoLocation
        expect(
          gen('/transcript?theme=dark').settings.arguments,
          const CameoLocation('/transcript', {'theme': 'dark'}),
        );

        expect(gen('/nope'), isA<CameoShellRoute<dynamic>>());
        expect(gen('/nope').settings.arguments, const CameoLocation('/nope'));
      },
    );

    test('Lab routes match the independent reference fixture', () {
      final fixture =
          jsonDecode(File('test/fixtures/lab-sections.json').readAsStringSync())
              as List;
      expect(labSections.length, fixture.length);
      for (var i = 0; i < labSections.length; i++) {
        final section = labSections[i];
        final expected = fixture[i] as Map<String, dynamic>;
        expect(section.title, expected['title']);
        final entries = expected['entries'] as List;
        expect(section.entries.length, entries.length);
        for (var j = 0; j < entries.length; j++) {
          final entry = section.entries[j];
          final row = entries[j] as Map<String, dynamic>;
          expect(
            [entry.frame, entry.nodes, entry.description, entry.location],
            [row['frame'], row['nodes'], row['description'], row['location']],
            reason: '${section.title} #$j',
          );
        }
      }
    });

    test('Lab 인덱스 항목은 모두 알려진 라우트·유효한 파라미터 · v6 딥링크 망라', () {
      final all = [for (final s in labSections) ...s.entries];
      expect(
        [for (final s in labSections) s.title],
        [
          '앱 흐름 (v6)',
          '통화 · 보기 (v6)',
          '앨범',
          '통화 기록 상세',
          '통화 v1 (모달)',
          '카메라 v3 (모달)',
          '디자인 시스템 v6 (infra)',
          '디자인 시스템',
          '참고',
        ],
      );

      expect(
        [for (final e in all) e.resetsStack],
        [for (final e in all) labSections.first.entries.contains(e)],
      );
      for (final e in all) {
        final name = e.location;
        if (name == null) continue;
        final l = CameoLocation.parse(name);
        expect(CameoRoutes.isKnownPath(l.path), isTrue, reason: name);
        expect(l.toString(), name, reason: '정규화된 이름');
        if (l.path == CameoRoutes.transcriptPath && l.param('theme') != null) {
          expect(
            TranscriptTheme.values.map((t) => t.param),
            contains(l.param('theme')),
          );
          expect(l.param('v'), '3', reason: name);
        }
        if (l.path == CameoRoutes.callPath && l.param('state') != null) {
          expect(CallState.tryParse(l.param('state')), isNotNull);
        }
      }
      final names = all.map((e) => e.location).toSet();

      expect(names, contains(CameoRoutes.transcriptPath));
      for (final t in TranscriptTheme.values) {
        expect(
          names,
          contains(
            CameoLocation(CameoRoutes.transcriptPath, {
              'theme': t.param,
              'v': '3',
            }).toString(),
          ),
        );
      }

      const aliases = {CallState.sleepToast, CallState.media1x1};
      for (final st in CallState.values) {
        if (aliases.contains(st)) continue;
        expect(names, contains(CameoRoutes.call(state: st)), reason: st.param);
      }
      for (final v in PhotoSheetVariant.values) {
        expect(names, contains(CameoRoutes.call(sheet: v)));
      }

      for (final v in ['liked', 'deleted', 'select']) {
        expect(names, contains('/?session=member&view=$v'));
      }
      expect(names, contains('/capture?session=member&review=1'));
      expect(names, contains('/verify?session=guest&state=success'));
      expect(names, contains('/partner?session=onboarding&state=done'));
      for (final scene in GlassV6Scene.values) {
        final prefix = CameoRoutes.glassV6Location(scene);
        expect(
          names.any((n) => n != null && n.startsWith(prefix)),
          isTrue,
          reason: scene.name,
        );
      }
      expect(names, contains(CameoRoutes.instant));
      expect(names, contains(CameoRoutes.photo(sectionId: 'sungsu', index: 0)));
    });

    test('놓을 때 판정 = RN JS stack 과 같은 선형 혼합', () {
      bool push(double dragFraction, double v) => shouldCompleteDismiss(
        drag: dragFraction * 400,
        velocity: v,
        extent: 400,
        completeProgress: CameoMotion.transitionPushCompleteProgress,
        completeVelocity: CameoMotion.transitionPushCompleteVelocity,
      );
      expect(push(0.49, 0), isFalse);
      expect(push(0.51, 0), isTrue);
      expect(push(0, 490), isFalse);
      expect(push(0, 510), isTrue);
      expect(push(0.3, 250), isTrue); // 0.6 + 0.5
      expect(push(0.2, 250), isFalse); // 0.4 + 0.5
      expect(push(0.9, -600), isFalse); // 1.8 − 1.2
    });

    test('환경 변수: iOS 용 libc getenv 경로가 Platform.environment 와 같다', () {
      expect(libcGetenv('PATH'), isNotNull);
      expect(libcGetenv('PATH'), Platform.environment['PATH']);
      expect(libcGetenv('CAMEO_ROUTE_SURELY_UNSET_7F3A'), isNull);
      expect(readEnvironmentVariable('PATH'), Platform.environment['PATH']);
    });

    test('CAMEO_ROUTE 시작 라우트 (없거나 모르면 홈 /)', () {
      expect(resolveInitialRoute(environment: {}), '/');
      expect(resolveInitialRoute(environment: {'CAMEO_ROUTE': ''}), '/');
      expect(resolveInitialRoute(environment: {'CAMEO_ROUTE': '/lab'}), '/lab');
      expect(
        resolveInitialRoute(environment: {'CAMEO_ROUTE': '/?demo=flow'}),
        '/?demo=flow',
      );
      expect(
        resolveInitialRoute(environment: {'CAMEO_ROUTE': '/camera'}),
        '/camera',
      );
      expect(
        resolveInitialRoute(
          environment: {'CAMEO_ROUTE': '/transcript?theme=dark'},
        ),
        '/transcript?theme=dark',
      );
      expect(
        resolveInitialRoute(environment: {'CAMEO_ROUTE': 'call-v1'}),
        '/call-v1',
      );
      expect(resolveInitialRoute(environment: {'CAMEO_ROUTE': '/nope'}), '/');

      expect(
        resolveInitialRoute(
          environment: {'CAMEO_ROUTE': '/settings?session=member'},
        ),
        '/settings?session=member',
      );
    });

    test(
      'CameoLaunch: session · partner=none 은 세션으로, 화면에는 깨끗한 위치 · demo=flow = guest + 웰컴',
      () {
        final member = CameoLaunch.parse('/settings?session=member');
        expect(member.location, const CameoLocation('/settings'));
        expect(member.devSession, DevSessionKind.member);
        expect(member.partnerNone, isFalse);
        expect(member.flowDemo, isFalse);
        final none = CameoLaunch.parse('/?session=member&partner=none');
        expect(none.location, const CameoLocation('/'));
        expect(none.partnerNone, isTrue);
        final verify = CameoLaunch.parse(
          '/verify?session=guest&phone=01012345678',
        );
        expect(
          verify.location,
          const CameoLocation('/verify', {'phone': '01012345678'}),
        );
        expect(verify.devSession, DevSessionKind.guest);
        final flow = CameoLaunch.parse('/?demo=flow');
        expect(flow.flowDemo, isTrue);
        expect(flow.devSession, DevSessionKind.guest);
        expect(flow.location, const CameoLocation('/welcome'));
        final plain = CameoLaunch.parse('/album?demo=1');
        expect(plain.devSession, isNull);
        expect(plain.location, const CameoLocation('/album', {'demo': '1'}));

        expect(CameoLaunch.parse('/?session=admin').devSession, isNull);

        final empty = CameoLaunch.parse('/?session=member&album=empty');
        expect(empty.location, const CameoLocation('/'));
        expect(empty.albumEmpty, isTrue);
        expect(empty.albumReset, isTrue);
        expect(member.albumEmpty, isNull);
        expect(member.albumReset, isFalse);
        expect(plain.albumReset, isNull);
        expect(flow.albumReset, isFalse);
        expect(
          CameoLaunch.parse('/capture?album=full').location,
          const CameoLocation('/capture'),
        );
        expect(CameoLaunch.parse('/?album=full').albumReset, isFalse);
      },
    );
  });

  group('스프링 타이밍 (RN withSpring 과 같은 물리)', () {
    test('정지 시간 = SpringSimulation 이 tolerance 안에 처음 들어오는 시각', () {
      for (final entry in CameoSprings.byName.entries) {
        final t = springSettleSeconds(entry.value);
        final sim = cameoSpringSimulation(entry.value, from: 0, to: 1);
        expect(sim.isDone(t), isTrue, reason: entry.key);
        expect(sim.isDone(t - 0.001), isFalse, reason: entry.key);
        expect(t, inInclusiveRange(0.1, 2.0), reason: entry.key);
      }
    });

    test('push/modal 전환 = smooth, transitionDuration = 정지 시간', () {
      expect(CameoMotion.transitionPushSpring, same(CameoSprings.smooth));
      expect(CameoMotion.transitionModalSpring, same(CameoSprings.smooth));
      final d = springSettleDuration(CameoSprings.smooth);
      expect(
        d.inMicroseconds,
        (springSettleSeconds(CameoSprings.smooth) * 1e6).round(),
      );
    });

    test('SpringCurve: 0 → 0, 1 → 1, 중간 = x(t · 정지 시간)', () {
      final curve = SpringCurve(CameoSprings.smooth);
      final sim = cameoSpringSimulation(CameoSprings.smooth, from: 0, to: 1);
      final secs = springSettleSeconds(CameoSprings.smooth);
      expect(curve.transform(0), 0);
      expect(curve.transform(1), 1);
      for (final t in [0.1, 0.25, 0.5, 0.75]) {
        expect(curve.transform(t), closeTo(sim.x(t * secs), 1e-9));
      }
      expect(curve.duration, springSettleDuration(CameoSprings.smooth));
    });

    test('rubberBand: f(0)=0, f(x)<x, f<d, 기울기(0)=계수', () {
      const d = 852.0;
      expect(rubberBand(0, d), 0);
      var prev = 0.0;
      for (final x in [10.0, 100.0, 400.0, 2000.0, 1e6]) {
        final f = rubberBand(x, d);
        expect(f, greaterThan(prev));
        expect(f, lessThan(x));
        expect(f, lessThan(d));
        expect(rubberBand(-x, d), -f);
        prev = f;
      }
      expect(rubberBandSlope(0, d), CameoMotion.rubberBandCoefficient);

      const x = 200.0;
      const h = 1e-3;
      expect(
        rubberBandSlope(x, d),
        closeTo((rubberBand(x + h, d) - rubberBand(x - h, d)) / (2 * h), 1e-6),
      );
    });
  });

  group('푸시 전환', () {
    testWidgets('스프링 정지 시간에 끝나고, 나가는 화면은 폭 × parallax 만큼 밀린다', (tester) async {
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_app(nav));
      final width =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;
      final route = CameoPageRoute<void>(builder: (_) => const _Page('b'));
      nav.currentState!.push(route);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      final p = route.animation!.value;
      expect(p, inExclusiveRange(0, 1));
      expect(_left(tester, 'b'), closeTo((1 - p) * width, 0.5));
      expect(
        _left(tester, '/'),
        closeTo(-p * CameoMotion.transitionPushParallax * width, 0.5),
      );

      final settle = springSettleDuration(CameoSprings.smooth);
      await tester.pump(
        settle - const Duration(milliseconds: 120) - _frame * 2,
      );
      expect(route.animation!.status, AnimationStatus.forward);
      await tester.pump(_frame * 3);
      expect(route.animation!.status, AnimationStatus.completed);
      expect(route.animation!.value, 1.0);
      expect(_left(tester, 'b'), 0);
    });

    testWidgets(
      '새 화면의 첫 프레임이 오래 걸려도 스프링 앞부분을 건너뛰지 않는다 (RN JS stack 과 같은 시작 규칙)',
      (tester) async {
        final nav = GlobalKey<NavigatorState>();
        await tester.pumpWidget(_app(nav));
        final width =
            tester.view.physicalSize.width / tester.view.devicePixelRatio;
        final route = CameoPageRoute<void>(builder: (_) => const _Page('b'));
        nav.currentState!.push(route);
        await tester.pump();
        expect(route.animation!.status, AnimationStatus.forward);
        expect(route.animation!.value, 0);

        await tester.pump(const Duration(milliseconds: 120));
        expect(route.animation!.value, 0);
        expect(_left(tester, 'b'), closeTo(width, 0.5));

        await tester.pump(_frame);
        final expected = cameoSpringSimulation(
          CameoMotion.transitionPushSpring,
          from: 0,
          to: 1,
        ).x(_frame.inMicroseconds / Duration.microsecondsPerSecond);
        expect(route.animation!.value, closeTo(expected, 1e-9));
        expect(route.animation!.value, inExclusiveRange(0, 0.1));
        await tester.pumpAndSettle();
        expect(_left(tester, 'b'), 0);
      },
    );

    testWidgets('모달 표시도 첫 프레임 뒤에 시작하고, pop 은 바로 시작한다', (tester) async {
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_app(nav));
      final route = CameoModalRoute<void>(builder: (_) => const _Page('m'));
      nav.currentState!.push(route);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      expect(route.animation!.value, 0);
      await tester.pumpAndSettle();
      expect(route.animation!.value, 1);

      nav.currentState!.pop();
      await tester.pump();
      await tester.pump(_frame);
      expect(route.animation!.value, lessThan(1));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('page-m')), findsNothing);
    });

    testWidgets('엣지 스와이프: 폭의 절반 넘게 끌면 pop, 조금 끌면 복귀', (tester) async {
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_app(nav));
      nav.currentState!.push(
        CameoPageRoute<void>(builder: (_) => const _Page('b')),
      );
      await tester.pumpAndSettle();
      final width =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;

      final gesture = await tester.startGesture(const Offset(4, 300));
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(8, 0));
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(_left(tester, 'b'), greaterThan(0));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('page-b')), findsOneWidget);
      expect(_left(tester, 'b'), 0);

      await tester.timedDragFrom(
        const Offset(4, 300),
        Offset(width * 0.7, 0),
        const Duration(seconds: 1),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('page-b')), findsNothing);
      expect(_left(tester, '/'), 0);
      expect(nav.currentState!.userGestureInProgress, isFalse);
    });

    testWidgets('엣지 스와이프: 빠르게 튕기면 짧아도 pop', (tester) async {
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_app(nav));
      nav.currentState!.push(
        CameoPageRoute<void>(builder: (_) => const _Page('b')),
      );
      await tester.pumpAndSettle();
      await tester.flingFrom(const Offset(4, 300), const Offset(80, 0), 1500);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('page-b')), findsNothing);
    });

    testWidgets('가장자리 밖에서 시작한 드래그는 뒤로가기가 아니다', (tester) async {
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_app(nav));
      nav.currentState!.push(
        CameoPageRoute<void>(builder: (_) => const _Page('b')),
      );
      await tester.pumpAndSettle();
      await tester.flingFrom(
        const Offset(200, 300),
        const Offset(300, 0),
        1500,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('page-b')), findsOneWidget);
    });
  });

  group('모달 전환', () {
    testWidgets('아래에서 올라오고, 아래로 1:1 로 끌리며, 빠르게 내리면 닫힌다', (tester) async {
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_app(nav));
      final height =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;
      final route = CameoModalRoute<void>(builder: (_) => const _Page('m'));
      nav.currentState!.push(route);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      final p = route.animation!.value;
      expect(_top(tester, 'm'), closeTo((1 - p) * height, 0.5));
      expect(_left(tester, '/'), 0);
      await tester.pumpAndSettle();
      expect(_top(tester, 'm'), 0);

      final gesture = await tester.startGesture(const Offset(300, 200));
      await gesture.moveBy(const Offset(0, 30));
      await tester.pump(const Duration(milliseconds: 50));
      final before = _top(tester, 'm');
      for (var i = 0; i < 5; i++) {
        await gesture.moveBy(const Offset(0, 10));
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(_top(tester, 'm') - before, closeTo(50, 0.5));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(_top(tester, 'm'), 0);
      expect(find.byKey(const ValueKey('page-m')), findsOneWidget);

      await tester.flingFrom(
        const Offset(300, 200),
        const Offset(0, 120),
        2000,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('page-m')), findsNothing);
      expect(nav.currentState!.userGestureInProgress, isFalse);
    });

    testWidgets('높이의 dismissProgress(50%) 넘게 천천히 끌면 닫힌다', (tester) async {
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_app(nav));
      final height =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;
      nav.currentState!.push(
        CameoModalRoute<void>(builder: (_) => const _Page('m')),
      );
      await tester.pumpAndSettle();
      await tester.timedDragFrom(
        const Offset(300, 100),
        Offset(0, height * (CameoMotion.transitionModalDismissProgress + 0.05)),
        const Duration(seconds: 2),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('page-m')), findsNothing);
    });

    testWidgets('위로 끌면 러버밴드로 덜 끌리고, 놓으면 제자리로', (tester) async {
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_app(nav));
      final height =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;
      nav.currentState!.push(
        CameoModalRoute<void>(builder: (_) => const _Page('m')),
      );
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(const Offset(300, 500));
      await gesture.moveBy(const Offset(0, -30));
      await tester.pump(const Duration(milliseconds: 16));
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(0, -20));
        await tester.pump(const Duration(milliseconds: 16));
      }
      final top = _top(tester, 'm');
      expect(top, lessThan(0));
      expect(top.abs(), lessThan(200));
      const dragged = -(30.0 + 200);
      expect(top, closeTo(rubberBand(dragged, height), 1));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(_top(tester, 'm'), 0);
      expect(find.byKey(const ValueKey('page-m')), findsOneWidget);
    });
  });

  group('모션 감소', () {
    testWidgets(
      'iOS 동작 줄이기(reduceMotion 만) → CameoReducedMotionScope 아래 disableAnimations · 끄면 다시 false',
      (tester) async {
        bool? seen;
        await tester.pumpWidget(
          CameoReducedMotionScope(
            child: Builder(
              builder: (context) {
                seen = MediaQuery.disableAnimationsOf(context);
                return const SizedBox();
              },
            ),
          ),
        );
        expect(seen, isFalse);

        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(reduceMotion: true);
        await tester.pump();
        expect(seen, isTrue);
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
        await tester.pump();
        expect(seen, isFalse);
      },
    );

    testWidgets('disableAnimations → durationBase 페이드', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_app(nav));
      final route = CameoPageRoute<void>(builder: (_) => const _Page('b'));
      nav.currentState!.push(route);
      await tester.pump();
      await tester.pump();
      expect(route.transitionDuration, CameoMotion.durationBase);
      await tester.pump(CameoMotion.durationBase + _frame);
      expect(route.animation!.status, AnimationStatus.completed);
      expect(_left(tester, 'b'), 0);
    });

    testWidgets('모달을 위로 끌어도 움직이지 않는다 (이동 없는 페이드 — RN forReducedMotionFade)', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_app(nav));
      nav.currentState!.push(
        CameoModalRoute<void>(builder: (_) => const _Page('m')),
      );
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(const Offset(300, 500));
      await gesture.moveBy(const Offset(0, -30));
      await tester.pump(_frame);
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(0, -20));
        await tester.pump(_frame);
      }
      expect(_top(tester, 'm'), 0);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(_top(tester, 'm'), 0);
      expect(find.byKey(const ValueKey('page-m')), findsOneWidget);
      expect(nav.currentState!.userGestureInProgress, isFalse);
    });
  });

  group('CameoNav.pop', () {
    testWidgets('같은 화면에서 두 번 불려도 그 화면만 닫힌다 (아래 라우트는 남는다)', (tester) async {
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_app(nav));
      nav.currentState!.push(
        CameoModalRoute<void>(builder: (_) => const _Page('m')),
      );
      await tester.pumpAndSettle();
      final modal = tester.element(find.byKey(const ValueKey('page-m')));

      expect(CameoNav.pop(modal), isTrue);
      expect(CameoNav.pop(modal), isFalse);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('page-m')), findsNothing);
      expect(find.byKey(const ValueKey('page-/')), findsOneWidget);
    });

    testWidgets('하나뿐인 라우트는 닫지 않는다 (빈 Navigator 방지)', (tester) async {
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_app(nav));
      expect(
        CameoNav.pop(tester.element(find.byKey(const ValueKey('page-/')))),
        isFalse,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('page-/')), findsOneWidget);
    });
  });

  group('CameoNav.push · presentModal (연타 가드 — RN useScreenNav)', () {
    testWidgets('같은 화면에서 연달아 불려도 한 번만 쌓인다 (두 번째는 맨 위가 아니라 무시)', (tester) async {
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_app(nav));
      final home = tester.element(find.byKey(const ValueKey('page-/')));

      CameoNav.push<void>(home, '/a');
      await tester.pump(_frame);
      CameoNav.push<void>(home, '/a');
      CameoNav.presentModal<void>(home, '/m');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('page-/a')), findsOneWidget);
      expect(find.byKey(const ValueKey('page-/m')), findsNothing);

      CameoNav.push<void>(
        tester.element(find.byKey(const ValueKey('page-/a'))),
        '/b',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('page-/b')), findsOneWidget);
    });

    testWidgets('맨 위가 아닌 화면의 presentCamera 는 열지 않고 null', (tester) async {
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_app(nav));
      final home = tester.element(find.byKey(const ValueKey('page-/')));
      CameoNav.push<void>(home, '/a');
      await tester.pumpAndSettle();
      expect(CameoNav.isTop(home), isFalse);
      expect(await CameoNav.presentCamera(home), isNull);
      await tester.pumpAndSettle();
      expect(find.byType(CameraScreen), findsNothing);
    });
  });

  group('CameoNav.dismissModalThen (통화 종료 → 앨범)', () {
    testWidgets('모달 닫힘 전환이 끝난 뒤에 푸시한다 — 닫히는 동안에는 새 화면이 없다', (tester) async {
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_app(nav));
      final modal = CameoModalRoute<void>(builder: (_) => const _Page('m'));
      nav.currentState!.push(modal);
      await tester.pumpAndSettle();

      CameoNav.dismissModalThen(
        tester.element(find.byKey(const ValueKey('page-m'))),
        '/album',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byKey(const ValueKey('page-m')), findsOneWidget);
      expect(find.byKey(const ValueKey('page-/album')), findsNothing);
      expect(modal.animation!.status, AnimationStatus.reverse);

      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('page-m')), findsNothing);
      expect(find.byKey(const ValueKey('page-/album')), findsOneWidget);

      expect(nav.currentState!.canPop(), isTrue);
      nav.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('page-/')), findsOneWidget);
    });

    testWidgets('두 번 불려도(닫기와 종료를 같은 프레임에) 한 번만 닫고 한 번만 푸시한다', (tester) async {
      final nav = GlobalKey<NavigatorState>();
      final pushed = <String>[];
      await tester.pumpWidget(
        _app(
          nav,
          onGenerateRoute: (s) {
            if (s.name != '/') pushed.add(s.name!);
            return CameoPageRoute<void>(
              settings: s,
              builder: (_) => _Page(s.name ?? '?'),
            );
          },
        ),
      );
      nav.currentState!.push(
        CameoModalRoute<void>(builder: (_) => const _Page('m')),
      );
      await tester.pumpAndSettle();
      final modal = tester.element(find.byKey(const ValueKey('page-m')));
      expect(CameoNav.dismissModalThen(modal, '/album'), isTrue);
      expect(CameoNav.dismissModalThen(modal, '/album'), isFalse);
      expect(CameoNav.pop(modal), isFalse);
      await tester.pumpAndSettle();
      expect(pushed, ['/album']);
      expect(find.byKey(const ValueKey('page-/')), findsNothing);
      expect(find.byKey(const ValueKey('page-/album')), findsOneWidget);
      nav.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('page-/')), findsOneWidget);
    });
  });

  group('앱 시작 (main.dart CameoApp — v4 세션 가드)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      FlowDemo.resetForTesting();
    });
    tearDown(FlowDemo.resetForTesting);

    testWidgets('저장된 세션이 없으면: 로드 전 스플래시(내비게이터 없음) → 웰컴 · 루트 색 모드 light', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(393, 852)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const CameoApp());
      expect(find.byType(WelcomeScreen), findsNothing);
      await tester.pump();

      for (var i = 0; i < 125; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(kCameoRootColorMode, CameoColorMode.light);

      await tester.tap(find.text(labV6.welcome.cta));
      await tester.pumpAndSettle();
      expect(find.byType(PhoneScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('흐름 데모 v6 (등록부 · 표 — docs/v6-plan.md §5 · docs/v6-notes-infra.md R6)', () {
    setUp(FlowDemo.resetForTesting);
    tearDown(FlowDemo.resetForTesting);

    const expected = [
      (1500, 'welcome.start', 'phone', false, false),
      (600, 'phone.type', 'phone', true, false),
      (500, 'phone.submit', 'verify', false, false),
      (1800, 'verify.autofill', 'profile', false, false),
      (600, 'profile.type', 'profile', true, false),
      (500, 'profile.submit', 'partner', false, false),
      (1200, 'partner.type', 'permissions', false, false),
      (1200, 'permissions.allow', 'home', false, false),
      (1500, 'home.scroll', 'home', true, false),
      (1000, 'home.openPhoto', 'photo', false, false),
      (1500, 'viewer.strip', 'photo', true, false),
      (1200, 'viewer.like', 'photo', true, false),
      (1200, 'back', 'home', false, false),
      (1500, 'home.liked', 'home', true, false),
      (1500, 'liked.close', 'home', true, false),
      (1200, 'home.deleted', 'home', true, false),
      (1500, 'deleted.close', 'home', true, false),
      (1200, 'home.select', 'home', true, false),
      (800, 'select.toggle', 'home', true, false),
      (1500, 'select.close', 'home', true, false),
      (1000, 'home.call', 'call', false, false),
      (1500, 'call.volume', 'call', true, false),
      (1500, 'call.highlight', 'call', true, false),
      (2000, 'call.camera', 'call', true, false),
      (1500, 'sheet.live', 'camera', false, false),
      (2000, 'camera.shutter', 'call', false, false),
      (2500, 'call.closeCard', 'call', true, false),
      (1200, 'call.sleep', 'call', true, false),
      (2500, 'aod.end', 'call', true, false),
      (1500, 'call.endCall', 'home', false, false),
      (1500, 'home.openCallCard', 'transcript', false, false),
      (2500, 'back', 'home', false, false),
      (1200, 'tabs.camera', 'capture', false, false),
      (1500, 'camera.shutter', 'capture', true, false),
      (1500, 'review.send', 'capture', true, false),
      (3200, 'camera.openShared', 'photo', false, false),
      (2000, 'back', 'capture', false, false),
      (1200, 'tabs.settings', 'settings', false, false),
      (1500, 'settings.logout', 'settings', true, false),
      (1200, 'sheet.confirm', 'welcome', false, false),
    ];

    test('표 = plan §5 (40 단계 · afterMs, action, to, settle, pending)', () {
      expect(flowDemoTimeline, hasLength(40));
      expect([
        for (final s in flowDemoTimeline)
          (s.afterMs, s.action.id, s.to.name, s.settle, s.pending),
      ], expected);
      expect(flowDemoStart, FlowDemoScreen.welcome);
      expect(flowDemoWaitLimit, const Duration(milliseconds: 15000));
      expect({
        for (final e in flowDemoV5Aliases.entries) e.key.id: e.value.id,
      }, isEmpty);
    });

    test('Flow timeline matches the independent reference fixture', () {
      final expected = jsonDecode(
        File('test/fixtures/flow-timeline.json').readAsStringSync(),
      );
      expect([
        for (final step in flowDemoTimeline)
          [
            step.afterMs,
            step.action.id,
            step.to.name,
            step.settle,
            step.pending,
          ],
      ], expected);
    });

    test('동작 이름 = RN 문자열 (v6 §5 + v4 등록만)', () {
      expect(
        [for (final a in FlowDemoAction.values) a.id],
        [
          'welcome.start',
          'phone.type',
          'phone.submit',
          'verify.autofill',
          'profile.type',
          'profile.submit',
          'partner.type',
          'permissions.allow',
          'home.scroll',
          'home.openPhoto',
          'viewer.strip',
          'viewer.like',
          'back',
          'home.liked',
          'liked.close',
          'home.deleted',
          'deleted.close',
          'home.select',
          'select.toggle',
          'select.close',
          'home.call',
          'call.volume',
          'call.highlight',
          'call.camera',
          'sheet.live',
          'camera.shutter',
          'call.closeCard',
          'call.sleep',
          'aod.end',
          'call.endCall',
          'home.openCallCard',
          'tabs.camera',
          'review.send',
          'camera.openShared',
          'tabs.settings',
          'settings.logout',
          'sheet.confirm',
          'home.openAlbum',
          'home.openDayAlbum',
          'gangneung.openAlbum',
          'album.openPhotoCard',
        ],
      );
    });

    test(
      '라우트 이름 → 흐름 화면 (RN flowScreenOfRouteName — v6: /instant = photo · /?view= = home)',
      () {
        final cases = {
          '/welcome': FlowDemoScreen.welcome,
          '/phone': FlowDemoScreen.phone,
          '/verify?phone=01012345678': FlowDemoScreen.verify,
          '/verify?phone=01012345678&state=success': FlowDemoScreen.verify,
          '/profile': FlowDemoScreen.profile,
          '/partner': FlowDemoScreen.partner,
          '/partner?state=done': FlowDemoScreen.partner,
          '/permissions': FlowDemoScreen.permissions,
          '/': FlowDemoScreen.home,
          '/?view=liked': FlowDemoScreen.home,
          '/photo?section=sungsu&index=0': FlowDemoScreen.photo,
          '/instant': FlowDemoScreen.photo,
          '/transcript?theme=photo': FlowDemoScreen.transcript,
          '/call?state=media-16x9&sheet=multi': FlowDemoScreen.call,
          '/camera': FlowDemoScreen.camera,
          '/capture': FlowDemoScreen.capture,
          '/capture?review=1': FlowDemoScreen.capture,
          '/settings': FlowDemoScreen.settings,
          '/albums/gangneung': FlowDemoScreen.gangneung,
          '/album': FlowDemoScreen.album,
        };
        cases.forEach((name, screen) {
          expect(FlowDemoScreen.ofRouteName(name), screen, reason: name);
        });

        for (final n in ['/lab', '/album-gangneung', '/connect', '/home-v4']) {
          expect(FlowDemoScreen.ofRouteName(n), isNull, reason: n);
        }
        expect(FlowDemoScreen.ofRouteName(null), isNull);
      },
    );

    test(
      'v5 별칭 없음 (call-camera v6): aod.end · camera.openShared 는 v6 등록만 — 없으면 거부, settle 은 제 동작만 센다',
      () {
        final calls = <String>[];
        expect(FlowDemo.run(FlowDemoAction.aodEnd), isFalse);
        final v6 = FlowDemo.register(
          FlowDemoAction.aodEnd,
          () => calls.add('end'),
        );
        expect(FlowDemo.run(FlowDemoAction.aodEnd), isTrue);
        expect(calls, ['end']);
        FlowDemo.settle(FlowDemoAction.aodEnd);
        expect(FlowDemo.settleCount(FlowDemoAction.aodEnd), 1);
        v6();
        expect(FlowDemo.run(FlowDemoAction.aodEnd), isFalse);
        expect(FlowDemo.run(FlowDemoAction.cameraOpenShared), isFalse);
      },
    );

    test('settle: 동작별로 센다 (단조 증가) · 초기화하면 0', () {
      expect(FlowDemo.settleCount(FlowDemoAction.phoneType), 0);
      FlowDemo.settle(FlowDemoAction.phoneType);
      FlowDemo.settle(FlowDemoAction.phoneType);
      FlowDemo.settle(FlowDemoAction.settingsLogout);
      expect(FlowDemo.settleCount(FlowDemoAction.phoneType), 2);
      expect(FlowDemo.settleCount(FlowDemoAction.settingsLogout), 1);
      expect(FlowDemo.settleCount(FlowDemoAction.profileType), 0);
      FlowDemo.resetForTesting();
      expect(FlowDemo.settleCount(FlowDemoAction.phoneType), 0);
      expect(FlowDemo.isActive, isFalse);
    });

    test('등록: 마지막(맨 위) 등록이 불리고, 해제하면 그 아래 등록으로', () {
      final calls = <String>[];
      final unregisterA = FlowDemo.register(
        FlowDemoAction.homeOpenAlbum,
        () => calls.add('a'),
      );
      final unregisterB = FlowDemo.register(
        FlowDemoAction.homeOpenAlbum,
        () => calls.add('b'),
      );
      expect(FlowDemo.isRegistered(FlowDemoAction.homeOpenAlbum), isTrue);
      expect(FlowDemo.run(FlowDemoAction.homeOpenAlbum), isTrue);
      unregisterB();
      expect(FlowDemo.run(FlowDemoAction.homeOpenAlbum), isTrue);
      unregisterA();
      expect(FlowDemo.isRegistered(FlowDemoAction.homeOpenAlbum), isFalse);

      expect(FlowDemo.run(FlowDemoAction.homeOpenAlbum), isFalse);
      expect(calls, ['b', 'a']);
    });

    test(
      '거부: 준비 안 됨(isReady false)이면 핸들러를 부르지 않고, 핸들러가 false 면 거부 · 거부는 마지막 실행 동작을 바꾸지 않는다',
      () {
        var ready = false;
        var calls = 0;
        final unregister = FlowDemo.register(
          FlowDemoAction.homeOpenAlbum,
          () => calls++,
          isReady: () => ready,
        );
        expect(FlowDemo.run(FlowDemoAction.homeOpenAlbum), isFalse);
        expect(calls, 0);
        ready = true;
        expect(FlowDemo.run(FlowDemoAction.homeOpenAlbum), isTrue);
        expect(calls, 1);
        unregister();

        var accept = false;
        final unregisterRefusing = FlowDemo.register(
          FlowDemoAction.homeOpenAlbum,
          () => accept,
        );
        expect(FlowDemo.run(FlowDemoAction.homeOpenAlbum), isFalse);
        accept = true;
        expect(FlowDemo.run(FlowDemoAction.homeOpenAlbum), isTrue);
        unregisterRefusing();
      },
    );

    testWidgets(
      'back = 잎 라우트 pop (내비게이터를 주면 그 맨 위) · 셔터 대체는 바로 앞 실행 동작이 call.camera 일 때만',
      (tester) async {
        final nav = GlobalKey<NavigatorState>();
        await tester.pumpWidget(_app(nav));
        Object? cameraResult = 'pending';
        nav.currentState!.push(
          CameoPageRoute<void>(builder: (_) => const _Page('b')),
        );
        await tester.pumpAndSettle();

        expect(FlowDemo.run(FlowDemoAction.back), isTrue);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('page-b')), findsNothing);

        expect(FlowDemo.run(FlowDemoAction.back), isFalse);
        expect(
          FlowDemo.run(FlowDemoAction.back, navigator: nav.currentState),
          isFalse,
        );

        final unregister = FlowDemo.register(FlowDemoAction.callCamera, () {
          nav.currentState!
              .push<Object?>(
                CameoModalRoute<Object?>(builder: (_) => const _Page('cam')),
              )
              .then((r) => cameraResult = r);
        });
        addTearDown(unregister);

        expect(
          FlowDemo.run(
            FlowDemoAction.cameraShutter,
            navigator: nav.currentState,
          ),
          isFalse,
        );
        expect(FlowDemo.run(FlowDemoAction.callCamera), isTrue);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('page-cam')), findsOneWidget);

        expect(FlowDemo.run(FlowDemoAction.homeCall), isFalse);
        expect(FlowDemo.run(FlowDemoAction.cameraShutter), isTrue);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('page-cam')), findsNothing);
        expect(cameraResult, CapturedPhoto.placeholder());
      },
    );
  });

  group('Lab 인덱스', () {
    testWidgets('모든 항목을 그리고, 탭하면 그 라우트 이름으로 연다', (tester) async {
      final nav = GlobalKey<NavigatorState>();
      final pushed = <String>[];
      await tester.pumpWidget(
        _app(
          nav,
          onGenerateRoute: (s) {
            if (s.name == '/') {
              return CameoPageRoute<void>(
                settings: s,
                builder: (_) => const LabScreen(),
              );
            }
            pushed.add(s.name!);
            return CameoPageRoute<void>(
              settings: s,
              builder: (_) => _Page(s.name!),
            );
          },
        ),
      );
      final entries = [for (final s in labSections) ...s.entries];
      for (final e in entries) {
        await tester.scrollUntilVisible(
          find.text(e.description),
          200,
          scrollable: find.byType(Scrollable),
        );
        expect(find.text(e.description), findsOneWidget);
      }

      await tester.tap(find.text('화면 아님 — 앨범 샘플 사진 원본 (에셋만)'));
      await tester.pumpAndSettle();
      expect(pushed, isEmpty);
      final target = entries.firstWhere((e) => e.location == '/transcript');
      await tester.scrollUntilVisible(
        find.text(target.description),
        -200,
        scrollable: find.byType(Scrollable),
      );
      await tester.ensureVisible(find.text(target.description));
      await tester.pumpAndSettle();
      await tester.tap(find.text(target.description));
      await tester.pumpAndSettle();
      expect(pushed, ['/transcript']);
    });
  });
}
