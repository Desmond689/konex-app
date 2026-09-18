import '../../../calls/presentation/providers/call_controller.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/dependency_injection.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/color_utils.dart';
import '../../../../core/widgets/kx_button.dart';
import '../../../../core/widgets/kx_error_view.dart';
import '../../../chat/presentation/providers/chat_provider.dart';
import '../../../posts/domain/entities/post_entity.dart';
import '../../../posts/presentation/providers/post_provider.dart';
import '../../../posts/presentation/widgets/post_card.dart';
import '../../../social/presentation/social_provider.dart';
import '../../domain/entities/profile_entity.dart';
import '../providers/profile_provider.dart';
import 'follow_list_screen.dart';
import 'manage_games_screen.dart';
import '../../../social/presentation/report_dialog.dart';
import '../../../../core/deep_links/share_service.dart';
import '../../../stories/presentation/providers/story_provider.dart';
import '../../../stories/presentation/screens/create_story_screen.dart';
import '../../../stories/presentation/screens/story_viewer_screen.dart';
import '../../../stories/domain/entities/story_entity.dart';
import '../../../../core/errors/error_handler.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key, this.userId});

  final String? userId;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  TabController? _tabs;
  List<PostEntity> _posts = [];
  bool _postsLoading = true;
  String? _postsLoadedFor;

  @override
  void dispose() {
    _tabs?.dispose();
    super.dispose();
  }

  Future<void> _loadPosts(String userId) async {
    // Guard against re-entrant calls: every rebuild while loading was
    // re-scheduling another load of the same user, racing the first one.
    if (_postsLoadedFor == userId && !_postsLoading) return;
    _postsLoadedFor = userId;
    setState(() => _postsLoading = true);
    final r = await ref.read(postRepositoryProvider).getUserPosts(userId);
    if (!mounted) return;
    setState(() {
      _posts = r.valueOrNull ?? [];
      _postsLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(supabaseClientProvider).auth.currentUser?.id;
    final id = widget.userId ?? me;
    if (id == null) {
      return const Scaffold(body: Center(child: Text('Not signed in')));
    }
    final isMe = id == me;
    final asyncProfile = isMe
        ? ref.watch(myProfileProvider)
        : ref.watch(profileByIdProvider(id));

    return asyncProfile.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: KxErrorView(message: ErrorHandler.userMessage(e)),
      ),
      data: (profile) {
        if (profile == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Profile not found')),
          );
        }

        if (!isMe && profile.isPrivate && !profile.isFollowing) {
          return Scaffold(
            appBar: AppBar(title: Text(profile.displayName)),
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundImage: profile.avatarUrl != null
                        ? NetworkImage(profile.avatarUrl!)
                        : null,
                    child: profile.avatarUrl == null
                        ? Text(
                            profile.displayName.isNotEmpty
                                ? profile.displayName[0]
                                : '?',
                          )
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Text(profile.displayName, style: AppTextStyles.headline),
                  Text(
                    '@${profile.username}',
                    style: AppTextStyles.bodySecondary,
                  ),
                  const SizedBox(height: 16),
                  const Text('This account is private.'),
                  const SizedBox(height: 16),
                  if (profile.canFollow(false))
                    KxButton(
                      label: profile.isFollowing ? 'Following' : 'Follow',
                      onPressed: () async {
                        final social = ref.read(socialRepositoryProvider);
                        if (profile.isFollowing) {
                          await social.unfollow(profile.id);
                        } else {
                          await social.follow(profile.id);
                        }
                        ref.invalidate(profileByIdProvider(profile.id));
                      },
                    ),
                ],
              ),
            ),
          );
        }

        _tabs ??= TabController(length: 4, vsync: this);
        // Load posts once when profile arrives
        if (_postsLoading && _posts.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _loadPosts(profile.id),
          );
        }

        return Scaffold(
          body: NestedScrollView(
            headerSliverBuilder: (context, inner) => [
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                clipBehavior: Clip.none,
                leading: isMe
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => context.pop(),
                      ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.share_outlined),
                    onPressed: () =>
                        ShareService.shareProfile(context, profile.username),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v == 'settings') {
                        context.push(Routes.settings);
                        return;
                      }
                      if (v == 'report') {
                        await showReportDialog(
                          context,
                          targetType: 'profile',
                          targetId: profile.id,
                        );
                      }
                      if (v == 'block') {
                        final social = ref.read(socialRepositoryProvider);
                        if (profile.isBlocked) {
                          await social.unblock(profile.id);
                        } else {
                          await social.block(profile.id);
                        }
                        ref.invalidate(profileByIdProvider(profile.id));
                      }
                      if (v == 'copy') {
                        await Clipboard.setData(
                          ClipboardData(text: '@${profile.username}'),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Username copied')),
                          );
                        }
                      }
                    },
                    itemBuilder: (_) => [
                      if (isMe)
                        const PopupMenuItem(
                          value: 'settings',
                          child: Text('Settings'),
                        ),
                      if (!isMe) ...[
                        const PopupMenuItem(
                          value: 'copy',
                          child: Text('Copy username'),
                        ),
                        PopupMenuItem(
                          value: 'block',
                          child: Text(profile.isBlocked ? 'Unblock' : 'Block'),
                        ),
                        const PopupMenuItem(
                          value: 'report',
                          child: Text('Report'),
                        ),
                      ],
                    ],
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (profile.bannerUrl != null)
                        CachedNetworkImage(
                          imageUrl: profile.bannerUrl!,
                          fit: BoxFit.cover,
                        )
                      else
                        Container(color: AppColors.surfaceElevated),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              AppColors.background.withValues(alpha: 0.85),
                            ],
                          ),
                        ),
                      ),
