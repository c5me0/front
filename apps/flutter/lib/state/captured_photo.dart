// Captured or imported photo metadata and image provider selection. Placeholder assets
// and device files use different providers; video entries store a poster and duration.

//

//            if (photo != null) … MediaCard(image: photo.image) …
import 'dart:io' show File;

import 'package:flutter/widgets.dart';

import '../content/lab.g.dart';

enum CapturedPhotoSource { camera, placeholder, library }

@immutable
class CapturedPhoto {
  const CapturedPhoto({
    required this.uri,
    required this.width,
    required this.height,
    required this.source,
    this.videoDuration,
  });

  factory CapturedPhoto.placeholder([
    String asset = LabImages.cameraPlaceholder,
  ]) {
    final size = LabImages.sizes[asset];
    return CapturedPhoto(
      uri: asset,
      width: (size?.width ?? 0).toDouble(),
      height: (size?.height ?? 0).toDouble(),
      source: CapturedPhotoSource.placeholder,
    );
  }

  final String uri;

  final double width;
  final double height;

  final CapturedPhotoSource source;

  final Duration? videoDuration;

  Map<String, Object?> toJson() => {
    'uri': uri,
    'width': width,
    'height': height,
    'source': source.name,
    'videoMs': videoDuration?.inMilliseconds,
  };

  factory CapturedPhoto.fromJson(Map<String, dynamic> json) => CapturedPhoto(
    uri: json['uri'] as String,
    width: (json['width'] as num).toDouble(),
    height: (json['height'] as num).toDouble(),
    source: CapturedPhotoSource.values.byName(json['source'] as String),
    videoDuration: json['videoMs'] == null
        ? null
        : Duration(milliseconds: json['videoMs'] as int),
  );

  bool get isVideo => videoDuration != null;

  CapturedPhoto asVideo(Duration duration) => CapturedPhoto(
    uri: uri,
    width: width,
    height: height,
    source: source,
    videoDuration: duration,
  );

  ImageProvider get image => switch (source) {
    CapturedPhotoSource.placeholder => AssetImage(uri),
    CapturedPhotoSource.camera ||
    CapturedPhotoSource.library => FileImage(File(uri)),
  };

  double get aspectRatio => height == 0 ? 0 : width / height;

  @override
  bool operator ==(Object other) =>
      other is CapturedPhoto &&
      other.uri == uri &&
      other.width == width &&
      other.height == height &&
      other.source == source &&
      other.videoDuration == videoDuration;

  @override
  int get hashCode => Object.hash(uri, width, height, source, videoDuration);

  @override
  String toString() =>
      'CapturedPhoto(${source.name}, $uri, ${width.toStringAsFixed(0)}x${height.toStringAsFixed(0)}'
      '${videoDuration == null ? '' : ', video ${videoDuration!.inMilliseconds} ms'})';
}
