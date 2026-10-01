import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../api/api_models.dart';
import '../api/cameo_api.dart';

abstract interface class CallPeer {
  Future<String> offer();
  Future<void> answer(String sdp);
  void mute(bool value);
  Future<void> close();
}

typedef CallPeerFactory =
    Future<CallPeer> Function(
      List<JsonObject> iceServers,
      void Function(JsonObject) onCandidate,
      void Function() onDisconnected,
    );

class WebRtcCallPeer implements CallPeer {
  WebRtcCallPeer._(this._connection, this._stream);
  final RTCPeerConnection _connection;
  final MediaStream? _stream;
  bool _closed = false;

  static Future<CallPeer> open(
    List<JsonObject> iceServers,
    void Function(JsonObject) onCandidate,
    void Function() onDisconnected,
  ) async {
    MediaStream? stream;
    RTCPeerConnection? connection;
    try {
      try {
        stream = await navigator.mediaDevices.getUserMedia({'audio': true, 'video': false});
      } catch (_) {
        throw const ApiException('microphone_required');
      }
      connection = await createPeerConnection({
        'iceServers': iceServers,
        'sdpSemantics': 'unified-plan',
      });
      final peer = WebRtcCallPeer._(connection, stream);
      connection.onIceCandidate = (candidate) {
        if (peer._closed || candidate.candidate?.isNotEmpty != true) return;
        onCandidate({
          'type': 'candidate',
          'candidate': candidate.candidate,
          'sdp_mid': candidate.sdpMid,
          'sdp_mline_index': candidate.sdpMLineIndex,
        });
      };
      connection.onConnectionState = (state) {
        if (!peer._closed &&
            state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
          onDisconnected();
        }
      };
      for (final track in stream.getAudioTracks()) {
        await connection.addTrack(track, stream);
      }
      return peer;
    } catch (_) {
      await connection?.close();
      for (final track in stream?.getTracks() ?? <MediaStreamTrack>[]) {
        await track.stop();
      }
      await stream?.dispose();
      rethrow;
    }
  }

  @override
  Future<String> offer() async {
    final description = await _connection.createOffer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': false,
    });
    await _connection.setLocalDescription(description);
    return description.sdp!;
  }

  @override
  Future<void> answer(String sdp) =>
      _connection.setRemoteDescription(RTCSessionDescription(sdp, 'answer'));
  @override
  void mute(bool value) {
    for (final track in _stream?.getAudioTracks() ?? <MediaStreamTrack>[]) {
      track.enabled = !value;
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    for (final track in _stream?.getTracks() ?? <MediaStreamTrack>[]) {
      await track.stop();
    }
    await _connection.close();
    await _stream?.dispose();
  }
}