<<<<<<< HEAD
                    ],
                  ),
                ),
              ),
              // Fix: avatar/name row used to live inside flexibleSpace's
              // background Stack, which Flutter internally clips to the app
              // bar's box — the bottom half of the avatar (the part meant to
              // overlap the banner) was getting cut off instead of showing on
              // top of it. Moving it to its own sliver, shifted upward with a
              // Transform (which paints outside layout bounds, unlike
              // Positioned inside a clipped parent) and closed up with a
              // matching negative margin so it doesn't leave a gap below.
              SliverToBoxAdapter(
                child: Container(
                  transform: Matrix4.translationValues(0, -46, 0),
                  margin: const EdgeInsets.only(bottom: -46),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      GestureDetector(
                        onTap: () {
                          final avatarUrl = profile.avatarUrl;
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => Scaffold(
                                backgroundColor: Colors.black,
                                appBar: AppBar(
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                ),
                                body: Center(
                                  child: avatarUrl != null
                                      ? InteractiveViewer(
                                          child: CachedNetworkImage(
                                            imageUrl: avatarUrl,
                                            fit: BoxFit.contain,
                                            width: double.infinity,
                                            height: double.infinity,
                                          ),
                                        )
                                      : Container(
                                          width: 220,
                                          height: 220,
                                          decoration: const BoxDecoration(
                                            color: AppColors.surfaceElevated,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: Text(
                                              profile.displayName.isNotEmpty
                                                  ? profile.displayName[0]
                                                      .toUpperCase()
                                                  : '?',
                                              style: AppTextStyles.headline
                                                  .copyWith(fontSize: 52),
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          );
                        },
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            CircleAvatar(
                              radius: 46,
                              backgroundColor: AppColors.surfaceElevated,
                              backgroundImage: profile.avatarUrl != null
                                  ? CachedNetworkImageProvider(
                                      profile.avatarUrl!,
                                    )
                                  : null,
                              child: profile.avatarUrl == null
                                  ? Text(
                                      profile.displayName.isNotEmpty
                                          ? profile.displayName[0]
                                              .toUpperCase()
                                          : '?',
                                      style: AppTextStyles.headline,
                                    )
                                  : null,
                            ),
                            Positioned(
                              right: 2,
                              bottom: 2,
                              child: profile.isOnline
                                  ? Container(
                                      width: 14,
                                      height: 14,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF22C55E),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: AppColors.background,
                                          width: 2,
                                        ),
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      profile.displayName,
                                      style: AppTextStyles.headline,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (profile.isVerified) ...[
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.verified,
                                      color: Colors.lightBlueAccent,
                                      size: 18,
                                    ),
                                  ],
                                ],
                              ),
                              if (profile.badges.isNotEmpty)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 4),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '🔥 ${profile.badges.first}',
                                    style: AppTextStyles.caption.copyWith(
                                      color: AppColors.textPrimary,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              Text(
                                '@${profile.username}',
                                style: AppTextStyles.bodySecondary,
                              ),
                              if (profile.playerType != null)
                                Text(
                                  '🎮 ${profile.playerType}',
                                  style: AppTextStyles.caption,
                                ),
                            ],
                          ),
=======
                      // Avatar + name/username/role, left-aligned, overlapping
                      // the bottom edge of the banner.
                      Positioned(
                        left: 20,
                        right: 20,
                        bottom: -46,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            GestureDetector(
                              onTap: () {
                                final avatarUrl = profile.avatarUrl;
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => Scaffold(
                                      backgroundColor: Colors.black,
                                      appBar: AppBar(
                                        backgroundColor: Colors.transparent,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                      ),
                                      body: Center(
                                        child: avatarUrl != null
                                            ? InteractiveViewer(
                                                child: CachedNetworkImage(
                                                  imageUrl: avatarUrl,
                                                  fit: BoxFit.contain,
                                                  width: double.infinity,
                                                  height: double.infinity,
                                                ),
                                              )
                                            : Container(
                                                width: 220,
                                                height: 220,
                                                decoration: const BoxDecoration(
                                                  color:
                                                      AppColors.surfaceElevated,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    profile.displayName
                                                            .isNotEmpty
                                                        ? profile.displayName[0]
                                                            .toUpperCase()
                                                        : '?',
                                                    style: AppTextStyles
                                                        .headline
                                                        .copyWith(fontSize: 52),
                                                  ),
                                                ),
                                              ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  CircleAvatar(
                                    radius: 46,
                                    backgroundColor: AppColors.surfaceElevated,
                                    backgroundImage: profile.avatarUrl != null
                                        ? CachedNetworkImageProvider(
                                            profile.avatarUrl!,
                                          )
                                        : null,
                                    child: profile.avatarUrl == null
                                        ? Text(
                                            profile.displayName.isNotEmpty
                                                ? profile.displayName[0]
                                                    .toUpperCase()
                                                : '?',
                                            style: AppTextStyles.headline,
                                          )
                                        : null,
                                  ),
                                  Positioned(
                                    right: 2,
                                    bottom: 2,
                                    child: profile.isOnline
                                        ? Container(
                                            width: 14,
                                            height: 14,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF22C55E),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: AppColors.background,
                                                width: 2,
                                              ),
                                            ),
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            profile.displayName,
                                            style: AppTextStyles.headline,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (profile.isVerified) ...[
                                          const SizedBox(width: 4),
                                          const Icon(
                                            Icons.verified,
                                            color: Colors.lightBlueAccent,
                                            size: 18,
                                          ),
                                        ],
                                      ],
                                    ),
                                    if (profile.badges.isNotEmpty)
                                      Container(
                                        margin:
                                            const EdgeInsets.only(bottom: 4),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary
                                              .withValues(alpha: 0.16),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '🔥 ${profile.badges.first}',
                                          style: AppTextStyles.caption.copyWith(
                                            color: AppColors.textPrimary,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                    Text(
                                      '@${profile.username}',
                                      style: AppTextStyles.bodySecondary,
                                    ),
                                    if (profile.playerType != null)
                                      Text(
                                        '🎮 ${profile.playerType}',
                                        style: AppTextStyles.caption,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
>>>>>>> origin/main
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _Header(
                  profile: profile,
                  isMe: isMe,
                  postCount: _posts.length,
                ),
              ),
              SliverToBoxAdapter(
                child: _ProfileStoriesSection(userId: profile.id, isMe: isMe),
              ),
              if ((isMe || profile.games.isNotEmpty) &&
                  profile.showGames(isMe, profile.isFollowing))
                ProfileGamesSliver(profile: profile, isMe: isMe),
              SliverPersistentHeader(
                pinned: true,
                delegate: _TabBarDelegate(
                  TabBar(
                    controller: _tabs,
                    tabs: const [
                      Tab(text: 'Posts'),
                      Tab(text: 'Media'),
                      Tab(text: 'Squads'),
                      Tab(text: 'About'),
                    ],
                  ),
                ),
              ),
            ],
            body: TabBarView(
              controller: _tabs,
              children: [
                _PostsTab(
                  posts: _posts,
                  loading: _postsLoading,
                  onRefresh: () => _loadPosts(profile.id),
                ),
                _MediaTab(posts: _posts),
                _SquadsTab(profile: profile),
                _AboutTab(profile: profile),
              ],
            ),
          ),
        );
      },
    );
  }
}

