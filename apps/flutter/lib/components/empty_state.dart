// Centered empty-state illustration, message, and action for retained preview screens.

import 'package:flutter/widgets.dart';

import '../design_system/design_system.dart';
import 'auth_scaffold.dart';
import 'primary_button.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    this.icon = CameoIconName.users,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
    this.entranceIndex,
  });

  final CameoIconName icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  final int? entranceIndex;

  static const Key circleKey = ValueKey('emptyState.circle');
  static const Key titleKey = ValueKey('emptyState.title');
  static const Key bodyKey = ValueKey('emptyState.body');
  static const Key actionKey = ValueKey('emptyState.action');

  @override
  Widget build(BuildContext context) {
    final palette = CameoTheme.colorsOf(context);
    final actionLabel = this.actionLabel;
    final index = entranceIndex ?? 0;
    final animate = entranceIndex != null;
    Widget enter(Widget child, {required bool fade}) =>
        AuthEntrance(index: index, enabled: animate, fade: fade, child: child);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: CameoLayout.emptyStatePaddingX,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          enter(
            fade: false,
            SizedBox.square(
              key: circleKey,
              dimension: CameoLayout.emptyStateCircle,
              child: GlassSurface(
                blur: CameoBlur.glassNav,
                tint: palette.backgroundNeutralSubtle,
                radius: CameoRadius.full,
                child: Center(
                  child: CameoIcon(
                    icon,
                    size: CameoLayout.emptyStateIconSize,
                    color: palette.foregroundNeutralBase,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: CameoLayout.emptyStateGap),
          enter(
            fade: true,
            Semantics(
              header: true,
              child: CameoText(
                title,
                key: titleKey,
                style: CameoTextStyles.headingSm,
                color: palette.foregroundNeutralBase,
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(height: CameoLayout.emptyStateTitleGap),
          enter(
            fade: true,
            CameoText(
              body,
              key: bodyKey,
              style: CameoTextStyles.bodyMd,
              color: palette.foregroundNeutralMuted,
              textAlign: TextAlign.center,
            ),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: CameoLayout.emptyStateActionGap),

            enter(
              fade: false,
              PrimaryButton(
                key: actionKey,
                label: actionLabel,
                onPress: onAction,
                fullWidth: false,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
