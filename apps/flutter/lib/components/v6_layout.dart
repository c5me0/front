// Responsive v6 component geometry. Convert design width rules into viewport-relative
// values without fixing the screen width.

//

//

//   Positioned(left: l.topNavRightButtonLeft, top: CameoLayout.topNavV6Top, child: ScrimButton(size: md, icon: x))
//   SizedBox(width: l.tabBarFullPillWidth, …)
import 'package:flutter/widgets.dart';

import '../design_system/design_system.dart';

@immutable
class V6Layout {
  const V6Layout(this.width, [this.height = CameoLayout.screenV6Height]);

  factory V6Layout.of(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return V6Layout(size.width, size.height);
  }

  static const V6Layout figma = V6Layout(
    CameoLayout.screenV6Width,
    CameoLayout.screenV6Height,
  );

  final double width;
  final double height;

  /* ───────── screenV6 ───────── */

  /// W − 2 × gutter (370)
  double get contentWidth => width - 2 * CameoLayout.screenV6Gutter;

  /// W − gutter (386)
  double get rightEdge => width - CameoLayout.screenV6Gutter;

  /* ───────── topNavV6 · albumNavV6 ───────── */

  double get topNavRightButtonLeft =>
      width - CameoLayout.topNavV6PaddingX - CameoLayout.topNavV6ButtonSize;

  double topNavPillLeft(int count) =>
      width - CameoLayout.topNavV6PaddingX - scrimPillWidth(count);

  double centeredLeft(double w) => (width - w) / 2;

  /* ───────── solidButtonV6 · scrimPillV6 ───────── */

  double get solidCtaWidth => contentWidth;

  static double scrimPillWidth(int count) =>
      2 * CameoLayout.scrimPillV6Padding +
      count * CameoLayout.scrimPillV6ItemSize +
      (count > 0 ? (count - 1) * CameoLayout.scrimPillV6Gap : 0);

  double get keypadCellWidth => (width - 2 * CameoLayout.keypadV6PaddingX) / 3;

  double get codeBoxWidth => contentWidth;

  double get codeBoxSlotWidth =>
      (codeBoxWidth -
          2 * CameoLayout.codeBoxV6BorderWidth -
          2 * CameoLayout.codeBoxV6Padding -
          (CameoLayout.codeBoxV6SlotCount - 1) * CameoLayout.codeBoxV6Gap) /
      CameoLayout.codeBoxV6SlotCount;

  double get textFieldWidth => contentWidth;

  double get welcomeTileWidth =>
      (width +
          2 * CameoLayout.welcomeV6TilesBleedX -
          2 * CameoLayout.welcomeV6TilesGap) /
      3;

  double get settingsCardWidth => contentWidth;

  /* ───────── tabBarV6 (full · mini · camera) ───────── */

  double get tabBarFullPillWidth =>
      width -
      2 * CameoLayout.tabBarV6FullPaddingX -
      CameoLayout.tabBarV6FullGap -
      CameoLayout.tabBarV6FullCallButtonSize;

  double get tabBarFullItemWidth =>
      (tabBarFullPillWidth - 2 * CameoLayout.tabBarV6FullPillPadding) / 3;

  double get tabBarFullPillLeft => CameoLayout.tabBarV6FullPaddingX;

  double get tabBarCallButtonLeft =>
      width -
      CameoLayout.tabBarV6FullPaddingX -
      CameoLayout.tabBarV6FullCallButtonSize;

  double get tabBarMiniPillLeft =>
      (width - CameoLayout.tabBarV6MiniPillWidth) / 2;

  double get tabBarCameraPillWidth =>
      width -
      2 * CameoLayout.tabBarV6FullPaddingX -
      CameoLayout.tabBarV6CameraThumbnailSize -
      CameoLayout.tabBarV6CameraFlipSize -
      2 * CameoLayout.tabBarV6CameraGap;

  double get tabBarCameraItemWidth =>
      (tabBarCameraPillWidth - 2 * CameoLayout.tabBarV6FullPillPadding) / 3;

  double get tabBarCameraPillLeft =>
      CameoLayout.tabBarV6FullPaddingX +
      CameoLayout.tabBarV6CameraThumbnailSize +
      CameoLayout.tabBarV6CameraGap;

  double get tabBarFlipLeft =>
      width -
      CameoLayout.tabBarV6FullPaddingX -
      CameoLayout.tabBarV6CameraFlipSize;

  /* ───────── albumV6 · emptyAlbumV6 · callListV6 ───────── */

  double get albumHeroSize => width;

  double get albumCardWidth => width - 2 * CameoLayout.albumV6CardsPadding;

