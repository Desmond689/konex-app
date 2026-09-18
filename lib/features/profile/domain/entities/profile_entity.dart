import 'package:equatable/equatable.dart';

class ProfileEntity extends Equatable {
  const ProfileEntity({
    required this.id,
    required this.username,
    this.gamerName,
    this.email,
    this.phone,
    this.avatarUrl,
    this.bannerUrl,
    this.bio,
    this.country,
    this.playerType,
    this.onboardingCompleted = false,
    this.isBanned = false,
    this.followerCount = 0,
    this.followingCount = 0,
    this.reputation,
    this.isFollowing = false,
    this.isBlocked = false,
    this.games = const [],
    this.gameCommunityIds = const {},
    this.squadId,
    this.squadName,
    this.squadRole,
    this.squadMemberCount,
    this.squadIsPublic = true,
    this.createdAt,
    this.isVerified = false,
    this.isPrivate = false,
    this.badges = const [],
    this.whoCanMessage = 'everyone',
    this.whoCanFollow = 'everyone',
    this.gamesVisibility = 'everyone',
    this.squadVisibility = 'everyone',
    this.lastSeen,
  });

  final String id;
  final String username;
  final String? gamerName;
  final String? email;
  final String? phone;
  final String? avatarUrl;
  final String? bannerUrl;
  final String? bio;
  final String? country;
  final String? playerType;
  final bool onboardingCompleted;
  final bool isBanned;
  final int followerCount;
  final int followingCount;
  // Server-computed (see migration 202608300004_profile_reputation.sql):
  // followers*10 + likes received*2 + comments received*1, kept in sync
  // by DB triggers. Nullable only for rows fetched before that column
  // existed; the UI treats a null the same as 0, never a guess.
  final int? reputation;
  final bool isFollowing;
  final bool isBlocked;
  final List<String> games;
  final Map<String, String> gameCommunityIds;
  final String? squadId;
  final String? squadName;
  final String? squadRole;
  final int? squadMemberCount;
  final bool squadIsPublic;
  final DateTime? createdAt;
  final bool isVerified;
  final bool isPrivate;
  final List<String> badges;
  final String whoCanMessage;
  final String whoCanFollow;
  final String gamesVisibility;
  final String squadVisibility;
  // Server-updated heartbeat (see PresenceService + touch_presence RPC,
  // migration 202608300005_profile_presence.sql). "Online" is derived from
  // this, never hardcoded — a user only shows online if they've actually
  // had the app foregrounded in the last couple of minutes.
  final DateTime? lastSeen;

  bool get isOnline =>
      lastSeen != null && DateTime.now().toUtc().difference(lastSeen!.toUtc()) < const Duration(minutes: 2);

  String get displayName =>
      (gamerName?.isNotEmpty == true) ? gamerName! : username;

  bool get hasSquadTag =>
      squadId != null && squadName != null && squadName!.isNotEmpty;

  /// Viewer is me or follows — for private content gates (client-side aid; RLS still applies).
  bool canViewSensitive(bool viewerIsOwner, bool viewerFollows) {
    if (viewerIsOwner) return true;
    if (!isPrivate) return true;
    return viewerFollows;
  }

  bool showGames(bool viewerIsOwner, bool viewerFollows) {
    if (viewerIsOwner) return true;
    switch (gamesVisibility) {
      case 'only_me':
        return false;
      case 'followers':
        return viewerFollows;
      default:
        return true;
    }
  }

  bool showSquadTag(bool viewerIsOwner, bool viewerFollows) {
    if (!hasSquadTag) return false;
    if (viewerIsOwner) return true;
    if (!squadIsPublic) return false;
    switch (squadVisibility) {
      case 'only_me':
        return false;
      case 'followers':
        return viewerFollows;
      default:
        return true;
    }
  }

  bool canMessage(bool viewerIsOwner, bool viewerFollows) {
    if (viewerIsOwner) return false;
    if (isBlocked) return false;
    switch (whoCanMessage) {
      case 'nobody':
        return false;
      case 'following':
        return viewerFollows;
      default:
        return true;
    }
  }

  bool canFollow(bool viewerIsOwner) {
    if (viewerIsOwner) return false;
    if (isBlocked) return false;
    return whoCanFollow != 'nobody';
  }

