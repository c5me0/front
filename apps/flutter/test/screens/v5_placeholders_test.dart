// Regression coverage for v5 placeholders. Preserve behavior, layout, and interaction
// expectations.

import 'package:cameo/content/app.g.dart';
import 'package:cameo/navigation/navigation.dart';
import 'package:cameo/screens/settings/settings_screen.dart';
import 'package:cameo/state/session.dart';
import 'package:flutter_test/flutter_test.dart';

import '../navigation/app_harness.dart';

void main() {
  setUp(() {
    FlowDemo.resetForTesting();
    ViewerSource.clear();
  });
  tearDown(FlowDemo.resetForTesting);

  testWidgets(
    '설정 › 개발: 사진 시트 방식 (A ↔ B, 세션 prefs 저장) — 빈 앨범은 Lab (album=empty · 설정 v5 는 RN 과 같은 행만, records-settings)',
    (tester) async {
      final session = await pumpCameoApp(tester, '/settings?session=member');
      final row = find.byKey(SettingsScreen.sheetVariantKey);
      await scrollIntoCenter(tester, row);
      expect(find.text(appContent.settingsV5.sheetInstant), findsOneWidget);
      await tester.tap(row);
      await tester.pump();
      expect(session.session.prefs.photoSheetVariant, PhotoSheetVariant.multi);
      expect(find.text(appContent.settingsV5.sheetMulti), findsOneWidget);

      await tester.tap(row);
      await tester.pump();
      expect(
        session.session.prefs.photoSheetVariant,
        PhotoSheetVariant.instant,
      );
      await disposeApp(tester);
    },
  );
}
