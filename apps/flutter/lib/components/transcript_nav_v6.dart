// Light transcript navigation with shared buttons and action pills.

import 'package:flutter/widgets.dart';

import '../content/app.g.dart';
import '../content/lab.g.dart';
import '../design_system/design_system.dart';
import 'scrim_pill.dart';
import 'solid_button.dart';
import 'v6_layout.dart';

CameoIconName _iconOf(String key) => CameoIconName.values.firstWhere(
  (n) => n.key == key,
  orElse: () => CameoIconName.borderNone,
);

class TranscriptNavV6 extends StatelessWidget {
  const TranscriptNavV6({
    super.key,
    required this.onClose,
    required this.onCall,
    required this.liked,
    required this.onToggleLike,
  });

  final VoidCallback onClose;
  final VoidCallback onCall;
  final bool liked;
  final VoidCallback onToggleLike;

  static const Key closeKey = ValueKey('transcriptNavV6.close');
  static const Key actionsKey = ValueKey('transcriptNavV6.actions');

  @override
  Widget build(BuildContext context) {
    final content = LabV6.of(context).transcript;
    final labels = AppContent.of(context).v6;

    final callIcon = _iconOf(content.navActions[0]);
    final heartIcon = _iconOf(content.navActions[1]);
    return SizedBox(
      height: CameoLayout.topNavV6ButtonSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            key: const ValueKey('transcriptNavV6.layer.close'),
            left: CameoLayout.topNavV6PaddingX,
            top: 0,
            child: SolidButton(
              key: closeKey,
              size: SolidButtonSize.md,
              variant: SolidButtonVariant.gray,
              icon: _iconOf(content.closeIcon),
              onPress: onClose,
              semanticLabel: labels.album.closeLabel,
            ),
          ),
          Positioned(
            key: const ValueKey('transcriptNavV6.layer.actions'),
            left: V6Layout.of(context).topNavPillLeft(2),
            top: 0,
            child: ScrimPill(
              key: actionsKey,
              tone: ScrimPillTone.gray,
              items: [
                ScrimPillItem(
                  icon: callIcon,
                  onPress: onCall,
                  semanticLabel: labels.tabBar.callLabel,
                ),
                ScrimPillItem(
                  icon: heartIcon,
                  active: liked,
                  onPress: onToggleLike,
                  semanticLabel: liked
                      ? labels.album.unlikeLabel
                      : labels.album.likeLabel,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
