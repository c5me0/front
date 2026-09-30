// Photo-backed legacy transcript surface with the shared dark background gradient.

import 'package:flutter/widgets.dart';

import '../content/lab.g.dart';
import '../design_system/design_system.dart';

class TranscriptBackground extends StatelessWidget {
  const TranscriptBackground({
    super.key,
    this.image = LabImages.transcriptDarkBackground,
  });

  final String image;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: IgnorePointer(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(image, fit: BoxFit.cover),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: CameoTheme.colorsOf(
                  context,
                ).gradients.transcriptDarkBackground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
