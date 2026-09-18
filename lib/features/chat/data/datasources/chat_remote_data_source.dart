import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/chat_entity.dart';

class ChatRemoteDataSource {
  ChatRemoteDataSource(this._client);
  final SupabaseClient _client;

  String get _uid {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('Not authenticated');
    return id;
  }

  Future<String> getOrCreateCommunityChat(String communityId) async {
    final membership = await _client
        .from('community_members')
        .select('status')
        .eq('community_id', communityId)
        .eq('user_id', _uid)
        .maybeSingle();
    if (membership?['status'] != 'active') {
      throw StateError('Join the community to use chat');
    }
    final existing = await _client
        .from('conversations')
        .select('id')
        .eq('type', 'community')
        .eq('community_id', communityId)
        .maybeSingle();
    if (existing != null) {
      await _ensureCommunityParticipant(existing['id'] as String, communityId);
      return existing['id'] as String;
    }

    final conv = await _client
        .from('conversations')
        .insert({
          'type': 'community',
          'community_id': communityId,
          'created_by': _uid,
        })
        .select()
        .single();
    final convId = conv['id'] as String;
    await _ensureCommunityParticipant(convId, communityId);
    return convId;
  }

  Future<void> _ensureCommunityParticipant(
    String conversationId,
    String communityId,
  ) async {
    final members = await _client
        .from('community_members')
        .select('user_id')
        .eq('community_id', communityId)
        .eq('status', 'active');
    final rows = (members as List)
        .map((m) => {
              'conversation_id': conversationId,
              'user_id': m['user_id'],
            })
        .toList();
    if (rows.isNotEmpty) {
      await _client.from('conversation_participants').upsert(rows);
    }
  }

  /// Open or reuse a DM conversation with [otherUserId]. Blocks prevent messaging.
  Future<String> getOrCreateDm(String otherUserId) async {
    if (otherUserId == _uid) throw StateError('Cannot DM yourself');

    final blocked = await _client
        .from('blocks')
        .select()
        .or('and(blocker_id.eq.$_uid,blocked_id.eq.$otherUserId),and(blocker_id.eq.$otherUserId,blocked_id.eq.$_uid)')
        .maybeSingle();
    if (blocked != null) {
      throw StateError('Cannot message this user (blocked)');
    }

    // Single-pass: my DM ids ∩ other user's conversation ids
    final myRows = await _client
        .from('conversation_participants')
        .select('conversation_id, conversations!inner(id, type)')
        .eq('user_id', _uid);
    final myDmIds = <String>{};
    for (final row in myRows as List) {
      final conv = row['conversations'] as Map<String, dynamic>?;
      if (conv != null && conv['type'] == 'dm') {
        myDmIds.add(row['conversation_id'] as String);
      }
    }
    if (myDmIds.isNotEmpty) {
      final their = await _client
          .from('conversation_participants')
          .select('conversation_id')
          .eq('user_id', otherUserId)
          .inFilter('conversation_id', myDmIds.toList());
      for (final row in their as List) {
        return (row as Map)['conversation_id'] as String;
      }
    }

    final conv = await _client
        .from('conversations')
        .insert({
          'type': 'dm',
        })
        .select()
        .single();

    final convId = conv['id'] as String;
    await _client.from('conversation_participants').insert([
      {'conversation_id': convId, 'user_id': _uid},
      {'conversation_id': convId, 'user_id': otherUserId},
    ]);
    return convId;
  }

  /// Create a multi-person group chat (type = group).
  Future<String> createGroupChat({
    required String title,
    required List<String> memberIds,
  }) async {
    final members = {_uid, ...memberIds}.toList();
    if (members.length < 2) {
      throw StateError('Group needs at least 2 members');
    }
    final row = await _client
        .from('conversations')
        .insert({
          'type': 'group',
          'title': title.trim().isEmpty ? 'Group chat' : title.trim(),
          'created_by': _uid,
        })
        .select()
        .single();
    final convId = row['id'] as String;
    await _client.from('conversation_participants').insert([
      for (final uid in members)
        {
          'conversation_id': convId,
          'user_id': uid,
          'role': uid == _uid ? 'owner' : 'member',
        }
    ]);
    return convId;
  }

