// Pure v6 transcript geometry, player placement, and safe-area calculations.

//

import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../content/lab.g.dart';
import '../design_system/design_system.dart';

double get transcriptV6LineHeight =>
    CameoTextStyles.transcriptLineV6.fontSize! *
    CameoTextStyles.transcriptLineV6.height!;

double playerV6ContainerHeight() =>
    CameoLayout.transcriptV6PlayerRowPaddingY * 2 +
    CameoLayout.transcriptV6PlayerPillHeight +
    CameoLayout.screenV6HomeIndicatorHeight;

({double left, double right, double y}) playerV6PillInsets() => (
  left: CameoLayout.transcriptV6PlayerPillPaddingLeft,
  right: CameoLayout.transcriptV6PlayerPillPaddingRight,
  y: CameoLayout.transcriptV6PlayerPillPaddingY,
);

double playerV6PillHeight() =>
    CameoLayout.transcriptV6PlayerBorderWidth * 2 +
    playerV6PillInsets().y * 2 +
    CameoLayout.transcriptV6PlayerPauseHeight;

double playerV6PillWidth(double width) =>
    width - 2 * CameoLayout.transcriptV6PlayerRowPaddingX;

double playerV6TrackWidth(double width, double timeWidth) {
  final i = playerV6PillInsets();
  return playerV6PillWidth(width) -
      CameoLayout.transcriptV6PlayerBorderWidth * 2 -
      i.left -
      i.right -
      CameoLayout.transcriptV6PlayerPauseWidth -
      CameoLayout.transcriptV6PlayerGap * 3 -
      timeWidth * 2;
}

double playerV6ThumbLeft(double position, double trackWidth) =>
    position * trackWidth - CameoLayout.transcriptV6PlayerThumbSize / 2;

double playerV6ThumbTop() =>
    (CameoLayout.transcriptV6PlayerTrackHeight -
        CameoLayout.transcriptV6PlayerThumbSize) /
    2;

/// RN `playerV6TapTarget`.
double? playerV6TapTarget(
  double fraction,
  List<PlayerV5MarkerContent> markers,
) {
  if (!(fraction >= 0 && fraction <= 1)) return null;
  for (final m in markers) {
    if (fraction >= m.start && fraction <= m.start + m.width) return m.start;
  }
  return fraction;
}

({double left, double width}) playerV6MarkerFrame(
  PlayerV5MarkerContent marker,
  double trackWidth,
) => (left: marker.start * trackWidth, width: marker.width * trackWidth);

Alignment inlinePhotoAlignV6(LabAlign side) =>
    side == LabAlign.right ? Alignment.centerRight : Alignment.centerLeft;

double transcriptV6ContentHeight({
  required List<int> outside,
  required int? photoAfter,
  required List<int> card,
}) {
  final lh = transcriptV6LineHeight;
  double lineBlock(int n) => CameoLayout.transcriptV6LinePaddingY * 2 + n * lh;
  var h =
      CameoLayout.transcriptV6HeaderHeight +
      CameoLayout.transcriptV6TitleBlockHeight;
  for (var i = 0; i < outside.length; i++) {
    h += lineBlock(outside[i]);
    if (photoAfter == i) {
      h +=
          CameoLayout.transcriptV6PhotoGapAbove +
          CameoLayout.transcriptV6PhotoHeight;
    }
  }
  final cardInner =
      card.fold<double>(0, (s, n) => s + n * lh) +
      CameoLayout.transcriptV6CardGap * math.max(0, card.length - 1);
  h +=
      CameoLayout.transcriptV6CardWrapperPaddingTop +
      CameoLayout.transcriptV6CardPaddingY * 2 +
      cardInner +
      CameoLayout.transcriptV6CardWrapperPaddingBottom;
  return h;
}

double transcriptV6MaxScroll(double contentHeight, double height) =>
    math.max(0, contentHeight - height);
