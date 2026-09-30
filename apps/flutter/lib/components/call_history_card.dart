// Call history card roles, sizing, and spring entrance for photo-backed and plain
// sections.

import 'dart:async';

import 'package:flutter/widgets.dart';

import '../content/lab.g.dart';
import '../design_system/design_system.dart';

enum CallHistoryCardTone { onPhoto, light, missed }

typedef _Roles = ({Color fill, Color title, Color subtitle, Color icon});

_Roles _rolesFor(CameoPalette c, CallHistoryCardTone tone) => switch (tone) {
  CallHistoryCardTone.onPhoto => (
    fill: c.albumCardTranslucent,
    title: c.foregroundNeutralInverseBase,
    subtitle: c.foregroundNeutralInverseMuted,
    icon: c.foregroundNeutralInverseBase,
  ),
  CallHistoryCardTone.light => (
    fill: c.backgroundNeutralSubtle,
    title: c.foregroundNeutralBase,
    subtitle: c.foregroundNeutralMuted,
    icon: c.foregroundNeutralBase,
  ),
  CallHistoryCardTone.missed => (
    fill: c.backgroundCriticalBase,
    title: c.foregroundNeutralInverseBase,
    subtitle: c.foregroundNeutralInverseMuted,
    icon: c.foregroundNeutralInverseBase,
  ),
};

final RegExp _subtitleSeparator = RegExp(r'^\s*∙\s*');

String callHistoryCardLabel(CallCardContent card) => [
  card.title,
  for (final s in card.subtitle)
    s.text.replaceFirst(_subtitleSeparator, '').trim(),
].where((t) => t.isNotEmpty).join(', ');

CameoIconName _iconOf(CallCardContent card) => CameoIconName.values.firstWhere(
  (n) => n.key == card.icon,
  orElse: () => card.direction == CallDirection.outgoing
      ? CameoIconName.arrowUpRight
      : CameoIconName.arrowDownLeft,
);

class CallHistoryCard extends StatefulWidget {
  const CallHistoryCard({
    super.key,
    required this.card,
    this.tone,
    this.onPress,
    this.appearIndex,
    this.accessibilityLabel,
  });

  final CallCardContent card;

  final CallHistoryCardTone? tone;

  final ValueChanged<CallCardContent>? onPress;

  final int? appearIndex;

  final String? accessibilityLabel;

  @override
  State<CallHistoryCard> createState() => _CallHistoryCardState();
}

class _CallHistoryCardState extends State<CallHistoryCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _appear = AnimationController.unbounded(
    vsync: this,
    value: widget.appearIndex == null ? 1 : 0,
  );
  Timer? _delay;
  bool _scheduled = false;
  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    if (!_scheduled) {
      _scheduled = true;
      final index = widget.appearIndex;
      if (index != null) {
        final delay = CameoMotion.staggerItem * index;
        if (delay == Duration.zero) {
          _playAppear();
        } else {
          _delay = Timer(delay, _playAppear);
        }
      }
    }
  }

  void _playAppear() {
    if (!mounted) return;
    if (_reduceMotion) {
      _appear.animateTo(
        1,
        duration: CameoMotion.durationBase,
        curve: CameoMotion.easingStandard,
      );
    } else {
      _appear.springTo(1, CameoMotion.staggerSpring).then((_) {
        if (mounted) _appear.value = 1;
      });
    }
  }

  @override
  void dispose() {
    _delay?.cancel();
    _appear.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final roles = _rolesFor(
      CameoTheme.colorsOf(context),
      widget.tone ??
          (card.direction == CallDirection.missed
              ? CallHistoryCardTone.missed
              : CallHistoryCardTone.onPhoto),
    );
    final onPress = widget.onPress;
    final label = widget.accessibilityLabel ?? callHistoryCardLabel(card);
    final rise = _reduceMotion ? 0.0 : CameoMotion.staggerRise;

    final surface = BlurSurface(
      tint: roles.fill,
      radius: CameoLayout.callCardRadius,
      padding: const EdgeInsets.symmetric(
        horizontal: CameoLayout.callCardPaddingX,
        vertical: CameoLayout.callCardPaddingY,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: CameoLayout.callCardGap,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: CameoLayout.callCardHeaderGap,
            children: [
              Expanded(
                child: CameoText(
                  card.title,
                  style: CameoTextStyles.bodyLgStrong,
                  color: roles.title,
                ),
              ),
              CameoIcon(
                _iconOf(card),
                size: CameoLayout.callCardHeaderIconSize,
                color: roles.icon,
              ),
            ],
          ),

          Text.rich(
            TextSpan(
              style: CameoTextStyles.bodySm.copyWith(color: roles.subtitle),
              children: [
                for (final span in card.subtitle)
                  cameoTextSpan(
                    span.text,
                    (span.weight == LabTextWeight.medium
                            ? CameoTextStyles.bodySmStrong
                            : CameoTextStyles.bodySm)
                        .copyWith(color: roles.subtitle),
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
        ],
      ),
    );

    return AnimatedBuilder(
      animation: _appear,
      builder: (context, child) {
        final p = _appear.value;
        return Opacity(
          opacity: p.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - p) * rise),
            child: child,
          ),
        );
      },
      child: onPress == null
          ? Semantics(
              container: true,
              label: label,
              child: ExcludeSemantics(child: surface),
            )
          : PressScale(
              onPress: () => onPress(card),
              accessibilityLabel: label,
              child: ExcludeSemantics(child: surface),
            ),
    );
  }
}
