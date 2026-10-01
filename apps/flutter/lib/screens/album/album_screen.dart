// Retained standalone album preview with hero, call history, and animated photo grid.

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/widgets.dart';
import '../../content/app.g.dart';

import '../../components/album_hero.dart';
import '../../components/album_section.dart';
import '../../components/call_history_list.dart';
import '../../components/nav_bar.dart';
import '../../components/photo_grid.dart';
import '../../components/text_header.dart';
import '../../content/lab.g.dart';
import '../../design_system/design_system.dart';
import '../../navigation/navigation.dart';

const CameoColorMode _colorMode = CameoColorMode.light;

AlbumSectionContent _sectionOf(String id) =>
    labAlbumDay.sections.firstWhere((s) => s.id == id);

final AlbumSectionContent _sungsu = _sectionOf('sungsu');

final AlbumSectionContent _emptyPhoto = _sectionOf('empty-photo');

final AlbumSectionContent _section3 = _sectionOf('section-3');

final List<String> _sungsuPhotos = [
  for (final p in _sungsu.grid!.photos) p.image,
];
final List<String> _section3Photos = [
  for (final p in _section3.grid!.photos) p.image,
];

const List<(int atMs, int photoNumber)> _demoTimeline = [
  (1500, 5),
  (4000, 12),
  (6500, 5),
];

TranscriptTheme transcriptThemeForSection(LabTone tone) =>
    tone == LabTone.dark ? TranscriptTheme.photo : TranscriptTheme.dark;

CameoStatusBarStyle _statusBarFor(AlbumSectionContent section) =>
    CameoStatusBarStyle.forBackground(dark: section.tone == LabTone.dark);

class AlbumScreen extends StatefulWidget {
  const AlbumScreen({super.key, this.initialScroll, this.demo = false});

  final double? initialScroll;

  final bool demo;

  static const ValueKey<String> scrollKey = ValueKey('album.scroll');
  static const ValueKey<String> backdropKey = ValueKey('album.backdrop');
  static const ValueKey<String> spacerKey = ValueKey('album.spacer');