  ProfileEntity copyWith({
    String? username,
    String? gamerName,
    String? avatarUrl,
    String? bannerUrl,
    String? bio,
    String? country,
    String? playerType,
    bool? isFollowing,
    bool? isBlocked,
    int? followerCount,
    int? followingCount,
    int? reputation,
    List<String>? games,
    Map<String, String>? gameCommunityIds,
    String? squadId,
    String? squadName,
    String? squadRole,
    int? squadMemberCount,
    bool? squadIsPublic,
    bool? isVerified,
    bool? isPrivate,
    List<String>? badges,
    String? whoCanMessage,
    String? whoCanFollow,
    String? gamesVisibility,
    String? squadVisibility,
  }) {
    return ProfileEntity(
      id: id,
      username: username ?? this.username,
      gamerName: gamerName ?? this.gamerName,
      email: email,
      phone: phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      bio: bio ?? this.bio,
      country: country ?? this.country,
      playerType: playerType ?? this.playerType,
      onboardingCompleted: onboardingCompleted,
      isBanned: isBanned,
      followerCount: followerCount ?? this.followerCount,
      followingCount: followingCount ?? this.followingCount,
      reputation: reputation ?? this.reputation,
      isFollowing: isFollowing ?? this.isFollowing,
      isBlocked: isBlocked ?? this.isBlocked,
      games: games ?? this.games,
      gameCommunityIds: gameCommunityIds ?? this.gameCommunityIds,
      squadId: squadId ?? this.squadId,
      squadName: squadName ?? this.squadName,
      squadRole: squadRole ?? this.squadRole,
      squadMemberCount: squadMemberCount ?? this.squadMemberCount,
      squadIsPublic: squadIsPublic ?? this.squadIsPublic,
      createdAt: createdAt,
      isVerified: isVerified ?? this.isVerified,
      isPrivate: isPrivate ?? this.isPrivate,
      badges: badges ?? this.badges,
      whoCanMessage: whoCanMessage ?? this.whoCanMessage,
      whoCanFollow: whoCanFollow ?? this.whoCanFollow,
      gamesVisibility: gamesVisibility ?? this.gamesVisibility,
      squadVisibility: squadVisibility ?? this.squadVisibility,
      lastSeen: lastSeen,
    );
  }

  factory ProfileEntity.fromMap(
    Map<String, dynamic> map, {
    bool? isFollowing,
    bool? isBlocked,
    List<String>? games,
    Map<String, String>? gameCommunityIds,
    String? squadId,
    String? squadName,
    String? squadRole,
    int? squadMemberCount,
    bool? squadIsPublic,
    List<String>? badges,
    String? whoCanMessage,
    String? whoCanFollow,
    String? gamesVisibility,
    String? squadVisibility,
  }) {
    return ProfileEntity(
      id: map['id'] as String,
      username: map['username'] as String? ?? '',
      gamerName: map['gamer_name'] as String?,
      email: map['email'] as String?,
      phone: map['phone'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      bannerUrl: map['banner_url'] as String?,
      bio: map['bio'] as String?,
      country: map['country'] as String?,
      playerType: map['player_type'] as String?,
      onboardingCompleted: map['onboarding_completed'] as bool? ?? false,
      isBanned: map['is_banned'] as bool? ?? false,
      followerCount: map['follower_count'] as int? ?? 0,
      followingCount: map['following_count'] as int? ?? 0,
      reputation: map['reputation'] as int?,
      isFollowing: isFollowing ?? false,
      isBlocked: isBlocked ?? false,
      games: games ?? const [],
      gameCommunityIds: gameCommunityIds ?? const {},
      squadId: squadId,
      squadName: squadName,
      squadRole: squadRole,
      squadMemberCount: squadMemberCount,
      squadIsPublic: squadIsPublic ?? true,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
      isVerified: map['is_verified'] as bool? ?? false,
      isPrivate: map['is_private'] as bool? ?? false,
      badges: badges ?? const [],
      whoCanMessage: whoCanMessage ?? 'everyone',
      whoCanFollow: whoCanFollow ?? 'everyone',
      gamesVisibility: gamesVisibility ?? 'everyone',
      squadVisibility: squadVisibility ?? 'everyone',
      lastSeen: map['last_seen'] != null
          ? DateTime.tryParse(map['last_seen'] as String)
          : null,
    );
  }

  @override
  List<Object?> get props =>
      [id, username, isPrivate, isVerified, squadId, isFollowing, isBlocked];
}
