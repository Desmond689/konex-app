import 'package:equatable/equatable.dart';

class NotificationEntity extends Equatable {
  const NotificationEntity({
    required this.id,
    required this.type,
    required this.title,
    this.body,
    this.actorId,
    this.targetType,
    this.targetId,
    this.isRead = false,
    required this.createdAt,
    this.category = 'social',
    this.groupKey,
    this.actorCount = 1,
    this.actorAvatarUrl,
    this.actorUsername,
  });

  final String id;
  final String type;
  final String title;
  final String? body;
  final String? actorId;
  final String? targetType;
  final String? targetId;
  final bool isRead;
  final DateTime createdAt;
  final String category;
  final String? groupKey;
  final int actorCount;
  final String? actorAvatarUrl;
  final String? actorUsername;

  String get displayTitle {
    if (actorCount <= 1) return title;
    final name = actorUsername ?? 'Someone';
    final others = actorCount - 1;
    if (type == 'like') {
      return others == 1
          ? '$name and 1 other liked your post'
          : '$name and $others others liked your post';
    }
    if (type == 'comment') {
      return others == 1
          ? '$name and 1 other commented on your post'
          : '$name and $others others commented on your post';
    }
    return title;
  }

  factory NotificationEntity.fromMap(Map<String, dynamic> m) {
    final actor = m['profiles'] as Map<String, dynamic>?;
    return NotificationEntity(
      id: m['id'] as String,
      type: m['type'] as String? ?? 'system',
      title: m['title'] as String? ?? '',
      body: m['body'] as String?,
      actorId: m['actor_id'] as String?,
      targetType: m['target_type'] as String?,
      targetId: m['target_id'] as String?,
      isRead: m['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(m['created_at'] as String),
      category: m['category'] as String? ?? 'social',
      groupKey: m['group_key'] as String?,
      actorCount: m['actor_count'] as int? ?? 1,
      actorAvatarUrl: actor?['avatar_url'] as String?,
      actorUsername:
          actor?['username'] as String? ?? actor?['gamer_name'] as String?,
    );
  }

  @override
  List<Object?> get props => [id, isRead, actorCount];
}

class NotificationPreferences extends Equatable {
  const NotificationPreferences({
    this.likes = true,
    this.comments = true,
    this.replies = true,
    this.follows = true,
    this.mentions = true,
    this.reposts = true,
    this.messages = true,
    this.squads = true,
    this.communities = true,
    this.lfg = true,
    this.security = true,
    this.marketing = false,
    this.quietUntil,
    this.whoCanMessage = 'everyone',
  });

  final bool likes;
  final bool comments;
  final bool replies;
  final bool follows;
  final bool mentions;
  final bool reposts;
  final bool messages;
  final bool squads;
  final bool communities;
  final bool lfg;
  final bool security;
  final bool marketing;
  final DateTime? quietUntil;
  final String whoCanMessage;

  factory NotificationPreferences.fromMap(Map<String, dynamic>? m) {
    if (m == null) return const NotificationPreferences();
    return NotificationPreferences(
      likes: m['likes'] as bool? ?? true,
      comments: m['comments'] as bool? ?? true,
      replies: m['replies'] as bool? ?? true,
      follows: m['follows'] as bool? ?? true,
      mentions: m['mentions'] as bool? ?? true,
      reposts: m['reposts'] as bool? ?? true,
      messages: m['messages'] as bool? ?? true,
      squads: m['squads'] as bool? ?? true,
      communities: m['communities'] as bool? ?? true,
      lfg: m['lfg'] as bool? ?? true,
      security: m['security'] as bool? ?? true,
      marketing: m['marketing'] as bool? ?? false,
      quietUntil: m['quiet_until'] != null
          ? DateTime.tryParse(m['quiet_until'] as String)
          : null,
      whoCanMessage: m['who_can_message'] as String? ?? 'everyone',
    );
  }

  Map<String, dynamic> toMap(String userId) => {
        'user_id': userId,
        'likes': likes,
        'comments': comments,
        'replies': replies,
        'follows': follows,
        'mentions': mentions,
        'reposts': reposts,
        'messages': messages,
        'squads': squads,
        'communities': communities,
        'lfg': lfg,
        'security': true,
        'marketing': marketing,
        'quiet_until': quietUntil?.toIso8601String(),
        'who_can_message': whoCanMessage,
        'updated_at': DateTime.now().toIso8601String(),
      };

  NotificationPreferences copyWith({
    bool? likes,
    bool? comments,
    bool? replies,
    bool? follows,
    bool? mentions,
    bool? reposts,
    bool? messages,
    bool? squads,
    bool? communities,
    bool? lfg,
    bool? marketing,
    DateTime? quietUntil,
    bool clearQuiet = false,
    String? whoCanMessage,
  }) =>
      NotificationPreferences(
        likes: likes ?? this.likes,
        comments: comments ?? this.comments,
        replies: replies ?? this.replies,
        follows: follows ?? this.follows,
        mentions: mentions ?? this.mentions,
        reposts: reposts ?? this.reposts,
        messages: messages ?? this.messages,
        squads: squads ?? this.squads,
        communities: communities ?? this.communities,
        lfg: lfg ?? this.lfg,
        security: true,
        marketing: marketing ?? this.marketing,
        quietUntil: clearQuiet ? null : (quietUntil ?? this.quietUntil),
        whoCanMessage: whoCanMessage ?? this.whoCanMessage,
      );

  @override
  List<Object?> get props => [likes, comments, quietUntil, whoCanMessage];
}