class ProfileGamesSliver extends StatelessWidget {
  const ProfileGamesSliver({
    super.key,
    required this.profile,
    required this.isMe,
  });
  final ProfileEntity profile;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: _GamesSection(profile: profile, isMe: isMe),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({
    required this.profile,
    required this.isMe,
    required this.postCount,
  });
  final ProfileEntity profile;
  final bool isMe;
  final int postCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Name/username/role are rendered over the banner (left-aligned next to
    // the avatar, matching the reference); this section starts below that
    // overlap with the squad bar, bio, stats, and action buttons.
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 12),
      child: Column(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (profile.showSquadTag(isMe, profile.isFollowing)) ...[
                _SquadTag(profile: profile),
                const SizedBox(height: 10),
              ],
              if (profile.bio != null && profile.bio!.isNotEmpty) ...[
                Text(profile.bio!, style: AppTextStyles.body),
                const SizedBox(height: 4),
              ],
              if (profile.badges.isNotEmpty) ...[
                Wrap(
                  spacing: 6,
                  children: profile.badges
                      .map(
                        (b) => Chip(
                          label: Text(b, style: AppTextStyles.caption),
                          visualDensity: VisualDensity.compact,
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 6),
              ],
              if (profile.country != null) ...[
                Text(profile.country!, style: AppTextStyles.caption),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    InkWell(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => FollowListScreen(
                            userId: profile.id,
                            mode: FollowListMode.followers,
                          ),
                        ),
                      ),
                      child: _Stat(
                        label: 'Followers',
                        value: profile.followerCount,
                      ),
                    ),
                    _statDivider(),
                    const SizedBox(width: 16),
                    InkWell(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => FollowListScreen(
                            userId: profile.id,
                            mode: FollowListMode.following,
                          ),
                        ),
                      ),
                      child: _Stat(
                        label: 'Following',
                        value: profile.followingCount,
                      ),
                    ),
                    _statDivider(),
                    const SizedBox(width: 16),
                    _Stat(label: 'Posts', value: postCount),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (isMe)
                Row(
                  children: [
                    Expanded(
                      child: KxButton(
                        label: 'Edit Profile',
                        icon: Icons.edit_outlined,
                        compact: true,
                        onPressed: () => context.push(Routes.editProfile),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: KxButton(
                        label: 'Share Profile',
                        icon: Icons.share_outlined,
                        compact: true,
                        outlined: true,
                        onPressed: () => ShareService.shareProfile(
                          context,
                          profile.username,
                        ),
                      ),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: KxButton(
                        label: profile.isFollowing ? 'Following' : 'Follow',
                        icon: Icons.person_add_alt_1_outlined,
                        compact: true,
                        onPressed: !profile.canFollow(false)
                            ? null
                            : () async {
                                final social = ref.read(
                                  socialRepositoryProvider,
                                );
                                if (profile.isFollowing) {
                                  await social.unfollow(profile.id);
                                } else {
                                  await social.follow(profile.id);
                                }
                                ref.invalidate(profileByIdProvider(profile.id));
                              },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: 'Voice call',
                      icon: const Icon(Icons.call),
                      onPressed: !profile.canMessage(false, profile.isFollowing)
                          ? null
                          : () async {
                              final dm = await ref
                                  .read(chatRepositoryProvider)
                                  .getOrCreateDm(profile.id);
                              if (!context.mounted) return;
                              final convId = dm.valueOrNull;
                              if (convId == null) return;
                              await ref
                                  .read(callControllerProvider.notifier)
                                  .startDmCall(
                                    conversationId: convId,
                                    calleeId: profile.id,
                                    calleeName:
                                        profile.gamerName ?? profile.username,
                                    calleeAvatar: profile.avatarUrl,
                                  );
                            },
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: KxButton(
                        label: 'Message',
                        icon: Icons.chat_bubble_outline,
                        compact: true,
                        outlined: true,
                        onPressed: !profile.canMessage(
                                false, profile.isFollowing)
                            ? null
                            : () async {
                                final r = await ref
                                    .read(chatRepositoryProvider)
                                    .getOrCreateDm(profile.id);
                                r.when(
                                  success: (cid) => context.push('/chat/$cid'),
                                  failure: (e, _) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('$e')),
                                    );
                                  },
                                );
                              },
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statDivider() => Container(
        height: 30,
        width: 1,
        color: AppColors.border,
      );
}

class _SquadTag extends StatelessWidget {
  const _SquadTag({required this.profile});
  final ProfileEntity profile;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceElevated,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (profile.squadId != null) {
            context.push('/squad/${profile.squadId}');
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Text('🔥', style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            profile.squadName ?? '',
                            style: AppTextStyles.title.copyWith(fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (profile.squadRole != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              profile.squadRole![0].toUpperCase() +
                                  profile.squadRole!.substring(1),
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 10,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (profile.squadMemberCount != null)
                      Text(
                        '${profile.squadMemberCount} members',
                        style: AppTextStyles.caption,
                      ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppColors.textMuted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GamesSection extends StatelessWidget {
  const _GamesSection({required this.profile, required this.isMe});
  final ProfileEntity profile;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final games = profile.games;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'My Games',
                style: AppTextStyles.title.copyWith(fontSize: 15),
              ),
              if (isMe)
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ManageGamesScreen(),
                    ),
                  ),
                  child: const Text('Manage'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.82,
            children: [
              for (var i = 0; i < games.length; i++)
                _GameTile(
                  name: games[i],
                  isMain: i == 0,
                  onTap: () {
                    final cid = profile.gameCommunityIds[games[i]];
                    if (cid != null) context.push('/community/$cid');
                  },
                ),
              if (isMe)
                _GameTile(
                  name: 'Add Game',
                  isAdd: true,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ManageGamesScreen(),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GameTile extends StatelessWidget {
  const _GameTile({
    required this.name,
    required this.onTap,
    this.isMain = false,
    this.isAdd = false,
  });
  final String name;
  final bool isMain;
  final bool isAdd;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isMain ? AppColors.primary : AppColors.border,
            style: isAdd ? BorderStyle.solid : BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isAdd)
              const Icon(Icons.add, color: AppColors.primary, size: 22)
            else
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            const SizedBox(height: 6),
            Text(
              name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                fontSize: 10.5,
                color: AppColors.textPrimary,
              ),
            ),
            if (!isAdd) ...[
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isMain ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  isMain ? 'Main Game' : 'Also Play',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 8.5,
                    color: isMain ? Colors.white : AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$value', style: AppTextStyles.title),
        Text(label, style: AppTextStyles.caption),
      ],
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  _TabBarDelegate(this.tabBar);
  final TabBar tabBar;

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(context, shrinkOffset, overlapsContent) {
    return Material(color: AppColors.background, child: tabBar);
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate old) => false;
}

class _PostsTab extends StatelessWidget {
  const _PostsTab({
    required this.posts,
    required this.loading,
    required this.onRefresh,
  });
  final List<PostEntity> posts;
  final bool loading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (posts.isEmpty) {
      return Center(child: Text('No posts yet', style: AppTextStyles.caption));
    }
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: posts.length,
        itemBuilder: (_, i) => PostCard(
          key: ValueKey(posts[i].id),
          post: posts[i],
          onDeleted: (_) => onRefresh(),
        ),
      ),
    );
  }
}

class _MediaTab extends StatelessWidget {
  const _MediaTab({required this.posts});
  final List<PostEntity> posts;

  @override
  Widget build(BuildContext context) {
    final media = posts.where((p) => p.mediaUrls.isNotEmpty).toList();
    if (media.isEmpty) {
      return Center(child: Text('No media yet', style: AppTextStyles.caption));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: media.length,
      itemBuilder: (_, i) {
        final urls = media[i].mediaUrls;
        if (urls.isEmpty) return const SizedBox.shrink();
        final url = urls.first;
        return CachedNetworkImage(imageUrl: url, fit: BoxFit.cover);
      },
    );
  }
}

class _SquadsTab extends StatelessWidget {
  const _SquadsTab({required this.profile});
  final ProfileEntity profile;

  @override
  Widget build(BuildContext context) {
    if (!profile.hasSquadTag) {
      return Center(
        child: Text('Not in a squad', style: AppTextStyles.caption),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ListTile(
          leading: const Text('🔥', style: TextStyle(fontSize: 24)),
          title: Text(profile.squadName!),
          subtitle: Text(
            [
              if (profile.squadRole != null) profile.squadRole!,
              if (profile.squadMemberCount != null)
                '${profile.squadMemberCount} members',
            ].join(' · '),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/squad/${profile.squadId}'),
        ),
      ],
    );
  }
}

class _AboutTab extends StatelessWidget {
  const _AboutTab({required this.profile});
  final ProfileEntity profile;

  @override
  Widget build(BuildContext context) {
    final joined = profile.createdAt != null
        ? DateFormat.yMMMM().format(profile.createdAt!)
        : null;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _row('Gamer name', profile.displayName),
        _row('Username', '@${profile.username}'),
        if (profile.country != null) _row('Country', profile.country!),
        if (profile.playerType != null) _row('Platform', profile.playerType!),
        if (joined != null) _row('Joined KONEX', joined),
        if (profile.bio != null) ...[
          const SizedBox(height: 12),
          Text('Bio', style: AppTextStyles.title),
          Text(profile.bio!),
        ],
        if (profile.games.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Games', style: AppTextStyles.title),
          Text(profile.games.join(', ')),
        ],
      ],
    );
  }

  Widget _row(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(k, style: AppTextStyles.caption)),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }
}

class _ProfileStoriesSection extends ConsumerWidget {
  const _ProfileStoriesSection({required this.userId, required this.isMe});
  final String userId;
  final bool isMe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(userStoriesProvider(userId));
    return async.when(
      loading: () => const SizedBox(height: 8),
      error: (_, __) => const SizedBox.shrink(),
      data: (stories) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Stories',
                    style: AppTextStyles.title.copyWith(fontSize: 15),
                  ),
                  const Spacer(),
                  if (stories.isNotEmpty)
                    Text(
                      'Watch All',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 96,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    if (isMe)
                      GestureDetector(
                        onTap: () async {
                          final ok = await Navigator.of(context).push<bool>(
                            MaterialPageRoute(
                              builder: (_) => const CreateStoryScreen(),
                            ),
                          );
                          if (ok == true) {
                            ref.invalidate(userStoriesProvider(userId));
                            ref.invalidate(homeStoryRingsProvider);
                          }
                        },
                        child: _storyTile(
                          label: 'Create Story',
                          icon: Icons.add,
                          isCreate: true,
                        ),
                      ),
                    ...stories.map((s) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: GestureDetector(
                          onTap: () {
                            final ring = StoryRing(
                              userId: userId,
                              displayName: s.displayName,
                              avatarUrl: s.avatarUrl,
                              stories: stories,
                              isMe: isMe,
                            );
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => StoryViewerScreen(
                                  rings: [ring],
                                  initialRingIndex: 0,
                                ),
                              ),
                            );
                          },
                          child: _storyTile(
                            label: s.timeAgo,
                            imageUrl:
                                s.mediaType == 'photo' ? s.mediaUrl : null,
                            isText: s.mediaType == 'text',
                            bg: s.backgroundColor,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _storyTile({
    required String label,
    String? imageUrl,
    IconData? icon,
    bool isCreate = false,
    bool isText = false,
    String? bg,
  }) {
    return SizedBox(
      width: 72,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isCreate
                  ? AppColors.surfaceElevated
                  : (isText ? safeHexColor(bg) : AppColors.surfaceElevated),
              border: isCreate
                  ? Border.all(
                      color: AppColors.primary.withValues(alpha: 0.5),
                      width: 1.5,
                    )
                  : null,
              image: imageUrl != null
                  ? DecorationImage(
                      image: NetworkImage(imageUrl),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: isCreate
                ? Icon(icon, color: AppColors.primary, size: 28)
                : (isText
                    ? const Icon(
                        Icons.text_fields,
                        color: Colors.white54,
                        size: 22,
                      )
                    : null),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(fontSize: 10),
          ),
        ],
      ),
    );
  }
}
