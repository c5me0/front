// Pure album modes, selection actions, section tone sampling, and timeline geometry.

import 'dart:math' as math;
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';

import '../../content/lab.g.dart';
import '../../design_system/design_system.dart';
import '../../navigation/rubber_band.dart';
import '../../state/album_store.dart';

enum AlbumMode { timeline, select, liked, deleted }

enum AlbumModeEvent { select, liked, deleted, close, empty }

AlbumMode albumModeAfter(AlbumMode mode, AlbumModeEvent event) {
  switch (event) {
    case AlbumModeEvent.empty:
      return AlbumMode.timeline;
    case AlbumModeEvent.close:
      return AlbumMode.timeline;
    case AlbumModeEvent.select:
      return mode == AlbumMode.timeline ? AlbumMode.select : mode;
    case AlbumModeEvent.liked:
      return mode == AlbumMode.timeline ? AlbumMode.liked : mode;
    case AlbumModeEvent.deleted:
      return mode == AlbumMode.timeline ? AlbumMode.deleted : mode;
  }
}

bool isSelectionMode(AlbumMode mode) => mode != AlbumMode.timeline;

double albumModeProgressTarget(AlbumMode mode) =>
    mode == AlbumMode.timeline ? 0 : 1;

enum AlbumNavLeft { select, close }

enum AlbumNavRight { main, selection, restore }

({AlbumNavLeft left, AlbumNavRight right}) albumNavChrome(AlbumMode mode) {
  if (mode == AlbumMode.timeline) {
    return (left: AlbumNavLeft.select, right: AlbumNavRight.main);
  }
  return (
    left: AlbumNavLeft.close,
    right: mode == AlbumMode.deleted
        ? AlbumNavRight.restore
        : AlbumNavRight.selection,
  );
}

int albumNavPillCount(AlbumNavRight right) =>
    right == AlbumNavRight.restore ? 1 : 3;

/// RN `layoutLikes(liked, mode)`.
List<bool> layoutLikes(List<bool> liked, AlbumMode mode) {
  final tiles = mode == AlbumMode.timeline || mode == AlbumMode.select;
  return [for (final v in liked) tiles && v];
}

/// RN `GridBadge`.
enum GridBadge { tile, every, none }

/// RN `gridBadgeOf`.
GridBadge gridBadgeOf(AlbumMode mode) => switch (mode) {
  AlbumMode.liked => GridBadge.every,
  AlbumMode.deleted => GridBadge.none,
  _ => GridBadge.tile,
};

bool cellHeartShown(
  GridBadge badge, {
  required bool tile,
  required bool selected,
  required bool exiting,
}) {
  if (exiting || selected) return false;
  return badge == GridBadge.every || (badge == GridBadge.tile && tile);
}

/// RN `selectionHeartTarget`.
bool? selectionHeartTarget(List<bool> likedFlags) {
  if (likedFlags.isEmpty) return null;
  return !likedFlags.every((v) => v);
}

/// RN `albumSectionsForMode(view, mode)`.
List<AlbumSection> albumSectionsForMode({
  required List<AlbumSection> sections,
  required List<AlbumSection> liked,
  required List<AlbumSection> deleted,
  required AlbumMode mode,
}) {
  if (mode == AlbumMode.timeline || mode == AlbumMode.select) return sections;
  final list = mode == AlbumMode.liked ? liked : deleted;
  if (list.isNotEmpty) return list;
  for (final s in sections) {
    if (s.heroImage != null) return [s.withPhotos(const [])];
  }
  return const [];
}

enum SectionHeaderKind { hero, text }

enum AlbumTone { photo, light }

@immutable
class SectionBlockPadding {
  const SectionBlockPadding({
    required this.top,
    required this.x,
    required this.bottom,
  });

  static const SectionBlockPadding zero = SectionBlockPadding(
    top: 0,
    x: 0,
    bottom: 0,
  );

  final double top;
  final double x;
  final double bottom;

  @override
  bool operator ==(Object other) =>
      other is SectionBlockPadding &&
      other.top == top &&
      other.x == x &&
      other.bottom == bottom;

  @override
  int get hashCode => Object.hash(top, x, bottom);

  @override
  String toString() => 'SectionBlockPadding($top, $x, $bottom)';
}

