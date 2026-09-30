// Section background roles for photo-backed and plain album sections.

import 'package:flutter/widgets.dart';

import '../design_system/design_system.dart';
import 'album_hero.dart';

///  canvasMuted = 'empty photo' 2042:2856 / 2028:696

enum AlbumSectionBackground {
  section1('album/section-1', AlbumHeroGradient.albumHero),
  canvasMuted('background/canvas/muted', null),
  section3('album/section-3', AlbumHeroGradient.albumHeroSection3);

  const AlbumSectionBackground(this.role, this.heroGradient);

  final String role;

  Color colorIn(CameoPalette c) => switch (this) {
    section1 => c.albumSection1,
    canvasMuted => c.backgroundCanvasMuted,
    section3 => c.albumSection3,
  };

  /// (RN `albumSectionHeroGradient`)
  final AlbumHeroGradient? heroGradient;
}

class AlbumSection extends StatelessWidget {
  const AlbumSection({
    super.key,
    required this.background,
    this.children = const <Widget>[],
  });

  final AlbumSectionBackground background;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: background.colorIn(CameoTheme.colorsOf(context)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}
