import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/constants.dart';
import '../../../../core/config/dependency_injection.dart';
import '../../domain/call_entity.dart';
import '../screens/incoming_call_screen.dart';
import '../screens/in_call_screen.dart';
import '../screens/outgoing_call_screen.dart';
import '../services/call_signaling_service.dart';
import '../services/webrtc_service.dart';
import '../../../../core/errors/error_handler.dart';

final callControllerProvider =
    StateNotifierProvider<CallController, CallState>((ref) {
  return CallController(ref.watch(supabaseClientProvider));
});

class CallState {
  const CallState({
    this.phase = CallUiPhase.idle,
    this.call,
    this.error,
    this.muted = false,
    this.speaker = true,
  });

  final CallUiPhase phase;
  final CallEntity? call;
  final String? error;
  final bool muted;
  final bool speaker;

  CallState copyWith({
    CallUiPhase? phase,
    CallEntity? call,
    String? error,
    bool? muted,
    bool? speaker,
    bool clearCall = false,
  }) =>
      CallState(
        phase: phase ?? this.phase,
        call: clearCall ? null : (call ?? this.call),
        error: error,
        muted: muted ?? this.muted,
        speaker: speaker ?? this.speaker,
      );
}

class CallController extends StateNotifier<CallState> {
  CallController(this._client) : super(const CallState()) {
    _webrtc = WebRtcService();
    _signaling = CallSignalingService(_client, _webrtc);
    _listenIncoming();
  }

  final SupabaseClient _client;
  late final WebRtcService _webrtc;
  late final CallSignalingService _signaling;
  RealtimeChannel? _inboxChannel;
  GlobalKey<NavigatorState>? navigatorKey;
  Timer? _durationTimer;
  DateTime? _connectedAt;
  StreamSubscription? _meshSub;

