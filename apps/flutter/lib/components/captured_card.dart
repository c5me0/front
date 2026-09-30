// Captured or shared photo overlay anchored above the call controls. Preserve the image
// while dragging and use token-defined dismissal thresholds.

import 'package:flutter/widgets.dart';

import '../design_system/design_system.dart';
import 'call_camera_geometry.dart';
import 'outside_shadow.dart';
import 'scrim_button.dart';

@immutable
class CapturedCardItem {
  const CapturedCardItem({
    required this.key,
    required this.image,
    required this.width,
    required this.height,
    this.video,
  });

  final String key;
  final ImageProvider image;

  final double width;
  final double height;

  final Duration? video;

  Size get size => Size(width, height);
}

class CapturedCard extends StatefulWidget {
  const CapturedCard({
    super.key,
    required this.items,
    required this.visible,
    this.appearInstantly = false,
    required this.onClose,
    this.onShown,
    this.onHidden,
  });

  final List<CapturedCardItem> items;

  final bool visible;

  final bool appearInstantly;
  final VoidCallback onClose;

  final VoidCallback? onShown;

  final VoidCallback? onHidden;

  static const Key cardKey = ValueKey('capturedCard.card');
  static const Key photoKey = ValueKey('capturedCard.photo');
  static const Key closeKey = ValueKey('capturedCard.close');
  static const Key badgeKey = ValueKey('capturedCard.badge');
  static const Key dotsKey = ValueKey('capturedCard.dots');
  static const Key pagesKey = ValueKey('capturedCard.pages');

  @override
  State<CapturedCard> createState() => CapturedCardState();
}

