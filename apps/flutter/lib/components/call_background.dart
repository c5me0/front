// Full-bleed call photo with the palette's call gradient. Keep the image crop centered
// and use the specified overlay stops.

import 'package:flutter/widgets.dart';

import '../content/lab.g.dart';
import '../design_system/design_system.dart';

class CallBackground extends StatelessWidget {
  const CallBackground({super.key, this.image = LabImages.callBackground});

  final String image;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ExcludeSemantics(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(image, fit: BoxFit.cover, alignment: Alignment.center),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: CameoTheme.colorsOf(context).gradients.callBackground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
