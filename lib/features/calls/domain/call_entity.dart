import 'package:equatable/equatable.dart';

class CallEntity extends Equatable {
  const CallEntity({
    required this.id,
    required this.callType,
    required this.initiatorId,
    required this.status,
    this.conversationId,
    this.squadId,
    this.maxParticipants = 8,
    this.startedAt,
    this.peerUserId,
    this.peerName,
    this.peerAvatar,
    this.squadName,
  });

  final String id;
  final String callType; // dm | squad
  final String initiatorId;
  final String status;
  final String? conversationId;
  final String? squadId;
  final int maxParticipants;
  final DateTime? startedAt;
  final String? peerUserId;
  final String? peerName;
  final String? peerAvatar;
  final String? squadName;

  factory CallEntity.fromMap(Map<String, dynamic> m) {
    return CallEntity(
      id: m['id'] as String,
      callType: m['call_type'] as String? ?? 'dm',
      initiatorId: m['initiator_id'] as String,
      status: m['status'] as String? ?? 'ringing',
      conversationId: m['conversation_id'] as String?,
      squadId: m['squad_id'] as String?,
      maxParticipants: m['max_participants'] as int? ?? 8,
      startedAt: m['started_at'] != null
          ? DateTime.tryParse(m['started_at'] as String)
          : null,
    );
  }

  @override
  List<Object?> get props => [id, status];
}

enum CallUiPhase { idle, outgoing, incoming, connected }
