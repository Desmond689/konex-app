import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/kx_empty_state.dart';
import '../../../../core/widgets/kx_error_view.dart';
import '../../../../core/widgets/kx_verified_badge.dart';
import '../../domain/entities/chat_entity.dart';
import '../providers/chat_provider.dart';
import '../../../../core/errors/error_handler.dart';

class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  final _search = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(inboxProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Inbox')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => KxErrorView(
          message: ErrorHandler.userMessage(e),
          onRetry: () => ref.invalidate(inboxProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return const KxEmptyState(
              title: 'No conversations',
              subtitle:
                  'Message a gamer from their profile, or open squad chat.',
              icon: Icons.chat_bubble_outline,
            );
          }

          final filtered = _q.isEmpty
              ? list
              : list
                  .where((c) =>
                      (c.title ?? '')
                          .toLowerCase()
                          .contains(_q.toLowerCase()) ||
                      (c.lastMessage ?? '')
                          .toLowerCase()
                          .contains(_q.toLowerCase()))
                  .toList();

          final pinned = filtered.where((c) => c.pinned).toList();
          final rest = filtered.where((c) => !c.pinned).toList()
            ..sort((a, b) {
              final at = a.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
              final bt = b.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
              return bt.compareTo(at);
            });

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: TextField(
                  controller: _search,
                  onChanged: (v) => setState(() => _q = v.trim()),
                  decoration: InputDecoration(
                    hintText: 'Search messages',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: AppColors.surfaceElevated,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async => ref.invalidate(inboxProvider),
                  child: ListView(
                    children: [
                      if (pinned.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                          child: Text('Pinned', style: AppTextStyles.caption),
                        ),
                        for (final c in pinned) _tile(c),
                        const Divider(),
                      ],
                      for (final c in rest) _tile(c),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _tile(ConversationEntity c) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.surfaceElevated,
        backgroundImage:
            c.avatarUrl != null ? NetworkImage(c.avatarUrl!) : null,
        child: c.avatarUrl == null
            ? Icon(
                c.type == 'squad' ? Icons.shield : Icons.person,
                size: 20,
              )
            : null,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              c.title ?? 'Chat',
              style: AppTextStyles.title.copyWith(fontSize: 15),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (c.muted)
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(Icons.volume_off, size: 14),
            ),
          if (c.isVerified)
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: KxVerifiedBadge(size: 15),
            ),
        ],
      ),
      subtitle: Text(
        c.lastMessage ?? '',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.caption.copyWith(
          fontWeight: c.unreadCount > 0 ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (c.lastMessageAt != null)
            Text(
              DateFormat.MMMd().format(c.lastMessageAt!.toLocal()),
              style: AppTextStyles.caption.copyWith(fontSize: 11),
            ),
          if (c.unreadCount > 0) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                c.unreadCount > 99 ? '99+' : '${c.unreadCount}',
                style: const TextStyle(fontSize: 11, color: Colors.white),
              ),
            ),
          ],
        ],
      ),
      onTap: () => context.push('/chat/${c.id}'),
      onLongPress: () => _menu(c),
    );
  }

  Future<void> _menu(ConversationEntity c) async {
    final repo = ref.read(chatRepositoryProvider);
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(c.pinned ? Icons.push_pin_outlined : Icons.push_pin),
              title: Text(c.pinned ? 'Unpin' : 'Pin'),
              onTap: () async {
                Navigator.pop(ctx);
                await repo.setConversationPinned(c.id, !c.pinned);
                ref.invalidate(inboxProvider);
              },
            ),
            ListTile(
              leading: Icon(c.muted ? Icons.volume_up : Icons.volume_off),
              title: Text(c.muted ? 'Unmute' : 'Mute'),
              onTap: () async {
                Navigator.pop(ctx);
                await repo.setConversationMuted(c.id, !c.muted);
                ref.invalidate(inboxProvider);
              },
            ),
            ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: const Text('Archive'),
              onTap: () async {
                Navigator.pop(ctx);
                await repo.archiveConversation(c.id);
                ref.invalidate(inboxProvider);
              },
            ),
          ],
        ),
      ),
    );
  }
}
