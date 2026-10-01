import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Adds standard editing gestures across a custom field, including its padding.
///
/// The child EditableText must use [editableTextKey] and set
/// `rendererIgnoresPointer: true` so selection and keyboard requests have one owner.
class TextInputGestures extends StatefulWidget {
  const TextInputGestures({
    super.key,
    required this.editableTextKey,
    required this.child,
  });

  final GlobalKey<EditableTextState> editableTextKey;
  final Widget child;

  @override
  State<TextInputGestures> createState() => _TextInputGesturesState();
}

class _TextInputGesturesState extends State<TextInputGestures>
    implements TextSelectionGestureDetectorBuilderDelegate {
  late final _gestures = TextSelectionGestureDetectorBuilder(delegate: this);

  @override
  GlobalKey<EditableTextState> get editableTextKey => widget.editableTextKey;

  @override
  bool get forcePressEnabled => defaultTargetPlatform == TargetPlatform.iOS;

  @override
  bool get selectionEnabled =>
      editableTextKey.currentState?.widget.selectionEnabled ?? false;

  @override
  Widget build(BuildContext context) => TextFieldTapRegion(
    child: _gestures.buildGestureDetector(
      behavior: HitTestBehavior.opaque,
      child: widget.child,
    ),
  );
}
