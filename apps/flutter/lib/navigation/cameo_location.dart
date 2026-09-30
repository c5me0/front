// Normalized route paths and query parameters carried through RouteSettings.

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

///

@immutable
class CameoLocation {
  const CameoLocation(this.path, [this.params = const {}]);

  factory CameoLocation.parse(String name) {
    final uri = Uri.tryParse(name.trim()) ?? Uri();
    var path = uri.path.isEmpty ? '/' : uri.path;
    if (!path.startsWith('/')) path = '/$path';
    if (path.length > 1 && path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    return CameoLocation(path, Map.unmodifiable(uri.queryParameters));
  }

  static CameoLocation of(BuildContext context) {
    final settings = ModalRoute.settingsOf(context);
    final args = settings?.arguments;
    if (args is CameoLocation) return args;
    return CameoLocation.parse(settings?.name ?? '/');
  }

  final String path;
  final Map<String, String> params;

  String? param(String key) => params[key];

  @override
  String toString() {
    if (params.isEmpty) return path;
    return '$path?${Uri(queryParameters: params).query}';
  }

  @override
  bool operator ==(Object other) =>
      other is CameoLocation &&
      other.path == path &&
      mapEquals(other.params, params);

  @override
  int get hashCode => Object.hash(
    path,
    Object.hashAllUnordered(
      params.entries.map((e) => Object.hash(e.key, e.value)),
    ),
  );
}
