// Resolve a development start route from CAMEO_ROUTE. Validate known paths before
// passing them to the session guard.

import 'dart:convert' show utf8;
import 'dart:ffi';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

import '../state/session.dart';
import 'cameo_location.dart';
import 'cameo_routes.dart';

///

/// v5: `'/?session=member&album=empty'` · `'/capture?session=member'` · `'/call?sheet=multi&session=member'` · `'/photo?section=sungsu&index=0'`

const String kCameoRouteEnv = 'CAMEO_ROUTE';

///

String resolveInitialRoute({Map<String, String>? environment}) {
  String? raw = environment != null
      ? environment[kCameoRouteEnv]
      : readEnvironmentVariable(kCameoRouteEnv);
  if ((raw == null || raw.trim().isEmpty) && environment == null) {
    raw = const String.fromEnvironment(kCameoRouteEnv);
  }
  if (raw == null || raw.trim().isEmpty) return CameoRoutes.home;

  final location = CameoLocation.parse(raw);
  if (!CameoRoutes.isKnownPath(location.path)) {
    debugPrint(
      '[cameo] $kCameoRouteEnv="$raw" is not a known route → ${CameoRoutes.home}',
    );
    return CameoRoutes.home;
  }
  final name = location.toString();
  debugPrint('[cameo] initial route: $name');
  return name;
}

@immutable
class CameoLaunch {
  const CameoLaunch({
    required this.location,
    this.devSession,
    this.partnerNone = false,
    this.flowDemo = false,
    this.albumEmpty,
  });

  factory CameoLaunch.parse(String name, {bool allowDemo = true}) {
    final raw = CameoLocation.parse(name);
    if (!allowDemo) {
      final location = CameoRoutes.withoutDevParams(raw);
      return CameoLaunch(
        location: CameoLocation(location.path, {
          for (final entry in location.params.entries)
            if (entry.key != 'demo') entry.key: entry.value,
        }),
      );
    }
    if (CameoRoutes.flowDemoOf(raw)) {
      return const CameoLaunch(
        location: CameoLocation(CameoRoutes.welcome),
        devSession: DevSessionKind.guest,
        flowDemo: true,
        albumEmpty: false,
      );
    }
    return CameoLaunch(
      location: CameoRoutes.withoutDevParams(raw),
      devSession: CameoRoutes.devSessionOf(raw),
      partnerNone: CameoRoutes.partnerNoneOf(raw),
      albumEmpty: CameoRoutes.albumEmptyOf(raw),
    );
  }

  final CameoLocation location;
  final DevSessionKind? devSession;
  final bool partnerNone;
  final bool flowDemo;
  final bool? albumEmpty;

  bool? get albumReset => albumEmpty ?? (devSession != null ? false : null);

  @override
  String toString() =>
      'CameoLaunch($location, session: ${devSession?.param}, '
      'partnerNone: $partnerNone, flowDemo: $flowDemo, albumEmpty: $albumEmpty)';
}

///

String? readEnvironmentVariable(String name) {
  try {
    final fromDart = Platform.environment[name];
    if (fromDart != null) return fromDart;
  } catch (_) {}
  return libcGetenv(name);
}

typedef _GetenvNative = Pointer<Uint8> Function(Pointer<Uint8>);
typedef _MallocNative = Pointer<Uint8> Function(IntPtr);
typedef _MallocDart = Pointer<Uint8> Function(int);
typedef _FreeNative = Void Function(Pointer<Uint8>);
typedef _FreeDart = void Function(Pointer<Uint8>);

@visibleForTesting
String? libcGetenv(String name) {
  try {
    final libc = DynamicLibrary.process();
    final getenv = libc.lookupFunction<_GetenvNative, _GetenvNative>('getenv');
    final malloc = libc.lookupFunction<_MallocNative, _MallocDart>('malloc');
    final free = libc.lookupFunction<_FreeNative, _FreeDart>('free');

    final key = utf8.encode(name);
    final cKey = malloc(key.length + 1);
    if (cKey == nullptr) return null;
    try {
      cKey.asTypedList(key.length + 1)
        ..setAll(0, key)
        ..[key.length] = 0;
      final value = getenv(cKey);
      if (value == nullptr) return null;
      var length = 0;
      while (value[length] != 0) {
        length++;
      }
      return utf8.decode(value.asTypedList(length));
    } finally {
      free(cKey);
    }
  } catch (_) {
    return null;
  }
}
