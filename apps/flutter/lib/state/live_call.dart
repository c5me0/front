import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import '../api/api_models.dart';
import '../api/cameo_api.dart';
import '../api/media_models.dart';
import 'call_peer.dart';
import 'remote_album.dart';
import 'permissions.dart';
import 'session.dart' show PermissionKind, PermissionState;

class LiveCallController extends ChangeNotifier {
  LiveCallController({
    CallPeerFactory? peerFactory,
    PermissionService? permissions,
  }) : _peerFactory = peerFactory ?? WebRtcCallPeer.open,
       _permissions = permissions ?? const SystemPermissionService();
  final CallPeerFactory _peerFactory;
  final PermissionService _permissions;
  CameoApi? _api;
  RemoteAlbum? _album;
  String? _ownerId, _partnerId;
  ApiCall? incoming;
  String? callId, error;
  String status = 'idle';
  DateTime? startedAt;
  ApiPhoto? receivedPhoto;
  int highlightEvents = 0;
  bool muted = false, connecting = false, _disposed = false, _polling = false;
  bool outgoing = false;
  bool _foreground = true;
  WebSocket? _socket;
  StreamSubscription<dynamic>? _subscription;
  Future<void>? _socketDone;
  CallPeer? _peer;
  Timer? _pollTimer, _reconnectTimer;
  int _epoch = 0, _attempts = 0;
  Future<void> _messages = Future.value();
  bool get hasCall =>
      connecting ||
      (callId != null && (status == 'ringing' || status == 'active'));
  bool get active => status == 'active';
  int get elapsed => startedAt == null
      ? 0
      : DateTime.now().difference(startedAt!).inSeconds.clamp(0, 1 << 31);
  bool _current(int epoch) => !_disposed && epoch == _epoch;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void configure(
    CameoApi? api,
    String? owner,
    String? partner,
    RemoteAlbum album,
  ) {
    if (identical(api, _api) && owner == _ownerId && partner == _partnerId) {
      return;
    }
    _epoch++;
    unawaited(_release());
    _pollTimer?.cancel();
    _reconnectTimer?.cancel();
    _api = api;
    _ownerId = owner;
    _partnerId = partner;
    _album = album;
    callId = null;
    incoming = null;
    status = 'idle';
    error = null;
    startedAt = null;
    receivedPhoto = null;
    connecting = false;
    muted = false;
    if (api != null && owner != null && partner != null) {
      unawaited(pollIncoming());
      _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (_foreground) unawaited(pollIncoming());
      });
    }
    _notify();
  }

  void setForeground(bool value) {
    _foreground = value;
    if (value) unawaited(pollIncoming());
  }

  Future<void> pollIncoming() async {
    if (_api == null ||
        _ownerId == null ||
        _partnerId == null ||
        _polling ||
        hasCall) {
      return;
    }
    final epoch = _epoch;
    _polling = true;
    try {
      final page = await _api!.calls();
      if (!_current(epoch)) return;
      final next = page.items
          .where((c) => c.status == 'ringing' && c.calleeId == _ownerId)
          .firstOrNull;
      if (next?.id != incoming?.id) {
        incoming = next;
        _notify();
      }
    } catch (_) {
      /* The album and session own foreground network error reporting. */
    } finally {
      _polling = false;
    }
  }

  Future<void> start({String? id}) async {
    if (hasCall || _api == null || _ownerId == null || _partnerId == null) {
      return;
    }
    final epoch = ++_epoch, api = _api!;
    callId = id;
    outgoing = id == null;
    connecting = true;
    status = 'ringing';
    error = null;
    startedAt = null;
    receivedPhoto = null;
    muted = false;
    _attempts = 0;
    incoming = null;
    _notify();
    try {
      final permission = await _permissions.request(PermissionKind.microphone);
      if (!_current(epoch)) return;
      if (permission != PermissionState.granted) {
        throw const ApiException('microphone_required');
      }
      final ApiCall call;
      final List<JsonObject> ice;
      if (id == null) {
        final result = await api.createCall();
        call = result.call;
        ice = result.iceServers;
      } else {
        final result = await api.call(id);
        call = result.call;
        ice = result.iceServers;
      }
      if (!_current(epoch)) {
        if (id == null) {
          try {
            await api.endCall(call.id);
          } catch (_) {}
        }
        return;
      }
      callId = call.id;
      outgoing = call.callerId == _ownerId;
      status = call.status;
      startedAt = call.startedAt;
      _notify();
      if (!call.live) {
        connecting = false;
        _notify();
        return;
      }
      await _connect(epoch, ice);
    } catch (problem) {
      if (!_current(epoch)) return;
      error = problem is ApiException ? problem.code : 'network_unavailable';
      final failedId = callId;
      if (failedId != null) {
        try {
          await api.endCall(failedId);
        } catch (_) {}
      }
      if (!_current(epoch)) return;
      status = 'failed';
      connecting = false;
      await _release();
      _notify();
    }
  }

  Future<void> _connect(int epoch, List<JsonObject> ice) async {
    final socket = await _api!.openSignal(callId!);
    if (!_current(epoch)) {
      await socket.close();
      return;
    }
    _socket = socket;
    final socketDone = Completer<void>();
    _socketDone = socketDone.future;
    _subscription = socket.listen(
      (frame) {
        _messages = _messages
            .then((_) async {
              if (_current(epoch)) {
                await _message(jsonObject(jsonDecode(frame as String)), epoch);
              }
            })
            .catchError((Object _) {
              if (_current(epoch)) {
                error = 'network_unavailable';
                _notify();
              }
            });
      },
      onDone: () {
        if (!socketDone.isCompleted) socketDone.complete();
        if (!_current(epoch) || !hasCall) return;
        if (socket.closeCode == 4000 || socket.closeCode == 1008) {
          unawaited(_finish('failed'));
          return;
        }
        _scheduleReconnect(epoch);
      },
      onError: (Object _) {
        if (_current(epoch)) _scheduleReconnect(epoch);
      },
    );
    final candidates = <JsonObject>[];
    var offered = false;
    final peer = await _peerFactory(callIceServers(ice), (candidate) {
      if (!_current(epoch)) return;
      if (offered && _socket?.readyState == WebSocket.open) {
        _socket!.add(jsonEncode(candidate));
      } else {
        candidates.add(candidate);
      }
    }, () => _scheduleReconnect(epoch));
    if (!_current(epoch) || !hasCall) {
      await peer.close();
      return;
    }
    _peer = peer;
    peer.mute(muted);
    final sdp = await peer.offer();
    if (!_current(epoch) || !hasCall || socket.readyState != WebSocket.open) {
      return;
    }
    socket.add(jsonEncode({'type': 'offer', 'sdp': sdp}));
    offered = true;
    for (final candidate in candidates) {
      socket.add(jsonEncode(candidate));
    }
    connecting = false;
    _notify();
  }

  Future<void> _message(JsonObject message, int epoch) async {
    switch (message['type']) {
      case 'answer':
        await _peer?.answer(message['sdp'] as String);
        if (!_current(epoch)) return;
        _attempts = 0;
        error = null;
      case 'state':
        status = message['status'] as String;
        startedAt = message['started_at'] == null
            ? null
            : DateTime.parse(message['started_at'] as String);
        if (status == 'active') error = null;
      case 'highlight_added':
        highlightEvents++;
      case 'photo_shared':
        receivedPhoto = ApiPhoto.fromJson(jsonObject(message['photo']));
        _album?.receivedPhoto(receivedPhoto!);
      case 'ended':
        await _finish(message['status'] as String);
        return;
      case 'error':
        error = message['code'] as String? ?? 'network_unavailable';
    }
    _notify();
  }

  void _scheduleReconnect(int epoch) {
    if (!_current(epoch) || !hasCall || _reconnectTimer != null) return;
    if (_attempts >= 4) {
      unawaited(end());
      return;
    }
    error = 'call_reconnecting';
    _notify();
    _reconnectTimer = Timer(const Duration(seconds: 2), () async {
      _reconnectTimer = null;
      if (!_current(epoch) || !hasCall) return;
      _attempts++;
      try {
        final detail = await _api!.call(callId!);
        if (!_current(epoch)) return;
        if (!detail.call.live) {
          await _finish(detail.call.status);
          return;
        }
        // Rebuild the peer connection as required by the server's negotiation contract.
        final nextEpoch = ++_epoch;
        await _release();
        if (_current(nextEpoch)) await _connect(nextEpoch, detail.iceServers);
      } catch (_) {
        _scheduleReconnect(_epoch);
      }
    });
  }

  void setMuted(bool value) {
    muted = value;
    _peer?.mute(value);
    _notify();
  }

  Future<bool> addHighlight() async {
    if (!active || callId == null) return false;
    final epoch = _epoch;
    try {
      await _api!.highlight(callId!, elapsed.toDouble());
      return _current(epoch);
    } catch (problem) {
      if (_current(epoch)) {
        error = problem is ApiException ? problem.code : 'network_unavailable';
        _notify();
      }
      return false;
    }
  }

  Future<ApiPhoto?> sharePhoto(String photoId) async {
    if (!active || callId == null) return null;
    final epoch = _epoch;
    try {
      final photo = await _api!.shareCallPhoto(callId!, photoId);
      if (!_current(epoch)) return null;
      _album?.receivedPhoto(photo);
      return photo;
    } catch (problem) {
      if (_current(epoch)) {
        error = problem is ApiException ? problem.code : 'network_unavailable';
        _notify();
      }
      return null;
    }
  }

  Future<void> decline() async {
    final call = incoming, api = _api;
    if (call == null || api == null) return;
    final epoch = _epoch;
    try {
      await api.declineCall(call.id);
      if (_current(epoch)) incoming = null;
    } on ApiException catch (problem) {
      if (_current(epoch)) error = problem.code;
    }
    _notify();
  }

  Future<void> end() async {
    final id = callId, api = _api;
    if (id == null || api == null) {
      if (connecting) await _finish('ended');
      return;
    }
    final epoch = _epoch;
    if (_socket?.readyState == WebSocket.open) {
      _socket!.add(jsonEncode({'type': 'hangup'}));
    }
    // Stop capturing immediately, including when the server cannot be reached.
    await _peer?.close();
    _peer = null;
    try {
      await api.endCall(id);
    } on ApiException catch (problem) {
      if (_current(epoch) && problem.status != 409) error = problem.code;
    }
    if (_current(epoch)) await _finish('ended');
  }

  Future<void> _finish(String terminalStatus) async {
    final epoch = ++_epoch;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    status = terminalStatus;
    connecting = false;
    await _release();
    if (!_current(epoch)) return;
    _notify();
    unawaited(_album?.refresh());
  }

  Future<void> _release() async {
    final subscription = _subscription, socket = _socket, peer = _peer;
    final socketDone = _socketDone;
    _subscription = null;
    _socket = null;
    _socketDone = null;
    _peer = null;
    try {
      await peer?.close();
    } finally {
      // Keep the stream's error handler attached while the TLS socket closes.
      try {
        await socket?.close();
        // close() flushes the outgoing close frame; the incoming stream may
        // still contain the peer's response. Drain it before cancelling reads.
        await socketDone?.timeout(const Duration(seconds: 5), onTimeout: () {});
      } finally {
        await subscription?.cancel();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    _pollTimer?.cancel();
    _reconnectTimer?.cancel();
    unawaited(_release());
    super.dispose();
  }
}

class LiveCallScope extends InheritedNotifier<LiveCallController> {
  const LiveCallScope({
    super.key,
    required LiveCallController controller,
    required super.child,
  }) : super(notifier: controller);
  static LiveCallController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LiveCallScope>()?.notifier;
  static LiveCallController? read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<LiveCallScope>()?.notifier;
}
