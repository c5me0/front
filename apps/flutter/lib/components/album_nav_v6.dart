// Album navigation switches between browsing, selection, favorites, and deleted-photo
// actions. Keep the glass surfaces mounted while their content and geometry change.

//    · select · liked: X (ScrimButton md x, 46) · pill [share-2 · heart · trash] (146).
//    · deleted: X · pill [archive] (46).

import 'package:flutter/widgets.dart';

import '../content/app.g.dart';
import '../content/lab.g.dart';
import '../design_system/design_system.dart';
import '../screens/home_timeline/album_timeline_model.dart';
import 'scrim_button.dart';
import 'scrim_pill.dart';
import 'toast.dart' show toastIconOf;
import 'v6_layout.dart';

@immutable
class AlbumNavV6Actions {
  const AlbumNavV6Actions({
    required this.onSelect,
    required this.onImport,
    required this.onLiked,
    required this.onDeleted,
    required this.onClose,
    required this.onShare,
    required this.onHeart,
    required this.onDelete,
    required this.onRestore,
  });

  final VoidCallback onSelect;
  final VoidCallback onImport;
  final VoidCallback onLiked;
  final VoidCallback onDeleted;
  final VoidCallback onClose;
  final VoidCallback onShare;
  final VoidCallback onHeart;
  final VoidCallback onDelete;
  final VoidCallback onRestore;
}

class AlbumNavV6 extends StatefulWidget {
  const AlbumNavV6({
    super.key,
    required this.mode,
    required this.progress,
    required this.toneProgress,
    required this.backdrop,
    required this.actions,
    this.selectDisabled = false,
    this.showDeleted = true,
    this.onRefresh,
  });

  final AlbumMode mode;

  final Animation<double> progress;

  final Animation<double> toneProgress;

  final GlassBackdropTone backdrop;
  final AlbumNavV6Actions actions;

  final bool selectDisabled;
  final bool showDeleted;
  final VoidCallback? onRefresh;

  static const Key headerKey = ValueKey('albumNavV6.header');
  static const Key headerPhotoKey = ValueKey('albumNavV6.header.photo');
  static const Key headerLightKey = ValueKey('albumNavV6.header.light');
  static const Key selectKey = ValueKey('albumNavV6.select');
  static const Key mainPillKey = ValueKey('albumNavV6.mainPill');
  static const Key closeKey = ValueKey('albumNavV6.close');
  static const Key selectionPillKey = ValueKey('albumNavV6.selectionPill');
  static const Key restorePillKey = ValueKey('albumNavV6.restorePill');

  @override
  State<AlbumNavV6> createState() => AlbumNavV6State();
}

class AlbumNavV6State extends State<AlbumNavV6> {
  static const double _epsilon = CameoMotion.transitionZoomChromeScaleFrom;

  late AlbumMode _lastOther = widget.mode == AlbumMode.timeline
      ? AlbumMode.select
      : widget.mode;

  @visibleForTesting
  AlbumMode get otherMode => _lastOther;

  @override
  void didUpdateWidget(AlbumNavV6 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.mode != AlbumMode.timeline) _lastOther = widget.mode;
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final layout = V6Layout.of(context);
    final c = CameoTheme.colorsOf(context);
    final lab = labV6.album;
    final copy = appContent.v6.album;
    final a = w.actions;
    final timeline = w.mode == AlbumMode.timeline;
    final other = _lastOther;
    final otherChrome = albumNavChrome(other);
    final otherCount = albumNavPillCount(otherChrome.right);

    Widget swap({
      required Key key,
      required bool normalSide,
      required double left,
      required Widget child,
    }) {
      final hidden = normalSide ? !timeline : timeline;
      return Positioned(
        key: key,
        left: left,
        top: CameoLayout.topNavV6Top,
        child: IgnorePointer(
          ignoring: hidden,
          child: ExcludeSemantics(
            excluding: hidden,
            child: AnimatedBuilder(
              animation: w.progress,
              child: child,
              builder: (context, child) {
                final scales = navSwapScales(w.progress.value, _epsilon);
                final scale = normalSide ? scales.normal : scales.select;
                return Offstage(
                  offstage: hidden && scale <= _epsilon + 1e-9,
                  child: Transform.scale(scale: scale, child: child),
                );
              },
            ),
          ),
        ),
      );
    }

