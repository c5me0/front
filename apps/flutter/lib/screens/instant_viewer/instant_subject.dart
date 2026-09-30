// Transient camera thumbnail or partner-shared photo used as the source of the unified
// viewer.

import 'package:flutter/widgets.dart';

import '../../content/lab.g.dart';

@immutable
class InstantSubject {
  const InstantSubject({
    required this.image,
    required this.share,
    this.albumPhotoId,
    this.video = false,
  });

  final ImageProvider image;

  final String share;

  final String? albumPhotoId;

  final bool video;
}

final InstantSubject partnerInstant = InstantSubject(
  image: AssetImage(labViewerV5.instant.image),
  share: labViewerV5.instant.image,
);

InstantSubject _subject = partnerInstant;

void setInstantSubject(InstantSubject next) => _subject = next;

InstantSubject get instantSubject => _subject;

void resetInstantSubject() => _subject = partnerInstant;
