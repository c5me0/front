// Captured-photo review state machine. Sending or discarding animates the photo while
// floating glass actions move without fading.

//    onEntered.

import 'package:flutter/widgets.dart';

import '../content/app.g.dart';
import '../content/lab.g.dart';
import '../design_system/design_system.dart';
import 'call_camera_geometry.dart';
import 'scrim_button.dart';
import 'scrim_pill.dart';
import 'media_player.dart';
import 'backend_notice.dart';

enum ReviewPhase { review, send, discard }

@immutable
class ReviewPhoto {
  const ReviewPhoto({required this.key, required this.image, this.videoUri});

  final String key;
  final ImageProvider image;
  final String? videoUri;
}

CameoIconName _iconOf(String name) => CameoIconName.values.firstWhere(
  (i) => i.key == name,
  orElse: () => CameoIconName.x,
);

/// RN `<ReviewOverlay photo phase onSend onDiscard onEntered onLanded onExited />`.
class ReviewOverlay extends StatefulWidget {
  const ReviewOverlay({
    super.key,
    required this.photo,
    required this.phase,
    required this.onSend,
    required this.onDiscard,
    this.onEntered,
    this.onLanded,
    this.onExited,
    this.liked = false,
    this.busy = false,
    this.onLike,
    this.onShare,
    this.onMore,
    this.error,
    this.onErrorAction,
  });

  final ReviewPhoto photo;
  final ReviewPhase phase;
  final VoidCallback onSend;
  final VoidCallback onDiscard;

  final VoidCallback? onEntered;

  final VoidCallback? onLanded;

  final VoidCallback? onExited;
  final bool liked, busy;
  final VoidCallback? onLike, onShare, onMore, onErrorAction;
  final String? error;

  static const Key rootKey = ValueKey('reviewV6');
  static const Key dimKey = ValueKey('reviewV6.dim');
  static const Key photoKey = ValueKey('reviewV6.photo');
  static const Key actionsKey = ValueKey('reviewV6.actions');
  static const Key discardKey = ValueKey('reviewV6.discard');
  static const Key sendKey = ValueKey('reviewV6.send');

  @override
  State<ReviewOverlay> createState() => ReviewOverlayState();
}

