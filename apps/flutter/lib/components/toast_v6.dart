// Shared flat and elevated v6 toast presentations, including camera placement.

//

//

//   final toast = ToastController();

//   Positioned(left: 0, right: 0, top: CameoLayout.toastV6CameraContainerTop,
//              child: ToastV6Host(controller: toast, variant: ToastV6Variant.elevated,

//   toast.showContent(labInCallV5.toasts.highlight);
import 'package:flutter/widgets.dart';

import '../design_system/design_system.dart';
import 'toast.dart';

enum ToastV6Variant { flat, elevated }

enum ToastV6Placement {
  /// px16 py12 (69)
  call,

  camera,
}

ToastVariant toastV6VariantOf(
  ToastV6Variant variant, [
  ToastV6Placement placement = ToastV6Placement.call,
]) => switch (variant) {
  ToastV6Variant.flat => ToastVariant.v6Flat,
  ToastV6Variant.elevated =>
    placement == ToastV6Placement.camera
        ? ToastVariant.v6ElevatedCamera
        : ToastVariant.v6Elevated,
};

/// RN `toastV6FlatBottom()`.
double toastV6FlatBottom() =>
    CameoLayout.screenV6Height -
    CameoLayout.toastV6FlatTop -
    CameoLayout.toastV6FlatContainerHeight;

class ToastV6Pill extends StatelessWidget {
  const ToastV6Pill({
    super.key,
    required this.message,
    required this.icon,
    this.variant = ToastV6Variant.flat,
  });

  final String message;
  final CameoIconName icon;
  final ToastV6Variant variant;

  static const Key pillKey = ValueKey('toastV6.pill');

  @override
  Widget build(BuildContext context) {
    final c = CameoTheme.colorsOf(context);
    final elevated = variant == ToastV6Variant.elevated;
    return Container(
      key: pillKey,
      constraints: BoxConstraints(
        minWidth: elevated
            ? CameoLayout.toastV6ElevatedMinWidth
            : CameoLayout.toastV6FlatMinWidth,
      ),
      padding: EdgeInsets.all(
        elevated
            ? CameoLayout.toastV6ElevatedPadding
            : CameoLayout.toastV6FlatPadding,
      ),

      decoration: BoxDecoration(
        color: c.staticWhiteBase,
        border: elevated
            ? Border.all(
                color: c.strokeBase,
                width: CameoLayout.toastV6ElevatedBorderWidth,
              )
            : null,
        borderRadius: BorderRadius.circular(CameoRadius.full),
        boxShadow: elevated ? [c.shadows.shadowV5] : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: elevated
            ? CameoLayout.toastV6ElevatedGap
            : CameoLayout.toastV6FlatGap,
        children: [
          CameoIcon(
            icon,
            size: elevated
                ? CameoLayout.toastV6ElevatedIconSize
                : CameoLayout.toastV6FlatIconSize,
            color: c.staticBlackBase,
          ),
          Flexible(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: elevated
                    ? CameoLayout.toastV6ElevatedTextPaddingX
                    : CameoLayout.toastV6FlatTextPaddingX,
              ),
              child: CameoText(
                message,
                style: CameoTextStyles.bodyMd,
                color: c.staticBlackBase,
                maxLines: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ToastV6 extends StatelessWidget {
  const ToastV6({
    super.key,
    required this.message,
    required this.icon,
    required this.visible,
    this.onHidden,
    this.showKey = 0,
    this.autoHide = true,
    this.variant = ToastV6Variant.flat,
    this.placement = ToastV6Placement.call,
    this.onPress,
  });

  final String message;
  final CameoIconName icon;
  final bool visible;
  final VoidCallback? onHidden;
  final int showKey;
  final bool autoHide;
  final ToastV6Variant variant;

  final ToastV6Placement placement;

  final VoidCallback? onPress;

  @override
  Widget build(BuildContext context) => Toast(
    message: message,
    icon: icon,
    visible: visible,
    onHidden: onHidden,
    showKey: showKey,
    autoHide: autoHide,
    variant: toastV6VariantOf(variant, placement),
    onPress: onPress,
  );
}

class ToastV6Host extends StatelessWidget {
  const ToastV6Host({
    super.key,
    required this.controller,
    this.autoHide = true,
    this.variant = ToastV6Variant.flat,
    this.placement = ToastV6Placement.call,
    this.onPress,
  });

  final ToastController controller;
  final bool autoHide;
  final ToastV6Variant variant;

  final ToastV6Placement placement;
  final VoidCallback? onPress;

  @override
  Widget build(BuildContext context) => ToastHost(
    controller: controller,
    variant: toastV6VariantOf(variant, placement),
    autoHide: autoHide,
    onPress: onPress,
  );
}
