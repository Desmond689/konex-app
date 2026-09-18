import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/profile_entity.dart';

class ProfileRemoteDataSource {
  ProfileRemoteDataSource(this._client);
  final SupabaseClient _client;

  String get _uid {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('Not authenticated');
    return id;
  }

  Future<ProfileEntity> getProfile(String userId) async {
    final row = await _client.from('profiles').select().eq('id', userId).single();
    var isFollowing = false;
    var isBlocked = false;
    final me = _client.auth.currentUser?.id;
    if (me != null && me != userId) {
      final follow = await _client
          .from('follows')
          .select()
          .eq('follower_id', me)
          .eq('following_id', userId)
          .maybeSingle();
      isFollowing = follow != null;
      final block = await _client
          .from('blocks')
          .select()
          .eq('blocker_id', me)
          .eq('blocked_id', userId)
          .maybeSingle();
      isBlocked = block != null;
    }

    final gamesData = await _loadGames(userId);
    final squad = await _loadSquadTag(userId);

    final followers = await _client
        .from('follows')
        .select('follower_id')
        .eq('following_id', userId)
        .count(CountOption.exact);
    final following = await _client
        .from('follows')
        .select('following_id')
        .eq('follower_id', userId)
        .count(CountOption.exact);

    final badges = await _loadBadges(userId);
    final privacy = await _loadPrivacy(userId);

    return ProfileEntity.fromMap(
      Map<String, dynamic>.from(row),
      isFollowing: isFollowing,
      isBlocked: isBlocked,
      games: gamesData.$1,
      gameCommunityIds: gamesData.$2,
      squadId: squad?.$1,
      squadName: squad?.$2,
      squadRole: squad?.$3,
      squadMemberCount: squad?.$4,
      squadIsPublic: squad?.$5 ?? true,
      badges: badges,
      whoCanMessage: privacy['who_can_message'] as String? ?? 'everyone',
      whoCanFollow: privacy['who_can_follow'] as String? ?? 'everyone',
      gamesVisibility: privacy['games_visibility'] as String? ?? 'everyone',
      squadVisibility: privacy['squad_visibility'] as String? ?? 'everyone',
    ).copyWith(
      followerCount: followers.count,
      followingCount: following.count,
    );
  }

  Future<List<String>> _loadBadges(String userId) async {
    try {
      final rows = await _client
          .from('user_badges')
          .select('badges ( name, code )')
          .eq('user_id', userId);
      final out = <String>[];
      for (final r in rows as List) {
        final b = r['badges'];
        if (b is Map && b['name'] != null) out.add(b['name'] as String);
      }
      return out;
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>> _loadPrivacy(String userId) async {
    try {
      final row = await _client
          .from('profile_privacy')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      return row == null ? <String, dynamic>{} : Map<String, dynamic>.from(row);
    } catch (_) {
      return {};
    }
  }

  Future<void> savePrivacy({
    required bool isPrivate,
    required String whoCanMessage,
    required String whoCanFollow,
    required String gamesVisibility,
    required String squadVisibility,
  }) async {
    await _client.from('profiles').update({
      'is_private': isPrivate,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', _uid);
    await _client.from('profile_privacy').upsert({
      'user_id': _uid,
      'who_can_message': whoCanMessage,
      'who_can_follow': whoCanFollow,
      'games_visibility': gamesVisibility,
      'squad_visibility': squadVisibility,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> changeUsername(String newUsername) async {
    await _client.rpc('change_username', params: {'p_new': newUsername});
  }

  Future<List<Map<String, dynamic>>> listFollowers(String userId) async {
    final rows = await _client
        .from('follows')
        .select('follower_id, profiles!follows_follower_id_fkey ( id, username, gamer_name, avatar_url )')
        .eq('following_id', userId)
        .limit(100);
    return (rows as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> listFollowing(String userId) async {
    final rows = await _client
        .from('follows')
        .select('following_id, profiles!follows_following_id_fkey ( id, username, gamer_name, avatar_url )')
        .eq('follower_id', userId)
        .limit(100);
    return (rows as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
  }


  Future<(List<String>, Map<String, String>)> _loadGames(String userId) async {
    final rows = await _client
        .from('user_games')
        .select('game_name, community_id')
        .eq('user_id', userId);
    final names = <String>[];
    final map = <String, String>{};
    for (final r in rows as List) {
      final name = r['game_name'] as String?;
      if (name == null) continue;
      names.add(name);
      final cid = r['community_id'] as String?;
      if (cid != null) map[name] = cid;
    }
    return (names, map);
  }

  /// One active squad for Squad Tag.
  Future<(String, String, String, int, bool)?> _loadSquadTag(String userId) async {
    final mem = await _client
        .from('squad_members')
        .select('squad_id, role, status')
        .eq('user_id', userId)
        .eq('status', 'active')
        .maybeSingle();
    if (mem == null) return null;
    final squad = await _client
        .from('squads')
        .select('id, name, member_count, is_public, is_deleted')
        .eq('id', mem['squad_id'])
        .maybeSingle();
    if (squad == null || squad['is_deleted'] == true) return null;
    // Hide private squad tag from non-members (viewer is not necessarily userId)
    final isPublic = squad['is_public'] as bool? ?? true;
    final me = _client.auth.currentUser?.id;
    if (!isPublic && me != userId) {
      final viewerMem = await _client
          .from('squad_members')
          .select()
          .eq('squad_id', squad['id'])
          .eq('user_id', me ?? '')
          .eq('status', 'active')
          .maybeSingle();
      if (viewerMem == null) return null;
    }
    return (
      squad['id'] as String,
      squad['name'] as String,
      mem['role'] as String? ?? 'member',
      squad['member_count'] as int? ?? 0,
      isPublic,
    );
  }

  Future<ProfileEntity> getMyProfile() => getProfile(_uid);

  Future<ProfileEntity> updateProfile({
    String? gamerName,
    String? bio,
    String? country,
    String? playerType,
    String? avatarUrl,
    String? bannerUrl,
  }) async {
    final payload = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (gamerName != null) payload['gamer_name'] = gamerName;
    if (bio != null) {
      final trimmed = bio.length > 160 ? bio.substring(0, 160) : bio;
      payload['bio'] = trimmed;
    }
    if (country != null) payload['country'] = country;
    if (playerType != null) payload['player_type'] = playerType;
    if (avatarUrl != null) payload['avatar_url'] = avatarUrl;
    if (bannerUrl != null) payload['banner_url'] = bannerUrl;

    await _client.from('profiles').update(payload).eq('id', _uid);
    return getMyProfile();
  }

  Future<String> uploadAvatar(String localPath) async {
    final file = File(localPath);
    final ext = p.extension(localPath).replaceFirst('.', '');
    final key = '$_uid/${const Uuid().v4()}.$ext';
    await _client.storage.from('avatars').upload(
          key,
          file,
          fileOptions: const FileOptions(upsert: true),
        );
    return _client.storage.from('avatars').getPublicUrl(key);
  }

  Future<String> uploadBanner(String localPath) async {
    final file = File(localPath);
    final ext = p.extension(localPath).replaceFirst('.', '');
    final key = '$_uid/banner_${const Uuid().v4()}.$ext';
    await _client.storage.from('avatars').upload(
          key,
          file,
          fileOptions: const FileOptions(upsert: true),
        );
    return _client.storage.from('avatars').getPublicUrl(key);
  }

  Future<List<String>> getUserGames(String userId) async {
    final data = await _loadGames(userId);
    return data.$1;
  }
}