  Future<List<Map<String, dynamic>>> listParticipants(
      String conversationId) async {
    final rows = await _client
        .from('conversation_participants')
        .select(
          'user_id, role, profiles!conversation_participants_user_id_fkey(username, gamer_name, avatar_url)',
        )
        .eq('conversation_id', conversationId);
    return (rows as List)
        .map((r) => Map<String, dynamic>.from(r as Map))
        .toList();
  }

  Future<String> getOrCreateSquadChat(String squadId) async {
    final existing = await _client
        .from('conversations')
        .select('id')
        .eq('type', 'squad')
        .eq('squad_id', squadId)
        .maybeSingle();
    if (existing != null) return existing['id'] as String;

    final conv = await _client
        .from('conversations')
        .insert({
          'type': 'squad',
          'squad_id': squadId,
        })
        .select()
        .single();
    final convId = conv['id'] as String;

    final members = await _client
        .from('squad_members')
        .select('user_id')
        .eq('squad_id', squadId)
        .eq('status', 'active');
    final rows = (members as List)
        .map((m) => {
              'conversation_id': convId,
              'user_id': m['user_id'],
            })
        .toList();
    if (rows.isNotEmpty) {
      await _client.from('conversation_participants').upsert(rows);
    }
    return convId;
  }

  Future<List<ConversationEntity>> listInbox() async {
    final parts = await _client
        .from('conversation_participants')
        .select(
            'conversation_id, last_read_at, pinned, muted, archived, unread_count')
        .eq('user_id', _uid)
        .eq('archived', false);

    final list = <ConversationEntity>[];
    for (final p in parts as List) {
      final convId = p['conversation_id'] as String;
      final conv = await _client
          .from('conversations')
          .select()
          .eq('id', convId)
          .maybeSingle();
      if (conv == null) continue;

      final lastMsg = await _client
          .from('messages')
          .select('body, created_at, sender_id')
          .eq('conversation_id', convId)
          .eq('is_deleted', false)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      String? title;
      String? otherUserId;
      String? avatarUrl;
      var conversationVerified = false;
      if (conv['type'] == 'dm') {
        final others = await _client
            .from('conversation_participants')
            .select(
                'user_id, profiles!conversation_participants_user_id_fkey(username, gamer_name, avatar_url, is_verified)')
            .eq('conversation_id', convId)
            .neq('user_id', _uid)
            .limit(1)
            .maybeSingle();
        if (others != null) {
          otherUserId = others['user_id'] as String?;
          final profile = others['profiles'] as Map<String, dynamic>?;
          final fallback = profile == null && otherUserId != null
              ? await _client
                  .from('profiles')
                  .select('username, gamer_name, avatar_url, is_verified')
                  .eq('id', otherUserId)
                  .maybeSingle()
              : null;
          final resolvedProfile = profile ?? fallback;
          title =
              (resolvedProfile?['gamer_name'] as String?)?.isNotEmpty == true
                  ? resolvedProfile!['gamer_name'] as String
                  : resolvedProfile?['username'] as String? ?? 'User';
          avatarUrl = resolvedProfile?['avatar_url'] as String?;
          conversationVerified = resolvedProfile?['is_verified'] == true;
        }
      } else if (conv['type'] == 'group') {
        title = (conv['title'] as String?)?.isNotEmpty == true
            ? conv['title'] as String
            : 'Group chat';
      } else if (conv['squad_id'] != null) {
        final squad = await _client
            .from('squads')
            .select('name, logo_url')
            .eq('id', conv['squad_id'])
            .maybeSingle();
        title = squad?['name'] as String? ?? 'Squad chat';
        avatarUrl = squad?['logo_url'] as String?;
      } else if (conv['community_id'] != null) {
        final community = await _client
            .from('communities')
            .select('name, avatar_url')
            .eq('id', conv['community_id'])
            .maybeSingle();
        title = community?['name'] as String? ?? 'Community chat';
        avatarUrl = community?['avatar_url'] as String?;
      }

      final unread = (p['unread_count'] as int?) ?? 0;
      list.add(ConversationEntity(
        id: convId,
        type: conv['type'] as String,
        squadId: conv['squad_id'] as String?,
        communityId: conv['community_id'] as String?,
        title: title,
        avatarUrl: avatarUrl,
        otherUserId: otherUserId,
        isVerified: conversationVerified,
        lastMessage: lastMsg?['body'] as String?,
        lastMessageAt: lastMsg != null
            ? DateTime.tryParse(lastMsg['created_at'] as String? ?? '')
            : null,
        unread: unread > 0,
        unreadCount: unread,
        pinned: p['pinned'] as bool? ?? false,
        muted: p['muted'] as bool? ?? false,
        archived: p['archived'] as bool? ?? false,
        isRequest: conv['is_request'] as bool? ?? false,
      ));
    }

    list.sort((a, b) {
      final aa = a.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bb = b.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bb.compareTo(aa);
    });
    return list;
  }

