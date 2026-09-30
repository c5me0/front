// Album hero backgrounds, gradients, and parallax. Resolve colors through the current
// palette and measure positions relative to the scroll viewport.

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../content/lab.g.dart';
import '../design_system/design_system.dart';
import 'meta_row.dart';

enum AlbumHeroGradient {
  albumHero,
  albumHeroSection3,
  albumHeroGangneung;

  LinearGradient resolve(CameoGradientSet g) => switch (this) {
    albumHero => g.albumHero,
    albumHeroSection3 => g.albumHeroSection3,
    albumHeroGangneung => g.albumHeroGangneung,
  };
}

typedef AlbumHeroScrollTransform = ({
  double parallaxY,
  double translateY,
  double scale,
});

AlbumHeroScrollTransform albumHeroScrollTransform(
  double offset,
  double height,
) {
  if (offset >= 0) {
    return (
      parallaxY: offset * CameoMotion.heroParallax,
      translateY: 0,
      scale: 1,
    );
  }
  final scale = height > 0
      ? 1 + (-offset * CameoMotion.heroOverscrollStretch) / height
      : 1.0;
  return (parallaxY: 0, translateY: offset, scale: scale);
}

class ScrollOffsetListenable implements ValueListenable<double> {
  const ScrollOffsetListenable(this.controller);

  final ScrollController controller;

  @override
  double get value {
    if (!controller.hasClients) return 0;
    final position = controller.position;
    return position.hasPixels ? position.pixels : 0;
  }

  @override
  void addListener(VoidCallback listener) => controller.addListener(listener);

  @override
  void removeListener(VoidCallback listener) =>
      controller.removeListener(listener);

  @override
  bool operator ==(Object other) =>
      other is ScrollOffsetListenable && other.controller == controller;

  @override
  int get hashCode => controller.hashCode;
}

class AlbumHero extends StatelessWidget {
  const AlbumHero({
    super.key,
    required this.cover,
    required this.title,
    required this.subtitle,
    this.stats,
    this.gradient = AlbumHeroGradient.albumHero,
    this.scrollOffset,
    this.onPress,
    this.accessibilityLabel,
  });

  final String cover;

  final String title;

  final String subtitle;

  final AlbumStatsContent? stats;

  final AlbumHeroGradient gradient;

  final ValueListenable<double>? scrollOffset;

  final VoidCallback? onPress;

  final String? accessibilityLabel;

  @override
  Widget build(BuildContext context) {
    final onPress = this.onPress;
    final hero = _buildHero(context);
    if (onPress == null) return hero;
    return PressScale(
      onPress: onPress,
      accessibilityLabel: accessibilityLabel ?? title,
      child: hero,
    );
  }

  Widget _buildHero(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final palette = CameoTheme.colorsOf(context);
    final stats = this.stats;

    return AspectRatio(
      aspectRatio: CameoLayout.albumHeroAspectRatio,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          _HeroBackdrop(
            cover: cover,
            gradient: gradient.resolve(palette.gradients),
            scrollOffset: reduceMotion ? null : scrollOffset,
          ),
          Padding(
            padding: const EdgeInsets.all(CameoLayout.albumHeroPadding),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: CameoText(
                    title,
                    style: CameoTextStyles.headingLg,
                    color: palette.foregroundNeutralInverseBase,
                    maxLines: 1,
                  ),
                ),
                if (stats != null) ...[
                  const SizedBox(height: CameoLayout.albumHeroGap),
                  MetaRow(label: subtitle, stats: stats, tone: LabTone.dark),
                ] else ...[
                  const SizedBox(height: CameoLayout.albumHeroGangneungGap),
                  CameoText(
                    subtitle,
                    style: CameoTextStyles.bodyLg,
                    color: palette.foregroundNeutralInverseMuted,
                    maxLines: 1,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroBackdrop extends StatelessWidget {
  const _HeroBackdrop({
    required this.cover,
    required this.gradient,
    required this.scrollOffset,
  });

  final String cover;
  final LinearGradient gradient;
  final ValueListenable<double>? scrollOffset;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      cover,
      fit: BoxFit.cover,
      excludeFromSemantics: true,
      gaplessPlayback: true,
    );
    final fill = DecoratedBox(decoration: BoxDecoration(gradient: gradient));
    final offset = scrollOffset;
    if (offset == null) {
      return IgnorePointer(
        child: ClipRect(
          child: Stack(fit: StackFit.expand, children: [image, fill]),
        ),
      );
    }
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) => ValueListenableBuilder<double>(
          valueListenable: offset,
          child: image,
          builder: (context, y, image) {
            final t = albumHeroScrollTransform(y, constraints.maxHeight);
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
                      child: image,
                    ),
                    fill,
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
