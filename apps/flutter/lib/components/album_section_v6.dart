// Date sections combine a hero, call cards, and the photo grid. Derive the section type
// from its current content and retain featured tiles during selection.

import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../content/lab.g.dart';
import '../design_system/design_system.dart';
import '../navigation/spring_timing.dart';
import '../screens/home_timeline/album_timeline_model.dart';
import '../state/album_store.dart';
import 'album_appear.dart';
import 'album_hero.dart' show albumHeroScrollTransform;
import 'call_list_card.dart';
import 'photo_grid_layout.dart';
import 'photo_grid_v6.dart';

const int _extraRowSlots = 4;

class AlbumSectionV6 extends StatefulWidget {
  const AlbumSectionV6({
    super.key,
    required this.section,
    required this.index,
    required this.isLast,
    required this.prevTint,
    required this.scrollY,
    required this.sectionTop,
    required this.viewportH,
    required this.mode,
    required this.modeProgress,
    this.selected = const {},
    required this.reduceMotion,
    this.onToggleLike,
    this.onOpenPhoto,
    this.onToggleSelect,
    this.onOpenCall,
    this.gridKey,
  });

  final AlbumSection section;

  final int index;
  final bool isLast;

  final String? prevTint;

  final ValueListenable<double> scrollY;

  final ValueListenable<double> sectionTop;
  final double viewportH;

  final AlbumMode mode;

  final Animation<double> modeProgress;
  final Set<String> selected;
  final bool reduceMotion;
  final ValueChanged<String>? onToggleLike;
  final void Function(String sectionId, String photoId)? onOpenPhoto;
  final ValueChanged<String>? onToggleSelect;
  final void Function(String sectionId, int cardIndex)? onOpenCall;

  final GlobalKey<PhotoGridV6State>? gridKey;

  static SectionPlan planOf(AlbumSection s, double width) {
    final calls = cardsOf(s);
    final kind = s.includeCalls
        ? s.kind
        : (calls.isEmpty
              ? AlbumSectionKind.photosOnly
              : AlbumSectionKind.photosCalls);
    return resolveSectionPlan(
      kind: kind,
      hasHero: s.heroImage != null,
      callCount: calls.length,
      photoCount: s.photos.length,
      width: width,
    );
  }

  static List<CallCardV5Content> cardsOf(AlbumSection s) =>
      s.includeCalls ? s.calls : s.content.callCards;

  static Key cardKey(String sectionId, int index) =>
      ValueKey('albumSection.$sectionId.card.$index');
  static Key heroKey(String sectionId) =>
      ValueKey('albumSection.$sectionId.hero');
  static Key heroImageKey(String sectionId) =>
      ValueKey('albumSection.$sectionId.heroImage');
  static Key heroVeilKey(String sectionId) =>
      ValueKey('albumSection.$sectionId.heroVeil');
  static Key heroGradientKey(String sectionId) =>
      ValueKey('albumSection.$sectionId.heroGradient');
  static Key headerKey(String sectionId) =>
      ValueKey('albumSection.$sectionId.header');
  static Key cardsKey(String sectionId) =>
      ValueKey('albumSection.$sectionId.cards');
  static Key gridBoxKey(String sectionId) =>
      ValueKey('albumSection.$sectionId.grid');
  static Key blendKey(String sectionId) =>
      ValueKey('albumSection.$sectionId.blend');
  static Key backgroundKey(String sectionId) =>
      ValueKey('albumSection.$sectionId.background');
  static Key titleKey(String sectionId) =>
      ValueKey('albumSection.$sectionId.title');
  static Key metaKey(String sectionId) =>
      ValueKey('albumSection.$sectionId.meta');

  @override
  State<AlbumSectionV6> createState() => AlbumSectionV6State();
}

