import 'package:flutter/cupertino.dart';

import '../content/app.g.dart';
import '../design_system/design_system.dart';
import 'call_camera_geometry.dart' show recordingLabel;

Future<void> showMediaDetails(
  BuildContext context, {
  required bool video,
  required double width,
  required double height,
  Duration? duration,
}) {
  final copy = AppContent.of(context).v6.mediaDetails;
  return showCupertinoModalPopup<void>(
    context: context,
    builder: (sheetContext) => CupertinoActionSheet(
      title: Text(copy.title),
      message: Text(
        [
          video ? copy.video : copy.photo,
          if (width > 0 && height > 0)
            fillTemplate(copy.dimensions, {
              'width': width.round(),
              'height': height.round(),
            }),
          if (duration != null)
            fillTemplate(copy.duration, {'duration': recordingLabel(duration)}),
        ].join('\n'),
        style: CameoTextStyles.bodyMd,
      ),
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.of(sheetContext).pop(),
        child: Text(copy.close),
      ),
    ),
  );
}
