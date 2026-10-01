// Pure geometry and motion calculations for calls, camera capture, photo sheets, and
// review. Preserve operation order for consistent transition endpoints.

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../content/lab.g.dart' show CapturedOrientation;
import '../design_system/design_system.dart';

export '../content/lab.g.dart' show CapturedOrientation;

/// RN `callBottomNavHeight()`.
double callBottomNavHeight() => CameoLayout.callV6BottomNavHeight;

double callBottomNavTop(double h) => h - CameoLayout.callV6BottomNavHeight;

double callBarWidth(double w) => w - 2 * CameoLayout.callV6BottomNavPaddingX;

double callBarItemWidth(double w) =>
    (callBarWidth(w) - 2 * CameoLayout.callV6BottomNavBarPadding) /
    CameoLayout.callV6BottomNavSlots;

({double top, double size, double leftX, double rightX}) callNavButtons(
  double w,
) => (
  top: CameoLayout.topNavV6Top,
  size: CameoLayout.topNavV6ButtonSize,
  leftX: CameoLayout.topNavV6PaddingX,
  rightX: w - CameoLayout.topNavV6PaddingX - CameoLayout.topNavV6ButtonSize,
);

CapturedOrientation capturedCardOrientation(double width, double height) =>
    width > 0 && height > 0 && width > height
    ? CapturedOrientation.landscape
    : CapturedOrientation.portrait;

/// RN `capturedCardRect(orientation, W, H)`.
Rect capturedCardRect(CapturedOrientation orientation, double w, double h) {
  const width =
      CameoLayout.capturedCardV6PortraitHeight *
      CameoLayout.capturedCardV6PortraitAspectRatio;
  final height = orientation == CapturedOrientation.landscape
      ? width * CameoLayout.capturedCardV6PortraitAspectRatio
      : CameoLayout.capturedCardV6PortraitHeight;
  final bottom = callBottomNavTop(h);
  return Rect.fromLTWH((w - width) / 2, bottom - height, width, height);
}

double capturedCardClipBottom() => CameoLayout.callV6BottomNavHeight;

const Offset capturedCardCloseOffset = Offset(
  CameoLayout.capturedCardV6CloseLeft,
  CameoLayout.capturedCardV6CloseTop,
);

typedef CapturedCardTransform = ({
  double translateY,
  double scale,
  double opacity,
});

/// RN `capturedCardTransform(p, closing)`.
CapturedCardTransform capturedCardTransform(double p, {bool closing = false}) {
  final from = closing
      ? CameoMotion.capturedCardExitScale
      : CameoMotion.capturedCardEnterScale;
  return (
    translateY: (1 - p) * CameoMotion.capturedCardEnterOffset,
    scale: from + (1 - from) * p,
    opacity: p.clamp(0.0, 1.0),
  );
}

CapturedOrientation capturedCardOrientationOf(Iterable<Size> sizes) {
  if (sizes.isEmpty) return CapturedOrientation.portrait;
  final first = sizes.first;
  return capturedCardOrientation(first.width, first.height);
}

int capturedCardPageAt(double offsetX, double pageWidth, int count) {
  if (count <= 0 || pageWidth <= 0) return 0;
  return (offsetX / pageWidth).round().clamp(0, count - 1);
}

const double capturedCardDotSize = CameoSpace.s6;
const double capturedCardDotGap = CameoSpace.s6;
const double capturedCardDotBottom = CameoSpace.s12;

double capturedCardDotActive(double position, int index) =>
    (1 - (position - index).abs()).clamp(0.0, 1.0);

double sliderThumbCenter(double value) =>
    value.clamp(0.0, 1.0) * CameoLayout.sliderV6TrackWidth;

double sliderThumbLeft(double value) =>
    sliderThumbCenter(value) - CameoLayout.sliderV6ThumbSize / 2;

double sliderFillWidth(double value) =>
    math.max(0, sliderThumbCenter(value) - CameoLayout.sliderV6FillLeft);

double sliderValueAt(double trackX) {
  const w = CameoLayout.sliderV6TrackWidth;
  if (!(w > 0)) return 0;
  return (trackX / w).clamp(0.0, 1.0);
}

const double sliderTrackInset =
    CameoLayout.sliderV6PillBorderWidth + CameoLayout.sliderV6PillPadding;

double sliderPillLeft(double w) => (w - CameoLayout.sliderV6PillWidth) / 2;

