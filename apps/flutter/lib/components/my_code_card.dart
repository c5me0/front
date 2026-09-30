// Pairing-code card. Copy the raw code and display confirmation with the shared toast
// system.

import 'package:flutter/widgets.dart';

import '../content/app.g.dart';
import '../content/lab.g.dart';
import '../design_system/design_system.dart';
import 'phone_number_field.dart' show spokenDigits;

class MyCodeCard extends StatelessWidget {
  const MyCodeCard({super.key, required this.code, this.onCopy, this.label});

  final String code;
  final VoidCallback? onCopy;

  final String? label;

  static const Key cardKey = ValueKey('myCodeCard.card');
  static const Key codeKey = ValueKey('myCodeCard.code');
  static const Key copyKey = ValueKey('myCodeCard.copy');

  @override
  Widget build(BuildContext context) {
    final c = CameoTheme.colorsOf(context);
    final label = this.label ?? labV6.partner.myCodeLabel;
    return PressScale(
      onPress: onCopy,
      pressedColor: c.backgroundFillScrimInteraction,
      pressedRadius: CameoLayout.partnerV6MyCodeRadius,
      accessibilityLabel:
          '${appContent.v6.partner.copyLabel}, $label ${spokenDigits(code)}',
      child: ExcludeSemantics(
        child: SizedBox(
          key: cardKey,
          height: CameoLayout.partnerV6MyCodeHeight,
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: c.backgroundFillNeutralBase,
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(
                  CameoLayout.partnerV6MyCodeRadius,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: CameoLayout.partnerV6MyCodePaddingX,
                vertical: CameoLayout.partnerV6MyCodePaddingY,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: CameoLayout.partnerV6MyCodeGap,
                children: [
                  CameoText(
                    label,
                    style: CameoTextStyles.bodySm,
                    color: c.foregroundNeutralMuted,
                    maxLines: 1,
                  ),
                  Row(
                    spacing: CameoLayout.partnerV6MyCodeRowGap,
                    children: [
                      Expanded(
                        child: CameoText(
                          code,
                          key: codeKey,

                          style: CameoTextStyles.bodyLgStrong.copyWith(
                            fontFeatures: const [
                              FontFeature.liningFigures(),
                              FontFeature.tabularFigures(),
                            ],
                          ),
                          color: c.foregroundNeutralBase,
                          maxLines: 1,
                        ),
                      ),
                      CameoIcon(
                        key: copyKey,
                        CameoIconName.copy,
                        size: CameoLayout.partnerV6MyCodeCopyIconSize,
                        color: c.foregroundNeutralBase,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