    ScrimPillItem item(String key, String label, VoidCallback onPress) =>
        ScrimPillItem(
          icon: toastIconOf(key),
          semanticLabel: label,
          onPress: onPress,
        );

    final mainItems = [
      for (final key in lab.navActions)
        if (w.showDeleted ||
            key == 'plus' ||
            key == 'heart' ||
            w.onRefresh != null)
          switch (key) {
            'plus' => item(key, copy.importLabel, a.onImport),
            'heart' => item(key, copy.likedLabel, a.onLiked),
            _ =>
              w.showDeleted
                  ? item(key, copy.deletedLabel, a.onDeleted)
                  : item(
                      'refresh',
                      appContent.v6.backend.refresh,
                      w.onRefresh!,
                    ),
          },
    ];
    final otherItems = otherChrome.right == AlbumNavRight.restore
        ? [
            for (final key in lab.deletedActions)
              item(key, copy.restoreLabel, a.onRestore),
          ]
        : [
            for (final key
                in other == AlbumMode.liked
                    ? lab.likedActions
                    : lab.selectActions)
              switch (key) {
                'share-2' => item(key, copy.shareLabel, a.onShare),
                'heart' => item(
                  key,
                  other == AlbumMode.liked ? copy.unlikeLabel : copy.likeLabel,
                  a.onHeart,
                ),
                _ => item(key, copy.deleteLabel, a.onDelete),
              },
          ];

    return GlassBackdrop(
      tone: w.backdrop,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            key: AlbumNavV6.headerKey,
            left: 0,
            right: 0,
            top: 0,
            height: CameoLayout.albumNavV6HeaderHeight,
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: w.toneProgress,
                builder: (context, _) {
                  final p = w.toneProgress.value.clamp(0.0, 1.0);
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      Opacity(
                        key: AlbumNavV6.headerPhotoKey,
                        opacity: 1 - p,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: c.gradients.sectionFadeTopV6,
                          ),
                        ),
                      ),
                      Opacity(
                        key: AlbumNavV6.headerLightKey,
                        opacity: p,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: c.gradients.topLinear,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

          swap(
            key: const ValueKey('albumNavV6.slot.select'),
            normalSide: true,
            left: CameoLayout.albumNavV6RowPaddingX,
            child: ScrimButton(
              key: AlbumNavV6.selectKey,
              size: ScrimButtonSize.md,
              label: lab.selectLabel,
              disabled: w.selectDisabled,
              semanticLabel: copy.selectLabel,
              onPress: a.onSelect,
            ),
          ),
          swap(
            key: const ValueKey('albumNavV6.slot.mainPill'),
            normalSide: true,
            left: layout.topNavPillLeft(mainItems.length),
            child: ScrimPill(key: AlbumNavV6.mainPillKey, items: mainItems),
          ),

          swap(
            key: const ValueKey('albumNavV6.slot.close'),
            normalSide: false,
            left: CameoLayout.albumNavV6RowPaddingX,
            child: ScrimButton(
              key: AlbumNavV6.closeKey,
              size: ScrimButtonSize.md,
              icon: toastIconOf(lab.closeIcon),
              semanticLabel: copy.closeLabel,
              onPress: a.onClose,
            ),
          ),
          swap(
            key: const ValueKey('albumNavV6.slot.otherPill'),
            normalSide: false,
            left: layout.topNavPillLeft(otherCount),
            child: ScrimPill(
              key: otherChrome.right == AlbumNavRight.restore
                  ? AlbumNavV6.restorePillKey
                  : AlbumNavV6.selectionPillKey,
              items: otherItems,
            ),
          ),
        ],
      ),
    );
  }
}
