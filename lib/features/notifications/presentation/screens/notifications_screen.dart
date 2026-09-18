
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/kx_empty_state.dart';
import '../../../../core/widgets/kx_error_view.dart';
import '../../domain/notification_entity.dart';
import '../providers/notification_provider.dart';
import 'notification_settings_screen.dart';
import '../../../../core/errors/error_handler.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _open(NotificationEntity n) {
    final type = n.targetType;
    final id = n.targetId;
    if (type == null || id == null) return;
    switch (type) {
      case 'post':
        context.push('/post/$id');
      case 'profile':
        context.push('/user/$id');
      case 'squad':
        context.push('/squad/$id');
      case 'community':
      case 'game':
        context.push('/community/$id');
      case 'conversation':
        context.push('/chat/$id');
      default:
        break;
    }
  }

  IconData _icon(String type) {
    switch (type) {
      case 'like':
        return Icons.favorite;
      case 'comment':
      case 'reply':
        return Icons.chat_bubble_outline;
      case 'follow':
        return Icons.person_add_alt_1;
      case 'mention':
        return Icons.alternate_email;
      case 'squad_invite':
      case 'squad_request':
      case 'squad_approved':
      case 'squad_announcement':
        return Icons.groups;
      case 'community_announcement':
        return Icons.sports_esports;
      case 'security':
        return Icons.lock_outline;
      case 'moderation':
        return Icons.gavel;
      default:
        return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () async {
              await ref.read(notificationRepositoryProvider).markAllRead();
              ref.invalidate(notificationsListProvider);
              ref.invalidate(unreadNotificationsProvider);
            },
            child: const Text('Mark all read'),
          ),
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Social'),
            Tab(text: 'Squads'),
            Tab(text: 'Games'),
            Tab(text: 'System'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          for (final cat in ['all', 'social', 'squads', 'games', 'system'])
            _List(category: cat, onOpen: _open, iconFor: _icon),
        ],
      ),
    );
  }
}

class _List extends ConsumerWidget {
  const _List({required this.category, required this.onOpen, required this.iconFor});
  final String category;
  final void Function(NotificationEntity) onOpen;
  final IconData Function(String) iconFor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationsListProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => KxErrorView(
        message: ErrorHandler.userMessage(e),
        onRetry: () => ref.invalidate(notificationsListProvider),
      ),
      data: (all) {
        final list = category == 'all'
            ? all
            : all.where((n) => n.category == category).toList();
        if (list.isEmpty) {
          return const KxEmptyState(
            title: 'No notifications',
            subtitle: 'Likes, follows, squads and game activity appear here.',
            icon: Icons.notifications_none,
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(notificationsListProvider);
            await ref.read(notificationsListProvider.future);
          },
          child: ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final n = list[i];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                leading: Stack(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: AppColors.surfaceElevated,
                      backgroundImage: n.actorAvatarUrl != null
                          ? CachedNetworkImageProvider(n.actorAvatarUrl!)
                          : null,
                      child: n.actorAvatarUrl == null
                          ? Icon(iconFor(n.type), size: 20)
                          : null,
                    ),
                    if (!n.isRead)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Color(0xFF20D5EC),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
                title: Text(
                  n.displayTitle,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: n.isRead ? FontWeight.w400 : FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (n.body != null && n.body!.isNotEmpty)
                      Text(n.body!, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTextStyles.caption),
                    Text(_rel(n.createdAt), style: AppTextStyles.caption.copyWith(fontSize: 11)),
                  ],
                ),
                onTap: () async {
                  if (!n.isRead) {
                    await ref.read(notificationRepositoryProvider).markRead(n.id);
                    ref.invalidate(notificationsListProvider);
                    ref.invalidate(unreadNotificationsProvider);
                  }
                  onOpen(n);
                },
              );
            },
          ),
        );
      },
    );
  }

  static String _rel(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 1) return 'just now';
    if (d.inHours < 1) return '${d.inMinutes}m ago';
    if (d.inDays < 1) return '${d.inHours}h ago';
    if (d.inDays < 7) return '${d.inDays}d ago';
    return DateFormat.MMMd().add_jm().format(dt.toLocal());
  }
}
