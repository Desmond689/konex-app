import 'dart:typed_data';
import '../../../../core/services/image_compression_service.dart';

import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/config/constants.dart';
import '../../domain/entities/post_entity.dart';

class PostRemoteDataSource {
  PostRemoteDataSource(this._client);
  final SupabaseClient _client;

  String get _uid {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('Not authenticated');
    return id;
  }

  Future<List<PostEntity>> getLatestFeed(
      {int page = 0, int pageSize = AppConstants.feedPageSize}) async {
    final from = page * pageSize;
    final to = from + pageSize - 1;

    final rows = await _client
        .from('posts')
        .select('''
          id, author_id, community_id, squad_id, post_type, body, visibility, is_announcement, is_pinned,
          like_count, comment_count, share_count, created_at,
          profiles!posts_author_id_fkey ( username, gamer_name, avatar_url, is_verified ),
          communities ( name ),
          squads ( name ),
          post_media ( media:media_id ( media_url ) )
        ''')
        .eq('is_deleted', false)
        .order('created_at', ascending: false)
        .range(from, to);

    final maps = (rows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
    return mapPostsBatch(maps);
  }

  Future<List<PostEntity>> getFollowingFeed(
      {int page = 0, int pageSize = AppConstants.feedPageSize}) async {
    final following = await _client
        .from('follows')
        .select('following_id')
        .eq('follower_id', _uid);
    final ids =
        (following as List).map((e) => e['following_id'] as String).toList();
    if (ids.isEmpty) return [];
    final from = page * pageSize;
    final to = from + pageSize - 1;
    final rows = await _client
        .from('posts')
        .select(
          'id, author_id, community_id, squad_id, post_type, body, visibility, is_announcement, is_pinned, '
          'like_count, comment_count, share_count, created_at, '
          'profiles!posts_author_id_fkey ( username, gamer_name, avatar_url, is_verified ), '
          'communities ( name ), '
          'squads ( name ), '
          'post_media ( media:media_id ( media_url ) )',
        )
        .inFilter('author_id', ids)
        .eq('is_deleted', false)
        .order('created_at', ascending: false)
        .range(from, to);
    final maps = (rows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
    return mapPostsBatch(maps);
  }

  Future<List<PostEntity>> getForYouFeed({
    int page = 0,
    int pageSize = AppConstants.feedPageSize,
    String? communityFilter,
  }) async {
    final from = page * pageSize;
    final to = from + pageSize - 1;
    var query = _client
        .from('posts')
        .select(
          'id, author_id, community_id, squad_id, post_type, body, visibility, is_announcement, is_pinned, '
          'like_count, comment_count, share_count, created_at, '
          'profiles!posts_author_id_fkey ( username, gamer_name, avatar_url, is_verified ), '
          'communities ( name ), '
          'squads ( name ), '
          'post_media ( media:media_id ( media_url ) )',
        )
        .eq('is_deleted', false);
    if (communityFilter != null) {
      query = query.eq('community_id', communityFilter);
    }
    final rows =
        await query.order('created_at', ascending: false).range(from, to);
    final maps = (rows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
    return mapPostsBatch(maps);
  }

  Future<List<PostEntity>> getUserPosts(String userId, {int page = 0}) async {
    final from = page * AppConstants.feedPageSize;
    final to = from + AppConstants.feedPageSize - 1;
    final rows = await _client
        .from('posts')
        .select('''
          id, author_id, community_id, squad_id, post_type, body, visibility, is_announcement, is_pinned,
          like_count, comment_count, share_count, created_at,
          profiles!posts_author_id_fkey ( username, gamer_name, avatar_url, is_verified ),
          communities ( name ),
          squads ( name ),
          post_media ( media:media_id ( media_url ) )
        ''')
        .eq('author_id', userId)
        .eq('is_deleted', false)
        .order('created_at', ascending: false)
        .range(from, to);

    final maps = (rows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
    return mapPostsBatch(maps);
  }

  /// Fetch posts by primary keys (e.g. saved-post IDs). Order follows [ids].
  Future<List<PostEntity>> getPostsByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    const chunkSize = 100;
    final byId = <String, PostEntity>{};
    for (var i = 0; i < ids.length; i += chunkSize) {
      final end = (i + chunkSize > ids.length) ? ids.length : i + chunkSize;
      final chunk = ids.sublist(i, end);
      final rows = await _client
          .from('posts')
          .select(
            'id, author_id, community_id, squad_id, post_type, body, visibility, is_announcement, is_pinned, '
            'like_count, comment_count, share_count, created_at, '
            'profiles!posts_author_id_fkey ( username, gamer_name, avatar_url, is_verified ), '
            'communities ( name ), '
            'squads ( name ), '
            'post_media ( media:media_id ( media_url ) )',
          )
          .inFilter('id', chunk)
          .eq('is_deleted', false);
      final maps = (rows as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      final mapped = await mapPostsBatch(maps);
      for (final p in mapped) {
        byId[p.id] = p;
      }
    }
    return [
      for (final id in ids)
        if (byId.containsKey(id)) byId[id]!,
    ];
  }

  /// Posts within a community, pinned first then newest first.
  Future<List<PostEntity>> getCommunityPosts(String communityId,
      {int page = 0, int pageSize = AppConstants.feedPageSize}) async {
    final from = page * pageSize;
    final to = from + pageSize - 1;
    final rows = await _client
        .from('posts')
        .select(
          'id, author_id, community_id, squad_id, post_type, body, visibility, is_announcement, is_pinned, '
          'like_count, comment_count, share_count, created_at, '
          'profiles!posts_author_id_fkey ( username, gamer_name, avatar_url, is_verified ), '
          'communities ( name ), '
          'squads ( name ), '
          'post_media ( media:media_id ( media_url ) )',
        )
        .eq('community_id', communityId)
        .eq('is_deleted', false)
        .order('is_pinned', ascending: false)
        .order('created_at', ascending: false)
        .range(from, to);
    final maps = (rows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
    return mapPostsBatch(maps);
  }

  /// Posts within a squad, pinned first then newest first.
  Future<List<PostEntity>> getSquadPosts(String squadId,
      {int page = 0, int pageSize = AppConstants.feedPageSize}) async {
    final from = page * pageSize;
    final to = from + pageSize - 1;
    final rows = await _client
        .from('posts')
        .select(
          'id, author_id, community_id, squad_id, post_type, body, visibility, is_announcement, is_pinned, '
          'like_count, comment_count, share_count, created_at, '
          'profiles!posts_author_id_fkey ( username, gamer_name, avatar_url, is_verified ), '
          'communities ( name ), '
          'squads ( name ), '
          'post_media ( media:media_id ( media_url ) )',
        )
        .eq('squad_id', squadId)
        .eq('is_deleted', false)
        .order('is_pinned', ascending: false)
        .order('created_at', ascending: false)
        .range(from, to);
    final maps = (rows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
    final ids = maps.map((m) => m['author_id'] as String).toSet().toList();
    final roles = await _squadRoles(squadId, ids);
    return mapPostsBatch(maps, squadRoles: roles);
  }

  Future<Map<String, String>> _squadRoles(
      String squadId, List<String> userIds) async {
    if (userIds.isEmpty) return const {};
    final rows = await _client
        .from('squad_members')
        .select('user_id, role')
        .eq('squad_id', squadId)
        .inFilter('user_id', userIds);
    final out = <String, String>{};
    for (final r in rows as List) {
      final m = r as Map;
      out[m['user_id'] as String] = m['role'] as String? ?? 'member';
    }
    return out;
  }

  Future<PostEntity> createTextPost({
    required String body,
    String? communityId,
    String? squadId,
    String postType = 'text',
    bool isAnnouncement = false,
    bool isPinned = false,
    String visibility = 'public',
  }) async {
    final row = await _client.from('posts').insert({
      'author_id': _uid,
      'body': body.trim(),
      'post_type': postType,
      'visibility': visibility,
      'is_announcement': isAnnouncement,
      'is_pinned': isPinned,
      if (communityId != null) 'community_id': communityId,
      if (squadId != null) 'squad_id': squadId,
    }).select('''
      id, author_id, community_id, squad_id, post_type, body, visibility, is_announcement, is_pinned,
      like_count, comment_count, share_count, created_at,
      profiles!posts_author_id_fkey ( username, gamer_name, avatar_url, is_verified ),
      communities ( name ),
      squads ( name )
    ''').single();

    return _mapPost(Map<String, dynamic>.from(row));
  }

  Future<PostEntity> createImagePost({
    required String body,
    required String localImagePath,
    String? communityId,
    String? squadId,
    String postType = 'image',
  }) =>
      createMultiImagePost(
        body: body,
        localImagePaths: [localImagePath],
        communityId: communityId,
        squadId: squadId,
        postType: postType,
      );

  Future<PostEntity> createMultiImagePost({
    required String body,
    required List<String> localImagePaths,
    String? communityId,
    String? squadId,
    String postType = 'image',
  }) async {
    if (localImagePaths.isEmpty) {
      throw ArgumentError('At least one image is required');
    }

    final postRow = await _client
        .from('posts')
        .insert({
          'author_id': _uid,
          'body': body.trim().isEmpty ? null : body.trim(),
          'post_type': postType,
          'visibility': 'public',
          if (communityId != null) 'community_id': communityId,
          if (squadId != null) 'squad_id': squadId,
        })
        .select()
        .single();

    final postId = postRow['id'] as String;
    var position = 0;
    for (final localImagePath in localImagePaths.take(10)) {
      final compressed =
          await ImageCompressionService().compressForUpload(localImagePath);
      final file = compressed;
      final ext = p.extension(localImagePath).replaceFirst('.', '');
      final key = '$_uid/${const Uuid().v4()}.$ext';
      await _client.storage.from('post-images').upload(key, file);
      final url = _client.storage.from('post-images').getPublicUrl(key);

      final mediaRow = await _client
          .from('media')
          .insert({
            'owner_id': _uid,
            'type': 'image',
            'provider': 'supabase',
            'storage_key': key,
            'media_url': url,
            'status': 'ready',
          })
          .select()
          .single();

      await _client.from('post_media').insert({
        'post_id': postId,
        'media_id': mediaRow['id'],
        'position': position,
      });
      position++;
    }

    return getPostById(postId);
  }

  Future<PostEntity> getPostById(String postId) async {
    final row = await _client.from('posts').select('''
          id, author_id, community_id, squad_id, post_type, body, visibility, is_announcement, is_pinned,
          like_count, comment_count, share_count, created_at,
          profiles!posts_author_id_fkey ( username, gamer_name, avatar_url ),
          communities ( name ),
          squads ( name ),
          post_media ( media:media_id ( media_url ) )
        ''').eq('id', postId).single();
    return _mapPost(Map<String, dynamic>.from(row));
  }

  Future<void> deletePost(String postId) async {
    await _client
        .from('posts')
        .update({
          'is_deleted': true,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', postId)
        .eq('author_id', _uid);
  }

  Future<void> likePost(String postId) async {
    await _client.from('likes').upsert({
      'user_id': _uid,
      'post_id': postId,
    });
  }

  Future<void> unlikePost(String postId) async {
    await _client
        .from('likes')
        .delete()
        .eq('user_id', _uid)
        .eq('post_id', postId);
  }

  Future<void> savePost(String postId) async {
    await _client.from('saves').upsert({
      'user_id': _uid,
      'post_id': postId,
    });
  }

  Future<void> unsavePost(String postId) async {
    await _client
        .from('saves')
        .delete()
        .eq('user_id', _uid)
        .eq('post_id', postId);
  }

  Future<List<CommentEntity>> getComments(String postId,
      {String? postAuthorId}) async {
    final rows = await _client
        .from('comments')
        .select('''
          id, post_id, author_id, parent_id, body, media_url, like_count, created_at,
          profiles!comments_author_id_fkey ( username, avatar_url, is_verified )
        ''')
        .eq('post_id', postId)
        .eq('is_deleted', false)
        .order('like_count', ascending: false)
        .order('created_at', ascending: true)
        .limit(200);

    final list =
        (rows as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
    final ids = list.map((m) => m['id'] as String).toList();
    final myLiked = <String>{};
    final creatorLiked = <String>{};
    String? creatorAvatar;

    if (ids.isNotEmpty) {
      final mine = await _client
          .from('comment_likes')
          .select('comment_id')
          .eq('user_id', _uid)
          .inFilter('comment_id', ids);
      for (final r in mine as List) {
        myLiked.add((r as Map)['comment_id'] as String);
      }
    }

    if (postAuthorId != null && postAuthorId.isNotEmpty && ids.isNotEmpty) {
      final cl = await _client
          .from('comment_likes')
          .select('comment_id')
          .eq('user_id', postAuthorId)
          .inFilter('comment_id', ids);
      for (final r in cl as List) {
        creatorLiked.add((r as Map)['comment_id'] as String);
      }
      final prof = await _client
          .from('profiles')
          .select('avatar_url')
          .eq('id', postAuthorId)
          .maybeSingle();
      creatorAvatar = prof?['avatar_url'] as String?;
    }

    return list.map((m) {
      final profile = m['profiles'] as Map<String, dynamic>?;
      final authorId = m['author_id'] as String;
      return CommentEntity(
        id: m['id'] as String,
        postId: m['post_id'] as String,
        authorId: authorId,
        authorUsername: profile?['username'] as String? ?? '',
        authorAvatarUrl: profile?['avatar_url'] as String?,
        authorVerified: profile?['is_verified'] == true,
        parentId: m['parent_id'] as String?,
        body: (m['body'] as String?) ?? '',
        mediaUrl: m['media_url'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
        likeCount: (m['like_count'] as int?) ?? 0,
        likedByMe: myLiked.contains(m['id'] as String),
        likedByCreator: creatorLiked.contains(m['id'] as String),
        creatorAvatarUrl: creatorAvatar,
        isCreator: postAuthorId != null && authorId == postAuthorId,
      );
    }).toList();
  }

  Future<CommentEntity> addComment(
    String postId,
    String body, {
    String? parentId,
    String? mediaUrl,
    String? postAuthorId,
  }) async {
    final insert = <String, dynamic>{
      'post_id': postId,
      'author_id': _uid,
    };
    final trimmed = body.trim();
    if (trimmed.isNotEmpty) insert['body'] = trimmed;
    if (parentId != null) insert['parent_id'] = parentId;
    if (mediaUrl != null) insert['media_url'] = mediaUrl;

    final row = await _client.from('comments').insert(insert).select('''
      id, post_id, author_id, parent_id, body, media_url, like_count, created_at,
      profiles!comments_author_id_fkey ( username, avatar_url, is_verified )
    ''').single();

    final m = Map<String, dynamic>.from(row);
    final profile = m['profiles'] as Map<String, dynamic>?;
    final authorId = m['author_id'] as String;
    return CommentEntity(
      id: m['id'] as String,
      postId: m['post_id'] as String,
      authorId: authorId,
      authorUsername: profile?['username'] as String? ?? '',
      authorAvatarUrl: profile?['avatar_url'] as String?,
      authorVerified: profile?['is_verified'] == true,
      parentId: m['parent_id'] as String?,
      body: (m['body'] as String?) ?? '',
      mediaUrl: m['media_url'] as String?,
      createdAt: DateTime.parse(m['created_at'] as String),
      likeCount: (m['like_count'] as int?) ?? 0,
      isCreator: postAuthorId != null && authorId == postAuthorId,
    );
  }

  Future<void> likeComment(String commentId) async {
    await _client.from('comment_likes').upsert({
      'user_id': _uid,
      'comment_id': commentId,
    });
  }

  Future<void> unlikeComment(String commentId) async {
    await _client
        .from('comment_likes')
        .delete()
        .eq('user_id', _uid)
        .eq('comment_id', commentId);
  }

  Future<void> softDeleteComment(String commentId) async {
    await _client
        .from('comments')
        .update({
          'is_deleted': true,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', commentId)
        .eq('author_id', _uid);
  }

  Future<String> uploadCommentImage(List<int> bytes) async {
    final name = '$_uid/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _client.storage.from('comment-media').uploadBinary(
          name,
          Uint8List.fromList(bytes),
          fileOptions:
              const FileOptions(contentType: 'image/jpeg', upsert: true),
        );
    return _client.storage.from('comment-media').getPublicUrl(name);
  }

  /// Batch-fetch likes/saves for a page of posts (2 queries instead of 2N).
  Future<List<PostEntity>> mapPostsBatch(
    List<Map<String, dynamic>> rows, {
    Map<String, String>? squadRoles,
  }) async {
    if (rows.isEmpty) return [];
    final ids = rows.map((m) => m['id'] as String).toList();
    final myLiked = <String>{};
    final mySaved = <String>{};
    final me = _client.auth.currentUser?.id;
    if (me != null && ids.isNotEmpty) {
      final likes = await _client
          .from('likes')
          .select('post_id')
          .eq('user_id', me)
          .inFilter('post_id', ids);
      for (final r in likes as List) {
        myLiked.add((r as Map)['post_id'] as String);
      }
      final saves = await _client
          .from('saves')
          .select('post_id')
          .eq('user_id', me)
          .inFilter('post_id', ids);
      for (final r in saves as List) {
        mySaved.add((r as Map)['post_id'] as String);
      }
    }
    final out = <PostEntity>[];
    for (final m in rows) {
      final id = m['id'] as String;
      out.add(await _mapPost(
        m,
        likedOverride: myLiked.contains(id),
        savedOverride: mySaved.contains(id),
        skipEngagementFetch: true,
        squadRole: squadRoles?[m['author_id'] as String],
      ));
    }
    return out;
  }

  Future<PostEntity> _mapPost(
    Map<String, dynamic> m, {
    bool? likedOverride,
    bool? savedOverride,
    bool skipEngagementFetch = false,
    String? squadRole,
  }) async {
    final profile = m['profiles'] as Map<String, dynamic>?;
    final community = m['communities'] as Map<String, dynamic>?;
    final squad = m['squads'] as Map<String, dynamic>?;
    final mediaList = m['post_media'] as List? ?? [];
    final urls = <String>[];
    for (final pm in mediaList) {
      final media = (pm as Map)['media'];
      if (media is Map && media['media_url'] != null) {
        urls.add(media['media_url'] as String);
      }
    }

    var liked = likedOverride ?? false;
    var saved = savedOverride ?? false;
    if (!skipEngagementFetch &&
        likedOverride == null &&
        savedOverride == null) {
      final me = _client.auth.currentUser?.id;
      if (me != null) {
        final like = await _client
            .from('likes')
            .select()
            .eq('user_id', me)
            .eq('post_id', m['id'])
            .maybeSingle();
        liked = like != null;
        final save = await _client
            .from('saves')
            .select()
            .eq('user_id', me)
            .eq('post_id', m['id'])
            .maybeSingle();
        saved = save != null;
      }
    }

    return PostEntity(
      id: m['id'] as String,
      authorId: m['author_id'] as String,
      authorUsername: profile?['username'] as String? ?? '',
      authorGamerName: profile?['gamer_name'] as String?,
      authorAvatarUrl: profile?['avatar_url'] as String?,
      authorVerified: profile?['is_verified'] == true,
      communityId: m['community_id'] as String?,
      communityName: community?['name'] as String?,
      squadId: m['squad_id'] as String?,
      squadName: squad?['name'] as String?,
      postType: m['post_type'] as String? ?? 'text',
      body: m['body'] as String?,
      mediaUrls: urls,
      visibility: m['visibility'] as String? ?? 'public',
      likeCount: m['like_count'] as int? ?? 0,
      commentCount: m['comment_count'] as int? ?? 0,
      shareCount: m['share_count'] as int? ?? 0,
      likedByMe: liked,
      savedByMe: saved,
      isAnnouncement: m['is_announcement'] as bool? ?? false,
      isPinned: m['is_pinned'] as bool? ?? false,
      authorSquadRole: squadRole,
      createdAt: DateTime.parse(m['created_at'] as String),
    );
  }
}
