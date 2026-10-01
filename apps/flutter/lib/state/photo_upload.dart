import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../api/cameo_api.dart';
import 'captured_photo.dart';
import 'video_media.dart';

class PreparedPhoto {
  PreparedPhoto(
    Uint8List data,
    this.thumbnail,
    this.contentType,
    this.width,
    this.height,
  ) : bytes = data,
      filePath = null,
      sizeBytes = data.length,
      durationSeconds = null;
  PreparedPhoto.video(
    String path,
    int size,
    this.thumbnail,
    this.contentType,
    this.width,
    this.height,
    this.durationSeconds,
  ) : bytes = null,
      filePath = path,
      sizeBytes = size;

  final Uint8List? bytes;
  final Uint8List thumbnail;
  final String? filePath;
  final int sizeBytes;
  final double? durationSeconds;

  Future<void> uploadOriginal(CameoApi api, String url) => filePath == null
      ? api.uploadObject(url, bytes!, contentType)
      : api.uploadFileObject(url, filePath!, sizeBytes, contentType);
  final String contentType;
  final int width, height;
}

Future<PreparedPhoto> preparePhoto(CapturedPhoto photo) async {
  if (photo.isVideo) return _prepareVideo(photo);
  if (photo.source == CapturedPhotoSource.placeholder) {
    throw const ApiException('camera_unavailable');
  }
  final file = File(photo.uri);
  if (await file.length() > 25 << 20) {
    throw const ApiException('photo_too_large');
  }
  final bytes = await file.readAsBytes();
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  ui.Image? image;
  try {
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    final width = descriptor.width, height = descriptor.height;
    final scale = 512 / (width > height ? width : height);
    codec = await descriptor.instantiateCodec(
      targetWidth: scale < 1 ? (width * scale).round().clamp(1, 512) : width,
      targetHeight: scale < 1 ? (height * scale).round().clamp(1, 512) : height,
    );
    image = (await codec.getNextFrame()).image;
    final thumbnail = (await image.toByteData(
      format: ui.ImageByteFormat.png,
    ))!.buffer.asUint8List();
    if (thumbnail.length > 1 << 20) throw const ApiException('photo_too_large');
    final type = _contentType(bytes);
    return PreparedPhoto(bytes, thumbnail, type, width, height);
  } on ApiException {
    rethrow;
  } catch (_) {
    throw const ApiException('photo_unsupported');
  } finally {
    image?.dispose();
    codec?.dispose();
    descriptor?.dispose();
    buffer.dispose();
  }
}

String _contentType(Uint8List bytes) {
  if (bytes.length >= 3 &&
      bytes[0] == 0xff &&
      bytes[1] == 0xd8 &&
      bytes[2] == 0xff) {
    return 'image/jpeg';
  }
  if (bytes.length >= 8 &&
      bytes[0] == 137 &&
      String.fromCharCodes(bytes.sublist(1, 4)) == 'PNG') {
    return 'image/png';
  }
  if (bytes.length >= 12 &&
      String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
      String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
    return 'image/webp';
  }
  if (bytes.length >= 12 &&
      String.fromCharCodes(bytes.sublist(4, 8)) == 'ftyp' &&
      {
        'heic',
        'heix',
        'hevc',
        'hevx',
        'mif1',
      }.contains(String.fromCharCodes(bytes.sublist(8, 12)))) {
    return 'image/heic';
  }
  throw const ApiException('photo_unsupported');
}

Future<PreparedPhoto> _prepareVideo(CapturedPhoto photo) async {
  if (photo.source == CapturedPhotoSource.placeholder) {
    throw const ApiException('camera_unavailable');
  }
  final file = File(photo.uri);
  final size = await file.length();
  if (size > maxVideoBytes) throw const ApiException('video_too_large');
  if (size < 12) throw const ApiException('video_unsupported');
  final handle = await file.open();
  late Uint8List header;
  try {
    header = await handle.read(32);
  } finally {
    await handle.close();
  }
  if (String.fromCharCodes(header.sublist(4, 8)) != 'ftyp') {
    throw const ApiException('video_unsupported');
  }
  final brand = String.fromCharCodes(header.sublist(8, 12));
  final type = switch (brand) {
    'qt  ' => 'video/quicktime',
    'isom' || 'iso2' || 'mp41' || 'mp42' || 'avc1' || 'M4V ' => 'video/mp4',
    _ => throw const ApiException('video_unsupported'),
  };
  final metadata = photo.thumbnailPath == null
      ? await videoOfFile(photo.uri, source: photo.source)
      : photo;
  final thumbnail = await File(metadata.thumbnailPath!).readAsBytes();
  if (thumbnail.isEmpty ||
      thumbnail.length > 1 << 20 ||
      metadata.videoDuration == null) {
    throw const ApiException('video_unreadable');
  }
  return PreparedPhoto.video(
    photo.uri,
    size,
    thumbnail,
    type,
    metadata.width.round(),
    metadata.height.round(),
    metadata.videoDuration!.inMilliseconds / 1000,
  );
}
