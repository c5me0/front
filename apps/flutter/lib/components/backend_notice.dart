import 'package:flutter/widgets.dart';
import '../design_system/design_system.dart';

class BackendNotice extends StatelessWidget {
  const BackendNotice({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) {
    final c = CameoTheme.colorsOf(context);
    return Semantics(
      liveRegion: true,
      button: onRetry != null,
      child: GestureDetector(
        onTap: onRetry,
        behavior: HitTestBehavior.opaque,
        child: ColoredBox(
          color: c.backgroundCanvasNeutralBase,
          child: Padding(
            padding: const EdgeInsets.all(CameoLayout.albumNavV6RowPaddingX),
            child: CameoText(
              message,
              style: CameoTextStyles.bodyMd,
              color: onRetry == null ? c.foregroundNeutralMuted : c.systemRed,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
