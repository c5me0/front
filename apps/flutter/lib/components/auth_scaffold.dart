// Authentication layout with token-based navigation, header, body, accessory, keypad,
// and footer slots. Keyboard-aware footers track the keyboard inset. Stagger non-glass
// content only.

import 'dart:async';

import 'package:flutter/widgets.dart';

import '../content/app.g.dart';
import '../design_system/design_system.dart';
import 'onboarding_v6_layout.dart';
import 'solid_button.dart';

export 'onboarding_v6_layout.dart'
    show authV6FooterBottom, authV6HeaderTop, authV6NavTop;

Duration authEntranceDelay(int index) =>
    CameoMotion.staggerItem *
    (index * CameoMotion.authEntranceItemScale).round();

abstract final class AuthEntranceOrder {
  static const int title = 0;
  static const int subtitle = 1;
  static const int body = 2;
  static const int footer = 3;
}

class AuthEntrance extends StatefulWidget {
  const AuthEntrance({
    super.key,
    required this.index,
    this.enabled = true,
    this.fade = true,
    required this.child,
  });

  final int index;
  final bool enabled;

  final bool fade;
  final Widget child;

  @override
  State<AuthEntrance> createState() => AuthEntranceState();
}

class AuthEntranceState extends State<AuthEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _p = AnimationController.unbounded(
    vsync: this,
    value: widget.enabled ? 0 : 1,
    animationBehavior: AnimationBehavior.preserve,
  );
  Timer? _delay;
  bool _started = false;
  bool _reduceMotion = false;

  double get progress => _p.value;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (_started || !widget.enabled) return;
    _started = true;
    if (_reduceMotion && !widget.fade) {
      _p.value = 1;
      return;
    }
    final delay = authEntranceDelay(widget.index);
    if (delay == Duration.zero) {
      _play();
    } else {
      _delay = Timer(delay, _play);
    }
  }

  void _play() {
    if (!mounted) return;
    if (_reduceMotion) {
      _p.animateTo(
        1,
        duration: CameoMotion.durationBase,
        curve: CameoMotion.easingStandard,
      );
    } else {
      _p.springTo(1, CameoMotion.staggerSpring);
    }
  }

  @override
  void dispose() {
    _delay?.cancel();
    _p.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rise = _reduceMotion ? 0.0 : CameoMotion.staggerRise;
    return AnimatedBuilder(
      animation: _p,
      child: widget.child,
      builder: (context, child) {
        final p = _p.value;
        final moved = Transform.translate(
          offset: Offset(0, (1 - p) * rise),
          child: child,
        );
        if (!widget.fade) return moved;
        return Opacity(opacity: p.clamp(0.0, 1.0), child: moved);
      },
    );
  }
}

