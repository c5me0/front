// Share photos through the native sheet. Materialize bundled assets as temporary files
// and preserve cancellation as a distinct outcome.

//

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import '../api/cameo_api.dart' show mediaUri;

import 'device_services.dart';

enum ShareOutcome { shared, dismissed, unavailable }

abstract class ShareService {
  Future<ShareOutcome> shareImages(List<String> images, {Rect? origin});

  static ShareService of(BuildContext context) =>
      DeviceServicesScope.maybeOf(context)?.share ?? SystemShareService.shared;
}

bool isBundleAsset(String image) => image.startsWith('assets/');

Future<List<String>> writeAssetsToTemp(
  List<String> assets, {
  AssetBundle? bundle,
  Directory? directory,
}) async {
  final source = bundle ?? rootBundle;
  final dir = directory ?? await Directory.systemTemp.createTemp('cameo-share');
  final paths = <String>[];
  for (final asset in assets) {
    final data = await source.load(asset);
    final name = asset.split('/').last;
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      flush: true,
    );
    paths.add(file.path);
  }
  return paths;
}

class SystemShareService implements ShareService {
  SystemShareService._();

  static final SystemShareService shared = SystemShareService._();

  @override
  Future<ShareOutcome> shareImages(List<String> images, {Rect? origin}) async {
    if (images.isEmpty) return ShareOutcome.unavailable;
    Directory? directory;
    final client = http.Client();
    try {
      directory = await Directory.systemTemp.createTemp('cameo-share-');
      final paths = <String>[];
      for (var i = 0; i < images.length; i++) {
        final source = images[i];
        if (isBundleAsset(source)) {
          paths.addAll(await writeAssetsToTemp([source], directory: directory));
        } else if (source.startsWith('https://') ||
            source.startsWith('http://')) {
          final request = http.Request('GET', mediaUri(source))
            ..followRedirects = false;
          final response = await client
              .send(request)
              .timeout(const Duration(seconds: 30));
          if (response.statusCode != 200) return ShareOutcome.unavailable;
          final type = response.headers['content-type']?.split(';').first;
          final extension = switch (type) {
            'image/jpeg' => 'jpg',
            'image/png' => 'png',
            'image/webp' => 'webp',
            'image/heic' => 'heic',
            'video/mp4' => 'mp4',
            'video/quicktime' => 'mov',
            _ => null,
          };
          if (extension == null) return ShareOutcome.unavailable;
          final limit = type!.startsWith('video/') ? 250000000 : 25 << 20;
          if ((response.contentLength ?? 0) > limit) {
            return ShareOutcome.unavailable;
          }
          final file = File('${directory.path}/moment-$i.$extension');
          final sink = file.openWrite();
          var received = 0;
          try {
            await sink.addStream(
              response.stream.timeout(const Duration(seconds: 30)).map((chunk) {
                received += chunk.length;
                if (received > limit) {
                  throw const FormatException('Media exceeds share limit');
                }
                return chunk;
              }),
            );
          } finally {
            await sink.close();
          }
          if (received == 0) return ShareOutcome.unavailable;
          paths.add(file.path);
        } else {
          paths.add(source);
        }
      }
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [for (final path in paths) XFile(path)],
          sharePositionOrigin: origin,
        ),
      );
      return switch (result.status) {
        ShareResultStatus.success => ShareOutcome.shared,
        ShareResultStatus.dismissed => ShareOutcome.dismissed,
        ShareResultStatus.unavailable => ShareOutcome.unavailable,
      };
    } catch (_) {
      return ShareOutcome.unavailable;
    } finally {
      client.close();
      if (directory != null) {
        try {
          await directory.delete(recursive: true);
        } on FileSystemException catch (_) {}
      }
    }
  }
}

class SimulatedShareService implements ShareService {
  SimulatedShareService({this.outcome = ShareOutcome.shared});

  ShareOutcome outcome;

  final List<List<String>> requests = [];

  @override
  Future<ShareOutcome> shareImages(List<String> images, {Rect? origin}) {
    if (images.isEmpty) return SynchronousFuture(ShareOutcome.unavailable);
    requests.add(List.unmodifiable(images));
    return SynchronousFuture(outcome);
  }
}
