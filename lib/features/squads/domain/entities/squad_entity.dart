import 'package:equatable/equatable.dart';

class SquadEntity extends Equatable {
  const SquadEntity({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.logoUrl,
    this.bannerUrl,
    this.rules,
    this.primaryGame,
    this.category,
    this.invitePolicy = 'members',
    this.isPublic = true,
    this.requireApproval = true,
    required this.ownerId,
    this.ownerUsername,
    this.ownerGamerName,
    this.memberCount = 1,
    this.myRole,
    this.myStatus,
    this.isMember = false,
  });

  final String id;
  final String name;
  final String slug;
  final String? description;
  final String? logoUrl;
  final String? bannerUrl;
  final String? rules;
  final String? primaryGame;
  final String? category;
  final String invitePolicy;
  final bool isPublic;
  final bool requireApproval;
  final String ownerId;
  final String? ownerUsername;
  final String? ownerGamerName;
  final int memberCount;
  final String? myRole;
  final String? myStatus;
  final bool isMember;

  bool get isOwner => myRole == 'owner';
  bool get isModerator => myRole == 'moderator' || isOwner;
  bool get isBanned => myStatus == 'banned';
  bool get isPending => myStatus == 'pending';

  String get ownerDisplayName {
    if (ownerGamerName != null && ownerGamerName!.isNotEmpty) return ownerGamerName!;
    return ownerUsername ?? 'Owner';
  }

  factory SquadEntity.fromMap(
    Map<String, dynamic> m, {
    String? myRole,
    String? myStatus,
  }) {
    final owner = m['profiles'] as Map<String, dynamic>?;
    return SquadEntity(
      id: m['id'] as String,
      name: m['name'] as String,
      slug: m['slug'] as String,
      description: m['description'] as String?,
      logoUrl: m['logo_url'] as String?,
      bannerUrl: m['banner_url'] as String?,
      rules: m['rules'] as String?,
      primaryGame: m['primary_game'] as String?,
      category: m['category'] as String?,
      invitePolicy: m['invite_policy'] as String? ?? 'members',
      isPublic: m['is_public'] as bool? ?? true,
      requireApproval: m['require_approval'] as bool? ?? true,
      ownerId: m['owner_id'] as String,
      ownerUsername: owner?['username'] as String?,
      ownerGamerName: owner?['gamer_name'] as String?,
      memberCount: m['member_count'] as int? ?? 0,
      myRole: myRole,
      myStatus: myStatus,
      isMember: myStatus == 'active',
    );
  }

  @override
  List<Object?> get props => [id, myRole, myStatus, memberCount];
}

class SquadMemberEntity extends Equatable {
  const SquadMemberEntity({
    required this.userId,
    required this.username,
    this.gamerName,
    this.avatarUrl,
    this.isVerified = false,
    required this.role,
    required this.status,
    required this.joinedAt,
  });

  final String userId;
  final String username;
  final String? gamerName;
  final String? avatarUrl;
  final bool isVerified;
  final String role;
  final String status;
  final DateTime joinedAt;

  String get displayName =>
      (gamerName != null && gamerName!.isNotEmpty) ? gamerName! : username;

  @override
  List<Object?> get props => [userId, role, status];
}