const double sliderFigmaSampleValue =
    (CameoLayout.sliderV6ThumbSampleLeft + CameoLayout.sliderV6ThumbSize / 2) /
    CameoLayout.sliderV6TrackWidth;

typedef SliderPillTransform = ({
  double translateY,
  double scaleX,
  double scaleY,
});

/// translateY = (1 − p) · enterOffset · scaleX = lerp(enterScale, 1, p) · scaleY = lerp(chromeScaleFrom, 1, p) (≥ chromeScaleFrom)

SliderPillTransform sliderPillTransform(double p) {
  const from = CameoMotion.transitionZoomChromeScaleFrom;
  return (
    translateY: (1 - p) * CameoMotion.sliderEnterOffset,
    scaleX:
        CameoMotion.sliderEnterScale + (1 - CameoMotion.sliderEnterScale) * p,
    scaleY: math.max(from, from + (1 - from) * p),
  );
}

double shotRingProgress(Duration elapsed) {
  final max = CameoMotion.shotMaxRecord.inMicroseconds;
  if (max <= 0) return 0;
  return (elapsed.inMicroseconds / max).clamp(0.0, 1.0);
}

double shotRingSweepDeg(Duration elapsed) => shotRingProgress(elapsed) * 360;

double shotRingCircumference() => 2 * math.pi * CameoLayout.shotV6RingRadius;

double shotRingBox() =>
    CameoLayout.shotV6RecordingSize + 2 * CameoLayout.shotV6RingStrokeWidth;