  Future<List<MessageEntity>> getMessages(String conversationId,
      {int limit = 50}) async {
    final rows = await _client
        .from('messages')
        .select('''
          id, conversation_id, sender_id, body, created_at, media_url, media_type, pinned,
          profiles!messages_sender_id_fkey ( username, gamer_name, avatar_url, is_verified )
        ''')
        .eq('conversation_id', conversationId)
        .eq('is_deleted', false)
        .order('created_at', ascending: true)
        .limit(limit);

    final list = (rows as List).map((r) {
      final m = Map<String, dynamic>.from(r as Map);
      final p = m['profiles'] as Map<String, dynamic>?;
      final name = (p?['gamer_name'] as String?)?.isNotEmpty == true
          ? p!['gamer_name'] as String
          : p?['username'] as String? ?? '';
      return MessageEntity(
        id: m['id'] as String,
        conversationId: m['conversation_id'] as String,
        senderId: m['sender_id'] as String,
        senderName: name,
        senderAvatar: p?['avatar_url'] as String?,
        senderVerified: p?['is_verified'] == true,
        body: m['body'] as String? ?? '',
        createdAt: DateTime.parse(m['created_at'] as String),
        isMine: m['sender_id'] == _uid,
        mediaUrl: m['media_url'] as String?,
        mediaType: m['media_type'] as String?,
        pinned: m['pinned'] as bool? ?? false,
      );
    }).toList();

    // Load reactions in one query
    if (list.isNotEmpty) {
      try {
        final ids = list.map((m) => m.id).toList();
        final reacts = await _client
            .from('message_reactions')
            .select('message_id, emoji')
            .inFilter('message_id', ids);
        final Map<String, Map<String, int>> byMsg = {};
        for (final r in reacts as List) {
          final mid = (r as Map)['message_id'] as String;
          final emoji = r['emoji'] as String;
          byMsg.putIfAbsent(mid, () => {});
          byMsg[mid]![emoji] = (byMsg[mid]![emoji] ?? 0) + 1;
        }
        return list
            .map((m) => MessageEntity(
                  id: m.id,
                  conversationId: m.conversationId,
                  senderId: m.senderId,
                  senderName: m.senderName,
                  senderAvatar: m.senderAvatar,
                  senderVerified: m.senderVerified,
                  body: m.body,
                  createdAt: m.createdAt,
                  isMine: m.isMine,
                  mediaUrl: m.mediaUrl,
                  mediaType: m.mediaType,
                  pinned: m.pinned,
                  reactions: byMsg[m.id] ?? const {},
                ))
            .toList();
      } catch (_) {
        return list;
      }
    }
    return list;
  }

