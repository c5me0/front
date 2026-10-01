// Import selected device photos into today's album section in picker order and display
// the result through the shared album store.

import 'package:flutter/widgets.dart';

import 'album_store.dart';
import 'photo_picker_service.dart';

bool _busy = false;

Future<List<AlbumPhoto>> importPhotos(
  PhotoPickerService picker,
  AlbumStore album,
) async {
  if (_busy) return const [];
  _busy = true;
  try {
    final photos = await picker.pickPhotos();
    return await album.savePhotos(photos);
  } finally {
    _busy = false;
  }
}

Future<List<AlbumPhoto>> importPhotosFrom(BuildContext context) =>
    importPhotos(PhotoPickerService.of(context), AlbumScope.read(context));
