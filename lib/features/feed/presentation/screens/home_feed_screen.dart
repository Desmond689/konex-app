import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../notifications/presentation/providers/notification_provider.dart';
import '../../../chat/presentation/providers/chat_provider.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/kx_empty_state.dart';
import '../../../../core/widgets/kx_error_view.dart';
import '../../../communities/presentation/providers/community_provider.dart';
import '../../../lfg/presentation/screens/create_lfg_screen.dart';
import '../../../lfg/presentation/screens/create_poll_screen.dart';
import '../../../media/presentation/create_video_post_screen.dart';
import '../../../posts/presentation/providers/post_provider.dart';
import '../../../posts/presentation/widgets/post_card.dart';
import '../../../posts/presentation/widgets/composer_sheet.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../squads/presentation/providers/squad_provider.dart';
import '../../../stories/presentation/widgets/stories_row.dart';

/// Home — "For You" feed matching the KONEX design (quick-access row,
/// composer bar, per-game filter pills, squad spotlight, live feed).
class HomeFeedScreen extends ConsumerStatefulWidget {
  const HomeFeedScreen({super.key});

  @override
  ConsumerState<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends ConsumerState<HomeFeedScreen>
    with SingleTickerProviderStateMixin {
  final _scroll = ScrollController();
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(() {
      if (_tabs.indexIsChanging) return;
      final mode = switch (_tabs.index) {
        1 => 'following',
        2 => 'latest',
        _ => 'forYou',
      };
      ref.read(feedControllerProvider.notifier).setMode(mode);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(feedControllerProvider.notifier).loadInitial();
    });
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 400) {
        ref.read(feedControllerProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _openComposer() async {
    final created =
        await showCreatePostSheet(context, origin: ComposerOrigin.home);
    if (created == true) {
      ref.read(feedControllerProvider.notifier).loadInitial();
    }
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(feedControllerProvider);
    final myGames = ref.watch(myCommunitiesProvider);
    final me = ref.watch(myProfileProvider).valueOrNull;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(feedControllerProvider.notifier).loadInitial(),
        color: AppColors.primary,
        child: CustomScrollView(
          controller: _scroll,
          slivers: [
            SliverAppBar(
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 28,
                      height: 28,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('KONEX',
                      style: AppTextStyles.brand
                          .copyWith(fontSize: 18, letterSpacing: 1.5)),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => context.push(Routes.search),
                ),
                IconButton(
                  tooltip: 'Inbox',
                  onPressed: () => context.go(Routes.inbox),
                  icon: Badge(
                    isLabelVisible: (ref.watch(inboxProvider).valueOrNull ?? [])
                            .fold<int>(0, (s, c) => s + c.unreadCount) >
                        0,
                    label: Text(
                      () {
                        final n = (ref.watch(inboxProvider).valueOrNull ?? [])
                            .fold<int>(0, (s, c) => s + c.unreadCount);
                        return n > 99 ? '99+' : '$n';
                      }(),
                      style: const TextStyle(fontSize: 10),
                    ),
                    child: const Icon(Icons.chat_bubble_outline),
                  ),
                ),
                IconButton(
                  onPressed: () => context.push(Routes.notifications),
                  icon: Badge(
                    isLabelVisible:
                        (ref.watch(unreadNotificationsProvider).valueOrNull ??
                                0) >
                            0,
                    label: Text(
                      () {
                        final n = ref
                                .watch(unreadNotificationsProvider)
                                .valueOrNull ??
                            0;
                        return n > 99 ? '99+' : '$n';
                      }(),
                      style: const TextStyle(fontSize: 10),
                    ),
                    child: const Icon(Icons.notifications_outlined),
                  ),
                ),
              ],
              bottom: TabBar(
                controller: _tabs,
                tabs: const [
                  Tab(text: 'For You'),
                  Tab(text: 'Following'),
                  Tab(text: 'Latest'),
                ],
              ),
              floating: false,
              pinned: false,
            ),
            const SliverToBoxAdapter(child: StoriesRow()),
            SliverToBoxAdapter(
              child: _ComposerBar(
                name: me?.displayName ?? 'gamer',
                avatarUrl: me?.avatarUrl,
                onTap: _openComposer,
                onVideo: () async {
                  final created = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                        builder: (_) => const CreateVideoPostScreen()),
                  );
                  if (created == true) {
                    ref.read(feedControllerProvider.notifier).loadInitial();
                  }
                },
                onPoll: () async {
                  final created = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(builder: (_) => const CreatePollScreen()),
                  );
                  if (created == true) {
                    ref.read(feedControllerProvider.notifier).loadInitial();
                  }
                },
                onEvent: () async {
                  await Navigator.of(context).push<bool>(
                    MaterialPageRoute(builder: (_) => const CreateLfgScreen()),
                  );
                },
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _FilterHeaderDelegate(
                child: _FilterPillsRow(
                  asyncGames: myGames,
                  selectedId: feed.communityFilter,
                  onSelect: (id) => ref
                      .read(feedControllerProvider.notifier)
                      .setCommunityFilter(id),
                ),
              ),
            ),
            ..._buildBodySlivers(feed, myGames),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildBodySlivers(FeedState feed, AsyncValue myGames) {
    final noGames = myGames.maybeWhen(
      data: (list) => list.isEmpty,
      orElse: () => false,
    );

    if (feed.loading && feed.posts.isEmpty) {
      return const [
        SliverFillRemaining(
          child: Center(
              child: CircularProgressIndicator(color: AppColors.primary)),
        ),
      ];
    }
    if (feed.error != null && feed.posts.isEmpty) {
      return [
        SliverFillRemaining(
          child: KxErrorView(
            message: feed.error!,
            onRetry: () =>
                ref.read(feedControllerProvider.notifier).loadInitial(),
          ),
        ),
      ];
    }

    if (noGames && feed.mode == 'forYou' && feed.posts.isEmpty) {
      return [
        SliverFillRemaining(
          child: KxEmptyState(
            title: 'Welcome to KONEX',
            subtitle: 'Choose the games you play to personalize your feed.',
            icon: Icons.sports_esports_outlined,
            action: TextButton(
              onPressed: () => context.go(Routes.communities),
              child: const Text('Choose Games'),
            ),
          ),
        ),
      ];
    }

    if (feed.posts.isEmpty) {
      return [
        SliverFillRemaining(
          child: KxEmptyState(
            title: feed.mode == 'following'
                ? 'No posts from people you follow'
                : 'No posts yet',
            subtitle: feed.mode == 'following'
                ? 'Follow gamers to see their posts here.'
                : 'Be the first to share a clip or thought.',
            icon: Icons.sports_esports_outlined,
          ),
        ),
      ];
    }

    return [
      const SliverToBoxAdapter(child: _SquadSpotlightCard()),
      SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, i) => PostCard(
            key: ValueKey(feed.posts[i].id),
            post: feed.posts[i],
          ),
          childCount: feed.posts.length,
        ),
      ),
      if (feed.loadingMore)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      const SliverPadding(
        padding: EdgeInsets.only(bottom: 96),
        sliver: SliverToBoxAdapter(child: SizedBox.shrink()),
      ),
    ];
  }
}