  Future<MessageEntity> sendMessage(
    String conversationId,
    String body, {
    String? mediaUrl,
    String? mediaType,
  }) async {
    final row = await _client.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': _uid,
      'body': body.trim(),
      if (mediaUrl != null) 'media_url': mediaUrl,
      if (mediaType != null) 'media_type': mediaType,
    }).select('''
      id, conversation_id, sender_id, body, created_at, media_url, media_type, pinned,
      profiles!messages_sender_id_fkey ( username, gamer_name, avatar_url, is_verified )
    ''').single();

    final m = Map<String, dynamic>.from(row);
    final p = m['profiles'] as Map<String, dynamic>?;
    final name = (p?['gamer_name'] as String?)?.isNotEmpty == true
        ? p!['gamer_name'] as String
        : p?['username'] as String? ?? '';
    return MessageEntity(
      id: m['id'] as String,
      conversationId: m['conversation_id'] as String,
      senderId: m['sender_id'] as String,
      senderName: name,
      senderAvatar: p?['avatar_url'] as String?,
      senderVerified: p?['is_verified'] == true,
      body: m['body'] as String? ?? '',
      createdAt: DateTime.parse(m['created_at'] as String),
      isMine: true,
      mediaUrl: m['media_url'] as String?,
      mediaType: m['media_type'] as String?,
      pinned: m['pinned'] as bool? ?? false,
    );
  }

  Future<String> uploadChatMedia(File file) async {
    final uid = _uid;
    final path = 'chat/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _client.storage.from('media').upload(
          path,
          file,
          fileOptions:
              const FileOptions(contentType: 'image/jpeg', upsert: true),
        );
    return _client.storage.from('media').getPublicUrl(path);
  }

  Future<void> pinMessage(String messageId, bool pinned) async {
    await _client
        .from('messages')
        .update({'pinned': pinned}).eq('id', messageId);
  }

  Future<void> deleteMessage(String messageId) async {
    await _client
        .from('messages')
        .update({
          'is_deleted': true,
          'body': 'This message was deleted',
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', messageId)
        .eq('sender_id', _uid);
  }

  RealtimeChannel subscribeMessages(
    String conversationId,
    void Function(MessageEntity) onInsert,
  ) {
    final channel = _client.channel('messages:$conversationId');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) async {
            final m = payload.newRecord;
            if (m['sender_id'] == _uid) return;
            final profile = await _client
                .from('profiles')
                .select('username, gamer_name, avatar_url, is_verified')
                .eq('id', m['sender_id'] as String)
                .maybeSingle();
            final name = (profile?['gamer_name'] as String?)?.isNotEmpty == true
                ? profile!['gamer_name'] as String
                : profile?['username'] as String? ?? '';
            onInsert(MessageEntity(
              id: m['id'] as String,
              conversationId: m['conversation_id'] as String,
              senderId: m['sender_id'] as String,
              senderName: name,
              senderAvatar: profile?['avatar_url'] as String?,
              senderVerified: profile?['is_verified'] == true,
              body: m['body'] as String? ?? '',
              createdAt: DateTime.parse(m['created_at'] as String),
              isMine: false,
            ));
          },
        )
        .subscribe();
    return channel;
  }

  Future<void> setConversationPinned(String conversationId, bool pinned) async {
    await _client
        .from('conversation_participants')
        .update({
          'pinned': pinned,
        })
        .eq('conversation_id', conversationId)
        .eq('user_id', _uid);
  }

  Future<void> setConversationMuted(String conversationId, bool muted) async {
    await _client
        .from('conversation_participants')
        .update({
          'muted': muted,
        })
        .eq('conversation_id', conversationId)
        .eq('user_id', _uid);
  }

  Future<void> archiveConversation(String conversationId) async {
    await _client
        .from('conversation_participants')
        .update({
          'archived': true,
        })
        .eq('conversation_id', conversationId)
        .eq('user_id', _uid);
  }

  Future<void> markConversationRead(String conversationId) async {
    await _client
        .from('conversation_participants')
        .update({
          'unread_count': 0,
          'last_read_at': DateTime.now().toIso8601String(),
        })
        .eq('conversation_id', conversationId)
        .eq('user_id', _uid);
  }

  Future<void> reactToMessage(String messageId, String emoji) async {
    await _client.from('message_reactions').upsert({
      'message_id': messageId,
      'user_id': _uid,
      'emoji': emoji,
    });
  }

  /// Other participant's last_read_at (for read receipts on DMs).
  Future<DateTime?> otherLastReadAt(String conversationId) async {
    final rows = await _client
        .from('conversation_participants')
        .select('user_id, last_read_at')
        .eq('conversation_id', conversationId)
        .neq('user_id', _uid);
    if ((rows as List).isEmpty) return null;
    final ts = (rows.first as Map)['last_read_at'] as String?;
    return ts != null ? DateTime.tryParse(ts) : null;
  }

  /// Broadcast typing via realtime channel (ephemeral).
  RealtimeChannel subscribeTyping(
    String conversationId,
    void Function(String userId, bool isTyping) onTyping,
  ) {
    final channel = _client.channel('typing:$conversationId');
    channel
        .onBroadcast(
          event: 'typing',
          callback: (payload) {
            final data = payload;
            final uid = data['user_id'] as String?;
            final typing = data['typing'] as bool? ?? false;
            if (uid != null && uid != _uid) {
              onTyping(uid, typing);
            }
          },
        )
        .subscribe();
    return channel;
  }

  Future<void> sendTyping(String conversationId, bool isTyping) async {
    final channel = _client.channel('typing:$conversationId');
    await channel.sendBroadcastMessage(
      event: 'typing',
      payload: {'user_id': _uid, 'typing': isTyping},
    );
  }
}
