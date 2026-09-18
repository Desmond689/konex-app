import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/result.dart';
import '../../../core/network/base_repository.dart';
import '../domain/community_entity.dart';

class CommunityRepository with BaseRepository {
  CommunityRepository(this._client);
  final SupabaseClient _client;

  String get _uid {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('Not authenticated');
    return id;
  }

  static const _cols = '''
    id, name, slug, game_name, description, rules, avatar_url, banner_url,
    category, platforms, primary_region, is_official, is_private,
    require_approval, member_count, is_archived
  ''';

  Future<Result<List<CommunityEntity>>> listDiscover({String? query}) =>
      guard(() async {
        var q = _client
            .from('communities')
            .select(_cols)
            .eq('is_private', false)
            .eq('is_archived', false);
        if (query != null && query.trim().isNotEmpty) {
          q = q.or(
            'name.ilike.%${query.trim()}%,game_name.ilike.%${query.trim()}%',
          );
        }
        // Communities with the most members always show first; name breaks ties
        // so the order stays stable for newly-added games that start at 0.
        final rows = await q
            .order('member_count', ascending: false)
            .order('name', ascending: true)
            .limit(50);
        final out = <CommunityEntity>[];
        for (final r in rows as List) {
          out.add(await _enrich(Map<String, dynamic>.from(r as Map)));
        }
        return out;
      });

  /// Official public games available at signup (no fake rows — only DB content).
  Future<Result<List<CommunityEntity>>> listOfficialGames() => guard(() async {
        final rows = await _client
            .from('communities')
            .select(_cols)
            .eq('is_official', true)
            .eq('is_private', false)
            .eq('is_archived', false)
            .order('name');
        return (rows as List)
            .map((r) => CommunityEntity.fromMap(Map<String, dynamic>.from(r as Map)))
            .toList();
      });

  Future<Result<List<CommunityEntity>>> myCommunities() => guard(() async {
        final memberships = await _client
            .from('community_members')
            .select('community_id, role, status')
            .eq('user_id', _uid)
            .eq('status', 'active');
        final out = <CommunityEntity>[];
        for (final m in memberships as List) {
          final row = await _client
              .from('communities')
              .select(_cols)
              .eq('id', m['community_id'])
              .eq('is_archived', false)
              .maybeSingle();
          if (row == null) continue;
          out.add(CommunityEntity.fromMap(
            Map<String, dynamic>.from(row),
            isMember: true,
            myRole: m['role'] as String?,
            myStatus: m['status'] as String?,
          ));
        }
        return out;
      });

  Future<Result<CommunityEntity>> getById(String id) => guard(() async {
        final row = await _client
            .from('communities')
            .select(_cols)
            .eq('id', id)
            .eq('is_archived', false)
            .single();
        return _enrich(Map<String, dynamic>.from(row));
      });

  Future<Result<void>> join(String communityId) => guard(() async {
        await _client.rpc('join_game_community', params: {
          'p_community_id': communityId,
        });
      });

  /// Join many official games (onboarding). Skips failures per id.
  Future<Result<void>> joinMany(List<String> communityIds) => guard(() async {
        for (final id in communityIds) {
          try {
            await _client.rpc('join_game_community', params: {
              'p_community_id': id,
            });
          } catch (_) {
            // skip banned / missing
          }
        }
      });

  Future<Result<void>> leave(String communityId) => guard(() async {
        await _client.rpc('leave_game_community', params: {
          'p_community_id': communityId,
        });
      });

