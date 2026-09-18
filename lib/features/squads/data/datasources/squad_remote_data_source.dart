import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/squad_entity.dart';

class SquadRemoteDataSource {
  SquadRemoteDataSource(this._client);
  final SupabaseClient _client;

  String get _uid {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('Not authenticated');
    return id;
  }

  static const _select = '''
    id, name, slug, description, logo_url, banner_url, rules,
    primary_game, category, invite_policy, is_public, require_approval,
    owner_id, member_count, created_at,
    profiles!squads_owner_id_fkey ( username, gamer_name, avatar_url )
  ''';

  /// Active squad for current user, or null.
  Future<SquadEntity?> myActiveSquad() async {
    final mem = await _client
        .from('squad_members')
        .select('squad_id, role, status')
        .eq('user_id', _uid)
        .eq('status', 'active')
        .maybeSingle();
    if (mem == null) return null;
    final row = await _client
        .from('squads')
        .select(_select)
        .eq('id', mem['squad_id'])
        .eq('is_deleted', false)
        .maybeSingle();
    if (row == null) return null;
    return SquadEntity.fromMap(
      Map<String, dynamic>.from(row),
      myRole: mem['role'] as String?,
      myStatus: mem['status'] as String?,
    );
  }

  Future<bool> hasActiveSquad() async {
    final mem = await _client
        .from('squad_members')
        .select('squad_id')
        .eq('user_id', _uid)
        .eq('status', 'active')
        .maybeSingle();
    return mem != null;
  }

  Future<List<SquadEntity>> listDiscover({String? query, String? game}) async {
    var q = _client
        .from('squads')
        .select(_select)
        .eq('is_public', true)
        .eq('is_deleted', false);

    if (query != null && query.trim().isNotEmpty) {
      q = q.ilike('name', '%${query.trim()}%');
    }
    if (game != null && game.isNotEmpty) {
      q = q.eq('primary_game', game);
    }

    final rows = await q.order('member_count', ascending: false).limit(40);
    final list = <SquadEntity>[];
    for (final r in rows as List) {
      list.add(await _enrich(Map<String, dynamic>.from(r as Map)));
    }
    return list;
  }

  Future<List<SquadEntity>> mySquads() async {
    final s = await myActiveSquad();
    return s == null ? [] : [s];
  }

  Future<SquadEntity> getSquad(String id) async {
    final row = await _client
        .from('squads')
        .select(_select)
        .eq('id', id)
        .eq('is_deleted', false)
        .single();
    return _enrich(Map<String, dynamic>.from(row));
  }

  Future<SquadEntity> createSquad({
    required String name,
    String? description,
    String? rules,
    String? primaryGame,
    String? category,
    bool isPublic = true,
    bool requireApproval = true,
    String? logoUrl,
  }) async {
    if (await hasActiveSquad()) {
      throw StateError(
          'You already belong to a squad. Leave it before creating another.');
    }

    final slug = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');

    String? communityId;
    if (primaryGame != null && primaryGame.isNotEmpty) {
      final game = await _client
          .from('communities')
          .select('id')
          .eq('game_name', primaryGame)
          .eq('is_official', true)
          .maybeSingle();
      communityId = game?['id'] as String?;
    }

    final row = await _client
        .from('squads')
        .insert({
          'name': name.trim(),
          'slug': '$slug-${DateTime.now().millisecondsSinceEpoch % 100000}',
          'description': description?.trim(),
          'rules': rules?.trim(),
          'logo_url': logoUrl,
          'primary_game': primaryGame,
          'category': category,
          'community_id': communityId,
          'is_public': isPublic,
          'require_approval': isPublic ? requireApproval : true,
          'owner_id': _uid,
          'member_count': 1,
        })
        .select(_select)
        .single();

    await _client.from('squad_members').insert({
      'squad_id': row['id'],
      'user_id': _uid,
      'role': 'owner',
      'status': 'active',
    });

    return SquadEntity.fromMap(
      Map<String, dynamic>.from(row),
      myRole: 'owner',
      myStatus: 'active',
    );
  }

