import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/dependency_injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../social/presentation/report_dialog.dart';
import '../../domain/entities/post_entity.dart';
import '../providers/post_provider.dart';
import '../../../../core/widgets/kx_verified_badge.dart';

/// Opens the comments sheet and returns the post's final comment count once
/// it closes (however it closes — send, delete, swipe-down, or tap-outside),
/// so the caller (usually a [PostCard]) can update its own displayed count
/// without waiting for a full feed refresh. Returns null if the count never
/// changed from what was loaded (e.g. the sheet was dismissed immediately).
Future<int?> showCommentsSheet(
  BuildContext context,
  String postId, {
  String? postAuthorId,
}) async {
  int? latestCount;
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => CommentsSheet(
      postId: postId,
      postAuthorId: postAuthorId,
      onCountChanged: (count) => latestCount = count,
    ),
  );
  return latestCount;
}

class CommentsSheet extends ConsumerStatefulWidget {
  const CommentsSheet({
    super.key,
    required this.postId,
    this.postAuthorId,
    this.onCountChanged,
  });
  final String postId;
  final String? postAuthorId;

  /// Fired whenever the visible comment count changes: on initial load,
  /// on realtime-triggered reload, on sending a comment, and on deleting one.
  final void Function(int count)? onCountChanged;

  @override
  ConsumerState<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends ConsumerState<CommentsSheet> {
  final _controller = TextEditingController();
  final _expandedReplies = <String>{};
  List<CommentEntity> _all = [];
  bool _loading = true;
  bool _sending = false;
  String? _replyToId;
  String? _replyToName;
  String? _pendingImagePath;
  RealtimeChannel? _channel;
  String? _myUid;

  @override
  void initState() {
    super.initState();
    _myUid = ref.read(supabaseClientProvider).auth.currentUser?.id;
    _load();
    _subscribeRealtime();
  }

  void _subscribeRealtime() {
    final client = ref.read(supabaseClientProvider);
    _channel = client
        .channel('comments-${widget.postId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'comments',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'post_id',
            value: widget.postId,
          ),
          callback: (_) {
            if (mounted) _load(silent: true);
          },
        )
        .subscribe();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    final r = await ref.read(postRepositoryProvider).getComments(
          widget.postId,
          postAuthorId: widget.postAuthorId,
        );
    if (!mounted) return;
    setState(() {
      _all = r.valueOrNull ?? [];
      _loading = false;
    });
    widget.onCountChanged?.call(_all.length);
  }

  List<CommentEntity> get _roots {
    final roots = _all.where((c) => c.parentId == null).toList()
      ..sort((a, b) {
        final lc = b.likeCount.compareTo(a.likeCount);
        if (lc != 0) return lc;
        return a.createdAt.compareTo(b.createdAt);
      });
    return roots;
  }

  List<CommentEntity> _repliesOf(String parentId) {
    final list = _all.where((c) => c.parentId == parentId).toList()
      ..sort((a, b) {
        if (a.isCreator != b.isCreator) return a.isCreator ? -1 : 1;
        final lc = b.likeCount.compareTo(a.likeCount);
        if (lc != 0) return lc;
        return a.createdAt.compareTo(b.createdAt);
      });
    return list;
  }

  Future<void> _toggleLike(CommentEntity c) async {
    final repo = ref.read(postRepositoryProvider);
    final nextLiked = !c.likedByMe;
    final previous = c;
    setState(() {
      _all = _all
          .map(
            (x) => x.id == c.id
                ? x.copyWith(
                    likedByMe: nextLiked,
                    likeCount: nextLiked
                        ? x.likeCount + 1
                        : (x.likeCount - 1).clamp(0, 1 << 30),
                  )
                : x,
          )
          .toList();
    });
    final result = nextLiked
        ? await repo.likeComment(c.id)
        : await repo.unlikeComment(c.id);
    if (result.isFailure && mounted) {
      setState(() {
        _all = _all
            .map((x) => x.id == previous.id ? previous : x)
            .toList();
      });
    }
  }