@immutable
class SectionCardsPlan {
  const SectionCardsPlan({
    required this.count,
    required this.padding,
    required this.gap,
    required this.height,
  });

  final int count;
  final SectionBlockPadding padding;
  final double gap;
  final double height;
}

@immutable
class SectionGridPlan {
  const SectionGridPlan({required this.has, required this.padding});

  final bool has;
  final SectionBlockPadding padding;
}

@immutable
class SectionPlan {
  const SectionPlan({
    required this.header,
    required this.headerHeight,
    required this.titleTop,
    required this.metaTop,
    required this.cards,
    required this.grid,
    required this.tone,
    required this.tint,
  });

  final SectionHeaderKind header;

  final double headerHeight;

  final double titleTop;
  final double metaTop;
  final SectionCardsPlan cards;
  final SectionGridPlan grid;
  final AlbumTone tone;

  final String tint;
}

const Map<AlbumTone, String> toneTint = {
  AlbumTone.photo: 'section/tint',
  AlbumTone.light: 'background/canvas/neutral/base',
};

double cardsBlockHeight(int count, SectionBlockPadding padding, double gap) {
  if (count <= 0) return 0;
  return padding.top +
      count * CameoLayout.callListV6Height +
      (count - 1) * gap +
      padding.bottom;
}

const double _headingLgLine =
    CameoLayout.albumV6HeroMetaTop -
    CameoLayout.albumV6HeroTitleTop -
    CameoLayout.albumV6HeroGap;

double heroSize(double width) => width;

double heroMetaTop(double width) =>
    heroSize(width) -
    CameoLayout.albumV6HeroPadding -
    CameoLayout.albumV6MetaHeight;

double heroTitleTop(double width) =>
    heroMetaTop(width) - CameoLayout.albumV6HeroGap - _headingLgLine;

SectionPlan resolveSectionPlan({
  required AlbumSectionKind kind,
  required bool hasHero,
  required int callCount,
  required int photoCount,
  required double width,
}) {
  final header = hasHero ? SectionHeaderKind.hero : SectionHeaderKind.text;
  final callsOnly = kind == AlbumSectionKind.callsOnly;
  final cardsPadding = callCount == 0
      ? SectionBlockPadding.zero
      : callsOnly
      ? const SectionBlockPadding(
          top: CameoLayout.albumV6CallsOnlyListPaddingTop,
          x: CameoLayout.albumV6CallsOnlyListPaddingX,
          bottom: CameoLayout.albumV6CallsOnlyListPaddingBottom,
        )
      : const SectionBlockPadding(
          top: CameoLayout.albumV6CardsPadding,
          x: CameoLayout.albumV6CardsPadding,
          bottom: CameoLayout.albumV6CardsPadding,
        );
  final cardsGap = callsOnly
      ? CameoLayout.albumV6CallsOnlyListGap
      : CameoLayout.albumV6CardsGap;
  final hero = header == SectionHeaderKind.hero;
  final tone = hero ? AlbumTone.photo : AlbumTone.light;
  return SectionPlan(
    header: header,
    headerHeight: hero
        ? heroSize(width)
        : CameoLayout.albumV6CallsOnlyHeaderHeight,
    titleTop: hero
        ? heroTitleTop(width)
        : CameoLayout.albumV6CallsOnlyHeaderPaddingTop,

    metaTop: hero
        ? heroMetaTop(width)
        : CameoLayout.albumV6CallsOnlyHeaderHeight -
              CameoLayout.albumV6CallsOnlyHeaderPaddingBottom -
              CameoLayout.albumV6MetaHeight,
    cards: SectionCardsPlan(
      count: callCount,
      padding: cardsPadding,
      gap: cardsGap,
      height: cardsBlockHeight(callCount, cardsPadding, cardsGap),
    ),
    grid: SectionGridPlan(
      has: photoCount > 0,
      padding: photoCount > 0
          ? const SectionBlockPadding(
              top: CameoLayout.albumV6GridPadding,
              x: CameoLayout.albumV6GridPadding,
              bottom: CameoLayout.albumV6GridPadding,
            )
          : SectionBlockPadding.zero,
    ),
    tone: tone,
    tint: toneTint[tone]!,
  );
}

