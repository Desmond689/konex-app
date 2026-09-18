import 'package:equatable/equatable.dart';

class LfgEntity extends Equatable {
  const LfgEntity({
    required this.postId,
    required this.gameName,
    this.mode,
    this.rankRequirement,
    this.platform,
    this.region = 'CM',
    this.micRequired = false,
    this.playersNeeded = 1,
    this.status = 'open',
    this.body,
    this.authorId,
    this.authorName,
    this.createdAt,
  });

  final String postId;
  final String gameName;
  final String? mode;
  final String? rankRequirement;
  final String? platform;
  final String region;
  final bool micRequired;
  final int playersNeeded;
  final String status;
  final String? body;
  final String? authorId;
  final String? authorName;
  final DateTime? createdAt;

  bool get isOpen => status == 'open';

  @override
  List<Object?> get props => [postId, status, playersNeeded];
}

class PollEntity extends Equatable {
  const PollEntity({
    required this.id,
    required this.postId,
    required this.question,
    required this.options,
    this.endsAt,
    this.allowChangeVote = false,
    this.myOptionId,
  });

  final String id;
  final String postId;
  final String question;
  final List<PollOptionEntity> options;
  final DateTime? endsAt;
  final bool allowChangeVote;
  final String? myOptionId;

  bool get isClosed => endsAt != null && DateTime.now().isAfter(endsAt!);

  @override
  List<Object?> get props => [id, myOptionId, options];
}

class PollOptionEntity extends Equatable {
  const PollOptionEntity({
    required this.id,
    required this.label,
    this.voteCount = 0,
    this.position = 0,
  });

  final String id;
  final String label;
  final int voteCount;
  final int position;

  @override
  List<Object?> get props => [id, voteCount];
}

class BadgeEntity extends Equatable {
  const BadgeEntity({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    this.iconUrl,
  });

  final String id;
  final String code;
  final String name;
  final String? description;
  final String? iconUrl;

  @override
  List<Object?> get props => [id, code];
}
