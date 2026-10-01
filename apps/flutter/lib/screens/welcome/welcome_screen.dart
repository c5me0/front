// Signed-out entry screen with eighteen drifting couple photos and a phone sign-in
// action.

import 'package:flutter/widgets.dart';

import '../../components/auth_scaffold.dart';
import '../../components/onboarding_v6_layout.dart';
import '../../components/solid_button.dart';
import '../../components/welcome_tiles.dart';
import '../../content/lab.g.dart';
import '../../design_system/design_system.dart';
import '../../navigation/navigation.dart';

abstract final class WelcomeEntranceSlots {
  static const int wordmark = 1;
  static const int tagline = 2;
  static const int cta = 3;
}

///    (786 – 840).

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  static const Key wordmarkKey = ValueKey('welcome.wordmark');
  static const Key taglineKey = ValueKey('welcome.tagline');
  static const Key textBlockKey = ValueKey('welcome.text');
  static const Key navKey = ValueKey('welcome.nav');
  static const Key ctaKey = ValueKey('welcome.cta');

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  late final VoidCallback _unregisterFlow;

  @override
  void initState() {
    super.initState();

    _unregisterFlow = FlowDemo.register(FlowDemoAction.welcomeStart, _start);
  }

  @override
  void dispose() {
    _unregisterFlow();
    super.dispose();
  }

  bool _start() {
    if (!mounted || !CameoNav.isTop(context)) return false;
    CameoNav.openPhone(context);
    return true;
  }

  @override
  Widget build(BuildContext context) => GlassBackdrop(
    tone: GlassBackdropTone.fromToken(
      CameoEffects.liquidGlassBackdropWelcomeV6,
    ),
    child: Builder(builder: _buildOnCanvas),
  );

  Widget _buildOnCanvas(BuildContext context) {
    final c = CameoTheme.colorsOf(context);
    final padding = MediaQuery.paddingOf(context);
    final block = welcomeTextBlock(padding.top, padding.bottom);
    final welcome = LabV6.of(context).welcome;
    return ColoredBox(
      color: c.backgroundCanvasNeutralStrong,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const WelcomeTiles(key: ValueKey('welcome.tiles')),
          Positioned(
            key: WelcomeScreen.textBlockKey,
            top: block.top,
            bottom: block.bottom,
            left: 0,
            right: 0,
            // 2295:16908 — gradient to top: effect/linear/base 23 % → effect/linear/subtle
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: c.gradients.welcomeFadeV6),
              child: Padding(
                padding: const EdgeInsets.all(CameoLayout.welcomeV6TextPadding),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: CameoLayout.welcomeV6TextGap,
                  children: [
                    AuthEntrance(
                      index: WelcomeEntranceSlots.wordmark,
                      child: Semantics(
                        header: true,
                        child: CameoText(
                          welcome.wordmark,
                          key: WelcomeScreen.wordmarkKey,
                          style: CameoTextStyles.wordmark,
                          color: c.foregroundNeutralBase,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    AuthEntrance(
                      index: WelcomeEntranceSlots.tagline,
                      child: CameoText(
                        welcome.tagline,
                        key: WelcomeScreen.taglineKey,
                        style: CameoTextStyles.tagline,
                        color: c.foregroundNeutralMuted,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            key: WelcomeScreen.navKey,
            left: 0,
            right: 0,
            bottom: 0,
            height: welcomeNavHeight(padding.bottom),

            child: ColoredBox(
              color: c.welcomeNavSolid,
              child: Padding(
                padding: const EdgeInsets.only(
                  top: CameoLayout.welcomeV6BottomNavPaddingTop,
                  left: CameoLayout.welcomeV6BottomNavPaddingX,
                  right: CameoLayout.welcomeV6BottomNavPaddingX,
                ),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: AuthEntrance(
                    index: WelcomeEntranceSlots.cta,
                    child: SolidButton(
                      key: WelcomeScreen.ctaKey,
                      label: welcome.cta,
                      stretch: true,
                      onPress: _start,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