  Future<Result<List<Map<String, dynamic>>>> posts(String communityId) =>
      guard(() async {
        final rows = await _client
            .from('posts')
            .select('''
              id, body, post_type, is_announcement, created_at, like_count, comment_count,
              author_id, profiles!posts_author_id_fkey ( username, gamer_name, avatar_url )
            ''')
            .eq('community_id', communityId)
            .eq('is_deleted', false)
            .order('is_announcement', ascending: false)
            .order('created_at', ascending: false)
            .limit(40);
        return (rows as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
      });

  Future<Result<void>> createPost({
    required String communityId,
    required String body,
    bool announcement = false,
  }) =>
      guard(() async {
        final mem = await _client
            .from('community_members')
            .select('role, status')
            .eq('community_id', communityId)
            .eq('user_id', _uid)
            .maybeSingle();
        if (mem == null || mem['status'] != 'active') {
          throw StateError('Join this community to post');
        }
        if (announcement) {
          final role = mem['role'] as String?;
          if (role != 'moderator' && role != 'admin') {
            // platform staff also allowed via app_role check optional
            final profile = await _client
                .from('profiles')
                .select('app_role')
                .eq('id', _uid)
                .maybeSingle();
            final appRole = profile?['app_role'] as String? ?? 'user';
            if (appRole != 'admin' && appRole != 'super_admin' && appRole != 'moderator') {
              throw StateError('Only moderators/admins can announce');
            }
          }
        }
        await _client.from('posts').insert({
          'author_id': _uid,
          'body': body.trim(),
          'post_type': 'text',
          'visibility': 'public',
          'community_id': communityId,
          'is_announcement': announcement,
        });
      });

  Future<Result<List<Map<String, dynamic>>>> members(String communityId) =>
      guard(() async {
        final rows = await _client
            .from('community_members')
            .select('''
              user_id, role, status, joined_at,
              profiles!community_members_user_id_fkey ( username, gamer_name, avatar_url )
            ''')
            .eq('community_id', communityId)
            .eq('status', 'active')
            .order('joined_at')
            .limit(100);
        return (rows as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
      });

  Future<Result<List<Map<String, dynamic>>>> squadsForGame(String communityId) =>
      guard(() async {
        final rows = await _client
            .from('squads')
            .select('id, name, member_count, is_public, primary_game, logo_url')
            .eq('community_id', communityId)
            .eq('is_deleted', false)
            .eq('is_public', true)
            .order('member_count', ascending: false)
            .limit(20);
        return (rows as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
      });

  /// Staff: create game (= community).
  Future<Result<String>> adminCreateGame({
    required String name,
    String? description,
    String? rules,
    String? category,
    List<String> platforms = const [],
    String? avatarUrl,
  }) =>
      guard(() async {
        final slug = name
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
            .replaceAll(RegExp(r'^-|-$'), '');
        final id = await _client.rpc('admin_create_game', params: {
          'p_name': name.trim(),
          'p_slug': '$slug-${DateTime.now().millisecondsSinceEpoch % 10000}',
          'p_description': description,
          'p_rules': rules,
          'p_category': category,
          'p_platforms': platforms,
        });
        // The create RPC doesn't take a logo (it predates logo uploads) —
        // set it as a follow-up update so callers can still create a
        // fully-branded community in one screen.
        if (avatarUrl != null && avatarUrl.isNotEmpty) {
          await _client.rpc('admin_update_game', params: {
            'p_community_id': id,
            'p_avatar_url': avatarUrl,
          });
        }
        return id as String;
      });

  /// Staff: upload a logo image for a game/community. Returns the public URL —
  /// pass it to [adminUpdateGame] (or the create flow) as `avatarUrl`.
  Future<Result<String>> uploadLogo(String filePath) => guard(() async {
        final file = File(filePath);
        if (!file.existsSync()) {
          throw StateError('File not found');
        }
        final ext = filePath.split('.').last.toLowerCase();
        const allowed = {'jpg', 'jpeg', 'png', 'gif', 'webp'};
        if (!allowed.contains(ext)) {
          throw StateError('Unsupported image format. Use JPG, PNG, GIF, or WebP.');
        }
        final fileName =
            'community_logo_${_uid}_${DateTime.now().millisecondsSinceEpoch}.$ext';
        final bytes = await file.readAsBytes();
        await _client.storage.from('community-logos').uploadBinary(
              fileName,
              bytes,
              fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
            );
        return _client.storage.from('community-logos').getPublicUrl(fileName);
      });

  /// Staff: edit an existing game/community (name, description, rules,
  /// category, platforms, logo/banner, region, privacy). Every field is
  /// optional — only what's passed gets changed.
  Future<Result<void>> adminUpdateGame({
    required String communityId,
    String? name,
    String? description,
    String? rules,
    String? category,
    List<String>? platforms,
    String? avatarUrl,
    String? bannerUrl,
    String? primaryRegion,
    bool? isPrivate,
    bool? requireApproval,
  }) =>
      guard(() async {
        await _client.rpc('admin_update_game', params: {
          'p_community_id': communityId,
          'p_name': name,
          'p_description': description,
          'p_rules': rules,
          'p_category': category,
          'p_platforms': platforms,
          'p_avatar_url': avatarUrl,
          'p_banner_url': bannerUrl,
          'p_primary_region': primaryRegion,
          'p_is_private': isPrivate,
          'p_require_approval': requireApproval,
        });
      });

  /// Staff: every game/community (official or not), for the "Manage games"
  /// admin screen. Highest member count first, same ordering as Discover.
  Future<Result<List<CommunityEntity>>> adminListAllGames({String? query}) =>
      guard(() async {
        var q = _client.from('communities').select(_cols).eq('is_archived', false);
        if (query != null && query.trim().isNotEmpty) {
          q = q.or(
            'name.ilike.%${query.trim()}%,game_name.ilike.%${query.trim()}%',
          );
        }
        final rows = await q
            .order('member_count', ascending: false)
            .order('name', ascending: true)
            .limit(300);
        return (rows as List)
            .map((r) => CommunityEntity.fromMap(Map<String, dynamic>.from(r as Map)))
            .toList();
      });

  Future<CommunityEntity> _enrich(Map<String, dynamic> m) async {
    final mem = await _client
        .from('community_members')
        .select('role, status')
        .eq('community_id', m['id'])
        .eq('user_id', _uid)
        .maybeSingle();
    return CommunityEntity.fromMap(
      m,
      isMember: mem?['status'] == 'active',
      myRole: mem?['role'] as String?,
      myStatus: mem?['status'] as String?,
    );
  }
}
