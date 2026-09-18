import 'package:equatable/equatable.dart';

class StoryEntity extends Equatable {
  const StoryEntity({
    required this.id,
    required this.userId,
    required this.mediaType,
    this.mediaUrl,
    this.textContent,
    this.backgroundColor,
    required this.privacy,
    this.communityId,
    required this.viewCount,
    required this.createdAt,
    required this.expiresAt,
    this.username,
    this.gamerName,
    this.avatarUrl,
    this.viewedByMe = false,
    this.isLive = false,
  });

  final String id;
  final String userId;
  final String mediaType; // photo | video | text
  final String? mediaUrl;
  final String? textContent;
  final String? backgroundColor;
  final String privacy;
  final String? communityId;
  final int viewCount;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String? username;
  final String? gamerName;
  final String? avatarUrl;
  final bool viewedByMe;
  final bool isLive;

  String get displayName =>
      (gamerName != null && gamerName!.isNotEmpty) ? gamerName! : (username ?? 'User');

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Duration get timeLeft {
    final d = expiresAt.difference(DateTime.now());
    return d.isNegative ? Duration.zero : d;
  }

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  List<Object?> get props => [id, mediaUrl, viewedByMe, viewCount];
}

/// Group of stories belonging to one user (for the horizontal row).
class StoryRing extends Equatable {
  const StoryRing({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    required this.stories,
    this.isMe = false,
    this.lastSeen,
  });

  final String userId;
  final String displayName;
  final String? avatarUrl;
  final List<StoryEntity> stories;
  final bool isMe;
  // Same real heartbeat as ProfileEntity.lastSeen (see PresenceService) —
  // "online" here is never a stored/default flag, only this computed check.
  final DateTime? lastSeen;

  bool get isOnline =>
      lastSeen != null && DateTime.now().toUtc().difference(lastSeen!.toUtc()) < const Duration(minutes: 2);

  bool get hasUnseen => stories.any((s) => !s.viewedByMe);
  bool get hasStories => stories.isNotEmpty;

  @override
  List<Object?> get props => [userId, stories.length, hasUnseen];
}
