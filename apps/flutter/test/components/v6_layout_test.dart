// Regression coverage for v6 layout. Preserve behavior, layout, and interaction
// expectations.

import 'package:cameo/components/scrim_pill.dart';
import 'package:cameo/components/toast_v6.dart';
import 'package:cameo/components/v6_layout.dart';
import 'package:cameo/design_system/design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('W 402 × 874 = 토큰 (Figma 값)', () {
    const l = V6Layout.figma;
    expect(l, const V6Layout(402, 874));
    expect(l.contentWidth, CameoLayout.screenV6ContentWidth); // 370
    expect(l.rightEdge, 386);
    expect(l.topNavRightButtonLeft, CameoLayout.topNavV6RightButtonLeft); // 340
    expect(l.topNavPillLeft(3), CameoLayout.albumNavV6PillLeft); // 240
    expect(l.topNavPillLeft(2), 290);
    expect(l.topNavPillLeft(1), CameoLayout.albumNavV6SinglePillLeft); // 340
    expect(l.solidCtaWidth, CameoLayout.solidButtonV6CtaWidth); // 370
    expect(V6Layout.scrimPillWidth(1), CameoLayout.scrimPillV6Width1);
    expect(V6Layout.scrimPillWidth(2), CameoLayout.scrimPillV6Width2);
    expect(V6Layout.scrimPillWidth(3), CameoLayout.scrimPillV6Width3);
    expect(scrimPillWidth(3), 146);
    expect(l.keypadCellWidth, closeTo(CameoLayout.keypadV6CellWidth, 1e-5));
    expect(l.codeBoxWidth, CameoLayout.codeBoxV6Width);
    expect(l.codeBoxSlotWidth, closeTo(CameoLayout.codeBoxV6SlotWidth, 1e-5));
    expect(l.textFieldWidth, CameoLayout.textFieldV6Width);
    expect(l.welcomeTileWidth, CameoLayout.welcomeV6TilesWidth); // 132
    expect(l.settingsCardWidth, 370);

    expect(l.tabBarFullPillWidth, CameoLayout.tabBarV6FullPillWidth); // 308
    expect(l.tabBarFullItemWidth, CameoLayout.tabBarV6FullItemWidth); // 100
    expect(l.tabBarFullPillLeft, 16);
    expect(
      l.tabBarCallButtonLeft,
      CameoLayout.tabBarV6FullCallButtonLeft,
    ); // 332
    expect(l.tabBarMiniPillLeft, 106);
    expect(l.tabBarCameraPillWidth, CameoLayout.tabBarV6CameraPillWidth); // 246
    expect(
      l.tabBarCameraItemWidth,
      closeTo(CameoLayout.tabBarV6CameraItemWidth, 1e-5),
    );
    expect(l.tabBarCameraPillLeft, 78);
    expect(l.tabBarFlipLeft, 332);

    expect(l.albumHeroSize, CameoLayout.albumV6HeroSize); // 402
    expect(l.albumCardWidth, CameoLayout.albumV6CardsWidth); // 386
    expect(l.albumCellSize, closeTo(CameoLayout.albumV6GridCellSize, 1e-9));
    expect(
      l.albumLikedTileSize,
      closeTo(CameoLayout.albumV6GridLikedTileSize, 1e-9),
    );
    expect(l.callListWidth, CameoLayout.callListV6Width); // 386
    expect(
      l.emptyAlbumColumnTop,
      (874 - CameoLayout.emptyAlbumV6ColumnHeight) / 2,
    );

    expect(l.viewerCardWidth, CameoLayout.viewerV6CardWidth);
    expect(l.viewerCardHeight, closeTo(CameoLayout.viewerV6CardHeight, 1e-5));
    expect(l.viewerStripHeight, closeTo(CameoLayout.viewerV6StripHeight, 1e-5));
    expect(l.viewerPageStep, CameoLayout.viewerV6PageStep);
    expect(l.transcriptCardWidth, CameoLayout.transcriptV6CardWidth);
    expect(
      l.transcriptPlayerPillWidth,
      CameoLayout.transcriptV6PlayerPillWidth,
    );

    expect(l.bottomNavTop, CameoLayout.callV6BottomNavTop); // 770
    expect(l.callBarWidth, 370);
    expect(
      l.callBarItemWidth,
      closeTo(CameoLayout.callV6BottomNavItemWidth, 1e-9),
    );
    expect(l.sliderPillLeft, 76);
    expect(l.toastFlatContainerBottom, 770);
    expect(l.toastV6FlatBottom, 104);
    expect(toastV6FlatBottom(), 104);
    expect(l.toastV6CameraTop, CameoLayout.toastV6CameraContainerTop); // 66
    expect(l.photoSheetWidth, CameoLayout.photoSheetV6Width);
    expect(l.photoSheetBottom, CameoLayout.photoSheetV6Bottom);
    expect(l.photoSheetHeight, CameoLayout.photoSheetV6Height);
    expect(
      l.photoSheetCellSize,
      closeTo(CameoLayout.photoSheetV6GridCellSize, 1e-5),
    );
    expect(
      l.photoSheetLiveCellHeight,
      closeTo(CameoLayout.photoSheetV6LiveCellHeight, 1e-5),
    );
    expect(
      l.capturedCardPortraitWidth,
      CameoLayout.capturedCardV6PortraitWidth,
    );
    expect(
      l.capturedCardLandscapeHeight,
      closeTo(CameoLayout.capturedCardV6LandscapeHeight, 1e-5),
    );
    expect(l.capturedCardLeft, CameoLayout.capturedCardV6PortraitLeft);
    expect(l.capturedCardBottom, CameoLayout.capturedCardV6PortraitBottom);
    expect(l.aodButtonTop, CameoLayout.aodV6ButtonTop); // 774
    expect(l.aodButtonLeft, 126);
    expect(l.cameraViewfinderWidth, CameoLayout.cameraV6ViewfinderWidth);
    expect(
      l.cameraViewfinderHeight,
      closeTo(CameoLayout.cameraV6ViewfinderHeight, 1e-5),
    );
    expect(l.cameraShotCenterX, CameoLayout.cameraV6ShotCenterX); // 201
    expect(l.cameraShotCenterY, closeTo(CameoLayout.cameraV6ShotCenterY, 1e-5));
    expect(l.reviewActionsTop, CameoLayout.reviewV6ActionsTop); // 784
    expect(l.reviewSendLeft, 340);
    expect(l.centeredLeft(190), 106);
  });

  test('W 393 × 852 = 같은 식 (RN R3 과 같은 수)', () {
    const l = V6Layout(393, 852);
    expect(l.contentWidth, 361);
    expect(l.rightEdge, 377);
    expect(l.topNavRightButtonLeft, 331);
    expect(l.topNavPillLeft(3), 231);
    expect(l.solidCtaWidth, 361);
    expect(l.tabBarFullPillWidth, 299);
    expect(l.tabBarFullItemWidth, 97);
    expect(l.tabBarCallButtonLeft, 323);
    expect(l.tabBarMiniPillLeft, 101.5);
    expect(l.tabBarCameraPillLeft, 78);
    expect(l.tabBarCameraPillWidth, 237);
    expect(l.tabBarCameraItemWidth, closeTo(76.333333, 1e-5));
    expect(l.callListWidth, 377);
    expect(l.albumCellSize, closeTo((393 - 16 - 8) / 5, 1e-9)); // 73.8
    expect(l.viewerCardWidth, 385);
    expect(l.bottomNavTop, 852 - 104);
    expect(l.toastV6FlatBottom, 104);
    expect(l.cameraShotCenterX, 196.5);
    expect(l.aodButtonTop, 852 - 34 - 12 - 54);
    expect(l.reviewActionsTop, 852 - 34 - 10 - 46);
    expect(l.sliderPillLeft, (393 - 250) / 2);
    expect(l.centeredLeft(150), 121.5);
  });

  testWidgets('V6Layout.of = MediaQuery 크기', (tester) async {
    late V6Layout layout;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(402, 874)),
        child: Builder(
          builder: (context) {
            layout = V6Layout.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(layout, V6Layout.figma);
  });
}
