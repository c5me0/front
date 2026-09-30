// Legacy album-list preview retained for card-to-album zoom transitions.

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../components/album_card.dart';
import '../../components/auth_scaffold.dart';
import '../../components/empty_state.dart';
import '../../components/glass_tab_bar.dart';
import '../../components/scroll_edge_fade.dart';
import '../../content/app.g.dart';
import '../../design_system/design_system.dart';
import '../../navigation/navigation.dart';
import '../../state/session.dart';

ZoomTarget _targetOf(AppContentHomeAlbum album) =>
    ZoomTarget.values.firstWhere((t) => t.id == album.route);

double homeHeaderTop(double safeTop) =>
    math.max(safeTop, CameoLayout.homeScreenHeaderTop);

double tabBarPillCenterY(double screenHeight) =>
    screenHeight -
    CameoLayout.tabBarContainerHeight +
    CameoLayout.tabBarContainerPaddingTop +
    CameoLayout.tabBarPillHeight / 2;

GlassTabBarTone homeTabBarTone({
  required int cardCount,
  required double scrollOffset,
  required Size screen,
  required double safeTop,
}) {
  final y = tabBarPillCenterY(screen.height);
  final size = screen.width - 2 * CameoLayout.homeScreenPaddingX;
  final first =
      homeHeaderTop(safeTop) +
      CameoLayout.homeScreenHeaderHeight +
      CameoLayout.homeScreenListGap -
      scrollOffset;
  for (var i = 0; i < cardCount; i++) {
    final top = first + i * (size + CameoLayout.homeScreenCardGap);
    if (top <= y && y <= top + size) return GlassTabBarTone.photo;
  }
  return GlassTabBarTone.canvas;
}

double scrollEdgeOpacity(double offset) =>
    (offset / CameoLayout.homeScreenHeaderHeight).clamp(0.0, 1.0);

class ScrollLinkedEdgeFade extends StatelessWidget {
  const ScrollLinkedEdgeFade({super.key, required this.controller});

  final ScrollController controller;

  static const Key opacityKey = ValueKey('scrollEdge.opacity');

