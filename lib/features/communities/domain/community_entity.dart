import 'package:equatable/equatable.dart';

/// Game = Community. One user-facing entity.
class CommunityEntity extends Equatable {
  const CommunityEntity({
    required this.id,
    required this.name,
    required this.slug,
    required this.gameName,
    this.description,
    this.rules,
    this.avatarUrl,
    this.bannerUrl,
    this.category,
    this.platforms = const [],
    this.primaryRegion,
    this.isOfficial = false,
    this.isPrivate = false,
    this.requireApproval = false,
    this.memberCount = 0,
    this.isMember = false,
    this.myRole,
    this.myStatus,
  });

  final String id;
  final String name;
  final String slug;
  final String gameName;
  final String? description;
  final String? rules;
  final String? avatarUrl;
  final String? bannerUrl;
  final String? category;
  final List<String> platforms;
  final String? primaryRegion;
  final bool isOfficial;
  final bool isPrivate;
  final bool requireApproval;
  final int memberCount;
  final bool isMember;
  final String? myRole;
  final String? myStatus;

  bool get isModerator =>
      myRole == 'moderator' || myRole == 'admin' || myRole == 'owner';
  bool get isBanned => myStatus == 'banned';

  factory CommunityEntity.fromMap(
    Map<String, dynamic> m, {
    bool isMember = false,
    String? myRole,
    String? myStatus,
  }) {
    final platformsRaw = m['platforms'];
    List<String> platforms = const [];
    if (platformsRaw is List) {
      platforms = platformsRaw.map((e) => e.toString()).toList();
    }
    return CommunityEntity(
      id: m['id'] as String,
      name: m['name'] as String,
      slug: m['slug'] as String,
      gameName: m['game_name'] as String? ?? m['name'] as String,
      description: m['description'] as String?,
      rules: m['rules'] as String?,
      avatarUrl: m['avatar_url'] as String?,
      bannerUrl: m['banner_url'] as String?,
      category: m['category'] as String?,
      platforms: platforms,
      primaryRegion: m['primary_region'] as String?,
      isOfficial: m['is_official'] as bool? ?? false,
      isPrivate: m['is_private'] as bool? ?? false,
      requireApproval: m['require_approval'] as bool? ?? false,
      memberCount: m['member_count'] as int? ?? 0,
      isMember: isMember || myStatus == 'active',
      myRole: myRole,
      myStatus: myStatus,
    );
  }

  @override
  List<Object?> get props => [id, isMember, memberCount];
}