  /// Mesh call wiring for group (squad) calls: whenever a peer announces
  /// they're ready, the side with the higher UUID sends the offer (glare
  /// avoidance) so every pair in the call ends up with a peer connection.
  ///
  /// Previously this was only ever set up inside [startSquadCall], so a
  /// participant who *joined* an existing call via [acceptIncoming] instead
  /// of starting it never listened for peer-ready at all. Two people who
  /// both joined (neither one started the call) would never exchange
  /// offers with each other — their audio just never connected. Calling
  /// this from both start and accept paths fixes that. The previous
  /// subscription is also cancelled first: without that, starting or
  /// joining a second call while this controller is alive stacked a new
  /// listener on top of the old one, sending duplicate/stale offers.
  void _wireMeshOffering() {
    _meshSub?.cancel();
    _meshSub = _signaling.events.listen((e) async {
      if (e['type'] != 'peer-ready') return;
      final peerId = e['from'] as String?;
      final me = _client.auth.currentUser?.id;
      if (peerId == null || me == null || peerId == me) return;
      if (me.compareTo(peerId) > 0) {
        try {
          final offer = await _webrtc.createOffer(peerId);
          await _signaling.sendOffer(peerId, offer);
        } catch (_) {}
      }
    });
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _connectedAt ??= DateTime.now();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      // Keep timer alive so duration can be read via connectedAt
      if (_connectedAt == null) {
        _durationTimer?.cancel();
        _durationTimer = null;
      }
    });
  }

  void _stopDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = null;
    _connectedAt = null;
  }

  Future<bool> _ensureMic() async {
    final s = await Permission.microphone.request();
    return s.isGranted;
  }

  void _listenIncoming() {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    _inboxChannel = _client
        .channel('user-calls:$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'call_participants',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: uid,
          ),
          callback: (payload) async {
            final row = payload.newRecord;
            if (row['status'] == 'ringing' || row['status'] == 'invited') {
              final callId = row['call_id'] as String;
              await _onIncoming(callId);
            }
          },
        )
        .subscribe();
  }

  Future<void> _onIncoming(String callId) async {
    if (state.phase != CallUiPhase.idle) return;
    final row = await _client.from('calls').select().eq('id', callId).maybeSingle();
    if (row == null) return;
    final call = await _hydrate(CallEntity.fromMap(Map<String, dynamic>.from(row)));
    state = state.copyWith(phase: CallUiPhase.incoming, call: call);
    final nav = navigatorKey?.currentState;
    if (nav != null) {
      nav.push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => IncomingCallScreen(call: call),
        ),
      );
    }
  }

  Future<CallEntity> _hydrate(CallEntity base) async {
    String? peerId;
    String? peerName;
    String? peerAvatar;
    String? squadName;
    if (base.callType == 'dm') {
      final others = await _client
          .from('call_participants')
          .select('user_id, profiles!call_participants_user_id_fkey(username,gamer_name,avatar_url)')
          .eq('call_id', base.id)
          .neq('user_id', _client.auth.currentUser!.id)
          .limit(1)
          .maybeSingle();
      if (others != null) {
        peerId = others['user_id'] as String?;
        final p = others['profiles'] as Map<String, dynamic>?;
        peerName = p?['gamer_name'] as String? ?? p?['username'] as String?;
        peerAvatar = p?['avatar_url'] as String?;
      }
    } else if (base.squadId != null) {
      final s = await _client
          .from('squads')
          .select('name')
          .eq('id', base.squadId!)
          .maybeSingle();
      squadName = s?['name'] as String?;
    }
    return CallEntity(
      id: base.id,
      callType: base.callType,
      initiatorId: base.initiatorId,
      status: base.status,
      conversationId: base.conversationId,
      squadId: base.squadId,
      maxParticipants: base.maxParticipants,
      startedAt: base.startedAt,
      peerUserId: peerId,
      peerName: peerName,
      peerAvatar: peerAvatar,
      squadName: squadName,
    );
  }

  Future<void> startDmCall({
    required String conversationId,
    required String calleeId,
    required String calleeName,
    String? calleeAvatar,
  }) async {
    if (!await _ensureMic()) {
      state = state.copyWith(error: 'Microphone permission required');
      return;
    }
    try {
      final id = await _client.rpc('initiate_dm_call', params: {
        'p_conversation_id': conversationId,
        'p_callee_id': calleeId,
      });
      final call = CallEntity(
        id: id as String,
        callType: 'dm',
        initiatorId: _client.auth.currentUser!.id,
        status: 'ringing',
        conversationId: conversationId,
        maxParticipants: 2,
        peerUserId: calleeId,
        peerName: calleeName,
        peerAvatar: calleeAvatar,
      );
      state = state.copyWith(phase: CallUiPhase.outgoing, call: call);
      await _webrtc.initLocalAudio();
      await _signaling.joinCallChannel(call.id);

      navigatorKey?.currentState?.push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => OutgoingCallScreen(call: call),
        ),
      );

      // Wait until callee joins channel (Accept) before sending offer — avoids lost SDP
      try {
        await _signaling.waitForPeer(calleeId, timeout: const Duration(seconds: 60));
        final offer = await _webrtc.createOffer(calleeId);
        await _signaling.sendOffer(calleeId, offer);
        state = state.copyWith(phase: CallUiPhase.connected);
        navigatorKey?.currentState?.pushReplacement(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => InCallScreen(call: call),
          ),
        );
      } catch (_) {
        // timeout or cancelled — leave hangup to user cancel
      }
    } catch (e) {
      state = state.copyWith(error: ErrorHandler.userMessage(e), phase: CallUiPhase.idle);
    }
  }

  Future<void> startSquadCall({
    required String squadId,
    String? conversationId,
    String? squadName,
  }) async {
    if (!await _ensureMic()) {
      state = state.copyWith(error: 'Microphone permission required');
      return;
    }
    try {
      final id = await _client.rpc('initiate_squad_call', params: {
        'p_squad_id': squadId,
        if (conversationId != null) 'p_conversation_id': conversationId,
      });
      final call = CallEntity(
        id: id as String,
        callType: 'squad',
        initiatorId: _client.auth.currentUser!.id,
        status: 'active',
        squadId: squadId,
        conversationId: conversationId,
        maxParticipants: AppConstants.maxCallParticipants,
        squadName: squadName,
      );
      state = state.copyWith(phase: CallUiPhase.connected, call: call);
      await _webrtc.initLocalAudio();
      await _signaling.joinCallChannel(call.id);
      _startDurationTimer();
      navigatorKey?.currentState?.push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => InCallScreen(call: call),
        ),
      );
      _wireMeshOffering();
    } catch (e) {
      state = state.copyWith(error: ErrorHandler.userMessage(e), phase: CallUiPhase.idle);
    }
  }


  /// App opened from FCM / local notification while killed or backgrounded.
  Future<void> handleIncomingFromPush(String callId) async {
    if (state.phase != CallUiPhase.idle && state.call?.id == callId) return;
    try {
      final row = await _client.from('calls').select().eq('id', callId).maybeSingle();
      if (row == null) return;
      final status = row['status'] as String?;
      if (status != null && status != 'ringing' && status != 'active') return;
      final call = await _hydrate(CallEntity.fromMap(Map<String, dynamic>.from(row)));
      state = state.copyWith(phase: CallUiPhase.incoming, call: call);
      navigatorKey?.currentState?.push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => IncomingCallScreen(call: call),
        ),
      );
    } catch (e) {
      state = state.copyWith(error: ErrorHandler.userMessage(e));
    }
  }

  Future<void> acceptIncoming() async {
    final call = state.call;
    if (call == null) return;
    if (!await _ensureMic()) return;
    await _client.rpc('answer_call', params: {'p_call_id': call.id});
    await _webrtc.initLocalAudio();
    await _signaling.joinCallChannel(call.id);
    // For DM, the caller sends the offer once it sees our peer-ready
    // broadcast; joinCallChannel already announces that. For a squad
    // (group) call there can be other members who *also* joined rather
    // than started the call, so this side needs the same mesh-offering
    // logic the initiator uses, or those pairs never connect.
    if (call.callType == 'squad') _wireMeshOffering();
    state = state.copyWith(phase: CallUiPhase.connected);
    _startDurationTimer();
    navigatorKey?.currentState?.pushReplacement(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => InCallScreen(call: call),
      ),
    );
  }

  Future<void> declineIncoming() async {
    final call = state.call;
    if (call == null) return;
    await _client.rpc('decline_call', params: {'p_call_id': call.id});
    await _cleanup();
    navigatorKey?.currentState?.pop();
  }

  Future<void> cancelOutgoing() async {
    final call = state.call;
    if (call != null) {
      await _client.rpc('leave_or_end_call', params: {'p_call_id': call.id});
    }
    await _cleanup();
    navigatorKey?.currentState?.pop();
  }

  Future<void> hangUp() async {
    final call = state.call;
    if (call != null) {
      await _client.rpc('leave_or_end_call', params: {'p_call_id': call.id});
    }
    await _cleanup();
    navigatorKey?.currentState?.pop();
  }

  Future<void> toggleMute() async {
    final next = !state.muted;
    await _webrtc.setMuted(next);
    state = state.copyWith(muted: next);
  }

  Future<void> toggleSpeaker() async {
    final next = !state.speaker;
    await _webrtc.setSpeaker(next);
    state = state.copyWith(speaker: next);
  }

  Future<void> _cleanup() async {
    await _meshSub?.cancel();
    _meshSub = null;
    await _signaling.leave();
    await _webrtc.hangUp();
    state = const CallState();
    _stopDurationTimer();
  }

  @override
  void dispose() {
    _stopDurationTimer();
    _meshSub?.cancel();
    _inboxChannel?.unsubscribe();
    _signaling.dispose();
    _webrtc.dispose();
    super.dispose();
  }
}