double gridCellSize(double width) {
  const columns = CameoLayout.albumV6GridColumns;
  final raw =
      (width -
          2 * CameoLayout.albumV6GridPadding -
          (columns - 1) * CameoLayout.albumV6GridGap) /
      columns;
  return raw > 0 ? raw : 0;
}

double likedTileSize(double width) =>
    2 * gridCellSize(width) + CameoLayout.albumV6GridGap;

double gridHeight(int rows, SectionBlockPadding padding, double width) {
  if (rows <= 0) return 0;
  final cell = gridCellSize(width);
  return padding.top +
      rows * cell +
      (rows - 1) * CameoLayout.albumV6GridGap +
      padding.bottom;
}

/// pb 8 → 94). RN `lastSectionInset`.
double lastSectionInset(SectionPlan plan) {
  final natural = plan.grid.has
      ? plan.grid.padding.bottom
      : plan.cards.count > 0
      ? plan.cards.padding.bottom
      : 0.0;
  return math.max(0, CameoLayout.tabBarV6FullContainerHeight - natural);
}

double sectionHeight(
  SectionPlan plan,
  int gridRows,
  double width, {
  required bool isLast,
}) =>
    plan.headerHeight +
    plan.cards.height +
    gridHeight(gridRows, plan.grid.padding, width) +
    (isLast ? lastSectionInset(plan) : 0);

/// RN `sectionSlotTops`.
List<double> sectionSlotTops(
  SectionPlan plan,
  int gridRows,
  double width, {
  bool cardsCollapsed = false,
}) {
  final tops = <double>[plan.titleTop, plan.metaTop];
  final cardsTop = plan.headerHeight;
  for (var i = 0; i < plan.cards.count; i++) {
    tops.add(
      cardsCollapsed
          ? cardsTop
          : cardsTop +
                plan.cards.padding.top +
                i * (CameoLayout.callListV6Height + plan.cards.gap),
    );
  }
  final gridTop = cardsTop + (cardsCollapsed ? 0 : plan.cards.height);
  final step = gridCellSize(width) + CameoLayout.albumV6GridGap;
  for (var r = 0; r < gridRows; r++) {
    tops.add(gridTop + plan.grid.padding.top + r * step);
  }
  return tops;
}

int firstRowSlot(SectionPlan plan) => 2 + plan.cards.count;

int revealCount(
  List<double> slotTops,
  double sectionTop,
  double scrollY,
  double viewportH,
) {
  if (sectionTop < 0) return 0;
  final edge = scrollY + viewportH;
  var n = 0;
  while (n < slotTops.length && sectionTop + slotTops[n] < edge) {
    n += 1;
  }
  return n;
}

Duration revealDelay(int k, int revealed) =>
    CameoMotion.albumContentStagger * math.max(0, k - revealed);

double heroEnterProgress(double heroTopInViewport, double viewportH) {
  if (viewportH <= 0) return 1;
  final p =
      (viewportH - heroTopInViewport) /
      (CameoMotion.albumHeroEnterRange * viewportH);
  return p.clamp(0.0, 1.0);
}

({double scale, double veil}) heroEnterLook(double p) => (
  scale:
      CameoMotion.albumHeroEnterScale +
      (1 - CameoMotion.albumHeroEnterScale) * p,
  veil: CameoMotion.albumHeroEnterDimOpacity * (1 - p),
);

double heroScrollOffset(
  double scrollY,
  double sectionTop, {
  required bool first,
}) {
  final local = scrollY - sectionTop;
  return first ? local : math.max(0, local);
}

const double navToneSampleY =
    CameoLayout.topNavV6Top + CameoLayout.topNavV6ButtonSize / 2;

double tabBarToneSampleY(double viewportH) =>
    viewportH -
    CameoLayout.screenV6HomeIndicatorHeight -
    CameoLayout.tabBarV6FullPillHeight / 2;

@immutable
class ToneBand {
  const ToneBand({required this.top, required this.bottom, required this.tone});

  factory ToneBand.of(double top, double height, AlbumTone tone) =>
      ToneBand(top: top, bottom: top + height, tone: tone);

  final double top;
  final double bottom;
  final AlbumTone tone;

  @override
  bool operator ==(Object other) =>
      other is ToneBand &&
      other.top == top &&
      other.bottom == bottom &&
      other.tone == tone;

  @override
  int get hashCode => Object.hash(top, bottom, tone);

