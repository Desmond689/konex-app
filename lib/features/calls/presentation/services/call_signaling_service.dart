import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'webrtc_service.dart';

/// Signaling over Supabase Realtime broadcast channel `call:{callId}`.
///
/// Protocol:
/// - `peer-ready` — participant joined channel and is ready for SDP
/// - `offer` / `answer` / `ice` — classic WebRTC
/// Caller does NOT send offer until it sees `peer-ready` from callee (fixes race).
class CallSignalingService {
  CallSignalingService(this._client, this._webrtc);
  final SupabaseClient _client;
  final WebRtcService _webrtc;

  RealtimeChannel? _channel;
  String? _myId;
  final _readyPeers = <String>{};

  final _events = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get events => _events.stream;

  StreamSubscription? _iceSub;

  Future<void> joinCallChannel(String callId) async {
    _myId = _client.auth.currentUser?.id;
    await leave();
    _readyPeers.clear();

    _channel = _client.channel('call:$callId');
    _channel!
        .onBroadcast(
          event: 'signal',
          callback: (payload) {
            final data = Map<String, dynamic>.from(payload);
            final to = data['to'] as String?;
            final from = data['from'] as String?;
            if (from == _myId) return;
            // Directed messages: only process if to is null (broadcast) or me
            if (to != null && to != _myId) return;
            _handleSignal(data);
          },
        )
        .subscribe((status, [err]) async {
          if (status == RealtimeSubscribeStatus.subscribed) {
            // Announce readiness so callers can offer
            await _send({
              'type': 'peer-ready',
              'from': _myId,
            });
          }
        });

    _iceSub = _webrtc.onIceCandidate.listen((ice) {
      final peerId = ice['peerId'] as String?;
      if (peerId == null) return;
      _send({
        'type': 'ice',
        'from': _myId,
        'to': peerId,
        'candidate': ice['candidate'],
        'sdpMid': ice['sdpMid'],
        'sdpMLineIndex': ice['sdpMLineIndex'],
      });
    });
  }

  bool isPeerReady(String userId) => _readyPeers.contains(userId);

  Future<void> waitForPeer(String userId, {Duration timeout = const Duration(seconds: 45)}) async {
    if (_readyPeers.contains(userId)) return;
    final completer = Completer<void>();
    late StreamSubscription sub;
    sub = _events.stream.listen((e) {
      if (e['type'] == 'peer-ready' && e['from'] == userId) {
        if (!completer.isCompleted) completer.complete();
      }
    });
    try {
      await completer.future.timeout(timeout);
    } finally {
      await sub.cancel();
    }
  }

  Future<void> _send(Map<String, dynamic> payload) async {
    if (_channel == null) return;
    await _channel!.sendBroadcastMessage(event: 'signal', payload: payload);
  }

  Future<void> sendOffer(String toUserId, RTCSessionDescription offer) async {
    await _send({
      'type': 'offer',
      'from': _myId,
      'to': toUserId,
      'sdp': offer.sdp,
      'sdpType': offer.type,
    });
  }

  Future<void> sendAnswer(String toUserId, RTCSessionDescription answer) async {
    await _send({
      'type': 'answer',
      'from': _myId,
      'to': toUserId,
      'sdp': answer.sdp,
      'sdpType': answer.type,
    });
  }

  Future<void> _handleSignal(Map<String, dynamic> data) async {
    final type = data['type'] as String?;
    final from = data['from'] as String?;
    if (type == null || from == null) return;

    if (type == 'peer-ready') {
      _readyPeers.add(from);
      _events.add(data);
      return;
    }

    if (type == 'offer') {
      final offer = RTCSessionDescription(
        data['sdp'] as String?,
        data['sdpType'] as String?,
      );
      final answer = await _webrtc.createAnswer(from, offer);
      await sendAnswer(from, answer);
      _events.add({'type': 'connected', 'peerId': from});
    } else if (type == 'answer') {
      final answer = RTCSessionDescription(
        data['sdp'] as String?,
        data['sdpType'] as String?,
      );
      await _webrtc.setRemoteAnswer(from, answer);
      _events.add({'type': 'connected', 'peerId': from});
    } else if (type == 'ice') {
      await _webrtc.addIceCandidate(
        from,
        RTCIceCandidate(
          data['candidate'] as String?,
          data['sdpMid'] as String?,
          data['sdpMLineIndex'] as int?,
        ),
      );
    }
    _events.add(data);
  }

  Future<void> leave() async {
    await _iceSub?.cancel();
    _iceSub = null;
    if (_channel != null) {
      try {
        await _client.removeChannel(_channel!);
      } catch (_) {}
      _channel = null;
    }
  }

  void dispose() {
    leave();
    if (!_events.isClosed) _events.close();
  }
}
