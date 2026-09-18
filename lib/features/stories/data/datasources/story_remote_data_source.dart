import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/story_entity.dart';

class StoryRemoteDataSource {
  StoryRemoteDataSource(this._client);
  final SupabaseClient _client;

  String? get _uid => _client.auth.currentUser?.id;

  Future<List<StoryRing>> fetchHomeStoryRings() async {
    final uid = _uid;
    if (uid == null) return [];

    // Active (non-expired) stories with profile info
    final rows = await _client
        .from('stories')
        .select(
          'id, user_id, media_type, media_url, text_content, background_color, '
          'privacy, community_id, view_count, created_at, expires_at, '
          'profiles!stories_user_id_fkey(username, gamer_name, avatar_url, last_seen)',
        )
        .gt('expires_at', DateTime.now().toIso8601String())
        .order('created_at', ascending: false)
        .limit(100);

    final viewed = await _client
        .from('story_views')
        .select('story_id')
        .eq('viewer_id', uid);

    final viewedIds = (viewed as List)
        .map((r) => (r as Map)['story_id'] as String)
        .toSet();

    final Map<String, List<StoryEntity>> byUser = {};
    final Map<String, Map<String, dynamic>> profiles = {};

    for (final raw in rows as List) {
      final r = raw as Map<String, dynamic>;
      final userId = r['user_id'] as String;
      final profile = r['profiles'] as Map<String, dynamic>?;
      profiles[userId] = profile ?? {};

      final story = StoryEntity(
        id: r['id'] as String,
        userId: userId,
        mediaType: r['media_type'] as String,
        mediaUrl: r['media_url'] as String?,
        textContent: r['text_content'] as String?,
        backgroundColor: r['background_color'] as String?,
        privacy: r['privacy'] as String? ?? 'everyone',
        communityId: r['community_id'] as String?,
        viewCount: (r['view_count'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.parse(r['created_at'] as String),
        expiresAt: DateTime.parse(r['expires_at'] as String),
        username: profile?['username'] as String?,
        gamerName: profile?['gamer_name'] as String?,
        avatarUrl: profile?['avatar_url'] as String?,
        viewedByMe: viewedIds.contains(r['id']),
      );

      byUser.putIfAbsent(userId, () => []).add(story);
    }

    final rings = <StoryRing>[];

    // Own ring first
    if (byUser.containsKey(uid)) {
      final p = profiles[uid] ?? {};
      rings.add(
        StoryRing(
          userId: uid,
          displayName: 'Your Story',
          avatarUrl: p['avatar_url'] as String?,
          stories: byUser[uid]!,
          isMe: true,
        ),
      );
      byUser.remove(uid);
    } else {
      // Empty "Your Story" so user can create
      final me = await _client
          .from('profiles')
          .select('username, gamer_name, avatar_url')
          .eq('id', uid)
          .maybeSingle();
      rings.add(
        StoryRing(
          userId: uid,
          displayName: 'Your Story',
          avatarUrl: me?['avatar_url'] as String?,
          stories: const [],
          isMe: true,
        ),
      );
    }

    for (final entry in byUser.entries) {
      final p = profiles[entry.key] ?? {};
      final name = (p['gamer_name'] as String?)?.isNotEmpty == true
          ? p['gamer_name'] as String
          : (p['username'] as String? ?? 'User');
      rings.add(
        StoryRing(
          userId: entry.key,
          displayName: name,
          avatarUrl: p['avatar_url'] as String?,
          stories: entry.value,
          lastSeen: p['last_seen'] != null
              ? DateTime.tryParse(p['last_seen'] as String)
              : null,
        ),
      );
    }

    return rings;
  }

  Future<List<StoryEntity>> fetchUserStories(String userId) async {
    final uid = _uid;
    final rows = await _client
        .from('stories')
        .select(
          'id, user_id, media_type, media_url, text_content, background_color, '
          'privacy, community_id, view_count, created_at, expires_at, '
          'profiles!stories_user_id_fkey(username, gamer_name, avatar_url)',
        )
        .eq('user_id', userId)
        .gt('expires_at', DateTime.now().toIso8601String())
        .order('created_at', ascending: true);

    Set<String> viewedIds = {};
    if (uid != null) {
      final viewed = await _client
          .from('story_views')
          .select('story_id')
          .eq('viewer_id', uid);
      viewedIds = (viewed as List)
          .map((r) => (r as Map)['story_id'] as String)
          .toSet();
    }

    return (rows as List).map((raw) {
      final r = raw as Map<String, dynamic>;
      final profile = r['profiles'] as Map<String, dynamic>?;
      return StoryEntity(
        id: r['id'] as String,
        userId: r['user_id'] as String,
        mediaType: r['media_type'] as String,
        mediaUrl: r['media_url'] as String?,
        textContent: r['text_content'] as String?,
        backgroundColor: r['background_color'] as String?,
        privacy: r['privacy'] as String? ?? 'everyone',
        communityId: r['community_id'] as String?,
        viewCount: (r['view_count'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.parse(r['created_at'] as String),
        expiresAt: DateTime.parse(r['expires_at'] as String),
        username: profile?['username'] as String?,
        gamerName: profile?['gamer_name'] as String?,
        avatarUrl: profile?['avatar_url'] as String?,
        viewedByMe: viewedIds.contains(r['id']),
      );
    }).toList();
  }

  Future<StoryEntity> createStory({
    required String mediaType,
    String? mediaUrl,
    String? textContent,
    String? backgroundColor,
    String privacy = 'everyone',
    String? communityId,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not authenticated');
    const allowedPrivacy = {'everyone', 'followers', 'friends', 'only_me'};
    if (!allowedPrivacy.contains(privacy)) {
      throw ArgumentError.value(
        privacy,
        'privacy',
        'Unsupported story privacy',
      );
    }
    if (mediaType == 'text' &&
        (textContent == null || textContent.trim().isEmpty)) {
      throw ArgumentError('Text stories must contain text');
    }
    if (mediaType != 'text' && (mediaUrl == null || mediaUrl.trim().isEmpty)) {
      throw ArgumentError('Media stories must contain a media URL');
    }
    if (communityId != null) {
      final membership = await _client
          .from('community_members')
          .select('status')
          .eq('community_id', communityId)
          .eq('user_id', uid)
          .maybeSingle();
      if (membership?['status'] != 'active') {
        throw StateError('Join the community before sharing a community story');
      }
    }

    final row = await _client
        .from('stories')
        .insert({
          'user_id': uid,
          'media_type': mediaType,
          'media_url': mediaUrl,
          'text_content': textContent,
          'background_color': backgroundColor ?? '#7C3AED',
          'privacy': privacy,
          'community_id': communityId,
        })
        .select()
        .single();

    return StoryEntity(
      id: row['id'] as String,
      userId: uid,
      mediaType: mediaType,
      mediaUrl: mediaUrl,
      textContent: textContent,
      backgroundColor: backgroundColor,
      privacy: privacy,
      communityId: communityId,
      viewCount: 0,
      createdAt: DateTime.parse(row['created_at'] as String),
      expiresAt: DateTime.parse(row['expires_at'] as String),
    );
  }

  Future<String> uploadStoryMedia(File file, String mediaType) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not authenticated');
    final ext = mediaType == 'video' ? 'mp4' : 'jpg';
    final path = 'stories/$uid/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _client.storage
        .from('media')
        .upload(
          path,
          file,
          fileOptions: FileOptions(
            contentType: mediaType == 'video' ? 'video/mp4' : 'image/jpeg',
            upsert: true,
          ),
        );
    return _client.storage.from('media').getPublicUrl(path);
  }

  Future<void> markViewed(String storyId) async {
    final uid = _uid;
    if (uid == null) return;
    final existing = await _client
        .from('story_views')
        .select('story_id')
        .eq('story_id', storyId)
        .eq('viewer_id', uid)
        .maybeSingle();
    if (existing != null) return;
    await _client.from('story_views').insert({
      'story_id': storyId,
      'viewer_id': uid,
    });
    await _client.rpc('increment_story_view', params: {'p_story_id': storyId});
  }

  Future<void> deleteStory(String storyId) async {
    final uid = _uid;
    if (uid == null) throw StateError('Not authenticated');
    await _client.from('stories').delete().eq('id', storyId).eq('user_id', uid);
  }
}