class ReviewOverlayState extends State<ReviewOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _dim = AnimationController(
    vsync: this,
    animationBehavior: AnimationBehavior.preserve,
  );

  late final AnimationController _actions = AnimationController.unbounded(
    vsync: this,
  );

  late final AnimationController _drop = AnimationController.unbounded(
    vsync: this,
  );

  bool _started = false;
  bool _landed = false;
  bool _reduceMotion = false;
  int _pending = 0;

  double get dim => _dim.value;
  double get actions => _actions.value;
  double get fly => _landed ? 1 : 0;
  bool get landed => _landed;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (_started) return;
    _started = true;
    _enter();
    if (widget.phase != ReviewPhase.review) _leave(widget.phase);
  }

  @override
  void didUpdateWidget(ReviewOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.phase != oldWidget.phase && widget.phase != ReviewPhase.review) {
      _leave(widget.phase);
    }
  }

  void _enter() {
    if (_reduceMotion) {
      _dim.value = 1;
      _actions.value = 1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onEntered?.call();
      });
      return;
    }
    _dim.animateTo(
      1,
      duration: CameoMotion.reviewV6DimIn,
      curve: CameoMotion.easingStandard,
    );
    _actions.springTo(1, CameoMotion.reviewV6EnterSpring).then((_) {
      if (!mounted || _actions.isAnimating) return;
      _actions.value = 1;
      if (widget.phase == ReviewPhase.review) widget.onEntered?.call();
    });
  }

  void _leftOne() {
    _pending -= 1;
    if (_pending == 0 && mounted) widget.onExited?.call();
  }

  void _leave(ReviewPhase phase) {
    if (phase == ReviewPhase.send) {
      // Keep the media in place; the viewer route owns the shared-image transition.
      _landed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.onLanded?.call();
        widget.onExited?.call();
      });
      return;
    }
    if (_reduceMotion) {
      for (final c in [_dim, _actions]) {
        c
          ..stop()
          ..value = 0;
      }
      _drop.value = 1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onExited?.call();
      });
      return;
    }
    _pending = 3;
    void settle(AnimationController c, TickerFuture run, double to) {
      run.then((_) {
        if (!mounted || c.isAnimating) return;
        c.value = to;
        _leftOne();
      });
    }

    settle(
      _dim,
      _dim.animateTo(
        0,
        duration: CameoMotion.reviewV6DimOut,
        curve: CameoMotion.easingStandard,
      ),
      0,
    );
    settle(_actions, _actions.springTo(0, CameoMotion.reviewV6ExitSpring), 0);
    settle(_drop, _drop.springTo(1, CameoMotion.reviewV6ExitSpring), 1);
  }

  @override
  void dispose() {
    _dim.dispose();
    _actions.dispose();
    _drop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = CameoTheme.colorsOf(context);
    final size = MediaQuery.sizeOf(context);
    final vf = cameraViewfinderRect(size.width, height: size.height);
    final row = reviewActions(size.width, size.height);
    final interactive = widget.phase == ReviewPhase.review && !widget.busy;
    final discard = widget.phase == ReviewPhase.discard;
    return IgnorePointer(
      key: ReviewOverlay.rootKey,
      ignoring: !interactive,
      child: GlassBackdrop(
        tone: GlassBackdropTone.fromToken(
          CameoEffects.liquidGlassBackdropReviewV6,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              key: const ValueKey('reviewV6.layer.dim'),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {},
                excludeFromSemantics: true,
                child: AnimatedBuilder(
                  animation: _dim,
                  builder: (context, _) {
                    final d = _dim.value.clamp(0.0, 1.0);
                    if (d <= 0) return const SizedBox.expand();
                    return Opacity(
                      key: ReviewOverlay.dimKey,
                      opacity: d,
                      child: ColoredBox(color: c.staticBlackBase),
                    );
                  },
                ),
              ),
            ),
            Positioned.fromRect(
              key: const ValueKey('reviewV6.layer.photo'),
              rect: vf,
              child: IgnorePointer(
                ignoring: !interactive,
                child: AnimatedBuilder(
                  animation: _drop,
                  builder: (context, child) {
                    if (discard) {
                      final t = reviewDiscardTransform(_drop.value);
                      return Opacity(
                        opacity: t.opacity,
                        child: Transform.scale(scale: t.scale, child: child),
                      );
                    }
                    return child!;
                  },
                  child: Semantics(
                    image: true,
                    label: AppContent.of(
                      context,
                    ).v6.accessibility.capturedPhoto,
                    child: ClipRSuperellipse(
                      key: ReviewOverlay.photoKey,
                      borderRadius: BorderRadius.circular(
                        CameoLayout.cameraV6ViewfinderRadius,
                      ),
                      child: widget.photo.videoUri != null
                          ? MediaPlayer(
                              uri: widget.photo.videoUri!,
                              poster: widget.photo.image,
                              active: interactive,
                            )
                          : Image(
                              image: widget.photo.image,
                              fit: BoxFit.cover,
                              excludeFromSemantics: true,
                              gaplessPlayback: true,
                            ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              key: const ValueKey('reviewV6.layer.actions'),
              left: 0,
              right: 0,
              top: row.top,
              height: row.size,
              child: AnimatedBuilder(
                key: ReviewOverlay.actionsKey,
                animation: _actions,
                builder: (context, child) {
                  final t = reviewActionsTransform(_actions.value);
                  return Transform.translate(
                    offset: Offset(0, t.translateY),
                    child: child,
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: CameoLayout.reviewV6ActionsPaddingX,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _pop(
                        ScrimButton(
                          key: ReviewOverlay.discardKey,
                          size: ScrimButtonSize.xl,
                          tone: ScrimButtonTone.dark,
                          neutral: true,
                          icon: _iconOf(LabV6.of(context).review.discardIcon),
                          semanticLabel: AppContent.of(
                            context,
                          ).v6.review.discardLabel,
                          onPress: interactive ? widget.onDiscard : null,
                        ),
                      ),
                      ScrimPill(
                        size: ScrimPillSize.large,
                        tone: ScrimPillTone.dark,
                        items: [
                          ScrimPillItem(
                            icon: CameoIconName.share2,
                            semanticLabel: AppContent.of(
                              context,
                            ).v6.album.shareLabel,
                            onPress: interactive ? widget.onShare : null,
                          ),
                          ScrimPillItem(
                            icon: CameoIconName.heart,
                            active: widget.liked,
                            semanticLabel: widget.liked
                                ? AppContent.of(context).v6.album.unlikeLabel
                                : AppContent.of(context).v6.album.likeLabel,
                            onPress: interactive ? widget.onLike : null,
                          ),
                          ScrimPillItem(
                            icon: CameoIconName.dots,
                            semanticLabel: AppContent.of(
                              context,
                            ).v6.mediaDetails.more,
                            onPress: interactive ? widget.onMore : null,
                          ),
                        ],
                      ),
                      _pop(
                        _SendButton(
                          key: ReviewOverlay.sendKey,
                          onPress: interactive ? widget.onSend : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (widget.error != null || widget.busy)
              Positioned(
                left: CameoSpace.s16,
                right: CameoSpace.s16,
                top: vf.top + CameoSpace.s24,
                child: BackendNotice(
                  message:
                      widget.error ??
                      AppContent.of(context).v6.backend.uploading,
                  onRetry: widget.onErrorAction,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _pop(Widget child) => AnimatedBuilder(
    animation: _actions,
    child: child,
    builder: (context, child) => Transform.scale(
      scale: reviewActionsTransform(_actions.value).scale,
      child: child,
    ),
  );
}

class _SendButton extends StatelessWidget {
  const _SendButton({super.key, this.onPress});

  final VoidCallback? onPress;

  @override
  Widget build(BuildContext context) {
    final c = CameoTheme.colorsOf(context);
    return PressScale(
      onPress: onPress,
      accessibilityLabel: AppContent.of(context).v6.review.sendLabel,
      pressedColor: CameoPalette.light.backgroundFillScrimInteraction,
      pressedRadius: CameoLayout.scrimButtonV6Radius,
      child: SizedBox.square(
        dimension: CameoLayout.reviewV6SendSize,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: c.staticWhiteBase,
            shape: BoxShape.circle,
          ),
          child: Padding(
            padding: const EdgeInsets.all(
              CameoLayout.reviewV6SendPadding +
                  CameoLayout.reviewV6SendInnerPadding,
            ),
            child: CameoIcon(
              _iconOf(LabV6.of(context).review.sendIcon),
              size: CameoLayout.reviewV6SendIconSize,
              color: c.staticBlackBase,
            ),
          ),
        ),
      ),
    );
  }
}
