import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import '../api/cameo_api.dart';
import 'live_call.dart';

/// Bridges the account-bound API to iOS push registration and the system call UI.
class SystemCalls {
  SystemCalls(this.onEvent);
  final Future<void> Function(Map<String, dynamic>) onEvent;
  static const _channel = MethodChannel('cameo/system_calls');
  CameoApi? _api;
  String? _owner, _callId, _status;
  bool _attached = false, _disposed = false;
  int _epoch = 0;
  final List<Map<String, dynamic>> _pending = [];

  Future<void> configure(CameoApi? api, String? owner) async {
    if (!Platform.isIOS ||
        _disposed ||
        (identical(api, _api) && owner == _owner)) {
      return;
    }
    _api = api;
    _owner = owner;
    final epoch = ++_epoch;
    if (!_attached) {
      _attached = true;
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'event') {
          await _event(Map<String, dynamic>.from(call.arguments as Map));
        }
      });
    }
    final result = await _invoke('configure', {
      'enabled': api != null && owner != null,
    });
    if (_disposed || epoch != _epoch) return;
    if (result is Map) {
      for (final entry in (result['tokens'] as Map? ?? {}).entries) {
        await _event({
          'type': 'token',
          'platform': entry.key,
          'token': entry.value,
        });
      }
      for (final event in result['events'] as List? ?? []) {
        await _event(Map<String, dynamic>.from(event as Map));
      }
    }
    if (api != null && owner != null) {
      final pending = List.of(_pending);
      _pending.clear();
      for (final event in pending) {
        await _event(event);
      }
    }
  }

  Future<void> _event(Map<String, dynamic> event) async {
    if (_disposed) return;
    if (_api == null || _owner == null) {
      _pending.add(event);
      return;
    }
    if (event['type'] == 'token') {
      try {
        await _api!.registerDevice(
          event['token'] as String,
          event['platform'] as String,
        );
      } catch (_) {
        /* Registration is retried on the next app activation. */
      }
      return;
    }
    if (event['type'] == 'token_invalidated') {
      try {
        await _api!.unregisterDevice(event['token'] as String);
      } catch (_) {}
      return;
    }
    await onEvent(event);
  }

  Future<void> refreshRegistration() async {
    if (_api == null || _owner == null || !Platform.isIOS) return;
    final result = await _invoke('tokens');
    if (result is Map) {
      for (final entry in result.entries) {
        await _event({
          'type': 'token',
          'platform': entry.key,
          'token': entry.value,
        });
      }
    }
  }

  Future<void> reportEnded(String id) async {
    await _invoke('ended', {'id': id, 'failed': true});
  }

  void sync(LiveCallController call, String name) {
    if (!Platform.isIOS || _disposed || call.callId == null) return;
    final id = call.callId!;
    if (_callId != id) {
      _callId = id;
      _status = null;
      if (call.outgoing && call.hasCall) {
        unawaited(_invoke('outgoing', {'id': id, 'name': name}));
      }
    }
    if (_status == call.status) return;
    _status = call.status;
    if (call.active) {
      unawaited(_invoke('connected', {'id': id}));
    } else if (!call.hasCall) {
      unawaited(
        _invoke('ended', {'id': id, 'failed': call.status == 'failed'}),
      );
    }
  }

  Future<Object?> _invoke(
    String method, [
    Map<String, Object?>? arguments,
  ]) async {
    try {
      return await _channel.invokeMethod<Object?>(method, arguments);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  void dispose() {
    _disposed = true;
    _epoch++;
    if (_attached) _channel.setMethodCallHandler(null);
  }
}