  @override
  Widget build(BuildContext context) {
    final height = scrollEdgeFadeHeight(MediaQuery.paddingOf(context).top);
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: ListenableBuilder(
        listenable: controller,
        child: ScrollEdgeFade(height: height),
        builder: (context, child) => Opacity(
          key: opacityKey,
          opacity: controller.hasClients
              ? scrollEdgeOpacity(controller.offset)
              : 0,
          child: child,
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  static const Key scrollKey = ValueKey('home.scroll');
  static const Key headerKey = ValueKey('home.header');
  static const Key titleKey = ValueKey('home.title');
  static const Key subtitleKey = ValueKey('home.subtitle');
  static const Key emptyKey = ValueKey('home.empty');
  static Key cardKey(String id) => ValueKey('home.card.$id');

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<GlobalKey<AlbumCardState>> _cards = [
    for (final album in appContent.home.albums)
      GlobalKey<AlbumCardState>(debugLabel: 'home.card.${album.id}'),
  ];
  final List<VoidCallback> _unregisterFlow = [];
  final ScrollController _scroll = ScrollController();

  void _reportTone() {
    if (!mounted) return;
    final partner = SessionScope.read(context).session.partner;
    final tone = homeTabBarTone(
      cardCount: partner == null ? 0 : appContent.home.albums.length,
      scrollOffset: _scroll.hasClients ? _scroll.offset : 0,
      screen: MediaQuery.sizeOf(context),
      safeTop: MediaQuery.paddingOf(context).top,
    );

    TabBarTone.report(
      context,
      tone == GlassTabBarTone.canvas ? TabBarV6Tone.canvas : TabBarV6Tone.photo,
    );
  }

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_reportTone);
    _unregisterFlow
      ..add(FlowDemo.register(FlowDemoAction.homeOpenAlbum, () => _demo(0)))
      ..add(FlowDemo.register(FlowDemoAction.homeOpenDayAlbum, () => _demo(1)));
  }

  @override
  void dispose() {
    for (final unregister in _unregisterFlow) {
      unregister();
    }
    _scroll.dispose();
    super.dispose();
  }

  bool _open(ZoomTarget target, Rect rect) {
    if (!mounted || !CameoNav.isTop(context) || rect.isEmpty) return false;
    CameoNav.openAlbumZoom(context, target, rect);
    return true;
  }

  bool _demo(int index) {
    final card = _cards[index].currentState;
    if (card == null) return false;
    return _open(_targetOf(appContent.home.albums[index]), card.drawnRect);
  }

  @override
  Widget build(BuildContext context) => GlassBackdrop(
    tone: GlassBackdropTone.fromToken(
      CameoEffects.liquidGlassBackdropCanvasScreen,
    ),
    child: Builder(builder: _buildOnCanvas),
  );

  Widget _buildOnCanvas(BuildContext context) {
    final c = CameoTheme.colorsOf(context);
    final insets = MediaQuery.paddingOf(context);
    final partner = SessionScope.of(context).session.partner;
    final home = appContent.home;
    final top = homeHeaderTop(insets.top);
    _reportTone();
    const bottom =
        CameoLayout.tabBarContainerHeight + CameoLayout.homeScreenBottomGap;

    final header = AuthEntrance(
      index: 0,
      child: SizedBox(
        key: HomeScreen.headerKey,
        height: CameoLayout.homeScreenHeaderHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Semantics(
              header: true,
              child: CameoText(
                home.title,
                key: HomeScreen.titleKey,
                style: CameoTextStyles.headingLg,
                color: c.foregroundNeutralBase,
                maxLines: 1,
              ),
            ),
            const SizedBox(height: CameoLayout.homeScreenSubtitleGap),
            CameoText(
              partner == null
                  ? home.subtitleEmpty
                  : fillTemplate(home.subtitle, {
                      'partner': partner.name,
                      'count': home.albums.length,
                    }),
              key: HomeScreen.subtitleKey,
              style: CameoTextStyles.bodyMd,
              color: c.foregroundNeutralMuted,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );

    final Widget body;
    if (partner != null) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: CameoLayout.homeScreenCardGap,
        children: [
          for (var i = 0; i < home.albums.length; i++)
            AuthEntrance(
              index: i + 1,
              child: AlbumCard(
                key: _cards[i],
                data: albumCardDataFor(home.albums[i]),
                onPress: (rect) => _open(_targetOf(home.albums[i]), rect),
              ),
            ),
        ],
      );
    } else {
      body = EmptyState(
        key: HomeScreen.emptyKey,
        title: home.empty.title,
        body: home.empty.body,
        actionLabel: home.empty.cta,
        onAction: () => CameoNav.openConnect(context),
        entranceIndex: 1,
      );
    }

    return ColoredBox(
      color: c.backgroundCanvasBase,
      child: Stack(
        fit: StackFit.expand,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final fill =
                  constraints.maxHeight -
                  top -
                  CameoLayout.homeScreenHeaderHeight -
                  CameoLayout.homeScreenListGap -
                  bottom;
              return SingleChildScrollView(
                key: HomeScreen.scrollKey,
                controller: _scroll,
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: EdgeInsets.only(top: top, bottom: bottom),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: CameoLayout.homeScreenPaddingX,
                      ),
                      child: header,
                    ),
                    const SizedBox(height: CameoLayout.homeScreenListGap),
                    if (partner != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: CameoLayout.homeScreenPaddingX,
                        ),
                        child: body,
                      )
                    else
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: math.max(0, fill),
                        ),
                        child: Center(child: body),
                      ),
                  ],
                ),
              );
            },
          ),
          ScrollLinkedEdgeFade(controller: _scroll),
        ],
      ),
    );
  }
}
