// Adapt instant camera photos to the shared v6 viewer while preserving their source
// geometry.

import 'package:flutter/widgets.dart';

import '../photo_viewer/photo_viewer_screen.dart';
import 'instant_subject.dart';

class InstantViewerScreen extends StatefulWidget {
  const InstantViewerScreen({super.key});

  static const Key cardKey = PhotoViewerScreen.cardKey;
  static const Key pillKey = PhotoViewerScreen.pillKey;
  static const Key closeKey = PhotoViewerScreen.closeKey;
  static const Key dateKey = PhotoViewerScreen.dateKey;
  static const Key bottomBarKey = PhotoViewerScreen.datePillKey;

  @override
  State<InstantViewerScreen> createState() => InstantViewerScreenState();
}

class InstantViewerScreenState extends State<InstantViewerScreen> {
  final InstantSubject _subject = instantSubject;

  InstantSubject get subject => _subject;

  @override
  Widget build(BuildContext context) =>
      PhotoViewerScreen(sectionId: '', index: 0, subject: _subject);
}
