import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/dependency_injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/kx_verified_badge.dart';
import '../../domain/entities/chat_entity.dart';
import '../providers/chat_provider.dart';
import '../../../calls/presentation/providers/call_controller.dart';

class ChatRoomScreen extends ConsumerStatefulWidget {
  const ChatRoomScreen({super.key, required this.conversationId});
  final String conversationId;

  @override
  ConsumerState<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends ConsumerState<ChatRoomScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  List<MessageEntity> _messages = [];
  bool _loading = true;
  bool _sending = false;
  bool _muted = false;
  RealtimeChannel? _channel;
  String _title = 'Chat';
  bool _someoneTyping = false;
  DateTime? _otherLastRead;
  RealtimeChannel? _typingChannel;
  // Populated only for DM conversations — resolved from the other
  // participant's real profile, never a placeholder name.
  String? _otherUserId;
  String? _otherAvatarUrl;
  bool _isCommunityChat = false;
<<<<<<< HEAD
  bool _isSquadChat = false;
=======
>>>>>>> origin/main
  DateTime? _otherLastSeen;
  Timer? _presencePoll;

  static const _emojis = ['👍', '❤️', '🔥', '😂', '😮', '🎮'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await ref
        .read(chatRepositoryProvider)
        .getMessages(widget.conversationId);
    if (!mounted) return;
    setState(() {
      _messages = r.valueOrNull ?? [];
      _loading = false;
    });
    _channel = ref.read(chatRepositoryProvider).subscribeMessages(
      widget.conversationId,
      (msg) {
        if (!mounted) return;
        setState(() => _messages = [..._messages, msg]);
        _scrollToEnd();
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
    ref
        .read(chatRepositoryProvider)
        .markConversationRead(widget.conversationId);

    _typingChannel = ref.read(chatRepositoryProvider).subscribeTyping(
      widget.conversationId,
      (uid, typing) {
        if (!mounted) return;
        setState(() => _someoneTyping = typing);
      },
    );
    final lr = await ref
        .read(chatRepositoryProvider)
        .otherLastReadAt(widget.conversationId);
    if (mounted) setState(() => _otherLastRead = lr.valueOrNull);

    try {
      final client = ref.read(supabaseClientProvider);
      final conv = await client
          .from('conversations')
          .select('type, squad_id, community_id, title')
          .eq('id', widget.conversationId)
          .maybeSingle();
      if (conv != null && mounted) {
        if (conv['type'] == 'squad' && conv['squad_id'] != null) {
          final s = await client
              .from('squads')
<<<<<<< HEAD
              .select('name, logo_url')
              .eq('id', conv['squad_id'])
              .maybeSingle();
          setState(() {
            _title = s?['name'] as String? ?? 'Squad Chat';
            _otherAvatarUrl = s?['logo_url'] as String?;
            _isSquadChat = true;
          });
=======
              .select('name')
              .eq('id', conv['squad_id'])
              .maybeSingle();
          setState(() => _title = s?['name'] as String? ?? 'Squad Chat');
>>>>>>> origin/main
        } else if (conv['type'] == 'community' &&
            conv['community_id'] != null) {
          final c = await client
              .from('communities')
              .select('name, avatar_url')
              .eq('id', conv['community_id'])
              .maybeSingle();
          setState(() {
            _title = c?['name'] as String? ?? 'Community Chat';
            _otherAvatarUrl = c?['avatar_url'] as String?;
            _isCommunityChat = true;
          });
        } else if (conv['type'] == 'dm') {
          // DMs never get a stored title — the header must be the other
          // participant's real name, not a generic fallback.
          await _loadOtherParticipant(client);
        } else {
          setState(() => _title = conv['title'] as String? ?? 'Chat');
        }
      }
    } catch (_) {}
  }

  Future<void> _loadOtherParticipant(SupabaseClient client) async {
    final me = client.auth.currentUser?.id;
    final parts = await client
        .from('conversation_participants')
        .select(
            'user_id, profiles!conversation_participants_user_id_fkey(username, gamer_name, avatar_url, last_seen)')
        .eq('conversation_id', widget.conversationId);
    for (final r in parts as List) {
      final row = r as Map;
      if (row['user_id'] == me) continue;
      final p = row['profiles'] as Map?;
      final name = (p?['gamer_name'] as String?)?.isNotEmpty == true
          ? p!['gamer_name'] as String
          : (p?['username'] as String? ?? 'User');
      if (!mounted) return;
      setState(() {
        _title = name;
        _otherUserId = row['user_id'] as String?;
        _otherAvatarUrl = p?['avatar_url'] as String?;
        _otherLastSeen = p?['last_seen'] != null
            ? DateTime.tryParse(p!['last_seen'] as String)
            : null;
      });
      break;
    }
    // Real presence, refreshed while this screen is open — same threshold
    // as ProfileEntity.isOnline / StoryRing.isOnline (2 minutes since the
    // other user's app last heartbeat via PresenceService).
    _presencePoll?.cancel();
    _presencePoll = Timer.periodic(const Duration(seconds: 30), (_) async {
      final uid = _otherUserId;
      if (uid == null || !mounted) return;
      final row = await client
          .from('profiles')
          .select('last_seen')
          .eq('id', uid)
          .maybeSingle();
      if (!mounted) return;
      final seen = row?['last_seen'] != null
          ? DateTime.tryParse(row!['last_seen'] as String)
          : null;
      setState(() => _otherLastSeen = seen);
    });
  }

  bool get _otherIsOnline =>
      _otherLastSeen != null &&
      DateTime.now().toUtc().difference(_otherLastSeen!.toUtc()) <
          const Duration(minutes: 2);

  void _scrollToEnd() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      _scroll.position.maxScrollExtent + 80,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _send({String? mediaUrl, String? mediaType}) async {
    final text = _input.text.trim();
    if ((text.isEmpty && mediaUrl == null) || _sending) return;
    setState(() => _sending = true);
    final r = await ref.read(chatRepositoryProvider).sendMessage(
          widget.conversationId,
          text.isEmpty ? (mediaType == 'image' ? '📷 Photo' : '') : text,
          mediaUrl: mediaUrl,
          mediaType: mediaType,
        );
    if (!mounted) return;
    setState(() => _sending = false);
    r.when(
      success: (msg) {
        _input.clear();
        setState(() => _messages = [..._messages, msg]);
        _scrollToEnd();
      },
      failure: (e, _) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      },
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1280,
      imageQuality: 80,
    );
    if (file == null) return;
    setState(() => _sending = true);
    final up =
        await ref.read(chatRepositoryProvider).uploadChatMedia(File(file.path));
    if (!mounted) return;
    final url = up.valueOrNull;
    if (url == null) {
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image upload failed')),
      );
      return;
    }
    await _send(mediaUrl: url, mediaType: 'image');
  }

