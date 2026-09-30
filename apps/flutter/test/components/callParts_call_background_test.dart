// ignore_for_file: file_names
// Regression coverage for callParts call background. Preserve behavior, layout, and
// interaction expectations.

import 'package:cameo/components/call_background.dart';
import 'package:cameo/content/lab.g.dart';
import 'package:cameo/design_system/design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const Size _screen = Size(393, 852);

void main() {
  testWidgets(
    'CallBackground (2042:2361 채움): 393x852 풀블리드 사진 cover + callBackground 그라데이션',
    (tester) async {
      tester.view.physicalSize = _screen;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(size: _screen),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Stack(children: [Positioned.fill(child: CallBackground())]),
          ),
        ),
      );

      expect(
        tester.getRect(find.byType(CallBackground)),
        Offset.zero & _screen,
      );

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.fit, BoxFit.cover);
      expect(image.alignment, Alignment.center);
      expect((image.image as AssetImage).assetName, labInCall.background);
      expect(tester.getRect(find.byType(Image)), Offset.zero & _screen);

      final gradientBox = find.byWidgetPredicate(
        (w) =>
            w is DecoratedBox &&
            (w.decoration as BoxDecoration).gradient != null,
      );
      final gradient =
          (tester.widget<DecoratedBox>(gradientBox).decoration as BoxDecoration)
                  .gradient!
              as LinearGradient;
      expect(gradient, CameoGradients.callBackground);
      expect(gradient.stops, [0.0, 0.5, 0.8]);
      expect(gradient.colors, [
        CameoColors.callBackgroundOverlayStart,
        CameoColors.callBackgroundOverlayMid,
        CameoColors.callBackgroundOverlay,
      ]);
      expect(gradient.begin, Alignment.topCenter);
      expect(gradient.end, Alignment.bottomCenter);
      expect(tester.getRect(gradientBox), Offset.zero & _screen);
    },
  );
}
