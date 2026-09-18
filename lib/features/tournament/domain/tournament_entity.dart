import 'package:equatable/equatable.dart';

class TournamentEntity extends Equatable {
  const TournamentEntity({
    required this.id,
    required this.title,
    required this.gameName,
    this.description,
    required this.status,
    this.maxParticipants = 16,
    this.participantCount = 0,
    this.startsAt,
    this.bracketType = 'single_elim',
    this.isEntered = false,
  });

  final String id;
  final String title;
  final String gameName;
  final String? description;
  final String status;
  final int maxParticipants;
  final int participantCount;
  final DateTime? startsAt;
  final String bracketType;
  final bool isEntered;

  bool get isOpen => status == 'open';

  factory TournamentEntity.fromMap(Map<String, dynamic> m, {bool isEntered = false}) {
    return TournamentEntity(
      id: m['id'] as String,
      title: m['title'] as String,
      gameName: m['game_name'] as String,
      description: m['description'] as String?,
      status: m['status'] as String? ?? 'draft',
      maxParticipants: m['max_participants'] as int? ?? 16,
      participantCount: m['participant_count'] as int? ?? 0,
      startsAt: m['starts_at'] != null
          ? DateTime.tryParse(m['starts_at'] as String)
          : null,
      bracketType: m['bracket_type'] as String? ?? 'single_elim',
      isEntered: isEntered,
    );
  }

  @override
  List<Object?> get props => [id, status, participantCount, isEntered];
}
