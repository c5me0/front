import 'dart:io';

import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../api/cameo_api.dart';
import 'captured_photo.dart';

const maxVideoBytes = 250000000;

Future<CapturedPhoto> videoOfFile(
  String path, {
  CapturedPhotoSource source = CapturedPhotoSource.library,
}) async {
  final size = await File(path).length();
  if (size <= 0) throw const ApiException('video_unreadable');
  if (size > maxVideoBytes) throw const ApiException('video_too_large');
  final player = VideoPlayerController.file(
    File(path),
    videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
  );
  try {
    await player.initialize();
    final value = player.value;
    if (value.duration <= Duration.zero || value.size.isEmpty) {
      throw const ApiException('video_unreadable');
    }
    final thumbnail = await VideoThumbnail.thumbnailFile(
      video: path,
      imageFormat: ImageFormat.PNG,
      maxWidth: 512,
    );
    if (thumbnail == null || !await File(thumbnail).exists()) {
      throw const ApiException('video_unreadable');
    }
    return CapturedPhoto(
      uri: path,
      width: value.size.width,
      height: value.size.height,
      source: source,
      videoDuration: value.duration,
      thumbnailPath: thumbnail,
    );
  } on ApiException {
    rethrow;
  } catch (_) {
    throw const ApiException('video_unreadable');
  } finally {
    await player.dispose();
  }
}
