// Shared v6 call card for incoming, outgoing, and failed calls. Use the light component
// palette even inside a dark surrounding theme.

//

import 'package:flutter/widgets.dart';

import '../content/lab.g.dart';
import '../design_system/design_system.dart';

enum CallListVariant {
  defaultVariant('default'),
  list('list'),
  failed('failed');

  const CallListVariant(this.key);

  final String key;

  static CallListVariant fromKey(String key) => key == 'scrim'
      ? list
      : values.firstWhere((v) => v.key == key, orElse: () => defaultVariant);
}

CameoIconName callListIconOf(CallDirection direction) => switch (direction) {
  CallDirection.outgoing => CameoIconName.arrowUpRight,
  CallDirection.incoming || CallDirection.missed => CameoIconName.arrowDownLeft,
};

({Color fill, Color title, Color subtitle}) callListColors(
  CameoPalette c,
  CallListVariant variant,
) => switch (variant) {
  CallListVariant.defaultVariant => (
    fill: CameoPalette.light.backgroundCanvasNeutralBase,
    title: CameoPalette.light.foregroundNeutralBase,
    subtitle: CameoPalette.light.foregroundNeutralMuted,
  ),
  CallListVariant.failed => (
    fill: c.systemRed,
    title: c.staticWhiteBase,
    subtitle: c.staticWhiteMuted,
  ),
  _ => (
    fill: c.backgroundFillNeutralList,
    title: c.staticWhiteBase,
    subtitle: c.staticWhiteMuted,
  ),
};

class CallListCard extends StatelessWidget {
  const CallListCard({
    super.key,
    this.variant = CallListVariant.defaultVariant,
    required this.direction,
    required this.title,
    required this.subtitle,
    this.onPress,
    this.semanticLabel,
  });

  factory CallListCard.fromContent(
    CallCardV5Content card, {
    Key? key,
    VoidCallback? onPress,
  }) => CallListCard(
    key: key,
    variant: CallListVariant.fromKey(card.variant),
    direction: card.direction,
    title: card.title,
    subtitle: card.subtitle,
    onPress: onPress,
  );

  final CallListVariant variant;
  final CallDirection direction;
  final String title;

  final List<LabTextSpan> subtitle;
  final VoidCallback? onPress;

  final String? semanticLabel;

  static const Key surfaceKey = ValueKey('callListCard.surface');
  static const Key iconKey = ValueKey('callListCard.icon');

  String get _subtitleText => subtitle.map((s) => s.text).join();

  @override
  Widget build(BuildContext context) {
    final colors = callListColors(CameoTheme.colorsOf(context), variant);
    final subtitleStyle = CameoTextStyles.bodySm.copyWith(
      color: colors.subtitle,
    );
    final surface = SizedBox(
      height: CameoLayout.callListV6Height,
      child: BlurSurface(
        key: surfaceKey,
        blur: CameoBlur.backgroundBlurV5Card,
        tint: colors.fill,
        radius: CameoLayout.callListV6Radius,
        padding: const EdgeInsets.symmetric(
          horizontal: CameoLayout.callListV6PaddingX,
          vertical: CameoLayout.callListV6PaddingY,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: CameoLayout.callListV6Gap,
          children: [
            SizedBox(
              height: CameoLayout.callListV6HeaderHeight,
              child: Row(
                spacing: CameoLayout.callListV6HeaderGap,
                children: [
                  Expanded(
                    child: CameoText(
                      title,
                      style: CameoTextStyles.bodyLgStrong,
                      color: colors.title,
                      maxLines: 1,
                    ),
                  ),
                  CameoIcon(
                    callListIconOf(direction),
                    key: iconKey,
                    size: CameoLayout.callListV6HeaderIconSize,
                    color: colors.title,
                  ),
                ],
              ),
            ),
            SizedBox(
              height: CameoLayout.callListV6SubtitleHeight,
              child: Text.rich(
                TextSpan(
                  style: subtitleStyle,
                  children: [
                    for (final span in subtitle)
                      cameoTextSpan(
                        span.text,
                        span.weight == LabTextWeight.medium
                            ? CameoTextStyles.bodySmStrong.copyWith(
                                color: colors.subtitle,
                              )
                            : subtitleStyle,
                      ),
                  ],
                ),
                strutStyle: cameoStrutOf(CameoTextStyles.bodySm),
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                textHeightBehavior: const TextHeightBehavior(
                  leadingDistribution: TextLeadingDistribution.even,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    final label = semanticLabel ?? '$title, $_subtitleText';
    final onPress = this.onPress;
    return onPress == null
        ? Semantics(
            container: true,
            label: label,
            child: ExcludeSemantics(child: surface),
          )
        : PressScale(
            onPress: onPress,
            accessibilityLabel: label,
            child: ExcludeSemantics(child: surface),
          );
  }
}