class _FilterHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _FilterHeaderDelegate({required this.child});
  final Widget child;

  @override
  double get minExtent => 44;

  @override
  double get maxExtent => 44;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Material(
      color: AppColors.background,
      elevation: overlapsContent ? 2 : 0,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _FilterHeaderDelegate oldDelegate) =>
      oldDelegate.child != child;
}

/// "What's on your mind" composer bar that opens the create-post sheet,
/// plus the Photo / Video / Poll / Event quick-action row beneath it.
class _ComposerBar extends StatelessWidget {
  const _ComposerBar({
    required this.name,
    required this.avatarUrl,
    required this.onTap,
    required this.onVideo,
    required this.onPoll,
    required this.onEvent,
  });
  final String name;
  final String? avatarUrl;
  final VoidCallback onTap;
  final VoidCallback onVideo;
  final VoidCallback onPoll;
  final VoidCallback onEvent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.3),
                    backgroundImage: avatarUrl != null
                        ? CachedNetworkImageProvider(avatarUrl!)
                        : null,
                    child: avatarUrl == null
                        ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?')
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text("What's on your mind, $name?",
                        style: AppTextStyles.bodySecondary),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(height: 1, color: AppColors.border),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _ComposerAction(
                    icon: Icons.image_outlined, label: 'Photo', onTap: onTap),
                _ComposerAction(
                    icon: Icons.videocam_outlined,
                    label: 'Video',
                    onTap: onVideo),
                _ComposerAction(
                    icon: Icons.poll_outlined, label: 'Poll', onTap: onPoll),
                _ComposerAction(
                    icon: Icons.event_outlined, label: 'Event', onTap: onEvent),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ComposerAction extends StatelessWidget {
  const _ComposerAction(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AppColors.textMuted),
            const SizedBox(width: 5),
            Text(label, style: AppTextStyles.caption.copyWith(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _FilterPillsRow extends StatelessWidget {
  const _FilterPillsRow({
    required this.asyncGames,
    required this.selectedId,
    required this.onSelect,
  });

  final AsyncValue asyncGames;
  final String? selectedId;
  final void Function(String? id) onSelect;

  @override
  Widget build(BuildContext context) {
    return asyncGames.when(
      loading: () => const SizedBox(height: 44),
      error: (_, __) => const SizedBox.shrink(),
      data: (games) {
        return SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: const Text('All'),
                  avatar: selectedId == null
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : null,
                  selected: selectedId == null,
                  selectedColor: AppColors.primary,
                  showCheckmark: false,
                  labelStyle: TextStyle(
                    color: selectedId == null
                        ? Colors.white
                        : AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  onSelected: (_) => onSelect(null),
                ),
              ),
              ...games.map(
                (g) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    avatar: g.avatarUrl != null
                        ? CircleAvatar(
                            backgroundImage:
                                CachedNetworkImageProvider(g.avatarUrl!))
                        : const Icon(Icons.sports_esports, size: 16),
                    label: Text(g.name),
                    selected: selectedId == g.id,
                    selectedColor: AppColors.primary,
                    showCheckmark: false,
                    labelStyle: TextStyle(
                      color: selectedId == g.id
                          ? Colors.white
                          : AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    onSelected: (sel) => onSelect(sel ? g.id : null),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SquadSpotlightCard extends ConsumerWidget {
  const _SquadSpotlightCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final top = ref.watch(squadsDiscoverProvider(null)).valueOrNull;
    final spotlight = (top != null && top.isNotEmpty) ? top.first : null;

    return InkWell(
      onTap: spotlight != null
          ? () => context.push('/squad/${spotlight.id}')
          : null,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withValues(alpha: 0.35),
              const Color(0xFF1A0A2E),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(12),
                image: spotlight?.logoUrl != null
                    ? DecorationImage(
                        image: CachedNetworkImageProvider(spotlight!.logoUrl!),
                        fit: BoxFit.cover)
                    : null,
              ),
              child: spotlight?.logoUrl == null
                  ? const Icon(Icons.emoji_events,
                      color: AppColors.primary, size: 28)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SQUAD SPOTLIGHT',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    spotlight?.name ?? 'No squads yet',
                    style: AppTextStyles.body
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (spotlight != null) ...[
                    Text(
                      spotlight.description?.isNotEmpty == true
                          ? spotlight.description!
                          : spotlight.primaryGame != null
                              ? 'Popular ${spotlight.primaryGame} squad'
                              : 'Popular squad on KONEX',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption,
                    ),
                    Text(
                      '${spotlight.memberCount} members',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.primary),
                    ),
                  ] else
                    Text('Join or create a squad to compete',
                        style: AppTextStyles.caption),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
