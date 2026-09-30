// Album preview card and zoom-transition source. Its hero data must match the
// destination hero so the first transition frame aligns.

import 'package:flutter/widgets.dart';

import '../content/app.g.dart';
import '../content/lab.g.dart';
import '../design_system/design_system.dart';
import 'album_hero.dart';

@immutable
class AlbumCardData {
  const AlbumCardData({
    required this.cover,
    required this.title,
    required this.subtitle,
    this.stats,
    this.gradient = AlbumHeroGradient.albumHero,
  });

  factory AlbumCardData.fromGangneung(AlbumGangneungContent g) => AlbumCardData(
    cover: g.cover,
    title: g.title,
    subtitle: g.date,
    gradient: AlbumHeroGradient.albumHeroGangneung,
  );

  factory AlbumCardData.fromSection(AlbumSectionContent s) => AlbumCardData(
    cover: s.cover ?? '',
    title: s.title,
    subtitle: s.subtitle,
    stats: s.stats,
    gradient: AlbumHeroGradient.albumHero,
  );

  final String cover;
  final String title;
  final String subtitle;
  final AlbumStatsContent? stats;
  final AlbumHeroGradient gradient;
}

AlbumCardData albumCardDataFor(AppContentHomeAlbum album) {
  final source = album.source;
  if (source == 'albumGangneung') {
    return AlbumCardData.fromGangneung(labAlbumGangneung);
  }
  const sectionPrefix = 'albumDay.sections.';
  if (source.startsWith(sectionPrefix)) {
    final i = int.tryParse(source.substring(sectionPrefix.length));
    if (i != null && i >= 0 && i < labAlbumDay.sections.length) {
      return AlbumCardData.fromSection(labAlbumDay.sections[i]);
    }
  }
  throw ArgumentError.value(source, 'album.source', '알 수 없는 앨범 source');
}

Rect albumCardScaledRect(Rect rect, double scale) => Rect.fromCenter(
  center: rect.center,
  width: rect.width * scale,
  height: rect.height * scale,
);

class AlbumCard extends StatefulWidget {
  const AlbumCard({
    super.key,
    required this.data,
    this.onPress,
    this.accessibilityLabel,
  });

  final AlbumCardData data;

  final ValueChanged<Rect>? onPress;
  final String? accessibilityLabel;

  static const Key cardKey = ValueKey('albumCard.card');

  static const Key clipKey = ValueKey('albumCard.clip');

  static const Key heroKey = ValueKey('albumCard.hero');

  static Rect globalRectOf(BuildContext context) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return Rect.zero;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  @override
  State<AlbumCard> createState() => AlbumCardState();
}

class AlbumCardState extends State<AlbumCard> {
  final GlobalKey _drawn = GlobalKey(debugLabel: 'albumCard.drawn');

  Rect get drawnRect {
    final box = _drawn.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return Rect.zero;
    return MatrixUtils.transformRect(
      box.getTransformTo(null),
      Offset.zero & box.size,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = CameoTheme.colorsOf(context);
    final onPress = widget.onPress;
    final data = widget.data;
    final radius = BorderRadius.circular(CameoLayout.albumCardRadius);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return SizedBox.square(
          key: AlbumCard.cardKey,
          dimension: width,
          child: PressScale(
            onPress: onPress == null ? null : () => onPress(drawnRect),
            accessibilityLabel:
                widget.accessibilityLabel ??
                fillTemplate(appContent.home.openAlbumLabel, {
                  'title': data.title,
                }),
            child: DecoratedBox(
              key: _drawn,
              decoration: ShapeDecoration(
                shape: RoundedSuperellipseBorder(borderRadius: radius),
                shadows: [palette.shadows.shadow],
              ),
              child: ClipRSuperellipse(
                key: AlbumCard.clipKey,
                borderRadius: radius,
                child: FittedBox(
                  key: AlbumCard.heroKey,
                  fit: BoxFit.fill,
                  alignment: Alignment.topLeft,
                  child: SizedBox.square(
                    dimension: CameoLayout.albumCardHeroWidth,
                    child: ExcludeSemantics(
                      child: AlbumHero(
                        cover: data.cover,
                        title: data.title,
                        subtitle: data.subtitle,
                        stats: data.stats,
                        gradient: data.gradient,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
