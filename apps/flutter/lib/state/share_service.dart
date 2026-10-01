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
    try {
      final assets = [
        for (final i in images)
          if (isBundleAsset(i)) i,
      ];
      final written = await writeAssetsToTemp(assets);
      var next = 0;
      final paths = [
        for (final i in images) isBundleAsset(i) ? written[next++] : i,
      ];
      for (var i = 0; i < paths.length; i++) {
        if (!paths[i].startsWith('https://') && !paths[i].startsWith('http://')) continue;
        final client = http.Client();
        try {
          final request = http.Request('GET', mediaUri(paths[i]))..followRedirects = false;
          final response = await client.send(request).timeout(const Duration(seconds: 30));
          if (response.statusCode != 200) return ShareOutcome.unavailable;
          final bytes = <int>[];
          await for (final chunk in response.stream.timeout(const Duration(seconds: 30))) {
            bytes.addAll(chunk);
            if (bytes.length > 25 << 20) return ShareOutcome.unavailable;
          }
          final extension = switch (response.headers['content-type']?.split(';').first) {
            'image/png' => 'png', 'image/webp' => 'webp', 'image/heic' => 'heic', _ => 'jpg',
          };
          final directory = await Directory.systemTemp.createTemp('cameo-share-');
          final file = File('${directory.path}/photo.$extension');
          await file.writeAsBytes(bytes);
          paths[i] = file.path;
        } finally { client.close(); }
      }
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [for (final p in paths) XFile(p)],
          sharePositionOrigin: origin,
        ),
      );
      return switch (result.status) {
        ShareResultStatus.success => ShareOutcome.shared,
        ShareResultStatus.dismissed => ShareOutcome.dismissed,
        ShareResultStatus.unavailable => ShareOutcome.unavailable,
      };
    } catch (error) {
      debugPrint('[cameo] sharing unavailable');
      return ShareOutcome.unavailable;
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