  Future<void> _pickImage() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1280,
      imageQuality: 82,
    );
    if (file != null && mounted) {
      setState(() => _pendingImagePath = file.path);
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty && _pendingImagePath == null) return;
    setState(() => _sending = true);
    try {
      String? mediaUrl;
      if (_pendingImagePath != null) {
        final bytes = await File(_pendingImagePath!).readAsBytes();
        final up =
            await ref.read(postRepositoryProvider).uploadCommentImage(bytes);
        mediaUrl = up.valueOrNull;
      }
      final r = await ref.read(postRepositoryProvider).addComment(
            widget.postId,
            text,
            parentId: _replyToId,
            mediaUrl: mediaUrl,
            postAuthorId: widget.postAuthorId,
          );
      if (!mounted) return;
      r.when(
        success: (c) {
          _controller.clear();
          setState(() {
            _all = [..._all, c];
            _pendingImagePath = null;
            if (_replyToId != null) _expandedReplies.add(_replyToId!);
            _replyToId = null;
            _replyToName = null;
          });
          widget.onCountChanged?.call(_all.length);
        },
        failure: (_, __) {},
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _menu(CommentEntity c) async {
    final isMine = c.authorId == _myUid;
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isMine)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Delete'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await ref.read(postRepositoryProvider).softDeleteComment(c.id);
                  if (mounted) {
                    setState(
                      () => _all = _all.where((x) => x.id != c.id).toList(),
                    );
                    widget.onCountChanged?.call(_all.length);
                  }
                },
              ),
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Report'),
              onTap: () async {
                Navigator.pop(ctx);
                await showReportDialog(
                  context,
                  targetType: 'comment',
                  targetId: c.id,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.72,
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Text(
                    '${_all.where((c) => c.parentId == null).length} comments',
                    style: AppTextStyles.title.copyWith(fontSize: 16),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _roots.isEmpty
                      ? Center(
                          child: Text(
                            'No comments yet — say something',
                            style: AppTextStyles.caption,
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _roots.length,
                          itemBuilder: (_, i) {
                            final root = _roots[i];
                            return _Thread(
                              root: root,
                              replies: _repliesOf(root.id),
                              expanded: _expandedReplies.contains(root.id),
                              onExpand: () =>
                                  setState(() => _expandedReplies.add(root.id)),
                              onCollapse: () => setState(
                                () => _expandedReplies.remove(root.id),
                              ),
                              onLike: _toggleLike,
                              onReply: (c) => setState(() {
                                _replyToId = c.parentId ?? c.id;
                                _replyToName = c.authorUsername;
                              }),
                              onMenu: _menu,
                            );
                          },
                        ),
            ),
            if (_replyToName != null)
              Container(
                width: double.infinity,
                color: AppColors.surfaceElevated,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Replying to @$_replyToName',
                        style: AppTextStyles.caption,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() {
                        _replyToId = null;
                        _replyToName = null;
                      }),
                      child: const Icon(Icons.close, size: 16),
                    ),
                  ],
                ),
              ),
            if (_pendingImagePath != null)
              Padding(
                padding: const EdgeInsets.only(left: 12, top: 6),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(_pendingImagePath!),
                        height: 72,
                        width: 72,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _pendingImagePath = null),
                        child: const CircleAvatar(
                          radius: 10,
                          backgroundColor: Colors.black54,
                          child: Icon(Icons.close,
                              size: 12, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.image_outlined),
                      onPressed: _pickImage,
                    ),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        minLines: 1,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'Add comment…',
                          filled: true,
                          fillColor: AppColors.surfaceElevated,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _sending ? null : _send,
                      icon: _sending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(Icons.send_rounded, color: AppColors.accent),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Thread extends StatelessWidget {
  const _Thread({
    required this.root,
    required this.replies,
    required this.expanded,
    required this.onExpand,
    required this.onCollapse,
    required this.onLike,
    required this.onReply,
    required this.onMenu,
  });

  final CommentEntity root;
  final List<CommentEntity> replies;
  final bool expanded;
  final VoidCallback onExpand;
  final VoidCallback onCollapse;
  final void Function(CommentEntity) onLike;
  final void Function(CommentEntity) onReply;
  final void Function(CommentEntity) onMenu;

  @override
  Widget build(BuildContext context) {
    final creatorReplies = replies.where((r) => r.isCreator).toList();
    final otherReplies = replies.where((r) => !r.isCreator).toList();
    final visibleReplies = expanded ? replies : creatorReplies;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CommentTile(
          comment: root,
          onLike: () => onLike(root),
          onReply: () => onReply(root),
          onMenu: () => onMenu(root),
        ),
        if (visibleReplies.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 44),
            child: Column(
              children: [
                for (final r in visibleReplies)
                  _CommentTile(
                    comment: r,
                    isReply: true,
                    onLike: () => onLike(r),
                    onReply: () => onReply(r),
                    onMenu: () => onMenu(r),
                  ),
              ],
            ),
          ),
        if (!expanded && otherReplies.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 56, bottom: 8),
            child: GestureDetector(
              onTap: onExpand,
              child: Text(
                'View ${otherReplies.length} ${otherReplies.length == 1 ? 'reply' : 'replies'}',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        if (expanded && otherReplies.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 56, bottom: 8),
            child: GestureDetector(
              onTap: onCollapse,
              child: Text(
                'Hide replies',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary),
              ),
            ),
          ),
      ],
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.onLike,
    required this.onReply,
    required this.onMenu,
    this.isReply = false,
  });

  final CommentEntity comment;
  final VoidCallback onLike;
  final VoidCallback onReply;
  final VoidCallback onMenu;
  final bool isReply;

  @override
  Widget build(BuildContext context) {
    final time = _rel(comment.createdAt);
    return Padding(
      padding: EdgeInsets.fromLTRB(isReply ? 8 : 12, 6, 8, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => context.push('/user/${comment.authorId}'),
            child: CircleAvatar(
              radius: isReply ? 14 : 16,
              backgroundColor: AppColors.surfaceElevated,
              backgroundImage: comment.authorAvatarUrl != null
                  ? CachedNetworkImageProvider(comment.authorAvatarUrl!)
                  : null,
              child: comment.authorAvatarUrl == null
                  ? Text(
                      comment.authorUsername.isNotEmpty
                          ? comment.authorUsername[0].toUpperCase()
                          : '?',
                      style: TextStyle(fontSize: isReply ? 11 : 13),
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
                        comment.authorUsername,
                        style: AppTextStyles.caption.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (comment.authorVerified)
                      const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: KxVerifiedBadge(size: 14),
                      ),
                    if (comment.isCreator) ...[
                      const SizedBox(width: 6),
                      const Text(
                        'Creator',
                        style: TextStyle(
                          color: Color(0xFF20D5EC),
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ],
                    const SizedBox(width: 6),
                    Text(
                      time,
                      style: AppTextStyles.caption.copyWith(fontSize: 11),
                    ),
                  ],
                ),
                if (comment.body.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    comment.body,
                    style: AppTextStyles.body.copyWith(fontSize: 14),
                  ),
                ],
                if (comment.mediaUrl != null) ...[
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: CachedNetworkImage(
                      imageUrl: comment.mediaUrl!,
                      width: 160,
                      height: 160,
                      fit: BoxFit.cover,
                      memCacheWidth: 320,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    GestureDetector(
                      onTap: onReply,
                      child: Text(
                        'Reply',
                        style: AppTextStyles.caption.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: onMenu,
                      child: Icon(
                        Icons.more_horiz,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                if (comment.likedByCreator) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          CircleAvatar(
                            radius: 10,
                            backgroundColor: AppColors.surfaceElevated,
                            backgroundImage: comment.creatorAvatarUrl != null
                                ? CachedNetworkImageProvider(
                                    comment.creatorAvatarUrl!)
                                : null,
                            child: comment.creatorAvatarUrl == null
                                ? const Icon(Icons.person, size: 12)
                                : null,
                          ),
                          Positioned(
                            right: -4,
                            bottom: -2,
                            child: Container(
                              padding: const EdgeInsets.all(1),
                              decoration: const BoxDecoration(
                                color: Colors.black87,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.favorite,
                                size: 10,
                                color: Color(0xFFFF2D55),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Creator liked',
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          GestureDetector(
            onTap: onLike,
            child: Padding(
              padding: const EdgeInsets.only(left: 4, top: 4),
              child: Column(
                children: [
                  Icon(
                    comment.likedByMe ? Icons.favorite : Icons.favorite_border,
                    size: 18,
                    color: comment.likedByMe
                        ? const Color(0xFFFF2D55)
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _fmtCount(comment.likeCount),
                    style: AppTextStyles.caption.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _rel(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 1) return 'now';
    if (d.inHours < 1) return '${d.inMinutes}m';
    if (d.inDays < 1) return '${d.inHours}h';
    if (d.inDays < 7) return '${d.inDays}d';
    return DateFormat.MMMd().format(dt);
  }

  static String _fmtCount(int n) {
    if (n <= 0) return '';
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}