///

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    this.subtitle,
    this.subtitleWidget,
    this.onBack,
    this.backLabel,
    this.trailingLabel,
    this.onTrailing,
    this.child,
    this.accessory,
    this.footer,
    this.keypad,
    this.footerRidesKeyboard = false,
    this.entrance = true,
    this.overlays = const [],
  });

  final String title;

  final String? subtitle;

  final Widget? subtitleWidget;

  final VoidCallback? onBack;

  final String? backLabel;

  final String? trailingLabel;
  final VoidCallback? onTrailing;

  final Widget? child;

  final Widget? accessory;

  final Widget? footer;

  final Widget? keypad;

  final bool footerRidesKeyboard;
  final bool entrance;
  final List<Widget> overlays;

  static const Key navKey = ValueKey('authScaffold.nav');
  static const Key backKey = ValueKey('authScaffold.back');
  static const Key trailingKey = ValueKey('authScaffold.trailing');
  static const Key headerKey = ValueKey('authScaffold.header');
  static const Key titleKey = ValueKey('authScaffold.title');
  static const Key subtitleKey = ValueKey('authScaffold.subtitle');
  static const Key bodyKey = ValueKey('authScaffold.body');
  static const Key accessoryKey = ValueKey('authScaffold.accessory');
  static const Key footerKey = ValueKey('authScaffold.footer');
  static const Key keypadKey = ValueKey('authScaffold.keypad');
  static const Key contentKey = ValueKey('authScaffold.content');

  @override
  Widget build(BuildContext context) => GlassBackdrop(
    tone: GlassBackdropTone.fromToken(CameoEffects.liquidGlassBackdropAuthV6),
    child: Builder(builder: _buildOnCanvas),
  );

  Widget _buildOnCanvas(BuildContext context) {
    final c = CameoTheme.colorsOf(context);
    final padding = MediaQuery.paddingOf(context);
    final hasKeypad = this.keypad != null;
    final navTop = authV6NavTop(padding.top);
    final footerBottom = authV6FooterBottom(
      padding.bottom,
      hasKeypad: hasKeypad,
    );
    final lift = footerRidesKeyboard
        ? keyboardFooterLiftV6(
            MediaQuery.viewInsetsOf(context).bottom,
            padding.bottom,
          )
        : 0.0;
    final onBack = this.onBack;
    final trailingLabel = this.trailingLabel;
    final subtitle = this.subtitle;
    final subtitleWidget = this.subtitleWidget;
    final child = this.child;
    final accessory = this.accessory;
    final footer = this.footer;
    final keypad = this.keypad;

    return ColoredBox(
      color: c.backgroundCanvasNeutralBase,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            key: contentKey,
            top: authV6HeaderTop(padding.top),
            left: 0,
            right: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  key: headerKey,
                  padding: const EdgeInsets.all(
                    CameoLayout.sectionHeaderPadding,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    spacing: CameoLayout.sectionHeaderGap,
                    children: [
                      AuthEntrance(
                        index: AuthEntranceOrder.title,
                        enabled: entrance,
                        child: Semantics(
                          header: true,
                          child: CameoText(
                            title,
                            key: titleKey,
                            style: CameoTextStyles.headingLg,
                            color: c.foregroundNeutralBase,
                          ),
                        ),
                      ),
                      if (subtitleWidget != null || subtitle != null)
                        AuthEntrance(
                          index: AuthEntranceOrder.subtitle,
                          enabled: entrance,
                          child: KeyedSubtree(
                            key: subtitleKey,
                            child:
                                subtitleWidget ??
                                CameoText(
                                  subtitle!,
                                  style: CameoTextStyles.bodyMd,
                                  color: c.foregroundNeutralMuted,
                                ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (child != null)
                  AuthEntrance(
                    index: AuthEntranceOrder.body,
                    enabled: entrance,
                    child: Padding(
                      key: bodyKey,
                      padding: const EdgeInsets.symmetric(
                        horizontal: CameoLayout.authV6BodyPaddingX,
                        vertical: CameoLayout.authV6BodyPaddingY,
                      ),
                      child: child,
                    ),
                  ),
              ],
            ),
          ),
          Positioned(
            key: keypadKey,
            left: 0,
            right: 0,
            bottom: 0,
            child: keypad ?? const SizedBox.shrink(),
          ),
          Positioned(
            key: accessoryKey,
            left: 0,
            right: 0,
            bottom: hasKeypad ? keypadV6Height(padding.bottom) : footerBottom,
            child: accessory == null
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: CameoLayout.partnerV6MyCodeBlockPaddingX,
                      vertical: CameoLayout.partnerV6MyCodeBlockPaddingY,
                    ),
                    child: AuthEntrance(
                      index: AuthEntranceOrder.footer,
                      enabled: entrance,
                      child: accessory,
                    ),
                  ),
          ),
          Positioned(
            key: footerKey,
            left: CameoLayout.authV6CtaFramePaddingX,
            right: CameoLayout.authV6CtaFramePaddingX,
            bottom: footerBottom + lift,
            child: footer == null
                ? const SizedBox.shrink()
                : AuthEntrance(
                    index: AuthEntranceOrder.footer,
                    enabled: entrance,
                    child: footer,
                  ),
          ),

          Positioned(
            key: navKey,
            top: navTop,
            left: 0,
            right: 0,
            height: CameoLayout.authV6NavHeight,
            child: Padding(
              padding: const EdgeInsets.only(
                left: CameoLayout.topNavV6PaddingX,
                right: CameoLayout.topNavV6PaddingX,
                bottom: CameoLayout.topNavV6PaddingBottom,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (onBack != null)
                    SolidButton(
                      key: backKey,
                      size: SolidButtonSize.md,
                      variant: SolidButtonVariant.gray,
                      icon: CameoIconName.chevronLeft,
                      onPress: onBack,
                      semanticLabel: backLabel ?? appContent.common.back,
                    )
                  else
                    const SizedBox.shrink(),
                  if (trailingLabel != null)
                    SolidButton(
                      key: trailingKey,
                      size: SolidButtonSize.md,
                      variant: SolidButtonVariant.gray,
                      label: trailingLabel,
                      onPress: onTrailing,
                    ),
                ],
              ),
            ),
          ),
          ...overlays,
        ],
      ),
    );
  }
}
