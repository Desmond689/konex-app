import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Peer-to-peer voice via flutter_webrtc. Signaling is external (Supabase Realtime).
class WebRtcService {
  final _peers = <String, RTCPeerConnection>{};
  final _remoteStreams = <String, MediaStream>{};
  /// Queue ICE candidates that arrive before PC exists for that peer.
  final _pendingIce = <String, List<RTCIceCandidate>>{};
  MediaStream? _localStream;
  bool _muted = false;
  bool _speaker = true;

  MediaStream? get localStream => _localStream;
  Map<String, MediaStream> get remoteStreams => Map.unmodifiable(_remoteStreams);
  bool get isMuted => _muted;
  bool get speakerOn => _speaker;

  final _iceController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onIceCandidate => _iceController.stream;

  static const _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ],
  };

  Future<void> initLocalAudio() async {
    if (_localStream != null) return;
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': false,
    });
  }

  Future<RTCPeerConnection> _createPc(String peerId) async {
    if (_peers.containsKey(peerId)) return _peers[peerId]!;
    final pc = await createPeerConnection(_iceServers);
    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        await pc.addTrack(track, _localStream!);
      }
    }
    pc.onIceCandidate = (c) {
      if (c.candidate != null) {
        _iceController.add({
          'peerId': peerId,
          'candidate': c.candidate,
          'sdpMid': c.sdpMid,
          'sdpMLineIndex': c.sdpMLineIndex,
        });
      }
    };
    pc.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteStreams[peerId] = event.streams.first;
      }
    };
    _peers[peerId] = pc;

    // Flush queued ICE for this peer
    final pending = _pendingIce.remove(peerId) ?? [];
    for (final c in pending) {
      try {
        await pc.addCandidate(c);
      } catch (_) {}
    }
    return pc;
  }

  Future<RTCSessionDescription> createOffer(String peerId) async {
    final pc = await _createPc(peerId);
    final offer = await pc.createOffer({'offerToReceiveAudio': 1});
    await pc.setLocalDescription(offer);
    return offer;
  }

  Future<RTCSessionDescription> createAnswer(
    String peerId,
    RTCSessionDescription remoteOffer,
  ) async {
    final pc = await _createPc(peerId);
    await pc.setRemoteDescription(remoteOffer);
    final answer = await pc.createAnswer({'offerToReceiveAudio': 1});
    await pc.setLocalDescription(answer);
    return answer;
  }

  Future<void> setRemoteAnswer(String peerId, RTCSessionDescription answer) async {
    final pc = _peers[peerId] ?? await _createPc(peerId);
    await pc.setRemoteDescription(answer);
  }

  Future<void> addIceCandidate(String peerId, RTCIceCandidate candidate) async {
    final pc = _peers[peerId];
    if (pc == null) {
      (_pendingIce[peerId] ??= []).add(candidate);
      return;
    }
    await pc.addCandidate(candidate);
  }

  Future<void> setMuted(bool muted) async {
    _muted = muted;
    _localStream?.getAudioTracks().forEach((t) {
      t.enabled = !muted;
    });
  }

  Future<void> setSpeaker(bool on) async {
    _speaker = on;
    try {
      await Helper.setSpeakerphoneOn(on);
    } catch (_) {}
  }

  Future<void> hangUp() async {
    for (final pc in _peers.values) {
      await pc.close();
    }
    _peers.clear();
    _remoteStreams.clear();
    _pendingIce.clear();
    await _localStream?.dispose();
    _localStream = null;
  }

  void dispose() {
    hangUp();
    if (!_iceController.isClosed) _iceController.close();
  }
}