String recordingLabel(Duration duration) {
  final s = math.max(0, (duration.inMilliseconds / 1000).round());
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

Rect cameraViewfinderRect(
  double w, {
  double height = CameoLayout.screenV6Height,
}) {
  const top = CameoLayout.cameraV6ViewfinderTop;
  const ratio = CameoLayout.cameraV6ViewfinderAspectRatio;
  final available = math.max(
    1.0,
    height - top - CameoLayout.cameraV6BottomNavHeight - CameoSpace.s12,
  );
  final width = math.min(
    w - 2 * CameoLayout.cameraV6ViewfinderContainerPadding,
    available * ratio,
  );
  return Rect.fromLTWH((w - width) / 2, top, width, width / ratio);
}

Offset cameraShotCenter(
  double w, {
  double height = CameoLayout.screenV6Height,
}) {
  final vf = cameraViewfinderRect(w, height: height);
  return Offset(w / 2, vf.bottom - CameoLayout.cameraV6ShotBottomOffset);
}

/// RN `reviewActions(W, H)`.
({double top, double size, double trashLeft, double sendLeft}) reviewActions(
  double w,
  double h,
) => (
  top:
      h -
      CameoLayout.screenV6HomeIndicatorHeight -
      CameoLayout.reviewV6ActionsPaddingBottom -
      CameoLayout.reviewV6ActionsButtonSize,
  size: CameoLayout.reviewV6ActionsButtonSize,
  trashLeft: CameoLayout.reviewV6ActionsPaddingX,
  sendLeft:
      w -
      CameoLayout.reviewV6ActionsPaddingX -
      CameoLayout.reviewV6ActionsButtonSize,
);

Rect cameraThumbnailRect(double h) {
  const size = CameoLayout.tabBarV6CameraThumbnailSize;
  const bottom =
      CameoLayout.screenV6HomeIndicatorHeight +
      (CameoLayout.tabBarV6FullPillHeight - size) / 2;
  return Rect.fromLTWH(
    CameoLayout.tabBarV6FullPaddingX,
    h - bottom - size,
    size,
    size,
  );
}

Offset reviewSendDelta(double w, double h) =>
    cameraThumbnailRect(h).center - cameraViewfinderRect(w).center;

/// RN `reviewSendTransform(p, dx, dy)`.
({double translateX, double translateY, double scale}) reviewSendTransform(
  double p,
  Offset delta,
) => (
  translateX: delta.dx * p,
  translateY: delta.dy * p,
  scale: 1 + (CameoMotion.reviewV6SendScale - 1) * p,
);

/// RN `reviewDiscardTransform(p)`.
({double scale, double opacity}) reviewDiscardTransform(double p) => (
  scale: 1 + (CameoMotion.reviewV6DiscardScale - 1) * p,
  opacity: 1 - p.clamp(0.0, 1.0),
);

({double translateY, double scale}) reviewActionsTransform(double p) {
  const from = CameoMotion.transitionZoomChromeScaleFrom;
  return (
    translateY: (1 - p) * CameoMotion.reviewV6ActionsOffsetY,
    scale: math.max(from, from + (1 - from) * p),
  );
}

/// RN `sleepVolumeAt`.
double sleepVolumeAt(Duration elapsed, double from) {
  final total = CameoMotion.sleepVolumeFade.inMicroseconds;
  final t = total > 0 ? (elapsed.inMicroseconds / total).clamp(0.0, 1.0) : 1.0;
  return from + (CameoMotion.sleepVolumeTarget - from) * t;
}

double aodOverlayAt(Duration elapsed) {
  final total = CameoMotion.sleepAod.inMicroseconds;
  final x = total > 0 ? (elapsed.inMicroseconds / total).clamp(0.0, 1.0) : 1.0;
  return CameoMotion.easingStandard.transform(x);
}

const ({double nav, double bar}) aodControlOffsets = (
  nav: -(CameoLayout.topNavV6Top + CameoLayout.topNavV6ButtonSize),
  bar: CameoLayout.callV6BottomNavHeight,
);

Rect aodButtonRect(double w, double h) => Rect.fromLTWH(
  (w - CameoLayout.aodV6ButtonWidth) / 2,
  h -
      CameoLayout.screenV6HomeIndicatorHeight -
      CameoLayout.aodV6ButtonContainerPaddingY -
      CameoLayout.aodV6ButtonHeight,
  CameoLayout.aodV6ButtonWidth,
  CameoLayout.aodV6ButtonHeight,
);

/// RN `aodButtonTransform(p)`.
({double translateY, double opacity}) aodButtonTransform(double p) => (
  translateY: (1 - p) * CameoMotion.aodV6ButtonOffsetY,
  opacity: p.clamp(0.0, 1.0),
);

/// RN `photoSheetRect(W, H)`.
Rect photoSheetRect(double w, double h) => Rect.fromLTRB(
  CameoLayout.photoSheetV6MarginX,
  CameoLayout.photoSheetV6Top,
  w - CameoLayout.photoSheetV6MarginX,
  callBottomNavTop(h),
);

double photoSheetCellSize(double w) =>
    (w -
        2 * CameoLayout.photoSheetV6MarginX -
        (CameoLayout.photoSheetV6GridColumns - 1) *
            CameoLayout.photoSheetV6GridGap) /
    CameoLayout.photoSheetV6GridColumns;

const int photoSheetLiveRows = 2;

Size photoSheetLiveCell(double w) {
  final c = photoSheetCellSize(w);
  return Size(c, photoSheetLiveRows * c + CameoLayout.photoSheetV6GridGap);
}

double photoSheetGridHeight(double h) =>
    callBottomNavTop(h) -
    CameoLayout.photoSheetV6Top -
    CameoLayout.photoSheetV6HeaderHeight;

({double x, double y, double size, int row, int col}) photoSheetCellFrame(
  int index,
  double w,
) {
  const columns = CameoLayout.photoSheetV6GridColumns;
  const top = photoSheetLiveRows * (columns - 1);
  final int row;
  final int col;
  if (index < top) {
    row = index ~/ (columns - 1);
    col = 1 + index % (columns - 1);
  } else {
    final k = index - top;
    row = photoSheetLiveRows + k ~/ columns;
    col = k % columns;
  }
  final size = photoSheetCellSize(w);
  final step = size + CameoLayout.photoSheetV6GridGap;
  return (x: col * step, y: row * step, size: size, row: row, col: col);
}

double photoSheetContentHeight(int count, double w) {
  final rows = count <= 0
      ? photoSheetLiveRows
      : math.max(photoSheetLiveRows, photoSheetCellFrame(count - 1, w).row + 1);
  return rows * photoSheetCellSize(w) +
      (rows - 1) * CameoLayout.photoSheetV6GridGap;
}

double photoSheetHiddenOffset(double h) => h - CameoLayout.photoSheetV6Top;

bool photoSheetShouldClose(
  double dragY,
  double velocityY,
  double sheetHeight,
) =>
    dragY >= CameoMotion.photoSheetDismissProgress * sheetHeight ||
    velocityY >= CameoMotion.photoSheetDismissVelocity;

typedef PhotoSheetCandidate<P> = ({
  P photo,
  String id,
  String? file,
  bool today,
});

List<P> photoSheetOrder<P>(
  List<PhotoSheetCandidate<P>> photos,
  List<String> preferredFiles,
) {
  final today = [
    for (final p in photos)
      if (p.today) p,
  ];
  final rest = [
    for (final p in photos)
      if (!p.today) p,
  ];
  final rank = {
    for (var i = 0; i < preferredFiles.length; i++) preferredFiles[i]: i,
  };
  final seenFiles = <String>{};
  final preferred = <PhotoSheetCandidate<P>>[];
  for (final p in rest) {
    final file = p.file;
    if (file == null || !rank.containsKey(file)) continue;
    if (!seenFiles.add(file)) continue;
    preferred.add(p);
  }
  preferred.sort((a, b) => rank[a.file]!.compareTo(rank[b.file]!));
  final picked = {for (final p in preferred) p.id};
  return [
    for (final p in today) p.photo,
    for (final p in preferred) p.photo,
    for (final p in rest)
      if (!picked.contains(p.id)) p.photo,
  ];
}

abstract final class CallDemoV6 {
  static const Duration volume = Duration(milliseconds: 1500);
  static const Duration volumeMove = Duration(milliseconds: 2100);
  static const Duration highlight = Duration(milliseconds: 5000);
  static const Duration sheet = Duration(milliseconds: 8000);
  static const Duration pick = Duration(milliseconds: 9500);
  static const Duration pickSecond = Duration(milliseconds: 10100);
  static const Duration share = Duration(milliseconds: 10900);
  static const Duration closeCard = Duration(milliseconds: 13500);
  static const Duration sleep = Duration(milliseconds: 15000);
  static const Duration sleepEnd = Duration(milliseconds: 20000);

  static const Duration volumeMoveDuration = Duration(milliseconds: 900);
  static const double volumeMoveDelta = 0.4;
}

enum SleepPhase { off, aod }

enum SleepEvent { moon, end }

SleepPhase? sleepTransition(SleepPhase phase, SleepEvent event) =>
    switch (event) {
      SleepEvent.moon => phase == SleepPhase.off ? SleepPhase.aod : null,
      SleepEvent.end => phase == SleepPhase.aod ? SleepPhase.off : null,
    };

enum ReviewStage { none, review, send, discard }

enum ReviewEvent { capture, send, discard, exited }

ReviewStage? reviewTransition(ReviewStage stage, ReviewEvent event) =>
    switch (event) {
      ReviewEvent.capture =>
        stage == ReviewStage.none ? ReviewStage.review : null,
      ReviewEvent.send => stage == ReviewStage.review ? ReviewStage.send : null,
      ReviewEvent.discard =>
        stage == ReviewStage.review ? ReviewStage.discard : null,
      ReviewEvent.exited =>
        stage == ReviewStage.send || stage == ReviewStage.discard
            ? ReviewStage.none
            : null,
    };

bool reviewHidesTabBar(ReviewStage stage) => stage == ReviewStage.review;

/// RN `partnerToastArmed`.
bool partnerToastArmed({
  required bool tab,
  required bool focused,
  required bool shown,
  required ReviewStage stage,
}) => tab && focused && !shown && stage == ReviewStage.none;

({bool volume, bool camera, bool highlight, bool microphone}) callBarSelection({
  required bool sliderShown,
  required bool sheetOpen,
  required bool toastVisible,
  required bool muted,
}) => (
  volume: sliderShown,
  camera: sheetOpen,
  highlight: toastVisible,
  microphone: muted,
);

({CapturedOrientation? card, bool slider, bool highlight, bool sleep})
callInitialFlags(String state) {
  const none = (card: null, slider: false, highlight: false, sleep: false);
  return switch (state) {
    'media-16x9' || 'media-1x1' => (
      card: CapturedOrientation.portrait,
      slider: false,
      highlight: false,
      sleep: false,
    ),
    'media-4x3' => (
      card: CapturedOrientation.landscape,
      slider: false,
      highlight: false,
      sleep: false,
    ),
    'volume' => (card: null, slider: true, highlight: false, sleep: false),
    'highlight' => (card: null, slider: false, highlight: true, sleep: false),
    'aod' ||
    'sleep-toast' => (card: null, slider: false, highlight: false, sleep: true),
    _ => none,
  };
}