  Future<void> _react(MessageEntity m, String emoji) async {
    await ref.read(chatRepositoryProvider).reactToMessage(m.id, emoji);
    if (!mounted) return;
    setState(() {
      final idx = _messages.indexWhere((x) => x.id == m.id);
      if (idx < 0) return;
      final map = Map<String, int>.from(m.reactions);
      map[emoji] = (map[emoji] ?? 0) + 1;
      _messages[idx] = MessageEntity(
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
        reactions: map,
      );
    });
  }

  Future<void> _toggleMute() async {
    final next = !_muted;
    await ref
        .read(chatRepositoryProvider)
        .setConversationMuted(widget.conversationId, next);
    if (!mounted) return;
    setState(() => _muted = next);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(next ? 'Notifications muted' : 'Notifications unmuted')),
      );
    }
  }

  Future<void> _pinMessage(MessageEntity m) async {
    final next = !m.pinned;
    await ref.read(chatRepositoryProvider).pinMessage(m.id, next);
    if (!mounted) return;
    setState(() {
      final idx = _messages.indexWhere((x) => x.id == m.id);
      if (idx < 0) return;
      _messages[idx] = MessageEntity(
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
        pinned: next,
        reactions: m.reactions,
      );
    });
  }

  void _showMessageActions(MessageEntity m) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: _emojis.map((e) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      _react(m, e);
                    },
                    child: Text(e, style: const TextStyle(fontSize: 28)),
                  );
                }).toList(),
              ),
            ),
            const Divider(),
            ListTile(
              leading:
                  Icon(m.pinned ? Icons.push_pin : Icons.push_pin_outlined),
              title: Text(m.pinned ? 'Unpin message' : 'Pin message'),
              onTap: () {
                Navigator.pop(ctx);
                _pinMessage(m);
              },
            ),
            if (m.isMine)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Delete message'),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteMessage(m);
                },
              ),
            if (!m.isMine)
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text('View ${m.senderName}'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/user/${m.senderId}');
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteMessage(MessageEntity message) async {
    final result =
        await ref.read(chatRepositoryProvider).deleteMessage(message.id);
    if (!mounted) return;
    if (result.isFailure) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.when(
              success: (_) => 'Delete failed', failure: (e, _) => '$e')),
        ),
      );
      return;
    }
    setState(() {
      _messages = _messages.where((m) => m.id != message.id).toList();
    });
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _typingChannel?.unsubscribe();
    _presencePoll?.cancel();
    try {
      ref.read(chatRepositoryProvider).sendTyping(widget.conversationId, false);
    } catch (_) {}
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _showParticipants() async {
    final r = await ref
        .read(chatRepositoryProvider)
        .listParticipants(widget.conversationId);
    if (!mounted) return;
    final rows = r.valueOrNull ?? [];
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child:
                  Text('Members (${rows.length})', style: AppTextStyles.title),
            ),
            ...rows.map((row) {
              final profile = row['profiles'] as Map?;
              final name = profile?['gamer_name'] as String? ??
                  profile?['username'] as String? ??
                  'User';
              final avatar = profile?['avatar_url'] as String?;
              final role = row['role'] as String? ?? 'member';
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                  child: avatar == null
                      ? Text(name.isNotEmpty ? name[0] : '?')
                      : null,
                ),
                title: Text(name),
                subtitle: Text(role),
                onTap: () {
                  Navigator.pop(ctx);
                  final uid = row['user_id'] as String?;
                  if (uid != null) context.push('/user/$uid');
                },
              );
            }),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pinned = _messages.where((m) => m.pinned).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
