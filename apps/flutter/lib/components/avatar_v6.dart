// Circular photo or initial avatars and an overlapping pair. Dimensions and overlap
// come from the shared design tokens.

import 'package:flutter/widgets.dart';

import '../design_system/design_system.dart';

String avatarInitialV6(String name) {
  final trimmed = name.trim();
  return trimmed.isEmpty ? '' : trimmed.characters.first.toUpperCase();
}

class AvatarV6 extends StatelessWidget {
  const AvatarV6({
    super.key,
    required this.size,
    this.image,
    this.name,
    required this.initialStyle,
    this.semanticLabel,
  });

  final double size;

  final String? image;

  final String? name;
  final TextStyle initialStyle;

  final String? semanticLabel;

  static const Key imageKey = ValueKey('avatarV6.image');
  static const Key initialKey = ValueKey('avatarV6.initial');

  @override
  Widget build(BuildContext context) {
    final c = CameoTheme.colorsOf(context);
    final image = this.image;
    final Widget body = image != null && image.isNotEmpty
        ? Image.asset(
            image,
            key: imageKey,
            width: size,
            height: size,
            fit: BoxFit.cover,
            excludeFromSemantics: true,
          )
        : ColoredBox(
            color: c.backgroundFillNeutralInverted,
            child: Center(
              child: CameoText(
                avatarInitialV6(name ?? ''),
                key: initialKey,
                style: initialStyle,
                color: c.avatarInitial,
                maxLines: 1,
              ),
            ),
          );
    final circle = SizedBox.square(
      dimension: size,
      child: ClipOval(child: body),
    );
    final label = semanticLabel;
    if (label == null) return ExcludeSemantics(child: circle);
    return Semantics(image: true, label: label, child: circle);
  }
}

class AvatarPair extends StatelessWidget {
  const AvatarPair({
    super.key,
    required this.myName,
    required this.partnerImage,
    this.size = CameoLayout.connectDoneV6AvatarSize,
    this.overlap = CameoLayout.connectDoneV6AvatarOverlap,
  });

  final String myName;

  final String partnerImage;
  final double size;
  final double overlap;

  static const Key meKey = ValueKey('avatarPair.me');
  static const Key partnerKey = ValueKey('avatarPair.partner');

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 2 * size - overlap,
      height: size,
      child: Stack(
        children: [
          Positioned(
            key: meKey,
            left: 0,
            top: 0,
            child: AvatarV6(
              size: size,
              name: myName,
              initialStyle: CameoTextStyles.headingLg,
            ),
          ),
          Positioned(
            key: partnerKey,
            left: size - overlap,
            top: 0,
            child: AvatarV6(
              size: size,
              image: partnerImage,
              initialStyle: CameoTextStyles.headingLg,
            ),
          ),
        ],
      ),
    );
  }
}
