import '../../../../core/deep_links/share_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/dependency_injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../social/presentation/report_dialog.dart';
import '../../data/repost_helper.dart';
import '../../domain/entities/post_entity.dart';
import '../providers/post_provider.dart';
import '../screens/comments_sheet.dart';
import '../../../media/presentation/video_post_player.dart';
import '../../../../core/services/data_saver_service.dart';
import '../../../../core/widgets/kx_verified_badge.dart';

class PostCard extends ConsumerWidget {
  const PostCard({
    super.key,
    required this.post,
    this.onDeleted,
    this.canInteract = true,
  });
  final PostEntity post;
  final void Function(String postId)? onDeleted;
  final bool canInteract;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.read(feedControllerProvider.notifier);

    return _PostCardBody(
      post: post,
      feed: feed,
      onDeleted: onDeleted,
      canInteract: canInteract,
    );
  }
}

class _PostCardBody extends ConsumerStatefulWidget {
  const _PostCardBody({
    required this.post,
    required this.feed,
    this.onDeleted,
    required this.canInteract,
  });
  final PostEntity post;
  final dynamic feed;
  final void Function(String postId)? onDeleted;
  final bool canInteract;

  @override
  ConsumerState<_PostCardBody> createState() => _PostCardBodyState();
}

class _PostCardBodyState extends ConsumerState<_PostCardBody>
    with SingleTickerProviderStateMixin {
  late final AnimationController _heartCtrl;
  bool _showHeart = false;

  // Owned locally rather than read from whichever feed/list provider handed
  // us this widget — that provider (home feed, squad tab, profile, saved
  // posts, post detail) usually doesn't share state with the others, so a
  // like/comment tap here would silently no-op or bounce back on the next
  // rebuild if we only wrote through it. This card is the source of truth
  // for its own like/comment count while it's on screen; other providers
  // are best-effort synced via syncPostFields so they don't go stale.
  late PostEntity _post;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    _heartCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void didUpdateWidget(covariant _PostCardBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only reset when this State has actually been handed a different post
    // (e.g. list reordering reused the State object) — otherwise keep our
    // local optimistic state instead of clobbering it with a possibly-stale
    // widget.post from a parent rebuild.
    if (oldWidget.post.id != widget.post.id) {
      _post = widget.post;
    }
  }

  @override
  void dispose() {
    _heartCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggleLike() async {
    if (!widget.canInteract) return;
    final wasLiked = _post.likedByMe;
    final previous = _post;
    final updated = _post.copyWith(
      likedByMe: !wasLiked,
      likeCount: wasLiked ? _post.likeCount - 1 : _post.likeCount + 1,
    );
    setState(() => _post = updated);

    final repo = ref.read(postRepositoryProvider);
    final result = wasLiked ? await repo.unlikePost(_post.id) : await repo.likePost(_post.id);
    if (!mounted) return;
    if (result.isFailure) {
      setState(() => _post = previous);
      return;
    }
    ref.read(feedControllerProvider.notifier).syncPostFields(
          updated.id,
          likeCount: updated.likeCount,
          likedByMe: updated.likedByMe,
        );
  }

  Future<void> _doubleTapLike() async {
    if (!_post.likedByMe) {
      await _toggleLike();
    }
    setState(() => _showHeart = true);
    await _heartCtrl.forward(from: 0);
    if (mounted) setState(() => _showHeart = false);
  }

  Future<void> _openComments() async {
    if (!widget.canInteract) return;
    final newCount = await showCommentsSheet(
      context,
      _post.id,
      postAuthorId: _post.authorId,
    );
    if (!mounted || newCount == null) return;
    setState(() => _post = _post.copyWith(commentCount: newCount));
    ref
        .read(feedControllerProvider.notifier)
        .syncPostFields(_post.id, commentCount: newCount);
  }

  @override
  Widget build(BuildContext context) {
    final post = _post;
    final currentUserId = ref.read(supabaseClientProvider).auth.currentUser?.id;
    final isAuthor = currentUserId != null && currentUserId == post.authorId;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: GestureDetector(
        onDoubleTap: _doubleTapLike,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => context.push('/user/${post.authorId}'),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.surfaceElevated,
                    backgroundImage: post.authorAvatarUrl != null
                        ? CachedNetworkImageProvider(post.authorAvatarUrl!)
                        : null,
                    child: post.authorAvatarUrl == null
                        ? Text(
                            post.authorDisplay.isNotEmpty
                                ? post.authorDisplay[0].toUpperCase()
                                : '?',
                          )
                        : null,
                  ),
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
                              post.authorDisplay,
                              style: AppTextStyles.title.copyWith(fontSize: 15),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (post.authorVerified)
                            const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: KxVerifiedBadge(size: 15),
                            ),
                          if (_roleBadgeLabel(post.authorSquadRole) != null) ...[
                            const SizedBox(width: 6),
                            _RoleBadge(label: _roleBadgeLabel(post.authorSquadRole)!),
                          ],
                        ],
                      ),
                      Text(
                        post.destinationLabel,
                        style: AppTextStyles.caption,
                      ),
                      Text(
                        DateFormat.MMMd().add_jm().format(post.createdAt.toLocal()),
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz, size: 20),
                  onSelected: (v) async {
                    if (v == 'report') {
                      await showReportDialog(
                        context,
                        targetType: 'post',
                        targetId: post.id,
                      );
                    } else if (v == 'share') {
                      ShareService.sharePost(context, post.id);
                    } else if (v == 'repost') {
                      final helper = RepostHelper(ref.read(supabaseClientProvider));
                      await helper.repost(post.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Reposted')),
                        );
                      }
                    } else if (v == 'delete') {
                      final result = await ref.read(postRepositoryProvider).deletePost(post.id);
                      result.when(
                        success: (_) async {
                          await ref.read(feedControllerProvider.notifier).deletePost(post.id);
                          widget.onDeleted?.call(post.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Post deleted')),
                            );
                          }
                        },
                        failure: (e, _) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Could not delete post: $e')),
                            );
                          }
                        },
                      );
                    }
                  },
                  itemBuilder: (_) {
                    final items = <PopupMenuEntry<String>>[
                      const PopupMenuItem(value: 'repost', child: Text('Repost')),
                      const PopupMenuItem(value: 'share', child: Text('Share')),
                      const PopupMenuItem(value: 'report', child: Text('Report')),
                    ];
                    if (isAuthor) {
                      items.add(const PopupMenuItem(value: 'delete', child: Text('Delete post')));
                    }
                    return items;
                  },
                ),
              ],
            ),
            if (_postTagLabel(post) != null) ...[
              const SizedBox(height: 10),
              _PostTypeTag(post: post),
            ],
            if (post.body != null && post.body!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(post.body!, style: AppTextStyles.body),
            ],
            if (post.postType == 'video' && post.mediaUrls.isNotEmpty) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: VideoPostPlayer(url: post.mediaUrls.first),
              ),
            ] else if (post.mediaUrls.isNotEmpty) ...[
              const SizedBox(height: 10),
              _PostMediaCarousel(
                urls: post.mediaUrls,
                dataSaver: ref.watch(dataSaverEnabledProvider).valueOrNull == true,
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                _Action(
                  icon: post.likedByMe ? Icons.favorite : Icons.favorite_border,
                  color: post.likedByMe ? AppColors.accent : AppColors.textSecondary,
                  label: '${post.likeCount}',
                  onTap: _toggleLike,
                ),
                const SizedBox(width: 16),
                _Action(
                  icon: Icons.chat_bubble_outline,
                  label: '${post.commentCount}',
                  onTap: _openComments,
                ),
                const SizedBox(width: 16),
                _Action(
                  icon: Icons.repeat,
                  label: '${post.shareCount}',
                  onTap: () async {
                    final helper = RepostHelper(ref.read(supabaseClientProvider));
                    await helper.repost(post.id);
                    if (context.mounted) {
                      setState(() => _post = _post.copyWith(shareCount: _post.shareCount + 1));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Reposted')),
                      );
                    }
                  },
                ),
                const Spacer(),
                _Action(
                  icon: post.savedByMe ? Icons.bookmark : Icons.bookmark_border,
                  color: post.savedByMe ? AppColors.secondary : AppColors.textSecondary,
                  label: '',
                  onTap: () => widget.feed.toggleSave(post),
                ),
              ],
            ),
          ],
        ),
      ),
            if (_showHeart)
              ScaleTransition(
                scale: Tween(begin: 0.6, end: 1.2).animate(
                  CurvedAnimation(parent: _heartCtrl, curve: Curves.easeOutBack),
                ),
                child: const Icon(
                  Icons.favorite,
                  size: 88,
                  color: Color(0xFFFF2D55),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Squad-role badge label shown next to the author's name (owner/moderator only).
String? _roleBadgeLabel(String? role) {
  switch (role) {
    case 'owner':
      return 'Owner';
    case 'moderator':
      return 'Mod';
    default:
      return null;
  }
}

/// Post-type tag shown above the body: Announcement takes priority, then the
/// squad/community post type (Discussion for plain text, or LFG/Tip/Event).
String? _postTagLabel(PostEntity post) {
  if (post.isAnnouncement) return 'Announcement';
  if (post.postType == 'text' || post.postType == 'image' || post.postType == 'video') {
    return 'Discussion';
  }
  return post.typeBadgeLabel;
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: AppColors.primary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PostTypeTag extends StatelessWidget {
  const _PostTypeTag({required this.post});
  final PostEntity post;

  @override
  Widget build(BuildContext context) {
    final label = _postTagLabel(post)!;
    final color = post.isAnnouncement
        ? AppColors.primary
        : switch (post.postType) {
            'lfg' => AppColors.secondary,
            'tip' => AppColors.accent,
            'event' => AppColors.success,
            _ => AppColors.textSecondary,
          };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color ?? AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(label, style: AppTextStyles.caption),
          ],
        ),
      ),
    );
  }
}