  @override
  State<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends State<AlbumScreen> {
  late final ScrollController _scroll = _InitialScrollController(
    initialScrollOffset: widget.initialScroll ?? 0,
  );

  bool _liked = false;

  late final ValueNotifier<List<bool>> _sungsuLikes = ValueNotifier(
    photoGridInitialLikes(_sungsu.grid!.photos),
  );
  late final ValueNotifier<List<bool>> _section3Likes = ValueNotifier(
    photoGridInitialLikes(_section3.grid!.photos),
  );

  final DemoTimeline _demo = DemoTimeline();

  late final VoidCallback _unregisterFlow;

  void _toggleSungsuLike(int index) =>
      _sungsuLikes.value = photoGridToggleLike(_sungsuLikes.value, index);

  void _toggleSection3Like(int index) =>
      _section3Likes.value = photoGridToggleLike(_section3Likes.value, index);

  late final Widget _content = _AlbumContent(
    scrollOffset: ScrollOffsetListenable(_scroll),
    onOpenTranscript: _openTranscript,
    sungsuLikes: _sungsuLikes,
    onToggleSungsuLike: _toggleSungsuLike,
    section3Likes: _section3Likes,
    onToggleSection3Like: _toggleSection3Like,
  );

  @override
  void initState() {
    super.initState();
    if (widget.demo) {
      _demo.start([
        for (final (atMs, photoNumber) in _demoTimeline)
          (
            at: Duration(milliseconds: atMs),
            run: () {
              if (mounted) _toggleSungsuLike(photoNumber - 1);
            },
          ),
      ]);
    }

    _unregisterFlow = FlowDemo.register(
      FlowDemoAction.albumOpenPhotoCard,
      () => _openTranscript(_sungsu.tone),
    );
  }

  void _openTranscript(LabTone tone) {
    if (!mounted) return;
    CameoNav.push(
      context,
      CameoRoutes.transcript(theme: transcriptThemeForSection(tone)),
    );
  }

  @override
  void dispose() {
    _unregisterFlow();
    _demo.cancel();
    _sungsuLikes.dispose();
    _section3Likes.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ZoomChrome(
      child: CameoTheme(
        mode: _colorMode,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const _OverscrollBackdrop(),
            SingleChildScrollView(
              key: AlbumScreen.scrollKey,
              controller: _scroll,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              child: _content,
            ),
            NavBar(
              tone: NavBarTone.dark,
              leading: NavLeading(
                icon: CameoIconName.chevronLeft,
                onPress: () => CameoNav.pop(context),
                accessibilityLabel: AppContent.of(context).common.back,
              ),
              actions: [
                NavAction(
                  icon: CameoIconName.heart,
                  activeIcon: CameoIconName.heartFilled,
                  active: _liked,
                  onPress: () => setState(() => _liked = !_liked),
                  accessibilityLabel: AppContent.of(context).v6.album.likeLabel,
                ),

                NavAction(
                  icon: CameoIconName.history,
                  accessibilityLabel: AppContent.of(
                    context,
                  ).v6.accessibility.history,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OverscrollBackdrop extends StatelessWidget {
  const _OverscrollBackdrop();

  @override
  Widget build(BuildContext context) {
    final palette = CameoTheme.colorsOf(context);
    return IgnorePointer(
      key: AlbumScreen.backdropKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ColoredBox(
              color: AlbumSectionBackground.section1.colorIn(palette),
            ),
          ),
          Expanded(
            child: ColoredBox(
              color: AlbumSectionBackground.section3.colorIn(palette),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlbumContent extends StatelessWidget {
  const _AlbumContent({
    required this.scrollOffset,
    required this.onOpenTranscript,
    required this.sungsuLikes,
    required this.onToggleSungsuLike,
    required this.section3Likes,
    required this.onToggleSection3Like,
  });

  final ValueListenable<List<bool>> sungsuLikes;
  final ValueChanged<int> onToggleSungsuLike;

  final ValueListenable<List<bool>> section3Likes;
  final ValueChanged<int> onToggleSection3Like;

  final ScrollOffsetListenable scrollOffset;

  final ValueChanged<LabTone> onOpenTranscript;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CameoStatusBar(
          style: _statusBarFor(_sungsu),
          child: AlbumSection(
            background: AlbumSectionBackground.section1,
            children: [
              AlbumHero(
                cover: _sungsu.cover!,
                title: LabSamples.of(context).labAlbumDay.sections
                    .firstWhere((s) => s.id == 'sungsu')
                    .title,
                subtitle: LabSamples.of(context).labAlbumDay.sections
                    .firstWhere((s) => s.id == 'sungsu')
                    .subtitle,
                stats: _sungsu.stats,
                gradient: AlbumHeroGradient.albumHero,
                scrollOffset: scrollOffset,
              ),
              CallHistoryList(
                cards: LabSamples.of(context).labAlbumDay.sections
                    .firstWhere((s) => s.id == 'sungsu')
                    .callCards,
                tone: CallHistoryListTone.onPhoto,
                onPress: (_) => onOpenTranscript(_sungsu.tone),
                appearIndex: 0,
              ),

              ValueListenableBuilder<List<bool>>(
                valueListenable: sungsuLikes,
                builder: (context, liked, _) => PhotoGrid(
                  variant: PhotoGridVariant.bordered,
                  photos: _sungsuPhotos,
                  liked: liked,
                  onToggleLike: onToggleSungsuLike,
                  animateIn: true,
                  appearIndex: LabSamples.of(context).labAlbumDay.sections
                      .firstWhere((s) => s.id == 'sungsu')
                      .callCards
                      .length,
                ),
              ),
            ],
          ),
        ),

        CameoStatusBar(
          style: _statusBarFor(_emptyPhoto),
          child: AlbumSection(
            background: AlbumSectionBackground.canvasMuted,
            children: [
              TextHeader(
                title: LabSamples.of(context).labAlbumDay.sections
                    .firstWhere((s) => s.id == 'empty-photo')
                    .title,
                subtitle: LabSamples.of(context).labAlbumDay.sections
                    .firstWhere((s) => s.id == 'empty-photo')
                    .subtitle,
                stats: _emptyPhoto.stats,
              ),
              CallHistoryList(
                cards: LabSamples.of(context).labAlbumDay.sections
                    .firstWhere((s) => s.id == 'empty-photo')
                    .callCards,
                tone: CallHistoryListTone.light,
                onPress: (_) => onOpenTranscript(_emptyPhoto.tone),
              ),
            ],
          ),
        ),

        CameoStatusBar(
          style: _statusBarFor(_section3),
          child: AlbumSection(
            background: AlbumSectionBackground.section3,
            children: [
              AlbumHero(
                cover: _section3.cover!,
                title: LabSamples.of(context).labAlbumDay.sections
                    .firstWhere((s) => s.id == 'section-3')
                    .title,
                subtitle: LabSamples.of(context).labAlbumDay.sections
                    .firstWhere((s) => s.id == 'section-3')
                    .subtitle,
                stats: _section3.stats,
                gradient: AlbumHeroGradient.albumHeroSection3,
              ),

              ValueListenableBuilder<List<bool>>(
                valueListenable: section3Likes,
                builder: (context, liked, _) => PhotoGrid(
                  variant: PhotoGridVariant.bordered,
                  photos: _section3Photos,
                  liked: liked,
                  onToggleLike: onToggleSection3Like,
                ),
              ),
              const SizedBox(
                key: AlbumScreen.spacerKey,
                height: CameoLayout.spacerHeight,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InitialScrollController extends ScrollController {
  _InitialScrollController({super.initialScrollOffset});

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
