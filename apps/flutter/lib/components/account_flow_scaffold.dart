// Account screens share the v6 navigation, spacing, and surfaces. Only the body
// scrolls; actions remain reachable above the safe area.

import 'dart:math' as math;
import 'package:flutter/widgets.dart';

import '../content/app.g.dart';
import '../design_system/design_system.dart';
import 'solid_button.dart';

class AccountFlowScaffold extends StatelessWidget {
  const AccountFlowScaffold({
    super.key,
    required this.title,
    required this.onBack,
    required this.child,
    required this.footer,
    this.trailing,
    this.busy = false,
  });
  final String title;
  final VoidCallback onBack;
  final Widget child;
  final Widget footer;
  final Widget? trailing;
  final bool busy;
  static const backKey = ValueKey('accountFlow.back');
  static const scrollKey = ValueKey('accountFlow.scroll');

  @override
  Widget build(BuildContext context) {
    final c = CameoTheme.colorsOf(context);
    final padding = MediaQuery.paddingOf(context);
    return GlassBackdrop(
      tone: GlassBackdropTone.light,
      child: ColoredBox(
        color: c.backgroundCanvasNeutralStrong,
        child: Padding(
          padding: EdgeInsets.only(
            top: math.max(padding.top, CameoLayout.screenV6StatusBarHeight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: CameoSpace.s16),
                child: Row(
                  children: [
                    SolidButton(
                      key: backKey,
                      size: SolidButtonSize.md,
                      variant: SolidButtonVariant.gray,
                      icon: CameoIconName.chevronLeft,
                      semanticLabel: appContent.common.back,
                      disabled: busy,
                      onPress: onBack,
                    ),
                    const SizedBox(width: CameoSpace.s12),
                    Expanded(
                      child: CameoText(
                        title,
                        style: CameoTextStyles.bodyLgStrong,
                        color: c.foregroundNeutralBase,
                      ),
                    ),
                    if (trailing != null) trailing!,
                  ],
                ),
              ),
              const SizedBox(height: CameoSpace.s10),
              Expanded(
                child: SingleChildScrollView(
                  key: scrollKey,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(CameoSpace.s16),
                  child: child,
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  CameoSpace.s16,
                  CameoSpace.s12,
                  CameoSpace.s16,
                  math.max(
                        padding.bottom,
                        CameoLayout.screenV6HomeIndicatorHeight,
                      ) +
                      CameoSpace.s16,
                ),
                child: footer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