<<<<<<< HEAD
            if (_otherUserId != null || _isCommunityChat || _isSquadChat) ...[
              GestureDetector(
                onTap: _otherUserId != null
                    ? () => context.push('/user/$_otherUserId')
                    : (_isCommunityChat || _isSquadChat)
                        ? _showParticipants
                        : null,
=======
            if (_otherUserId != null || _isCommunityChat) ...[
              GestureDetector(
                onTap: _otherUserId == null
                    ? null
                    : () => context.push('/user/$_otherUserId'),
>>>>>>> origin/main
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.surfaceElevated,
                      backgroundImage: _otherAvatarUrl != null
                          ? NetworkImage(_otherAvatarUrl!)
                          : null,
                      child: _otherAvatarUrl == null
                          ? Text(
                              _title.isNotEmpty ? _title[0].toUpperCase() : '?')
                          : null,
                    ),
                    if (_otherIsOnline)
                      Positioned(
                        right: -1,
                        bottom: -1,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: const Color(0xFF22C55E),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: AppColors.background, width: 1.5),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _otherUserId != null
                        ? (_otherIsOnline
                            ? 'Online'
                            : 'Tap & hold a message for reactions')
                        : 'Tap & hold a message for reactions',
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 11,
                      color: _otherUserId != null && _otherIsOnline
                          ? const Color(0xFF22C55E)
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.people_outline),
            tooltip: 'Members',
            onPressed: _showParticipants,
          ),
          IconButton(
            icon: Icon(_muted
                ? Icons.notifications_off_outlined
                : Icons.notifications_outlined),
            tooltip: _muted ? 'Unmute' : 'Mute',
            onPressed: _toggleMute,
          ),
          IconButton(
            icon: const Icon(Icons.call),
            tooltip: 'Voice call',
            onPressed: () async {
              final client = ref.read(supabaseClientProvider);
              final me = client.auth.currentUser?.id;
              final parts = await client
                  .from('conversation_participants')
                  .select(
                      'user_id, profiles!conversation_participants_user_id_fkey(username,gamer_name,avatar_url)')
                  .eq('conversation_id', widget.conversationId);
              String? otherId;
              String otherName = 'User';
              String? otherAvatar;
              for (final r in parts as List) {
                if ((r as Map)['user_id'] != me) {
                  otherId = r['user_id'] as String?;
                  final p = r['profiles'] as Map?;
                  otherName = p?['gamer_name'] as String? ??
                      p?['username'] as String? ??
                      'User';
                  otherAvatar = p?['avatar_url'] as String?;
                  break;
                }
              }
              final conv = await client
                  .from('conversations')
                  .select('type, squad_id')
                  .eq('id', widget.conversationId)
                  .maybeSingle();
              if (!mounted) return;
              if (conv != null &&
                  conv['type'] == 'squad' &&
                  conv['squad_id'] != null) {
                final squad = await client
                    .from('squads')
                    .select('name')
                    .eq('id', conv['squad_id'])
                    .maybeSingle();
                await ref.read(callControllerProvider.notifier).startSquadCall(
                      squadId: conv['squad_id'] as String,
                      conversationId: widget.conversationId,
                      squadName: squad?['name'] as String?,
                    );
                return;
              }
              if (otherId == null) return;
              await ref.read(callControllerProvider.notifier).startDmCall(
                    conversationId: widget.conversationId,
                    calleeId: otherId,
                    calleeName: otherName,
                    calleeAvatar: otherAvatar,
                  );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (pinned.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: AppColors.primary.withValues(alpha: 0.12),
              child: Row(
                children: [
                  const Icon(Icons.push_pin,
                      size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      pinned.last.body.isNotEmpty
                          ? pinned.last.body
                          : (pinned.last.mediaUrl != null
                              ? '📷 Photo'
                              : 'Pinned'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
          if (_someoneTyping)
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 4),
              child: Text(
                'typing...',
                style: AppTextStyles.caption.copyWith(
                  fontStyle: FontStyle.italic,
                  color: AppColors.primary,
                ),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scroll,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) {
                      final m = _messages[i];
                      final seen = m.isMine &&
                          _otherLastRead != null &&
                          !m.createdAt.isAfter(_otherLastRead!);
                      return _MessageBubble(
                        message: m,
                        timeStr: _formatTime(m.createdAt),
                        seen: seen,
                        onLongPress: () => _showMessageActions(m),
                        onTapAvatar: m.isMine
                            ? null
                            : () => context.push('/user/${m.senderId}'),
                      );
                    },
                  ),
          ),
          SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border:
                    Border(top: BorderSide(color: AppColors.surfaceElevated)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.emoji_emotions_outlined, size: 22),
                    color: AppColors.textMuted,
                    onPressed: () {},
                  ),
                  Expanded(
                    child: TextField(
                      controller: _input,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        filled: true,
                        fillColor: AppColors.surfaceElevated,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      textInputAction: TextInputAction.send,
                      onChanged: (v) {
                        ref.read(chatRepositoryProvider).sendTyping(
                              widget.conversationId,
                              v.trim().isNotEmpty,
                            );
                      },
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.photo_camera_outlined, size: 22),
                    color: AppColors.textMuted,
                    onPressed: _sending ? null : _pickImage,
                    tooltip: 'Photo',
                  ),
                  IconButton(
                    onPressed: _sending ? null : () => _send(),
                    icon: Icon(
                      Icons.send_rounded,
                      color: _sending ? AppColors.textMuted : AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.timeStr,
    required this.onLongPress,
    this.onTapAvatar,
    this.seen = false,
  });

  final MessageEntity message;
  final String timeStr;
  final VoidCallback onLongPress;
  final VoidCallback? onTapAvatar;
  final bool seen;

  @override
  Widget build(BuildContext context) {
    final m = message;
    return Align(
      alignment: m.isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!m.isMine) ...[
            GestureDetector(
              onTap: onTapAvatar,
              child: CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.surfaceElevated,
                backgroundImage: m.senderAvatar != null
                    ? NetworkImage(m.senderAvatar!)
                    : null,
                child: m.senderAvatar == null
                    ? Text(
                        m.senderName.isNotEmpty
                            ? m.senderName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(fontSize: 12),
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(child: _bubbleBody(context, m)),
        ],
      ),
    );
  }

  Widget _bubbleBody(BuildContext context, MessageEntity m) {
    return GestureDetector(
      onLongPress: onLongPress,
      onTap: m.isMine ? null : onTapAvatar,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        decoration: BoxDecoration(
          color: m.isMine ? AppColors.primary : AppColors.surfaceElevated,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(m.isMine ? 16 : 4),
            bottomRight: Radius.circular(m.isMine ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!m.isMine) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    m.senderName,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (m.senderVerified)
                    const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: KxVerifiedBadge(size: 13),
                    ),
                ],
              ),
              const SizedBox(height: 2),
            ],
            if (m.mediaUrl != null && m.mediaType == 'image') ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  m.mediaUrl!,
                  width: 220,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
                ),
              ),
              if (m.body.isNotEmpty && m.body != '📷 Photo')
                const SizedBox(height: 4),
            ],
            if (m.body.isNotEmpty && m.body != '📷 Photo')
              _MessageBody(body: m.body, mine: m.isMine),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (m.pinned)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(
                      Icons.push_pin,
                      size: 12,
                      color: m.isMine ? Colors.white70 : AppColors.primary,
                    ),
                  ),
                Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: 10,
                    color: m.isMine ? Colors.white70 : AppColors.textMuted,
                  ),
                ),
                if (m.isMine) ...[
                  const SizedBox(width: 4),
                  Icon(
                    seen ? Icons.done_all : Icons.done,
                    size: 14,
                    color: seen ? const Color(0xFF93C5FD) : Colors.white70,
                  ),
                ],
              ],
            ),
            if (m.reactions.isNotEmpty) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                children: m.reactions.entries.map((e) {
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (m.isMine ? Colors.white : AppColors.primary)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${e.key} ${e.value}',
                      style: TextStyle(
                        fontSize: 11,
                        color: m.isMine ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MessageBody extends StatelessWidget {
  const _MessageBody({required this.body, required this.mine});

  final String body;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final match =
        RegExp(r'https?://[^\s]+', caseSensitive: false).firstMatch(body);
    final url = match == null ? null : Uri.tryParse(match.group(0)!);
    final style = AppTextStyles.body.copyWith(
      color: mine ? Colors.white : AppColors.textPrimary,
      decoration: url == null ? TextDecoration.none : TextDecoration.underline,
    );
    return GestureDetector(
      onTap: url == null
          ? null
          : () async {
              if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Unable to open link')),
                  );
                }
              }
            },
      child: Text(body, style: style),
    );
  }
}
