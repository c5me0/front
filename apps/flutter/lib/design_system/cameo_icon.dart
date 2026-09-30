// Render bundled Tabler SVG assets using generated names and palette-driven colors.
// Keep the source view box intact.

import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'cameo_theme.dart';
import 'icons.g.dart';
import 'tokens.g.dart';

class CameoIcon extends StatelessWidget {
  const CameoIcon(
    this.name, {
    super.key,
    this.size = CameoIconTokens.sizeMd,
    this.color,
  });

  final CameoIconName name;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      name.asset,
      width: size,
      height: size,
      theme: SvgTheme(
        currentColor:
            color ?? CameoTheme.colorsOf(context).foregroundNeutralBase,
      ),
    );
  }
}