  Future<SquadEntity> updateSquad({
    required String squadId,
    String? name,
    String? description,
    String? rules,
    String? primaryGame,
    String? category,
    bool? isPublic,
    bool? requireApproval,
    String? logoUrl,
  }) async {
    final mem = await _client
        .from('squad_members')
        .select('role')
        .eq('squad_id', squadId)
        .eq('user_id', _uid)
        .maybeSingle();
    if (mem == null || mem['role'] != 'owner') {
      throw StateError('Only the squad owner can edit the squad');
    }

    String? communityId;
    if (primaryGame != null) {
      if (primaryGame.isEmpty) {
        communityId = null;
      } else {
        final game = await _client
            .from('communities')
            .select('id')
            .eq('game_name', primaryGame)
            .eq('is_official', true)
            .maybeSingle();
        communityId = game?['id'] as String?;
      }
    }

    final updates = <String, dynamic>{
      if (name != null) 'name': name.trim(),
      if (description != null) 'description': description.trim(),
      if (rules != null) 'rules': rules.trim(),
      if (logoUrl != null) 'logo_url': logoUrl,
      if (primaryGame != null)
        'primary_game': primaryGame.isEmpty ? null : primaryGame,
      if (primaryGame != null) 'community_id': communityId,
      if (category != null) 'category': category,
      if (isPublic != null) 'is_public': isPublic,
      if (requireApproval != null)
        'require_approval': isPublic == false ? true : requireApproval,
    };

    if (updates.isEmpty) {
      return getSquad(squadId);
    }

    final row = await _client
        .from('squads')
        .update(updates)
        .eq('id', squadId)
        .select(_select)
        .single();

    return SquadEntity.fromMap(
      Map<String, dynamic>.from(row),
      myRole: 'owner',
      myStatus: 'active',
    );
  }

  Future<void> deleteSquad(String squadId) async {
    final mem = await _client
        .from('squad_members')
        .select('role')
        .eq('squad_id', squadId)
        .eq('user_id', _uid)
        .maybeSingle();
    if (mem == null || mem['role'] != 'owner') {
      throw StateError('Only the squad owner can delete the squad');
    }

    final squad =
        await _client.from('squads').select('name').eq('id', squadId).single();

    final memberRows = await _client
        .from('squad_members')
        .select('user_id')
        .eq('squad_id', squadId)
        .eq('status', 'active');

    // Soft-delete: keep the row (and its history/posts) but hide it from
    // discovery and active-squad checks going forward.
    await _client.from('squads').update({
      'is_deleted': true,
      'deleted_at': DateTime.now().toIso8601String(),
    }).eq('id', squadId);

    await _client.from('squad_members').delete().eq('squad_id', squadId);

    final squadName = squad['name'] as String? ?? 'Your squad';
    final rows = [
      for (final m in memberRows as List)
        if ((m as Map)['user_id'] != _uid)
          {
            'user_id': m['user_id'],
            'type': 'squad_deleted',
            'title': squadName,
            'body': '$squadName was deleted by its owner.',
            'actor_id': _uid,
            'target_type': 'squad',
            'target_id': squadId,
            'category': 'squad',
          },
    ];
    if (rows.isNotEmpty) {
      try {
        await _client.from('notifications').insert(rows);
      } catch (_) {
        // Notification delivery is best-effort — the delete itself already succeeded.
      }
    }
  }

  Future<String> uploadLogo(String filePath) async {
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
        'squad_logo_${_uid}_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final bytes = await file.readAsBytes();

    await _client.storage.from('squad-logos').uploadBinary(
          fileName,
          bytes,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
        );

    final url = _client.storage.from('squad-logos').getPublicUrl(fileName);
    return url;
  }

  Future<void> requestJoin(String squadId, {String? message}) async {
    if (await hasActiveSquad()) {
      throw StateError(
          'You already belong to a squad. Leave it before joining another.');
    }

    final banned = await _client
        .from('squad_members')
        .select()
        .eq('squad_id', squadId)
        .eq('user_id', _uid)
        .eq('status', 'banned')
        .maybeSingle();
    if (banned != null) {
      throw StateError('You are banned from this squad');
    }

    final squad = await _client
        .from('squads')
        .select('is_public, require_approval')
        .eq('id', squadId)
        .single();

    final needsApproval = !(squad['is_public'] as bool? ?? true) ||
        (squad['require_approval'] as bool? ?? true);

    if (!needsApproval) {
      await _client.from('squad_members').upsert({
        'squad_id': squadId,
        'user_id': _uid,
        'role': 'member',
        'status': 'active',
      });
      return;
    }

    await _client.from('squad_join_requests').upsert({
      'squad_id': squadId,
      'user_id': _uid,
      'message': message,
      'status': 'pending',
    });
    await _client.from('squad_members').upsert({
      'squad_id': squadId,
      'user_id': _uid,
      'role': 'member',
      'status': 'pending',
    });
  }

  Future<void> leave(String squadId) async {
    final mem = await _client
        .from('squad_members')
        .select('role')
        .eq('squad_id', squadId)
        .eq('user_id', _uid)
        .maybeSingle();
    if (mem == null) return;
    if (mem['role'] == 'owner') {
      throw StateError('Transfer ownership before leaving the squad');
    }
    await _client
        .from('squad_members')
        .delete()
        .eq('squad_id', squadId)
        .eq('user_id', _uid);
  }

  Future<void> transferOwnership(String squadId, String newOwnerId) async {
    await _client.rpc('transfer_squad_ownership', params: {
      'p_squad_id': squadId,
      'p_new_owner_id': newOwnerId,
    });
  }

