import '../../../lfg/presentation/screens/lfg_screen.dart';
import '../../../../core/deep_links/share_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/kx_button.dart';
import '../../../../core/widgets/kx_error_view.dart';
import '../../../../core/widgets/kx_verified_badge.dart';
import '../../../admin/presentation/providers/admin_provider.dart';
import '../../../admin/presentation/screens/admin_edit_game_screen.dart';
import '../../../posts/presentation/providers/post_provider.dart';
import '../../../posts/presentation/widgets/post_card.dart';
import '../../../posts/presentation/widgets/composer_sheet.dart';
import '../../../chat/presentation/providers/chat_provider.dart';
import '../providers/community_provider.dart';
import '../../domain/community_entity.dart';
import '../../../../core/errors/error_handler.dart';

class CommunityDetailScreen extends ConsumerStatefulWidget {
  const CommunityDetailScreen({super.key, required this.communityId});
  final String communityId;

  @override
  ConsumerState<CommunityDetailScreen> createState() =>
      _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends ConsumerState<CommunityDetailScreen>
    with SingleTickerProviderStateMixin {
  TabController? _tabs;

  @override
  void dispose() {
    _tabs?.dispose();
    super.dispose();
  }

  Future<void> _join(CommunityEntity c) async {
    final r = await ref.read(communityRepositoryProvider).join(c.id);
    if (!mounted) return;
    r.when(
      success: (_) {
        ref.invalidate(communityByIdProvider(widget.communityId));
        ref.invalidate(myCommunitiesProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Joined ${c.name}')),
        );
      },
      failure: (e, _) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      },
    );
  }