class CapturedCardState extends State<CapturedCard>
    with TickerProviderStateMixin {
  late final bool _startShown = widget.appearInstantly && widget.visible;

  late final AnimationController _p = AnimationController.unbounded(
    vsync: this,
    value: _startShown ? 1 : 0,

    animationBehavior: AnimationBehavior.preserve,
  );

  late final AnimationController _chrome = AnimationController.unbounded(
    vsync: this,
    value: _startShown ? 1 : CameoMotion.transitionZoomChromeScaleFrom,
  );
  final PageController _pages = PageController();

  bool _closing = false;
  bool _reduceMotion = false;
  bool _started = false;
  int _page = 0;

  double get progress => _p.value;

  int get page => _page;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (!_started) {
      _started = true;
      _run();
    }
  }

  @override
  void didUpdateWidget(CapturedCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible != oldWidget.visible) _run();
  }

  void _run() {
    final visible = widget.visible;
    void finish() {
      if (!mounted || widget.visible != visible) return;
      visible ? widget.onShown?.call() : widget.onHidden?.call();
    }

    void settle(TickerFuture run, double target) {
      run.then((_) {
        if (!mounted || _p.isAnimating) return;
        _p.value = target;
        finish();
      });
    }

    if (visible) {
      _closing = false;
      if (_p.value >= 1) {
        WidgetsBinding.instance.addPostFrameCallback((_) => finish());
        return;
      }
      if (_reduceMotion) {
        _chrome.value = 1;
        settle(
          _p.animateTo(
            1,
            duration: CameoMotion.durationBase,
            curve: CameoMotion.easingStandard,
          ),
          1,
        );
        return;
      }
      _chrome.springTo(1, CameoMotion.transitionZoomChromeSpring);
      settle(_p.springTo(1, CameoMotion.capturedCardEnterSpring), 1);
      return;
    }
    _closing = true;
    if (_reduceMotion) {
      _chrome.value = CameoMotion.transitionZoomChromeScaleFrom;
      settle(
        _p.animateTo(
          0,
          duration: CameoMotion.durationBase,
          curve: CameoMotion.easingStandard,
        ),
        0,
      );
      return;
    }
    _chrome.springTo(
      CameoMotion.transitionZoomChromeScaleFrom,
      CameoMotion.transitionZoomChromeExitSpring,
    );
    settle(_p.springTo(0, CameoMotion.capturedCardExitSpring), 0);
  }

  @override
  void dispose() {
    _p.dispose();
    _chrome.dispose();
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final orientation = capturedCardOrientationOf(items.map((i) => i.size));
    final screen = MediaQuery.sizeOf(context);
    final rect = capturedCardRect(orientation, screen.width, screen.height);
    final multi = items.length > 1;
    final current = items.isEmpty
        ? null
        : items[_page.clamp(0, items.length - 1)];
    final cardLabel = multi
        ? '보낸 사진 ${items.length}장 중 ${_page + 1}번째'
        : current?.video != null
        ? '찍은 동영상'
        : '보낸 사진';

    const radius = CameoLayout.capturedCardV6Radius;
    final photo = AnimatedBuilder(
      animation: _p,
      builder: (context, child) =>
          Opacity(opacity: _p.value.clamp(0.0, 1.0), child: child),
      child: Semantics(
        image: true,
        label: cardLabel,
        child: ClipRSuperellipse(
          key: CapturedCard.photoKey,
          borderRadius: BorderRadius.circular(radius),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (multi)
                PageView(
                  key: CapturedCard.pagesKey,
                  controller: _pages,
                  onPageChanged: (i) => setState(() => _page = i),
                  children: [
                    for (final item in items)
                      Image(
                        image: item.image,
                        fit: BoxFit.cover,
                        excludeFromSemantics: true,
                        gaplessPlayback: true,
                      ),
                  ],
                )
              else if (current != null)
                Image(
                  image: current.image,
                  fit: BoxFit.cover,
                  excludeFromSemantics: true,
                  gaplessPlayback: true,
                ),
              if (multi)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: capturedCardDotBottom,
                  child: IgnorePointer(child: _dots(context, items.length)),
                ),
            ],
          ),
        ),
      ),
    );

    Widget chrome(Widget child) =>
        ScaleTransition(scale: _chrome, child: child);

    final card = Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(child: photo),

        if (current?.video case final video?)
          Positioned(
            key: const ValueKey('capturedCard.badgeLayer'),
            top: capturedCardCloseOffset.dy,
            right: capturedCardCloseOffset.dx,
            child: IgnorePointer(child: chrome(_badge(context, video))),
          ),
        Positioned(
          left: capturedCardCloseOffset.dx,
          top: capturedCardCloseOffset.dy,
          child: chrome(
            ScrimButton(
              key: CapturedCard.closeKey,
              size: ScrimButtonSize.md,
              tone: ScrimButtonTone.light,
              icon: CameoIconName.x,
              semanticLabel: '사진 닫기',
              onPress: widget.onClose,
            ),
          ),
        ),
      ],
    );

    return Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          bottom: capturedCardClipBottom(),
          child: ClipRect(
            child: Stack(
              children: [
                Positioned(
                  key: CapturedCard.cardKey,
                  left: rect.left,
                  top: rect.top,
                  width: rect.width,
                  height: rect.height,
                  child: IgnorePointer(
                    ignoring: !widget.visible,
                    child: AnimatedBuilder(
                      animation: _p,
                      child: card,
                      builder: (context, child) {
                        if (_reduceMotion) return child!;
                        final t = capturedCardTransform(
                          _p.value,
                          closing: _closing,
                        );
                        return Transform.translate(
                          offset: Offset(0, t.translateY),
                          child: Transform.scale(
                            scale: t.scale,
                            alignment: Alignment.bottomCenter,
                            child: child,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _dots(BuildContext context, int count) {
    final c = CameoTheme.colorsOf(context);
    return AnimatedBuilder(
      key: CapturedCard.dotsKey,
      animation: _pages,
      builder: (context, _) {
        final position = _pages.hasClients && _pages.position.haveDimensions
            ? (_pages.page ?? 0)
            : _page.toDouble();
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: capturedCardDotGap,
          children: [
            for (var i = 0; i < count; i++)
              SizedBox.square(
                dimension: capturedCardDotSize,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color.lerp(
                      c.staticWhiteSubtle,
                      c.staticWhiteBase,
                      capturedCardDotActive(position, i),
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _badge(BuildContext context, Duration video) {
    final m = scrimButtonMetrics(ScrimButtonSize.sm);
    const bw = CameoLayout.scrimButtonV6BorderWidth;
    final colors = scrimSurfaceColors(ScrimButtonTone.light);
    final text = recordingLabel(video);
    return Semantics(
      key: CapturedCard.badgeKey,
      label: '동영상 $text',
      excludeSemantics: true,
      child: OutsideShadow(
        shadow: colors.shadow,
        radius: CameoLayout.scrimButtonV6Radius,
        child: SizedBox(
          height: m.height,
          child: GlassSurface(
            blur: CameoBlur.scrim,
            tint: colors.tint,
            border: colors.border,
            borderWidth: bw,
            radius: CameoLayout.scrimButtonV6Radius,

            padding: EdgeInsets.symmetric(horizontal: m.padding - bw),
            child: V5ButtonContent(
              metrics: m,
              gap: CameoLayout.scrimButtonV6Gap,
              labelPaddingX: CameoLayout.scrimButtonV6LabelPaddingX,
              color: colors.content,
              icon: CameoIconName.playerPlayFilled,
              label: text,
            ),
          ),
        ),
      ),
    );
  }
}