  @override
  String toString() => 'ToneBand($top – $bottom, ${tone.name})';
}

AlbumTone toneAtY(List<ToneBand> bands, double y) {
  if (bands.isEmpty) return AlbumTone.photo;
  if (y < bands.first.top) return bands.first.tone;
  for (final b in bands) {
    if (y >= b.top && y < b.bottom) return b.tone;
  }
  return bands.last.tone;
}

AlbumTone toneOfProgress(double p) =>
    p >= 0.5 ? AlbumTone.light : AlbumTone.photo;

/// RN `TONE_BACKDROP`.
GlassBackdropTone toneBackdropOf(AlbumTone tone) => switch (tone) {
  AlbumTone.photo => GlassBackdropTone.fromToken(
    CameoEffects.liquidGlassBackdropAlbumV6,
  ),
  AlbumTone.light => GlassBackdropTone.fromToken(
    CameoEffects.liquidGlassBackdropEmptyAlbumV6,
  ),
};

GlassBackdropTone backdropOfToneProgress(double p) =>
    toneBackdropOf(toneOfProgress(p));

bool toneStatusGlyphsLight(AlbumTone tone) => tone != AlbumTone.light;

String clearTintOf(String tint) => tint == toneTint[AlbumTone.light]
    ? 'effect/linear/subtle'
    : 'section/tint-clear';

({double height, String from, String to})? boundaryBlendOf(
  int index,
  String? prevTint,
) {
  if (index <= 0 || prevTint == null) return null;
  return (
    height: CameoLayout.albumV6BoundaryBlendHeight,
    from: prevTint,
    to: clearTintOf(prevTint),
  );
}

Set<String> toggledSelection(Set<String> selected, String id) {
  final next = {...selected};
  if (!next.remove(id)) next.add(id);
  return next;
}

Set<String> prunedSelection(Set<String> selected, Set<String> existing) {
  if (selected.every(existing.contains)) return selected;
  return {
    for (final id in selected)
      if (existing.contains(id)) id,
  };
}

List<String> demoSelectionIds(List<AlbumPhoto> photos, AlbumMode mode, int n) {
  final tiles = mode == AlbumMode.timeline || mode == AlbumMode.select;
  return [
    for (final p in photos)
      if (!(tiles && p.liked)) p.id,
  ].take(math.max(0, n)).toList();
}

({double normal, double select}) navSwapScales(double s, double epsilon) {
  final a = (s / 0.5).clamp(0.0, 1.0);
  final b = ((s - 0.5) / 0.5).clamp(0.0, 1.0);
  return (normal: 1 + (epsilon - 1) * a, select: epsilon + (1 - epsilon) * b);
}

Rect viewerCardRectV6(
  double width, {
  double height = CameoLayout.screenV6Height,
  double aspectRatio = CameoLayout.viewerV6CardAspectRatio,
}) {
  final ratio = aspectRatio > 0 && aspectRatio.isFinite ? aspectRatio : 3 / 4;
  const top = CameoLayout.screenV6StatusBarHeight;
  final available = math.max(
    1.0,
    height - top - CameoLayout.viewerV6BottomHeight,
  );
  final maxWidth = width - 2 * CameoLayout.viewerV6CardInset;
  final cardHeight = math.min(maxWidth / ratio, available);
  final cardWidth = math.min(maxWidth, cardHeight * ratio);
  final aboveStrip = available - CameoLayout.silicaViewerStripHeight;
  return Rect.fromLTWH(
    (width - cardWidth) / 2,
    top + (cardHeight <= aboveStrip ? (aboveStrip - cardHeight) / 2 : 0),
    cardWidth,
    cardHeight,
  );
}

double viewerStripTop(
  double width, {
  double height = CameoLayout.screenV6Height,
}) =>
    height -
    CameoLayout.viewerV6BottomHeight -
    CameoLayout.silicaViewerStripHeight;

double viewerDatePillTop(double height) =>
    height -
    CameoLayout.screenV6HomeIndicatorHeight -
    CameoLayout.viewerV6BottomRowPaddingY -
    CameoLayout.viewerV6DatePillHeight;

({double top, double date, double strip}) viewerChromeTravel(
  double width,
  double height,
) => (
  top: CameoLayout.topNavV6Top + CameoLayout.topNavV6ButtonSize,
  date: CameoLayout.viewerV6BottomHeight,
  strip: height - viewerStripTop(width, height: height),
);

