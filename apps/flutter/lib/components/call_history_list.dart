// Call card grouping and section insets. Let the parent determine the list's width.

import 'package:flutter/widgets.dart';

import '../content/lab.g.dart';
import '../design_system/design_system.dart';
import 'call_history_card.dart';

enum CallHistoryListTone { onPhoto, light }

CallHistoryCardTone callHistoryCardToneFor(
  CallHistoryListTone tone,
  CallDirection direction,
) {
  if (direction == CallDirection.missed) return CallHistoryCardTone.missed;
  return switch (tone) {
    CallHistoryListTone.onPhoto => CallHistoryCardTone.onPhoto,
    CallHistoryListTone.light => CallHistoryCardTone.light,
  };
}

class CallHistoryList extends StatelessWidget {
  const CallHistoryList({
    super.key,
    required this.cards,
    this.tone = CallHistoryListTone.onPhoto,
    this.onPress,
    this.appearIndex,
  });

  final List<CallCardContent> cards;

  final CallHistoryListTone tone;

  final ValueChanged<CallCardContent>? onPress;

  final int? appearIndex;

  @override
  Widget build(BuildContext context) {
    final padding = switch (tone) {
      CallHistoryListTone.onPhoto => const EdgeInsets.all(
        CameoLayout.callHistoryListPadding,
      ),
      CallHistoryListTone.light => const EdgeInsets.fromLTRB(
        CameoLayout.callHistoryListLightPaddingX,
        CameoLayout.callHistoryListLightPaddingTop,
        CameoLayout.callHistoryListLightPaddingX,
        CameoLayout.callHistoryListLightPaddingBottom,
      ),
    };
    final start = appearIndex;
    return Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: CameoLayout.callHistoryListGap,
        children: [
          for (final (i, card) in cards.indexed)
            CallHistoryCard(
              key: ValueKey(card.nodeId),
              card: card,
              tone: callHistoryCardToneFor(tone, card.direction),
              onPress: onPress,
              appearIndex: start == null ? null : start + i,
            ),
        ],
      ),
    );
  }
}
