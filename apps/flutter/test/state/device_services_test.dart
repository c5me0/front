// Regression coverage for device services. Preserve behavior, layout, and interaction
// expectations.

import 'dart:io';

import 'package:cameo/design_system/design_system.dart';
import 'package:cameo/state/device_services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(Uint8List.fromList(key.codeUnits));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SimulatedVolumeService', () {
    test('set = 즉시 (0 … 1 로 자른다) · stream 에 흐른다 · get', () async {
      final v = SimulatedVolumeService(initial: 0.4);
      final seen = <double>[];
      final sub = v.stream.listen(seen.add);
      await v.set(1.4);
      expect(await v.get(), 1);
      await v.set(-1);
      expect(v.value, 0);
      v.simulateHardware(0.7);
      await Future<void>.delayed(Duration.zero);
      expect(seen, [1, 0, 0.7]);
      await sub.cancel();
      v.dispose();
    });

    testWidgets(
      'fadeTo = kVolumeFadeStep 걸음 · 시간에 선형 (RN 과 같다) · 끝 = true · 새 set 이 끊으면 false',
      (tester) async {
        final v = SimulatedVolumeService(initial: 1);
        bool? done;
        v
            .fadeTo(CameoMotion.sleepVolumeTarget, CameoMotion.sleepVolumeFade)
            .then((r) => done = r);
        await tester.pump();
        await tester.pump(CameoMotion.sleepVolumeFade ~/ 2);
        expect(v.isFading, isTrue);
        final steps =
            CameoMotion.sleepVolumeFade.inMilliseconds ~/
            kVolumeFadeStep.inMilliseconds ~/
            2;
        expect(v.writes.length, steps);

        final expected = 1 + (CameoMotion.sleepVolumeTarget - 1) * 0.5;
        expect(v.value, closeTo(expected, 1e-9));
        await tester.pump(CameoMotion.sleepVolumeFade);
        expect(done, isTrue);
        expect(v.value, closeTo(CameoMotion.sleepVolumeTarget, 1e-12));
        expect(v.isFading, isFalse);

        bool? cut;
        v.fadeTo(1, const Duration(seconds: 1)).then((r) => cut = r);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        await v.set(0.3);
        await tester.pump();
        expect(cut, isFalse);
        final after = v.writes.length;
        await tester.pump(const Duration(seconds: 1));
        expect(v.writes.length, after);
        expect(v.value, 0.3);

        expect(await v.fadeTo(0.9, Duration.zero), isTrue);
        expect(v.value, 0.9);
        v.dispose();
      },
    );
  });

  group('SystemVolumeService (플랫폼 없음)', () {
    testWidgets('플러그인이 없으면 예외 없이 마지막 값으로 동작 (시뮬레이터 · 테스트)', (tester) async {
      await withLogs((logs) async {
        await tester.runAsync(() async {
          final v = SystemVolumeService.shared;
          await v.set(0.25).timeout(const Duration(seconds: 5));
          expect(await v.get().timeout(const Duration(seconds: 5)), 0.25);
        });
        expect(logs.any((l) => l.contains('[cameo] volume')), isTrue);
      });
    });
  });

  group('밝기', () {
    test('SimulatedBrightnessService: set (자름) · restore = 시스템 값', () async {
      final b = SimulatedBrightnessService(system: 0.6);
      expect(await b.get(), 0.6);
      expect(b.overridden, isFalse);
      await b.set(-2);
      expect(b.value, 0);
      expect(b.overridden, isTrue);
      await b.restore();
      expect(b.value, 0.6);
    });

    testWidgets('SystemBrightnessService: 플러그인이 없으면 마지막 값', (tester) async {
      await withLogs((logs) async {
        await tester.runAsync(() async {
          final b = SystemBrightnessService.shared;
          await b.set(0.1).timeout(const Duration(seconds: 5));
          expect(await b.get().timeout(const Duration(seconds: 5)), 0.1);
          await b.restore().timeout(const Duration(seconds: 5));
        });
        expect(logs.any((l) => l.contains('[cameo] brightness')), isTrue);
      });
    });
  });

  group('공유', () {
    test('SimulatedShareService: 요청 기록 · 빈 목록 = unavailable', () async {
      final s = SimulatedShareService();
      expect(await s.shareImages(const []), ShareOutcome.unavailable);
      expect(
        await s.shareImages(['assets/content/a.jpg']),
        ShareOutcome.shared,
      );
      s.outcome = ShareOutcome.dismissed;
      expect(await s.shareImages(['x']), ShareOutcome.dismissed);
      expect(s.requests, [
        ['assets/content/a.jpg'],
        ['x'],
      ]);
    });

    test('writeAssetsToTemp: 번들 에셋 → 임시 파일 (이름 = 에셋 파일 이름, 바이트 그대로)', () async {
      final dir = await Directory.systemTemp.createTemp('cameo-share-test');
      addTearDown(() => dir.delete(recursive: true));
      final paths = await writeAssetsToTemp(
        ['assets/content/a.jpg', 'assets/content/b.png'],
        bundle: _FakeBundle(),
        directory: dir,
      );
      expect(paths, ['${dir.path}/a.jpg', '${dir.path}/b.png']);
      expect(File(paths.first).readAsStringSync(), 'assets/content/a.jpg');
      expect(isBundleAsset('assets/content/a.jpg'), isTrue);
      expect(isBundleAsset('/var/mobile/x.jpg'), isFalse);
    });
  });

  testWidgets('DeviceServicesScope — of 는 스코프 · 없으면 시스템', (tester) async {
    final services = DeviceServices.simulated();
    late BuildContext inside;
    late BuildContext outside;
    await tester.pumpWidget(
      Column(
        children: [
          Builder(
            builder: (c) {
              outside = c;
              return const SizedBox();
            },
          ),
          DeviceServicesScope(
            services: services,
            child: Builder(
              builder: (c) {
                inside = c;
                return const SizedBox();
              },
            ),
          ),
        ],
      ),
    );
    expect(VolumeService.of(inside), services.volume);
    expect(BrightnessService.of(inside), services.brightness);
    expect(ShareService.of(inside), services.share);
    expect(VolumeService.of(outside), SystemVolumeService.shared);
    expect(BrightnessService.of(outside), SystemBrightnessService.shared);
    expect(ShareService.of(outside), SystemShareService.shared);
    final system = DeviceServices.system();
    expect(system.volume, SystemVolumeService.shared);
  });
}

Future<void> withLogs(Future<void> Function(List<String> logs) body) async {
  final logs = <String>[];
  final original = debugPrint;
  debugPrint = (String? m, {int? wrapWidth}) => logs.add(m ?? '');
  try {
    await body(logs);
  } finally {
    debugPrint = original;
  }
}
