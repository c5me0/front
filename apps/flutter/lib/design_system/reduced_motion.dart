// Bridge the platform's reduce-motion accessibility flag to
// MediaQuery.disableAnimations for consistent animation behavior.

import 'package:flutter/widgets.dart';

///

class CameoReducedMotionScope extends StatefulWidget {
  const CameoReducedMotionScope({super.key, required this.child});

  final Widget child;

  static bool platformRequestsReducedMotion(BuildContext context) {
    final features = View.of(context).platformDispatcher.accessibilityFeatures;
    return features.disableAnimations || features.reduceMotion;
  }

  @override
  State<CameoReducedMotionScope> createState() =>
      _CameoReducedMotionScopeState();
}

class _CameoReducedMotionScopeState extends State<CameoReducedMotionScope>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAccessibilityFeatures() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return MediaQuery(
      data: media.copyWith(
        disableAnimations:
            media.disableAnimations ||
            CameoReducedMotionScope.platformRequestsReducedMotion(context),
      ),
      child: widget.child,
    );
  }
}
