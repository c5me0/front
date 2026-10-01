// Album detail preview supporting standalone and nested-tab navigation, measured zoom
// sources, and scroll restoration.

import 'package:flutter/widgets.dart';
import '../../content/app.g.dart';

import '../../components/album_hero.dart';
import '../../components/album_section.dart';
import '../../components/glass_tab_bar.dart';
import '../../components/nav_bar.dart';
import '../../components/photo_grid.dart';
import '../../components/quote_card.dart';
import '../../content/lab.g.dart';
import '../../design_system/design_system.dart';
import '../../navigation/navigation.dart';

const CameoColorMode _colorMode = CameoColorMode.light;

final List<String> _photos = [
  for (final p in labAlbumGangneung.grid.photos) p.image,
];

const int _phoneTab = 1;

const List<(int atMs, int photoNumber)> _demoTimeline = [
  (1500, 4),
  (4000, 9),
  (6500, 4),
];

class AlbumGangneungScreen extends StatefulWidget {
  const AlbumGangneungScreen({
    super.key,
    this.initialScroll,
    this.demo = false,
    this.home = false,
    this.inTabs = false,
  });

  final double? initialScroll;

  final bool demo;

  final bool home;

  final bool inTabs;

  @override
  State<AlbumGangneungScreen> createState() => _AlbumGangneungScreenState();
}

class _AlbumGangneungScreenState extends State<AlbumGangneungScreen> {
  late final _InitialScrollController _scroll = _InitialScrollController(
    initialScrollOffset: widget.initialScroll ?? 0,
  );

  List<bool> _liked = photoGridInitialLikes(labAlbumGangneung.grid.photos);

  final DemoTimeline _demo = DemoTimeline();

  late final VoidCallback _unregisterFlow;

  void _toggleLike(int index) {
    if (!mounted) return;
    setState(() => _liked = photoGridToggleLike(_liked, index));
  }

  void _openAlbum() {
    if (mounted) CameoNav.push(context, CameoRoutes.album);
  }

  void _openQuote(QuoteCardContent _) {
    if (!mounted) return;
    CameoNav.push(context, CameoRoutes.transcript(theme: TranscriptTheme.dark));
  }

  @override
  void initState() {
    super.initState();
    _unregisterFlow = FlowDemo.register(
      FlowDemoAction.gangneungOpenAlbum,
      _openAlbum,
      isReady: () => mounted && CameoNav.isTop(context),
    );
    if (widget.demo) {
      _demo.start([
        for (final (atMs, photoNumber) in _demoTimeline)
          (
            at: Duration(milliseconds: atMs),
            run: () => _toggleLike(photoNumber - 1),
          ),
      ]);
    }
    final initial = widget.initialScroll;
    if (initial == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients && _scroll.offset != initial) {
        _scroll.notifyCorrectedOffset();
      }
    });
  }

  @override
  void dispose() {
    _unregisterFlow();
    _demo.cancel();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = LabSamples.of(context).labAlbumGangneung;

    if (widget.inTabs) TabBarTone.report(context, TabBarV6Tone.photo);

    return ZoomChrome(
      child: CameoTheme(
        mode: _colorMode,
        child: ColoredBox(
          color: AlbumSectionBackground.section1.colorIn(
            CameoPalette.of(_colorMode),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              SingleChildScrollView(
                controller: _scroll,

                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),

                padding: const EdgeInsets.only(
                  bottom: CameoLayout.tabBarContainerHeight,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AlbumHero(
                      cover: content.cover,
                      title: content.title,
                      subtitle: content.date,
                      gradient: AlbumHeroGradient.albumHeroGangneung,
                      scrollOffset: ScrollOffsetListenable(_scroll),
                      onPress: _openAlbum,
                      accessibilityLabel: fillTemplate(
                        AppContent.of(context).v6.accessibility.dateAlbum,
                        {'title': content.title},
                      ),
                    ),
                    PhotoGrid(
                      variant: PhotoGridVariant.gangneung,
                      photos: _photos,
                      liked: _liked,
                      onToggleLike: _toggleLike,
                      animateIn: true,
                      footer: QuoteCard(
                        card: content.quoteCard,
                        onPress: _openQuote,
                      ),
                    ),
                  ],
                ),
              ),
              _GangneungNavBar(home: widget.home),
              if (!widget.inTabs) const _GangneungTabBar(),
            ],
          ),
        ),
      ),
    );
  }
}

class _GangneungNavBar extends StatefulWidget {
  const _GangneungNavBar({required this.home});

  final bool home;

  @override
  State<_GangneungNavBar> createState() => _GangneungNavBarState();
}

class _GangneungNavBarState extends State<_GangneungNavBar> {
  bool _starred = false;

  @override
  Widget build(BuildContext context) {
    return NavBar(
      variant: NavBarVariant.compact,
      leading: widget.home
          ? NavLeading(
              icon: CameoIconName.chevronLeft,
              onPress: () => CameoNav.push(context, CameoRoutes.lab),
              accessibilityLabel: AppContent.of(
                context,
              ).v6.accessibility.backLab,
            )
          : NavLeading(
              icon: CameoIconName.chevronLeft,
              onPress: () => CameoNav.pop(context),
              accessibilityLabel: AppContent.of(context).common.back,
            ),
      actions: [
        NavAction(
          icon: CameoIconName.star,
          activeIcon: CameoIconName.starFilled,
          active: _starred,
          onPress: () => setState(() => _starred = !_starred),
          accessibilityLabel: AppContent.of(context).v6.accessibility.favorite,
        ),
        NavAction(
          icon: CameoIconName.dots,
          accessibilityLabel: AppContent.of(context).v6.accessibility.more,
        ),
      ],
    );
  }
}

class _GangneungTabBar extends StatefulWidget {
  const _GangneungTabBar();

  @override
  State<_GangneungTabBar> createState() => _GangneungTabBarState();
}

class _GangneungTabBarState extends State<_GangneungTabBar> {
  int _tab = labAlbumGangneung.tabBar.selectedIndex;

  void _onSelect(int index) {
    if (!mounted) return;
    if (index == _phoneTab) {
      CameoNav.push(context, CameoRoutes.call());
    } else {
      setState(() => _tab = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassTabBar(
      selectedIndex: _tab,
      onSelect: _onSelect,
      avatar: labAlbumGangneung.tabBar.avatar,
    );
  }
}

class _InitialScrollController extends ScrollController {
  _InitialScrollController({super.initialScrollOffset});

  void notifyCorrectedOffset() => notifyListeners();

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    return _ClampOnceScrollPosition(
      physics: physics,
      context: context,
      initialPixels: initialScrollOffset,
      keepScrollOffset: keepScrollOffset,
      oldPosition: oldPosition,
      debugLabel: debugLabel,
    );
  }
}

class _ClampOnceScrollPosition extends ScrollPositionWithSingleContext {
  _ClampOnceScrollPosition({
    required super.physics,
    required super.context,
    super.initialPixels,
    super.keepScrollOffset,
    super.oldPosition,
    super.debugLabel,
  });

  bool _clamped = false;

  @override
  bool applyContentDimensions(double minScrollExtent, double maxScrollExtent) {
    if (!_clamped) {
      _clamped = true;
      if (hasPixels && pixels > maxScrollExtent) {
        correctPixels(maxScrollExtent);
      }
    }
    return super.applyContentDimensions(minScrollExtent, maxScrollExtent);
  }
}