double viewerPageStep(double width) => width;

double stripOffsetX(double pos, double width) =>
    width / 2 -
    CameoLayout.viewerV6StripCellSize / 2 -
    pos * (CameoLayout.viewerV6StripCellSize + CameoLayout.viewerV6StripGap);

double stripJumpStart(int index, int target) {
  final d = target - index;
  if (d.abs() <= 1) return index.toDouble();
  return (target - d.sign).toDouble();
}

typedef ViewerDragLook = ({
  double tx,
  double ty,
  double scale,
  double dim,
  double chrome,
});

ViewerDragLook viewerDragLook(double dx, double dy, double cardH) {
  final f = cardH > 0 ? math.max(0.0, dy) / cardH : 0.0;
  final hide = math.min(1.0, f / (2 * CameoMotion.viewerDismissProgress));
  return (
    tx: dx,
    ty: dy >= 0 ? dy : rubberBand(dy, cardH),
    scale: 1 - (1 - CameoMotion.viewerDragMinScale) * math.min(1.0, f),
    dim: 1 - hide,
    chrome: hide,
  );
}

bool viewerShouldDismiss(double dy, double vy, double cardH) {
  final offset = math.max(0.0, dy);
  final velocity = math.max(0.0, vy);
  if (cardH <= 0) return velocity >= CameoMotion.viewerDismissVelocity;
  return offset / cardH >= CameoMotion.viewerDismissProgress ||
      velocity >= CameoMotion.viewerDismissVelocity;
}

double viewerPagePosition(int index, int count, double dx, double pageWidth) {
  if (pageWidth <= 0) return index.toDouble();
  final beyondStart = index <= 0 && dx > 0;
  final beyondEnd = index >= count - 1 && dx < 0;
  final d = beyondStart || beyondEnd ? rubberBand(dx, pageWidth) : dx;
  return index - d / pageWidth;
}

int viewerPageTarget(
  int index,
  int count,
  double dx,
  double vx,
  double pageWidth,
) {
  final progress = pageWidth > 0 ? -dx / pageWidth : 0.0;
  var target = index;
  if (progress >= CameoMotion.viewerPageCompleteProgress ||
      -vx >= CameoMotion.viewerPageCompleteVelocity) {
    target = index + 1;
  } else if (progress <= -CameoMotion.viewerPageCompleteProgress ||
      vx >= CameoMotion.viewerPageCompleteVelocity) {
    target = index - 1;
  }
  return math.min(math.max(0, count - 1), math.max(0, target));
}

List<int> viewerPageWindow(int index, int count) => [
  for (var k = index - 1; k <= index + 1; k++)
    if (k >= 0 && k < count) k,
];

double emptyColumnTop(double height) =>
    (height - CameoLayout.emptyAlbumV6ColumnHeight) / 2;

double emptyFloatY(double tMs, int i) =>
    CameoMotion.emptyAlbumFloatAmplitude *
    math.sin(
      2 *
          math.pi *
          (tMs - i * CameoMotion.emptyAlbumFloatStagger.inMilliseconds) /
          CameoMotion.emptyAlbumFloatPeriod.inMilliseconds,
    );

({List<Duration> avatars, Duration title, Duration cta}) emptyEntranceDelays(
  int avatarCount,
) {
  final text = CameoMotion.emptyAlbumEnterStagger * avatarCount;
  return (
    avatars: [
      for (var i = 0; i < avatarCount; i++)
        CameoMotion.emptyAlbumEnterStagger * i,
    ],
    title: text,
    cta: text + CameoMotion.albumContentStagger,
  );
}

const double demoScrollAnchorY = CameoLayout.albumNavV6HeaderHeight;

List<double> demoScrollStops(
  List<double> sectionTops,
  double contentHeight,
  double viewportH,
) {
  final max = math.max(0.0, contentHeight - viewportH);
  final stops = <double>[];
  void push(double y) {
    if (stops.isEmpty || (stops.last - y).abs() > 0.5) stops.add(y);
  }

  for (var i = 1; i < sectionTops.length; i++) {
    push(math.max(0.0, math.min(max, sectionTops[i] - demoScrollAnchorY)));
  }
  push(max);
  push(0);
  return stops;
}