  double get albumCellSize =>
      (width -
          2 * CameoLayout.albumV6GridPadding -
          4 * CameoLayout.albumV6GridGap) /
      5;

  double get albumLikedTileSize =>
      2 * albumCellSize + CameoLayout.albumV6GridGap;

  double get emptyAlbumColumnTop =>
      (height - CameoLayout.emptyAlbumV6ColumnHeight) / 2;

  /// call-list = W − 16 (386)
  double get callListWidth => width - 2 * CameoLayout.albumV6CardsPadding;

  /* ───────── viewerV6 ───────── */

  double get viewerCardWidth => width - 2 * CameoLayout.viewerV6CardInset;

  double get viewerCardHeight =>
      viewerCardWidth / CameoLayout.viewerV6CardAspectRatio;

  double get viewerStripHeight =>
      height -
      CameoLayout.viewerV6PhotoRowTop -
      (viewerCardHeight + 2 * CameoLayout.viewerV6CardInset) -
      CameoLayout.viewerV6BottomHeight;

  double get viewerPageStep => width;

  /* ───────── transcriptV6 ───────── */

  double get transcriptCardWidth =>
      width - 2 * CameoLayout.transcriptV6CardWrapperPaddingX;

  double get transcriptPlayerPillWidth => contentWidth;

  /* ───────── callV6 · sliderV6 · toastV6 · photoSheetV6 · capturedCardV6 ───────── */

  double get bottomNavTop => height - CameoLayout.callV6BottomNavHeight;

  double get callBarWidth => width - 2 * CameoLayout.callV6BottomNavPaddingX;

  double get callBarItemWidth =>
      (callBarWidth - 2 * CameoLayout.callV6BottomNavBarPadding) /
      CameoLayout.callV6BottomNavSlots;

  double get sliderPillLeft => (width - CameoLayout.sliderV6PillWidth) / 2;

  double get toastFlatContainerBottom => bottomNavTop;

  double get toastV6FlatBottom => height - toastFlatContainerBottom;

  double get toastV6CameraTop => CameoLayout.cameraV6ViewfinderTop;

  double get photoSheetWidth => width - 2 * CameoLayout.photoSheetV6MarginX;

  double get photoSheetBottom => bottomNavTop;

  double get photoSheetHeight => photoSheetBottom - CameoLayout.photoSheetV6Top;

  double get photoSheetCellSize =>
      (photoSheetWidth - 2 * CameoLayout.photoSheetV6GridGap) / 3;

  double get photoSheetLiveCellHeight =>
      2 * photoSheetCellSize + CameoLayout.photoSheetV6GridGap;

  double get capturedCardPortraitWidth =>
      CameoLayout.capturedCardV6PortraitHeight *
      CameoLayout.capturedCardV6PortraitAspectRatio;

  double get capturedCardLandscapeHeight =>
      capturedCardPortraitWidth * CameoLayout.capturedCardV6PortraitAspectRatio;

  double get capturedCardLeft => (width - capturedCardPortraitWidth) / 2;

  double get capturedCardBottom => bottomNavTop;

  /* ───────── aodV6 · cameraV6 · reviewV6 ───────── */

  double get aodButtonTop =>
      height -
      CameoLayout.screenV6HomeIndicatorHeight -
      CameoLayout.aodV6ButtonContainerPaddingY -
      CameoLayout.aodV6ButtonHeight;

  double get aodButtonLeft => (width - CameoLayout.aodV6ButtonWidth) / 2;

  double get cameraViewfinderWidth =>
      width - 2 * CameoLayout.cameraV6ViewfinderContainerPadding;

  double get cameraViewfinderHeight =>
      cameraViewfinderWidth / CameoLayout.cameraV6ViewfinderAspectRatio;

  double get cameraShotCenterX => width / 2;

  double get cameraShotCenterY =>
      CameoLayout.cameraV6ViewfinderTop +
      cameraViewfinderHeight -
      CameoLayout.cameraV6ShotBottomOffset;

  double get reviewActionsTop =>
      height -
      CameoLayout.screenV6HomeIndicatorHeight -
      CameoLayout.reviewV6ActionsPaddingBottom -
      CameoLayout.reviewV6ActionsButtonSize;

  /// send left = W − 16 − 46 (340)
  double get reviewSendLeft =>
      width -
      CameoLayout.reviewV6ActionsPaddingX -
      CameoLayout.reviewV6SendSize;

  @override
  bool operator ==(Object other) =>
      other is V6Layout && other.width == width && other.height == height;

  @override
  int get hashCode => Object.hash(width, height);

  @override
  String toString() => 'V6Layout($width × $height)';
}
