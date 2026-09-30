// System photo-picker adapter with ordered results and image dimension probing. The
// album caller owns insertion and user feedback.

//

import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';

import 'captured_photo.dart';
import 'device_services.dart';

abstract class PhotoPickerService {
  Future<List<CapturedPhoto>> pickPhotos({int? limit});

  static PhotoPickerService of(BuildContext context) =>
      DeviceServicesScope.maybeOf(context)?.photoPicker ??
      SystemPhotoPickerService.shared;
}

class SystemPhotoPickerService implements PhotoPickerService {
  SystemPhotoPickerService._([ImagePicker? picker])
    : _picker = picker ?? ImagePicker();

  static final SystemPhotoPickerService shared = SystemPhotoPickerService._();

  final ImagePicker _picker;

  @override
  Future<List<CapturedPhoto>> pickPhotos({int? limit}) async {
    try {
      final List<XFile> files;
      if (limit == 1) {
        final one = await _picker.pickImage(source: ImageSource.gallery);
        files = one == null ? const [] : [one];
      } else {
        files = await _picker.pickMultiImage(
          limit: limit != null && limit >= 2 ? limit : null,
        );
      }
      return [for (final file in files) await photoOfFile(file.path)];
    } on PlatformException catch (e) {
      debugPrint('[cameo] photo picker failed: ${e.code} ${e.message}');
      return const [];
    }
  }
}

Future<CapturedPhoto> photoOfFile(String path) async {
  var width = 0.0;
  var height = 0.0;
  try {
    final buffer = await ui.ImmutableBuffer.fromFilePath(path);
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    width = descriptor.width.toDouble();
    height = descriptor.height.toDouble();
    descriptor.dispose();
    buffer.dispose();
  } catch (e) {
    debugPrint('[cameo] photo size unknown ($path): $e');
  }
  return CapturedPhoto(
    uri: path,
    width: width,
    height: height,
    source: CapturedPhotoSource.library,
  );
}

class SimulatedPhotoPickerService implements PhotoPickerService {
  SimulatedPhotoPickerService({List<CapturedPhoto>? result})
    : result = result ?? [CapturedPhoto.placeholder()];

  List<CapturedPhoto> result;

  final List<int?> requests = [];

  @override
  Future<List<CapturedPhoto>> pickPhotos({int? limit}) async {
    requests.add(limit);
    final photos = List<CapturedPhoto>.of(result);
    return limit == null || photos.length <= limit
        ? photos
        : photos.sublist(0, limit);
  }
}
