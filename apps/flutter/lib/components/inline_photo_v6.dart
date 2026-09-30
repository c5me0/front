// Inline transcript photo with the specified aspect ratio, rounded corners, and image-
// only opacity.

import 'package:flutter/widgets.dart';

import '../design_system/design_system.dart';

class InlinePhotoV6 extends StatelessWidget {
  const InlinePhotoV6({
    super.key,
    required this.image,
    this.onPress,
    this.semanticLabel,
  });

  final String image;

  final VoidCallback? onPress;
  final String? semanticLabel;

  static const Key cardKey = ValueKey('inlinePhotoV6.card');
  static const Key imageKey = ValueKey('inlinePhotoV6.image');

  @override
  Widget build(BuildContext context) {
    final card = SizedBox(
      key: cardKey,
      width: CameoLayout.transcriptV6PhotoWidth,
      height: CameoLayout.transcriptV6PhotoHeight,
      child: ClipRSuperellipse(
        borderRadius: BorderRadius.circular(
          CameoLayout.transcriptV6PhotoRadius,
        ),
        child: Opacity(
          key: imageKey,
          opacity: CameoLayout.transcriptV6PhotoOpacity,
          child: Image.asset(image, fit: BoxFit.cover),
        ),
      ),
    );
    final onPress = this.onPress;
    if (onPress == null) {
      return Semantics(image: true, label: semanticLabel, child: card);
    }
    return PressScale(
      onPress: onPress,
      accessibilityLabel: semanticLabel,
      child: card,
    );
  }
}
