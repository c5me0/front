// Legacy call-screen preview retained for visual and motion comparisons.

import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../components/call_background.dart';
import '../../components/call_control_bar.dart';
import '../../components/caller_block.dart';
import '../../components/nav_bar.dart';
import '../../components/toast.dart';
import '../../content/lab.g.dart';
import '../../design_system/design_system.dart';
import '../../navigation/navigation.dart';

import '../call/call_entrance.dart';

const CameoColorMode _colorMode = CameoColorMode.light;

abstract final class _Appear {
  static const int callerBlock = 0;
  static const int controlBar = 1;
  static const int toast = 2;
}

///

class CallV1Screen extends StatefulWidget {
  const CallV1Screen({super.key});

  @override
  State<CallV1Screen> createState() => _CallV1ScreenState();
}

class _CallV1ScreenState extends State<CallV1Screen> {
  static final ToastContent _sleepToast = labInCall.toasts.sleepModeRequest;

  final ToastController _toast = ToastController();
  bool _sleep = false;
  CallControlActive _controls = CallControlActive.none;

  bool _entered = false;
  Animation<double>? _routeAnimation;
  Timer? _firstToast;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_entered || _routeAnimation != null) return;
    final animation = ModalRoute.of(context)?.animation;
    if (animation == null || animation.isCompleted) {
      _enter();
    } else {
      _routeAnimation = animation..addStatusListener(_onRouteStatus);
    }
  }

  void _onRouteStatus(AnimationStatus status) {
    if (status.isCompleted && mounted) setState(_enter);
  }

  void _detachRoute() {
    _routeAnimation?.removeStatusListener(_onRouteStatus);
    _routeAnimation = null;
  }

  void _enter() {
    _detachRoute();
    if (_entered) return;
    _entered = true;
    _firstToast = Timer(CameoMotion.staggerItem * _Appear.toast, () {
      if (mounted) _toast.showContent(_sleepToast);
    });
  }

  void _toggleSleep() {
    final next = !_sleep;
    setState(() => _sleep = next);
    if (next) _toast.showContent(_sleepToast);
  }

  void _toggleControl(CallControlKey key) =>
      setState(() => _controls = _controls.toggled(key));

  void _close() => CameoNav.pop(context);

  @override
  void dispose() {
    _detachRoute();
    _firstToast?.cancel();
    _toast.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final navFrame = navBarFrameOf(context, variant: NavBarVariant.v1);
    final controlBarHeight = callControlBarContainerHeightOf(
      context,
      variant: CallControlBarVariant.v1,
    );

    return CameoTheme(
      mode: _colorMode,
      child: ColoredBox(
        color: CameoPalette.of(_colorMode).callBackgroundOverlay,
        child: Stack(
          children: [
            const Positioned.fill(child: CallBackground()),

            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: CallEntrance(
                play: _entered,
                index: _Appear.controlBar,
                rise: controlBarHeight,
                fade: false,
                child: CallControlBar(
                  variant: CallControlBarVariant.v1,
                  positioned: false,
                  active: _controls,
                  onToggle: _toggleControl,
                  onEndCall: _close,
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: callerBlockTop(navFrame.bottom),
              child: CallEntrance(
                play: _entered,
                index: _Appear.callerBlock,
                rise: CameoMotion.staggerRise,
                child: CallerBlock(
                  variant: CallerBlockVariant.v1,
                  name: labInCall.name,
                  startTime: labInCall.timer,
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: toastBottom(controlBarHeight),
              child: ToastHost(controller: _toast, variant: ToastVariant.v1),
            ),
            NavBar(
              variant: NavBarVariant.v1,
              leading: NavLeading(
                icon: CameoIconName.chevronDown,
                onPress: _close,
                accessibilityLabel: '닫기',
              ),
              actions: [
                NavAction(
                  icon: CameoIconName.moon,
                  activeIcon: CameoIconName.moonFilled,
                  active: _sleep,
                  onPress: _toggleSleep,
                  accessibilityLabel: '취침 모드',
                ),
                const NavAction(
                  icon: CameoIconName.focus,
                  accessibilityLabel: '포커스',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