  Future<void> _leave(CommunityEntity c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave community?'),
        content: Text('Leave ${c.name}? You can rejoin later.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Leave')),
        ],
      ),
    );
    if (ok != true) return;
    final r = await ref.read(communityRepositoryProvider).leave(c.id);
    if (!mounted) return;
    r.when(
      success: (_) {
        ref.invalidate(communityByIdProvider(widget.communityId));
        ref.invalidate(myCommunitiesProvider);
      },
      failure: (e, _) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      },
    );
  }

  Future<void> _openChat(CommunityEntity c) async {
    if (!c.isMember) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Join the community to use chat')),
      );
      return;
    }
    final r =
        await ref.read(chatRepositoryProvider).getOrCreateCommunityChat(c.id);
    if (!mounted) return;
    r.when(
      success: (id) => context.push('/chat/$id'),
      failure: (e, _) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      ),
    );
  }

  Future<void> _editGame(CommunityEntity c) async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AdminEditGameScreen(community: c)),
    );
    if (ok == true) {
      ref.invalidate(communityByIdProvider(widget.communityId));
      ref.invalidate(communitiesDiscoverProvider(null));
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(communityByIdProvider(widget.communityId));
    final isStaff = ref.watch(isStaffProvider).valueOrNull ?? false;

    return async.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
          appBar: AppBar(),
          body: KxErrorView(message: ErrorHandler.userMessage(e))),
      data: (c) {
        if (c == null) {
          return Scaffold(
              appBar: AppBar(), body: const Center(child: Text('Not found')));
        }

        _tabs ??= TabController(length: 5, vsync: this);

        return Scaffold(
          body: NestedScrollView(
            headerSliverBuilder: (context, _) => [
              SliverAppBar(
                expandedHeight: 180,
                pinned: true,
                actions: [
                  if (isStaff)
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'Edit game',
                      onPressed: () => _editGame(c),
                    ),
                  IconButton(
                    icon: const Icon(Icons.share_outlined),
                    onPressed: () => ShareService.shareGame(context, c.slug),
                  ),
                  if (c.isMember)
                    PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'leave') _leave(c);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                            value: 'leave', child: Text('Leave community')),
                      ],
                    ),
                  if (c.isMember)
                    IconButton(
                      icon: const Icon(Icons.chat_bubble_outline),
                      tooltip: 'Community chat',
                      onPressed: () => _openChat(c),
                    ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    color: AppColors.surfaceElevated,
                    padding: const EdgeInsets.only(bottom: 48),
                    alignment: Alignment.bottomCenter,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.25),
                          backgroundImage: c.avatarUrl != null
                              ? NetworkImage(c.avatarUrl!)
                              : null,
                          child: c.avatarUrl == null
                              ? Text(
                                  c.name.isNotEmpty
                                      ? c.name[0].toUpperCase()
                                      : '?',
                                  style: AppTextStyles.headline,
                                )
                              : null,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(c.name, style: AppTextStyles.title),
                            if (c.isOfficial) ...[
                              const SizedBox(width: 6),
                              const KxVerifiedBadge(size: 18),
                            ],
                          ],
                        ),
                        Text(
                          '${c.memberCount} members'
                          '${c.isOfficial ? ' · Official' : ''}'
                          '${c.platforms.isNotEmpty ? ' · ${c.platforms.join(", ")}' : ''}',
                          style: AppTextStyles.caption,
                        ),
                        const SizedBox(height: 8),
                        if (!c.isMember && !c.isBanned)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40),
                            child: KxButton(
                              label: c.isPrivate
                                  ? 'Request to join'
                                  : 'Join community',
                              onPressed: () => _join(c),
                            ),
                          )
                        else if (c.isMember)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check,
                                    size: 14, color: AppColors.textSecondary),
                                const SizedBox(width: 4),
                                Text('Joined', style: AppTextStyles.caption),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                bottom: TabBar(
                  controller: _tabs,
                  isScrollable: true,
                  tabs: const [
                    Tab(text: 'Home'),
                    Tab(text: 'Posts'),
                    Tab(text: 'LFG'),
                    Tab(text: 'Squads'),
                    Tab(text: 'About'),
                  ],
                ),
              ),
            ],
            body: TabBarView(
              controller: _tabs,
              children: [
                _HomeTab(
                  communityId: c.id,
                  community: c,
                  onSeeAllPosts: () => _tabs?.animateTo(1),
                ),
                _FeedTab(
                    communityId: c.id,
                    member: c.isMember,
                    canAnnounce: c.isModerator,
                    community: c),
                _LfgPlaceholder(gameName: c.gameName, member: c.isMember),
                _SquadsTab(communityId: c.id),
                _AboutTab(c: c),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HomeTab extends ConsumerWidget {
  const _HomeTab(
      {required this.communityId,
      required this.community,
      required this.onSeeAllPosts});
  final String communityId;
  final CommunityEntity community;
  final VoidCallback onSeeAllPosts;

  Future<void> _createPost(BuildContext context, WidgetRef ref) async {
    final created = await showCreatePostSheet(
      context,
      origin: ComposerOrigin.community,
      destinationId: communityId,
      destinationName: community.name,
      destinationAvatarUrl: community.avatarUrl,
      destinationSubtitle:
          '${community.memberCount} members · ${community.isOfficial ? 'Official' : 'Community'}',
    );
    if (created == true) ref.invalidate(communityPostFeedProvider(communityId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = community;
    final postsAsync = ref.watch(communityPostFeedProvider(communityId));

    return postsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => KxErrorView(message: ErrorHandler.userMessage(e)),
      data: (posts) {
        final highlight = posts.where((p) => p.isAnnouncement).isNotEmpty
            ? posts.firstWhere((p) => p.isAnnouncement)
            : null;

        return RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(communityPostFeedProvider(communityId)),
          color: AppColors.primary,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.3),
                      AppColors.surfaceElevated
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                        image: c.avatarUrl != null
                            ? DecorationImage(
                                image: NetworkImage(c.avatarUrl!),
                                fit: BoxFit.cover)
                            : null,
                      ),
                      child: c.avatarUrl == null
                          ? const Icon(Icons.sports_esports,
                              color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.isOfficial
                                ? 'Official ${c.gameName} community on KONEX'
                                : c.name,
                            style: AppTextStyles.body.copyWith(
                                fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                          Text(
                            'The place for players to team up, share tips, and stay updated!',
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (highlight != null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Highlights',
                        style: AppTextStyles.title.copyWith(fontSize: 15)),
                    TextButton(
                        onPressed: onSeeAllPosts, child: const Text('See all')),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.campaign_outlined,
                            color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(highlight.body ?? '',
                                style: AppTextStyles.body.copyWith(
                                    fontWeight: FontWeight.w600, fontSize: 13)),
                            const SizedBox(height: 2),
                            Text(_relativeTimeCommunity(highlight.createdAt),
                                style: AppTextStyles.caption),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Latest Posts',
                      style: AppTextStyles.title.copyWith(fontSize: 15)),
                  TextButton(
                      onPressed: onSeeAllPosts, child: const Text('See all')),
                ],
              ),
              if (posts.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text('No posts yet', style: AppTextStyles.caption),
                )
              else
                ...posts
                    .take(2)
                    .map((p) => PostCard(
                          key: ValueKey(p.id),
                          post: p,
                          canInteract: c.isMember,
                        )),
              const SizedBox(height: 8),
              if (c.isMember)
                KxButton(
                    label: 'Create Post',
                    onPressed: () => _createPost(context, ref)),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}

String _relativeTimeCommunity(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

class _FeedTab extends ConsumerStatefulWidget {
  const _FeedTab({
    required this.communityId,
    required this.member,
    required this.canAnnounce,
    required this.community,
  });
  final String communityId;
  final bool member;
  final bool canAnnounce;
  final CommunityEntity community;

  @override
  ConsumerState<_FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends ConsumerState<_FeedTab> {
  String _filter = 'all';

  Future<void> _createPost() async {
    final created = await showCreatePostSheet(
      context,
      origin: ComposerOrigin.community,
      destinationId: widget.communityId,
      destinationName: widget.community.name,
      destinationAvatarUrl: widget.community.avatarUrl,
      destinationSubtitle:
          '${widget.community.memberCount} members · ${widget.community.isOfficial ? 'Official' : 'Community'}',
    );
    if (created == true)
      ref.invalidate(communityPostFeedProvider(widget.communityId));
  }

  Future<void> _createAnnouncement() async {
    final created = await showCreateAnnouncementSheet(
      context,
      origin: ComposerOrigin.community,
      destinationId: widget.communityId,
      destinationName: widget.community.name,
      destinationAvatarUrl: widget.community.avatarUrl,
      destinationSubtitle:
          '${widget.community.memberCount} members · ${widget.community.isOfficial ? 'Official' : 'Community'}',
    );
    if (created == true)
      ref.invalidate(communityPostFeedProvider(widget.communityId));
  }

  @override
  Widget build(BuildContext context) {
    final postsAsync = ref.watch(communityPostFeedProvider(widget.communityId));

    return Column(
      children: [
        if (widget.member) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: KxButton(label: 'Create Post', onPressed: _createPost),
          ),
          if (widget.canAnnounce)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: OutlinedButton.icon(
                onPressed: _createAnnouncement,
                icon: const Icon(Icons.campaign_outlined, size: 18),
                label: const Text('Announce'),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                for (final f in const [
                  ('all', 'All'),
                  ('text', 'Discussion'),
                  ('lfg', 'LFG'),
                  ('tip', 'Tips'),
                  ('event', 'Events'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f.$2),
                      selected: _filter == f.$1,
                      onSelected: (_) => setState(() => _filter = f.$1),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
        ] else
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'Join to post and interact. You can still read public posts.',
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),
          ),
        Expanded(
          child: postsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => KxErrorView(message: ErrorHandler.userMessage(e)),
            data: (posts) {
              final filtered = _filter == 'all'
                  ? posts
                  : posts.where((p) => p.postType == _filter).toList();
              if (filtered.isEmpty) {
                return Center(
                    child: Text('No posts yet', style: AppTextStyles.caption));
              }
              return RefreshIndicator(
                onRefresh: () async => ref
                    .invalidate(communityPostFeedProvider(widget.communityId)),
                color: AppColors.primary,
                child: ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => PostCard(
                      key: ValueKey(filtered[i].id),
                      post: filtered[i],
                      canInteract: widget.member,
                    ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _LfgPlaceholder extends StatelessWidget {
  const _LfgPlaceholder({required this.gameName, required this.member});
  final String gameName;
  final bool member;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('LFG for $gameName', style: AppTextStyles.title),
            const SizedBox(height: 8),
            Text(
              'Browse open Looking-For-Group posts for this game and find teammates.',
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => LfgScreen(initialGame: gameName),
                  ),
                );
              },
              child: Text('Open $gameName LFG'),
            ),
            if (!member) ...[
              const SizedBox(height: 12),
              Text(
                'Join the community to post from the feed as well.',
                style: AppTextStyles.caption,
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SquadsTab extends ConsumerStatefulWidget {
  const _SquadsTab({required this.communityId});
  final String communityId;

  @override
  ConsumerState<_SquadsTab> createState() => _SquadsTabState();
}

class _SquadsTabState extends ConsumerState<_SquadsTab> {
  List<Map<String, dynamic>> _squads = [];
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await ref
        .read(communityRepositoryProvider)
        .squadsForGame(widget.communityId);
    if (!mounted) return;
    result.when(
      success: (squads) {
        setState(() {
          _squads = squads;
          _loading = false;
        });
      },
      failure: (error, _) {
        setState(() {
          _error = error;
          _loading = false;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return KxErrorView(message: _error.toString(), onRetry: _load);
    }
    if (_squads.isEmpty) {
      return Center(
        child: Text('No public squads in this community yet.',
            style: AppTextStyles.caption),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        itemCount: _squads.length,
        itemBuilder: (_, index) {
          final squad = _squads[index];
          final name = squad['name'] as String? ?? 'Squad';
          final logoUrl = squad['logo_url'] as String?;
          final game = squad['primary_game'] as String?;
          final memberCount = squad['member_count'] as int? ?? 0;
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.surfaceElevated,
              backgroundImage: logoUrl != null ? NetworkImage(logoUrl) : null,
              child: logoUrl == null
                  ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?')
                  : null,
            ),
            title: Text(name),
            subtitle: Text(
              [
                if (game != null && game.isNotEmpty) game,
                '$memberCount members',
              ].join(' · '),
              style: AppTextStyles.caption,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/squad/${squad['id']}'),
          );
        },
      ),
    );
  }
}

class _AboutTab extends StatelessWidget {
  const _AboutTab({required this.c});
  final CommunityEntity c;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (c.description != null) ...[
          Text('About', style: AppTextStyles.title),
          Text(c.description!),
          const SizedBox(height: 16),
        ],
        if (c.rules != null && c.rules!.isNotEmpty) ...[
          Text('Rules', style: AppTextStyles.title),
          Text(c.rules!),
          const SizedBox(height: 16),
        ],
        Text('Game: ${c.gameName}'),
        if (c.category != null) Text('Category: ${c.category}'),
        if (c.platforms.isNotEmpty)
          Text('Platforms: ${c.platforms.join(", ")}'),
        if (c.primaryRegion != null) Text('Region: ${c.primaryRegion}'),
        Text(c.isOfficial ? 'Official KONEX game community' : 'Community'),
        const SizedBox(height: 12),
        Text(
          'KONEX is not the game developer. Content is community-driven.',
          style: AppTextStyles.caption,
        ),
      ],
    );
  }
}