class _PostMediaCarousel extends StatefulWidget {
  const _PostMediaCarousel({required this.urls, this.dataSaver = false});
  final List<String> urls;
  final bool dataSaver;

  @override
  State<_PostMediaCarousel> createState() => _PostMediaCarouselState();
}

class _PostMediaCarouselState extends State<_PostMediaCarousel> {
  final _page = PageController();
  int _index = 0;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.urls;
    final cache = widget.dataSaver ? 720 : 1200;
    if (urls.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: urls.first,
          fit: BoxFit.cover,
          width: double.infinity,
          height: 280,
          memCacheWidth: cache,
          memCacheHeight: cache,
          placeholder: (_, __) => Container(
            height: 280,
            color: AppColors.surfaceElevated,
            child: const Center(child: CircularProgressIndicator()),
          ),
          errorWidget: (_, __, ___) => Container(
            height: 120,
            color: AppColors.surfaceElevated,
            child: const Icon(Icons.broken_image),
          ),
        ),
      );
    }

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 280,
            child: PageView.builder(
              controller: _page,
              itemCount: urls.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) {
                return CachedNetworkImage(
                  imageUrl: urls[i],
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: 280,
                  memCacheWidth: cache,
                  memCacheHeight: cache,
                  placeholder: (_, __) => Container(
                    color: AppColors.surfaceElevated,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: AppColors.surfaceElevated,
                    child: const Icon(Icons.broken_image),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(urls.length, (i) {
            final active = i == _index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 8 : 6,
              height: active ? 8 : 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active
                    ? AppColors.primary
                    : AppColors.textMuted.withValues(alpha: 0.4),
              ),
            );
          }),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${_index + 1}/${urls.length}',
            style: AppTextStyles.caption.copyWith(fontSize: 11),
          ),
        ),
      ],
    );
  }
}