class AlbumSectionV6State extends State<AlbumSectionV6>
    with TickerProviderStateMixin {
  late SectionPlan _plan;
  late int _gridRows;
  late List<double> _slotTops;
  double _width = 0;

  late final List<AnimationController> _appear;
  int _revealed = 0;
  final List<Timer> _timers = [];
  bool _checkPending = false;
  bool _started = false;

  @visibleForTesting
  int get revealed => _revealed;

  @visibleForTesting
  List<double> get appearValues => [for (final c in _appear) c.value];

  SectionPlan get plan => _plan;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final width = MediaQuery.sizeOf(context).width;
    if (width != _width || !_started) {
      _width = width;
      _computePlan();
    }
    if (_started) return;
    _started = true;
    final start = widget.reduceMotion ? 1.0 : 0.0;
    _appear = [
      for (var i = 0; i < _slotTops.length + _extraRowSlots; i++)
        AnimationController.unbounded(vsync: this, value: start),
    ];

    _revealed = widget.reduceMotion ? 1 << 30 : 0;
    widget.scrollY.addListener(_scheduleCheck);
    widget.sectionTop.addListener(_scheduleCheck);
    _scheduleCheck();
  }

  @override
  void didUpdateWidget(AlbumSectionV6 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollY != widget.scrollY) {
      oldWidget.scrollY.removeListener(_scheduleCheck);
      widget.scrollY.addListener(_scheduleCheck);
    }
    if (oldWidget.sectionTop != widget.sectionTop) {
      oldWidget.sectionTop.removeListener(_scheduleCheck);
      widget.sectionTop.addListener(_scheduleCheck);
    }
    _computePlan();
    _scheduleCheck();
  }

  @override
  void dispose() {
    widget.scrollY.removeListener(_scheduleCheck);
    widget.sectionTop.removeListener(_scheduleCheck);
    for (final t in _timers) {
      t.cancel();
    }
    for (final c in _appear) {
      c.dispose();
    }
    super.dispose();
  }

  void _computePlan() {
    final s = widget.section;
    _plan = AlbumSectionV6.planOf(s, _width);
    _gridRows = s.photos.isEmpty
        ? 0
        : layoutPhotoGrid(
            layoutLikes([for (final p in s.photos) p.liked], widget.mode),
            CameoLayout.albumV6GridColumns,
          ).rows;

    _slotTops = sectionSlotTops(
      _plan,
      _gridRows,
      _width,
      cardsCollapsed: isSelectionMode(widget.mode),
    );
  }

  void _scheduleCheck() {
    if (!mounted) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase != SchedulerPhase.persistentCallbacks) {
      _checkReveal();
      return;
    }
    if (_checkPending) return;
    _checkPending = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _checkPending = false;
      if (mounted) _checkReveal();
    });
  }

  void _checkReveal() {
    final n = revealCount(
      _slotTops,
      widget.sectionTop.value,
      widget.scrollY.value,
      widget.viewportH,
    );
    final done = _revealed;
    if (n <= done) return;
    for (var k = done; k < n && k < _appear.length; k++) {
      final delay = revealDelay(k, done);
      final controller = _appear[k];
      void play() {
        if (!mounted) return;
        controller.animateWith(
          cameoSpringSimulation(
            CameoMotion.albumContentSpring,
            from: controller.value,
            to: 1,
          ),
        );
      }

      if (delay == Duration.zero) {
        play();
      } else {
        _timers.add(Timer(delay, play));
      }
    }
    _revealed = n;
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final s = w.section;
    final plan = _plan;
    final c = CameoTheme.colorsOf(context);
    final rise = w.reduceMotion ? 0.0 : CameoMotion.albumContentRise;
    final band = boundaryBlendOf(w.index, w.prevTint);
    final rowStart = firstRowSlot(plan);
    final rowAppear = rowStart < _appear.length
        ? _appear.sublist(rowStart)
        : const <Animation<double>>[];
    final selecting = isSelectionMode(w.mode);

    final header = plan.header == SectionHeaderKind.hero
        ? _SectionHeroV6(
            key: AlbumSectionV6.heroKey(s.id),
            section: s,
            first: w.index == 0,
            size: plan.headerHeight,
            scrollY: w.scrollY,
            sectionTop: w.sectionTop,
            viewportH: w.viewportH,
            reduceMotion: w.reduceMotion,
            titleAppear: _appear[0],
            metaAppear: _appear[1],
            rise: rise,
          )
        : AlbumTextHeaderV6(
            key: AlbumSectionV6.headerKey(s.id),
            sectionId: s.id,
            title: s.content.title,
            subtitle: s.content.subtitle,
            stats: s.content.stats,
            titleAppear: _appear[0],
            metaAppear: _appear[1],
            rise: rise,
          );

    Widget? cards;
    if (plan.cards.count > 0) {
      final p = plan.cards.padding;
      final list = IgnorePointer(
        ignoring: selecting,
        child: ExcludeSemantics(
          excluding: selecting,
          child: Padding(
            padding: EdgeInsets.fromLTRB(p.x, p.top, p.x, p.bottom),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: plan.cards.gap,
              children: [
                for (final (i, call) in AlbumSectionV6.cardsOf(s).indexed)
                  AlbumAppear(
                    progress: 2 + i < _appear.length ? _appear[2 + i] : null,
                    rise: rise,
                    child: CallListCard.fromContent(
                      call,
                      key: AlbumSectionV6.cardKey(s.id, i),
                      onPress: w.onOpenCall == null
                          ? null
                          : () => w.onOpenCall!(s.id, i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
      cards = AnimatedBuilder(
        key: AlbumSectionV6.cardsKey(s.id),
        animation: w.modeProgress,
        child: list,
        builder: (context, child) {
          final k = w.modeProgress.value.clamp(0.0, 1.0);

          if (k >= 1) return const SizedBox.shrink();
          return ClipRect(
            child: Align(
              alignment: Alignment.topCenter,
              heightFactor: 1 - k,
              child: Opacity(opacity: 1 - k, child: child),
            ),
          );
        },
      );
    }

    Widget? grid;

    if (plan.grid.has || (selecting && plan.header == SectionHeaderKind.hero)) {
      final tiles = layoutLikes([for (final p in s.photos) p.liked], w.mode);
      grid = KeyedSubtree(
        key: AlbumSectionV6.gridBoxKey(s.id),
        child: PhotoGridV6(
          key: w.gridKey,
          items: [
            for (var i = 0; i < s.photos.length; i++)
              PhotoGridV6Item(
                id: s.photos[i].id,
                image: s.photos[i].thumbnailProvider,
                tile: tiles[i],
                label: '사진 ${i + 1}${s.photos[i].liked ? ', 좋아요' : ''}',
              ),
          ],
          badge: gridBadgeOf(w.mode),
          selecting: selecting,
          selected: w.selected,
          modeKey: w.mode.name,
          onToggleLike: w.onToggleLike,
          onOpen: w.onOpenPhoto == null
              ? null
              : (photoId) => w.onOpenPhoto!(s.id, photoId),
          onToggleSelect: w.onToggleSelect,
          rowAppear: rowAppear,
          appearRise: rise,
        ),
      );
    }

    return Stack(
      fit: StackFit.passthrough,
      clipBehavior: Clip.none,
      children: [
        Positioned(
          key: AlbumSectionV6.backgroundKey(s.id),
          left: 0,
          right: 0,
          top: 0,
          bottom: -1,
          child: IgnorePointer(
            child: ColoredBox(
              color: c.byRole[plan.tint] ?? c.backgroundCanvasNeutralBase,
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(
            bottom: w.isLast ? lastSectionInset(plan) : 0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [header, ?cards, ?grid],
          ),
        ),
        if (band != null)
          Positioned(
            key: AlbumSectionV6.blendKey(s.id),
            top: 0,
            left: 0,
            right: 0,
            child: BoundaryBandV6(from: band.from, to: band.to),
          ),
      ],
    );
  }
}

class BoundaryBandV6 extends StatelessWidget {
  const BoundaryBandV6({super.key, required this.from, required this.to});

  final String from;
  final String to;

  static const Key bandKey = ValueKey('boundaryBandV6.band');

  static const double seamBleed = 1;

  static LinearGradient gradientOf(CameoPalette c, String from, String to) =>
      LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          c.byRole[from] ?? c.sectionTint,
          c.byRole[to] ?? c.sectionTintClear,
        ],
      );

  @override
  Widget build(BuildContext context) {
    final c = CameoTheme.colorsOf(context);
    final g = gradientOf(c, from, to);
    const h = CameoLayout.albumV6BoundaryBlendHeight;
    return IgnorePointer(
      child: ExcludeSemantics(
        child: SizedBox(
          key: bandKey,
          height: h,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: -seamBleed,
                bottom: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: g.begin,
                      end: g.end,
                      colors: [g.colors.first, ...g.colors],
                      stops: const [0, seamBleed / (h + seamBleed), 1],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum AlbumMetaToneV6 { hero, text }

/// layout.albumV6.$roles.hero / callsOnly
({Color meta, Color icon, Color dot}) albumMetaRolesV6(
  CameoPalette c,
  AlbumMetaToneV6 tone,
) => switch (tone) {
  AlbumMetaToneV6.hero => (
    meta: c.staticWhiteMuted,
    icon: c.staticWhiteMuted,
    dot: c.staticWhiteMuted,
  ),
  AlbumMetaToneV6.text => (
    meta: c.foregroundNeutralMuted,
    icon: c.foregroundNeutralMuted,
    dot: c.backgroundFillNeutralInverted,
  ),
};

String albumMetaAccessibilityLabel(String label, AlbumStatsContent stats) =>
    '$label, 사진 ${stats.photos}장, 통화 ${stats.calls}건';

class AlbumMetaRowV6 extends StatelessWidget {
  const AlbumMetaRowV6({
    super.key,
    required this.label,
    required this.stats,
    required this.tone,
  });

  final String label;
  final AlbumStatsContent stats;
  final AlbumMetaToneV6 tone;

  static const Key dotKey = ValueKey('albumMetaRowV6.dot');

  @override
  Widget build(BuildContext context) {
    final roles = albumMetaRolesV6(CameoTheme.colorsOf(context), tone);
    Widget count(CameoIconName icon, String value) => Row(
      mainAxisSize: MainAxisSize.min,
      spacing: CameoLayout.albumV6MetaCountGap,
      children: [
        CameoIcon(
          icon,
          size: CameoLayout.albumV6MetaIconSize,
          color: roles.icon,
        ),
        CameoText(
          value,
          style: CameoTextStyles.bodyMd,
          color: roles.meta,
          maxLines: 1,
        ),
      ],
    );
    return Semantics(
      container: true,
      label: albumMetaAccessibilityLabel(label, stats),
      excludeSemantics: true,
      child: SizedBox(
        height: CameoLayout.albumV6MetaHeight,
        child: Row(
          spacing: CameoLayout.albumV6MetaGap,
          children: [
            Expanded(
              child: CameoText(
                label,
                style: CameoTextStyles.bodyMd,
                color: roles.meta,
                maxLines: 1,
              ),
            ),
            count(CameoIconName.photo, stats.photos),
            SizedBox.square(
              key: dotKey,
              dimension: CameoLayout.albumV6MetaDotSize,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: roles.dot,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            count(CameoIconName.phone, stats.calls),
          ],
        ),
      ),
    );
  }
}

class AlbumTextHeaderV6 extends StatelessWidget {
  const AlbumTextHeaderV6({
    super.key,
    required this.sectionId,
    required this.title,
    required this.subtitle,
    required this.stats,
    this.titleAppear,
    this.metaAppear,
    this.rise = 0,
  });

  final String sectionId;
  final String title;
  final String subtitle;
  final AlbumStatsContent stats;
  final Animation<double>? titleAppear;
  final Animation<double>? metaAppear;
  final double rise;

  @override
  Widget build(BuildContext context) {
    final c = CameoTheme.colorsOf(context);
    return SizedBox(
      height: CameoLayout.albumV6CallsOnlyHeaderHeight,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          CameoLayout.albumV6CallsOnlyHeaderPaddingX,
          CameoLayout.albumV6CallsOnlyHeaderPaddingTop,
          CameoLayout.albumV6CallsOnlyHeaderPaddingX,
          CameoLayout.albumV6CallsOnlyHeaderPaddingBottom,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: CameoLayout.albumV6CallsOnlyHeaderGap,
          children: [
            AlbumAppear(
              progress: titleAppear,
              rise: rise,
              child: Semantics(
                header: true,
                child: CameoText(
                  title,
                  key: AlbumSectionV6.titleKey(sectionId),
                  style: CameoTextStyles.headingLg,
                  color: c.foregroundNeutralBase,
                  maxLines: 1,
                ),
              ),
            ),
            AlbumAppear(
              progress: metaAppear,
              rise: rise,
              child: KeyedSubtree(
                key: AlbumSectionV6.metaKey(sectionId),
                child: AlbumMetaRowV6(
                  label: subtitle,
                  stats: stats,
                  tone: AlbumMetaToneV6.text,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeroV6 extends StatelessWidget {
  const _SectionHeroV6({
    super.key,
    required this.section,
    required this.first,
    required this.size,
    required this.scrollY,
    required this.sectionTop,
    required this.viewportH,
    required this.reduceMotion,
    required this.titleAppear,
    required this.metaAppear,
    required this.rise,
  });

  final AlbumSection section;
  final bool first;
  final double size;
  final ValueListenable<double> scrollY;
  final ValueListenable<double> sectionTop;
  final double viewportH;
  final bool reduceMotion;
  final Animation<double> titleAppear;
  final Animation<double> metaAppear;
  final double rise;

  @override
  Widget build(BuildContext context) {
    final c = CameoTheme.colorsOf(context);
    final content = section.content;

    final veil = c.staticBlackBase;
    final hero = section.heroImage;
    final image = hero == null
        ? const SizedBox.shrink()
        : Image(
            key: AlbumSectionV6.heroImageKey(section.id),
            image: hero,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            excludeFromSemantics: true,
          );
    return SizedBox(
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            child: ExcludeSemantics(
              child: AnimatedBuilder(
                animation: Listenable.merge([scrollY, sectionTop]),
                child: image,
                builder: (context, image) {
                  final top = sectionTop.value;
                  final y = scrollY.value;
                  final off = reduceMotion
                      ? 0.0
                      : heroScrollOffset(y, top, first: first);
                  final t = albumHeroScrollTransform(off, size);
                  final p = reduceMotion || top < 0
                      ? 1.0
                      : heroEnterProgress(top - y, viewportH);
                  final look = heroEnterLook(p);
                  return Transform(
                    alignment: Alignment.topCenter,
                    transform: Matrix4.translationValues(0, t.translateY, 0)
                      ..multiply(Matrix4.diagonal3Values(t.scale, t.scale, 1)),
                    child: ClipRect(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Transform.translate(
                            offset: Offset(0, t.parallaxY),
                            child: Transform.scale(
                              scale: look.scale,
                              child: image,
                            ),
                          ),
                          ColoredBox(
                            key: AlbumSectionV6.heroVeilKey(section.id),
                            color: veil.withValues(alpha: veil.a * look.veil),
                          ),
                          DecoratedBox(
                            key: AlbumSectionV6.heroGradientKey(section.id),
                            decoration: BoxDecoration(
                              gradient: c.gradients.albumHeroV6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Padding(
              padding: const EdgeInsets.all(CameoLayout.albumV6HeroPadding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: CameoLayout.albumV6HeroGap,
                children: [
                  AlbumAppear(
                    progress: titleAppear,
                    rise: rise,
                    child: Semantics(
                      header: true,
                      child: CameoText(
                        content.title,
                        key: AlbumSectionV6.titleKey(section.id),
                        style: CameoTextStyles.headingLg,
                        color: c.staticWhiteBase,
                        maxLines: 1,
                      ),
                    ),
                  ),
                  AlbumAppear(
                    progress: metaAppear,
                    rise: rise,
                    child: KeyedSubtree(
                      key: AlbumSectionV6.metaKey(section.id),
                      child: AlbumMetaRowV6(
                        label: content.subtitle,
                        stats: content.stats,
                        tone: AlbumMetaToneV6.hero,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