  Future<void> removeMember(String squadId, String userId,
      {bool ban = false}) async {
    if (ban) {
      await _client.from('squad_members').upsert({
        'squad_id': squadId,
        'user_id': userId,
        'role': 'member',
        'status': 'banned',
      });
    } else {
      await _client
          .from('squad_members')
          .delete()
          .eq('squad_id', squadId)
          .eq('user_id', userId);
    }
  }

  Future<void> approveRequest(String squadId, String userId) async {
    // Target must not already be in another squad
    final other = await _client
        .from('squad_members')
        .select('squad_id')
        .eq('user_id', userId)
        .eq('status', 'active')
        .neq('squad_id', squadId)
        .maybeSingle();
    if (other != null) {
      throw StateError('User already belongs to another squad');
    }

    await _client
        .from('squad_join_requests')
        .update({
          'status': 'approved',
          'reviewed_at': DateTime.now().toIso8601String(),
          'reviewed_by': _uid,
        })
        .eq('squad_id', squadId)
        .eq('user_id', userId);

    await _client.from('squad_members').upsert({
      'squad_id': squadId,
      'user_id': userId,
      'role': 'member',
      'status': 'active',
    });
  }

  Future<void> rejectRequest(String squadId, String userId) async {
    await _client
        .from('squad_join_requests')
        .update({
          'status': 'rejected',
          'reviewed_at': DateTime.now().toIso8601String(),
          'reviewed_by': _uid,
        })
        .eq('squad_id', squadId)
        .eq('user_id', userId);

    await _client
        .from('squad_members')
        .delete()
        .eq('squad_id', squadId)
        .eq('user_id', userId);
  }

  Future<List<SquadMemberEntity>> members(String squadId) async {
    final rows = await _client.from('squad_members').select('''
          user_id, role, status, joined_at,
          profiles!squad_members_user_id_fkey ( username, gamer_name, avatar_url, is_verified )
        ''').eq('squad_id', squadId).order('joined_at');

    return (rows as List).map((r) {
      final m = Map<String, dynamic>.from(r as Map);
      final p = m['profiles'] as Map<String, dynamic>?;
      return SquadMemberEntity(
        userId: m['user_id'] as String,
        username: p?['username'] as String? ?? '',
        gamerName: p?['gamer_name'] as String?,
        avatarUrl: p?['avatar_url'] as String?,
        isVerified: p?['is_verified'] == true,
        role: m['role'] as String,
        status: m['status'] as String,
        joinedAt: DateTime.parse(m['joined_at'] as String),
      );
    }).toList();
  }

  Future<List<Map<String, dynamic>>> pendingRequests(String squadId) async {
    final rows = await _client
        .from('squad_join_requests')
        .select('''
          id, user_id, message, status, created_at,
          profiles!squad_join_requests_user_id_fkey ( username, gamer_name, avatar_url )
        ''')
        .eq('squad_id', squadId)
        .eq('status', 'pending')
        .order('created_at');
    return (rows as List)
        .map((r) => Map<String, dynamic>.from(r as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> squadPosts(String squadId,
      {int limit = 30}) async {
    final rows = await _client
        .from('posts')
        .select('''
          id, body, post_type, is_announcement, created_at, like_count, comment_count,
          author_id, profiles!posts_author_id_fkey ( username, gamer_name, avatar_url )
        ''')
        .eq('squad_id', squadId)
        .eq('is_deleted', false)
        .order('is_announcement', ascending: false)
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .map((r) => Map<String, dynamic>.from(r as Map))
        .toList();
  }

  Future<void> createSquadPost({
    required String squadId,
    required String body,
    bool announcement = false,
  }) async {
    final mem = await _client
        .from('squad_members')
        .select('role, status')
        .eq('squad_id', squadId)
        .eq('user_id', _uid)
        .maybeSingle();
    if (mem == null || mem['status'] != 'active') {
      throw StateError('Only members can post');
    }
    if (announcement) {
      final role = mem['role'] as String?;
      if (role != 'owner' && role != 'moderator') {
        throw StateError('Only owner/moderators can post announcements');
      }
    }
    await _client.from('posts').insert({
      'author_id': _uid,
      'body': body.trim(),
      'post_type': 'text',
      'visibility': 'public',
      'squad_id': squadId,
      'is_announcement': announcement,
    });
  }

  Future<SquadEntity> _enrich(Map<String, dynamic> m) async {
    String? role;
    String? status;
    final mem = await _client
        .from('squad_members')
        .select('role, status')
        .eq('squad_id', m['id'])
        .eq('user_id', _uid)
        .maybeSingle();
    if (mem != null) {
      role = mem['role'] as String?;
      status = mem['status'] as String?;
    }
    return SquadEntity.fromMap(m, myRole: role, myStatus: status);
  }
}
