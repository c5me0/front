// Regression coverage for v6 services. Preserve behavior, layout, and interaction
// expectations.

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cameo/navigation/navigation.dart';
import 'package:cameo/state/captured_photo.dart';
import 'package:cameo/state/device_services.dart';
import 'package:cameo/state/notification_prefs.dart';
import 'package:cameo/state/session.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('사진 불러오기 (PhotoPickerService — RN pickPhotos)', () {
    test('Simulated: 정해 둔 결과 · limit 만큼 · 요청 기록 · 빈 목록 = 취소', () async {
      final a = CapturedPhoto.placeholder();
      final picker = SimulatedPhotoPickerService(result: [a, a, a]);
      expect(await picker.pickPhotos(), hasLength(3));
      expect(await picker.pickPhotos(limit: 2), hasLength(2));
      picker.result = [];
      expect(await picker.pickPhotos(limit: 1), isEmpty);
      expect(picker.requests, [null, 2, 1]);
      expect(
        SimulatedPhotoPickerService().result.single.source,
        CapturedPhotoSource.placeholder,
      );
    });

    test('DeviceServices: simulated = Simulated 선택기 · 생성자에서 빠지면 시스템', () {
      final sim = DeviceServices.simulated();
      expect(sim.photoPicker, isA<SimulatedPhotoPickerService>());
      final bare = DeviceServices(
        volume: SimulatedVolumeService(initial: 1),
        brightness: SimulatedBrightnessService(system: 1),
        share: SimulatedShareService(),
      );
      expect(bare.photoPicker, same(SystemPhotoPickerService.shared));
    });

    testWidgets('PhotoPickerService.of = 트리의 서비스 (없으면 시스템)', (tester) async {
      final services = DeviceServices.simulated();
      late PhotoPickerService found;
      late PhotoPickerService outside;
      await tester.pumpWidget(
        Column(
          children: [
            Builder(
              builder: (context) {
                outside = PhotoPickerService.of(context);
                return const SizedBox();
              },
            ),
            DeviceServicesScope(
              services: services,
              child: Builder(
                builder: (context) {
                  found = PhotoPickerService.of(context);
                  return const SizedBox();
                },
              ),
            ),
          ],
        ),
      );
      expect(found, same(services.photoPicker));
      expect(outside, same(SystemPhotoPickerService.shared));
    });

    testWidgets(
      'photoOfFile: 파일 경로 → library 사진 · 크기 = 이미지 헤더 · 읽지 못하면 0 · 그리기 = FileImage',
      (tester) async {
        await tester.runAsync(() async {
          final dir = await Directory.systemTemp.createTemp('cameo-picker');
          addTearDown(() => dir.delete(recursive: true));
          // 3 × 2 PNG
          final recorder = ui.PictureRecorder();
          ui.Canvas(recorder).drawRect(
            const Rect.fromLTWH(0, 0, 3, 2),
            ui.Paint()..color = const Color(0xFF000000),
          );
          final image = await recorder.endRecording().toImage(3, 2);
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('${dir.path}/picked.png');
          await file.writeAsBytes(png!.buffer.asUint8List());
          final photo = await photoOfFile(file.path);
          expect(photo.uri, file.path);
          expect(photo.source, CapturedPhotoSource.library);
          expect((photo.width, photo.height), (3.0, 2.0));
          expect(photo.image, isA<FileImage>());
          final missing = await photoOfFile('${dir.path}/none.png');
          expect((missing.width, missing.height), (0.0, 0.0));
        });
      },
    );
  });

  group('알림 설정 (NotificationPrefs — RN useNotificationPrefs)', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('기본 켬 · 저장 (세션 prefs JSON) · 로그아웃 = 초기화', () async {
      final session = SessionController();
      await session.load(dev: DevSessionKind.member);
      var prefs = NotificationPrefs.from(session);
      expect((prefs.callAlerts, prefs.highlightAlerts), (true, true));
      prefs.setCallAlerts(false);
      prefs = NotificationPrefs.from(session);
      expect((prefs.callAlerts, prefs.highlightAlerts), (false, true));
      prefs.setHighlightAlerts(false);
      expect(session.session.prefs.highlightAlerts, isFalse);
      await session.pendingWrites;
      final stored =
          jsonDecode(
                (await SharedPreferences.getInstance()).getString(
                  kSessionStorageKey,
                )!,
              )
              as Map;
      expect(stored['prefs'], containsPair('callAlerts', false));
      expect(stored['prefs'], containsPair('highlightAlerts', false));
      session.signOut();
      prefs = NotificationPrefs.from(session);
      expect((prefs.callAlerts, prefs.highlightAlerts), (true, true));
    });

    testWidgets('NotificationPrefs.of 는 세션을 구독한다 (바뀌면 다시 그린다)', (tester) async {
      final session = SessionController();
      await tester.runAsync(() => session.load(dev: DevSessionKind.member));
      final seen = <bool>[];
      await tester.pumpWidget(
        SessionScope(
          controller: session,
          child: Builder(
            builder: (context) {
              seen.add(NotificationPrefs.of(context).callAlerts);
              return const SizedBox();
            },
          ),
        ),
      );
      session.setPref(SessionPref.callAlerts, false);
      await tester.pump();
      expect(seen, [true, false]);
    });
  });

  group('v6 딥링크 파라미터 (RN routes.ts R5 와 같은 문자열)', () {
    CameoLocation at(String name) => CameoLocation.parse(name);

    test('`/?view=liked|deleted|select` → AlbumView (모르면 timeline) · 만들기', () {
      expect(CameoRoutes.albumViewOf(at('/')), AlbumView.timeline);
      expect(CameoRoutes.albumViewOf(at('/?view=liked')), AlbumView.liked);
      expect(CameoRoutes.albumViewOf(at('/?view=deleted')), AlbumView.deleted);
      expect(CameoRoutes.albumViewOf(at('/?view=select')), AlbumView.select);
      expect(CameoRoutes.albumViewOf(at('/?view=?')), AlbumView.timeline);
      expect(CameoRoutes.albumView(AlbumView.liked), '/?view=liked');
      expect(CameoRoutes.albumView(AlbumView.timeline), '/');
    });

    test(
      '`/capture?review=1` (1 만) · `/partner?state=done` · `/verify?state=success`',
      () {
        expect(CameoRoutes.captureReviewOf(at('/capture?review=1')), isTrue);
        expect(
          CameoRoutes.captureReviewOf(at('/capture?review=true')),
          isFalse,
        );
        expect(CameoRoutes.captureReviewOf(at('/capture')), isFalse);
        expect(CameoRoutes.captureLocation(review: true), '/capture?review=1');
        expect(CameoRoutes.captureLocation(), '/capture');
        expect(
          CameoRoutes.partnerStateOf(at('/partner?state=done')),
          PartnerRouteState.done,
        );
        expect(
          CameoRoutes.partnerStateOf(at('/partner')),
          PartnerRouteState.input,
        );
        expect(
          CameoRoutes.partnerLocation(state: PartnerRouteState.done),
          '/partner?state=done',
        );
        expect(
          CameoRoutes.verifyStateOf(at('/verify?phone=010&state=success')),
          VerifyRouteState.success,
        );
        expect(
          CameoRoutes.verifyStateOf(at('/verify?state=?')),
          VerifyRouteState.input,
        );
      },
    );

    test(
      '세션 가드 시작 스택이 쿼리를 지킨다 (`/partner?state=done` · `/verify?…&state=success` · `/?view=liked`)',
      () {
        final onboarding = devSessionOf(
          DevSessionKind.onboarding,
        ).copyWith(name: '주영');
        expect(initialLocationsFor(at('/partner?state=done'), onboarding), [
          CameoRoutes.profile,
          '/partner?state=done',
        ]);
        expect(
          initialLocationsFor(
            at('/verify?phone=01012345678&state=success'),
            Session.guest,
          ),
          [
            CameoRoutes.welcome,
            CameoRoutes.phone,
            '/verify?phone=01012345678&state=success',
          ],
        );
        expect(
          initialLocationsFor(
            at('/?view=liked'),
            devSessionOf(DevSessionKind.member),
          ),
          ['/?view=liked'],
        );
      },
    );
  });
}
