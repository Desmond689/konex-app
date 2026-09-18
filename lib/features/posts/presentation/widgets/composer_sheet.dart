import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/config/constants.dart';
import '../../../../core/config/dependency_injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/kx_button.dart';
import '../../../communities/presentation/providers/community_provider.dart';
import '../../../lfg/presentation/screens/create_poll_screen.dart';
import '../../../media/presentation/create_video_post_screen.dart';
import '../../../squads/presentation/providers/squad_provider.dart';
import '../providers/post_provider.dart';
import '../../../../core/errors/error_handler.dart';

/// Where the composer is being opened from — controls the destination badge,
/// footer copy, and which foreign key gets attached to the post row.
enum ComposerOrigin { home, community, squad }

/// Opens the "Create a post" sheet (Image: Squad Posts – Create Post).
/// Returns true if a post was created.
Future<bool?> showCreatePostSheet(
  BuildContext context, {
  required ComposerOrigin origin,
  String? destinationId,
  String? destinationName,
  String? destinationAvatarUrl,
  String? destinationSubtitle,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ComposerSheet(
      origin: origin,
      destinationId: destinationId,
      destinationName: destinationName,
      destinationAvatarUrl: destinationAvatarUrl,
      destinationSubtitle: destinationSubtitle,
    ),
  );
}

/// Opens the "Create an announcement" sheet (Image: Squad Posts – Announce).
/// Only owners/moderators should be able to trigger this from the UI.
/// Returns true if an announcement was posted.
Future<bool?> showCreateAnnouncementSheet(
  BuildContext context, {
  required ComposerOrigin origin,
  required String destinationId,
  required String destinationName,
  String? destinationAvatarUrl,
  String? destinationSubtitle,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AnnouncementSheet(
      origin: origin,
      destinationId: destinationId,
      destinationName: destinationName,
      destinationAvatarUrl: destinationAvatarUrl,
      destinationSubtitle: destinationSubtitle,
    ),
  );
}

class _SheetChrome extends StatelessWidget {
  const _SheetChrome({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.72,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _DestinationHeader extends StatelessWidget {
  const _DestinationHeader({
    required this.name,
    required this.subtitle,
    this.avatarUrl,
    required this.onClose,
  });

  final String name;
  final String subtitle;
  final String? avatarUrl;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close),
              visualDensity: VisualDensity.compact,
            ),
            const Spacer(),
            const SizedBox(width: 48),
          ],
        ),
        CircleAvatar(
          radius: 26,
          backgroundColor: AppColors.primary.withValues(alpha: 0.3),
          backgroundImage: avatarUrl != null ? CachedNetworkImageProvider(avatarUrl!) : null,
          child: avatarUrl == null
              ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: AppTextStyles.title)
              : null,
        ),
        const SizedBox(height: 6),
        Text(name, style: AppTextStyles.title),
        Text(subtitle, style: AppTextStyles.caption),
        const SizedBox(height: 16),
      ],
    );
  }
}

const _postTypes = <(String value, String label, IconData icon)>[
  ('text', 'Discussion', Icons.forum_outlined),
  ('lfg', 'LFG', Icons.person_search_outlined),
  ('tip', 'Tip', Icons.lightbulb_outline),
  ('event', 'Event', Icons.event_outlined),
];

class _ComposerSheet extends ConsumerStatefulWidget {
  const _ComposerSheet({
    required this.origin,
    this.destinationId,
    this.destinationName,
    this.destinationAvatarUrl,
    this.destinationSubtitle,
  });

  final ComposerOrigin origin;
  final String? destinationId;
  final String? destinationName;
  final String? destinationAvatarUrl;
  final String? destinationSubtitle;

  @override
  ConsumerState<_ComposerSheet> createState() => _ComposerSheetState();
}

class _ComposerSheetState extends ConsumerState<_ComposerSheet> {
  final _body = TextEditingController();
  final List<String> _imagePaths = [];
  String _postType = 'text';
  String? _taggedCommunityId;
  bool _loading = false;
  String? _error;

  static const _maxImages = 10;

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final remaining = _maxImages - _imagePaths.length;
    if (remaining <= 0) {
      setState(() => _error = 'Max $_maxImages photos per post');
      return;
    }
    final files = await picker.pickMultiImage(maxWidth: 1920, imageQuality: 85, limit: remaining);
    if (files.isEmpty || !mounted) return;
    setState(() {
      _imagePaths.addAll(files.map((f) => f.path).take(remaining));
      _error = null;
    });
  }

  Future<void> _openPoll() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CreatePollScreen()),
    );
    if (created == true && mounted) Navigator.of(context).pop(true);
  }

  Future<void> _openVideo() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CreateVideoPostScreen()),
    );
    if (created == true && mounted) Navigator.of(context).pop(true);
  }

  Future<void> _submit() async {
    final text = _body.text.trim();
    if (text.isEmpty && _imagePaths.isEmpty) {
      setState(() => _error = 'Write something or add photos');
      return;
    }
    if (text.length > AppConstants.maxPostTextLength) {
      setState(() => _error = 'Post is too long');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    final repo = ref.read(postRepositoryProvider);
    final communityId = widget.origin == ComposerOrigin.community
        ? widget.destinationId
        : _taggedCommunityId;
    final squadId = widget.origin == ComposerOrigin.squad ? widget.destinationId : null;

    final result = _imagePaths.isNotEmpty
        ? await repo.createMultiImagePost(
            body: text,
            localImagePaths: List.from(_imagePaths),
            communityId: communityId,
            squadId: squadId,
            postType: _postType == 'text' ? 'image' : _postType,
          )
        : await repo.createTextPost(
            body: text,
            communityId: communityId,
            squadId: squadId,
            postType: _postType,
          );

    if (!mounted) return;
    setState(() => _loading = false);

    result.when(
      success: (post) {
        if (squadId != null) ref.invalidate(squadPostFeedProvider(squadId));
        Navigator.of(context).pop(true);
      },
      failure: (e, _) => setState(() => _error = ErrorHandler.userMessage(e)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isHome = widget.origin == ComposerOrigin.home;
    final footer = switch (widget.origin) {
      ComposerOrigin.squad => 'Only squad members can see this post',
      ComposerOrigin.community => 'Visible to everyone in this community',
      ComposerOrigin.home => 'Visible to everyone on KONEX',
    };

    return _SheetChrome(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!isHome)
            _DestinationHeader(
              name: widget.destinationName ?? '',
              subtitle: widget.destinationSubtitle ?? '',
              avatarUrl: widget.destinationAvatarUrl,
              onClose: () => Navigator.of(context).pop(),
            )
          else
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 4),
                Text('Create a post', style: AppTextStyles.title),
              ],
            ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Create a post', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700)),
                Text('Share something with your squad', style: AppTextStyles.caption),
                const SizedBox(height: 10),
                TextField(
                  controller: _body,
                  maxLines: 5,
                  minLines: 3,
                  maxLength: AppConstants.maxPostTextLength,
                  decoration: const InputDecoration(
                    hintText: "What's on your mind?",
                    border: InputBorder.none,
                    counterText: '',
                  ),
                  style: AppTextStyles.body,
                ),
                if (_imagePaths.isNotEmpty) ...[
                  SizedBox(
                    height: 84,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _imagePaths.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) => Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(File(_imagePaths[i]), width: 84, height: 84, fit: BoxFit.cover),
                          ),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: GestureDetector(
                              onTap: () => setState(() => _imagePaths.removeAt(i)),
                              child: Container(
                                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                padding: const EdgeInsets.all(2),
                                child: const Icon(Icons.close, size: 14, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const Divider(height: 24),
                Row(
                  children: [
                    _AttachIcon(icon: Icons.image_outlined, label: 'Photo', onTap: _pickImages),
                    _AttachIcon(icon: Icons.videocam_outlined, label: 'Video', onTap: _openVideo),
                    _AttachIcon(icon: Icons.bar_chart_rounded, label: 'Poll', onTap: _openPoll),
                    _AttachIcon(icon: Icons.gif_box_outlined, label: 'GIF', onTap: _pickImages),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text('Post type', style: AppTextStyles.caption),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final t in _postTypes)
                ChoiceChip(
                  label: Text(t.$2),
                  avatar: Icon(t.$3, size: 16),
                  selected: _postType == t.$1,
                  onSelected: (_) => setState(() => _postType = t.$1),
                ),
            ],
          ),
          if (isHome) ...[
            const SizedBox(height: 14),
            Text('Tag game (optional)', style: AppTextStyles.caption),
            const SizedBox(height: 6),
            Consumer(
              builder: (context, ref, _) {
                final games = ref.watch(myCommunitiesProvider).valueOrNull ?? [];
                return DropdownButtonFormField<String>(
                  value: _taggedCommunityId,
                  isExpanded: true,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  hint: const Text('Select game'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('None')),
                    for (final g in games) DropdownMenuItem(value: g.id, child: Text(g.name)),
                  ],
                  onChanged: (v) => setState(() => _taggedCommunityId = v),
                );
              },
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: AppTextStyles.caption.copyWith(color: AppColors.error)),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: KxButton(label: 'Post', onPressed: _submit, loading: _loading),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Text(footer, style: AppTextStyles.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachIcon extends StatelessWidget {
  const _AttachIcon({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              Icon(icon, color: AppColors.textSecondary, size: 22),
              const SizedBox(height: 2),
              Text(label, style: AppTextStyles.caption.copyWith(fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnnouncementSheet extends ConsumerStatefulWidget {
  const _AnnouncementSheet({
    required this.origin,
    required this.destinationId,
    required this.destinationName,
    this.destinationAvatarUrl,
    this.destinationSubtitle,
  });

  final ComposerOrigin origin;
  final String destinationId;
  final String destinationName;
  final String? destinationAvatarUrl;
  final String? destinationSubtitle;

  @override
  ConsumerState<_AnnouncementSheet> createState() => _AnnouncementSheetState();
}

class _AnnouncementSheetState extends ConsumerState<_AnnouncementSheet> {
  final _body = TextEditingController();
  bool _notify = true;
  bool _pin = false;
  bool _loading = false;
  String? _error;
  static const _maxLen = 500;

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _notifyMembers(String postId) async {
    try {
      final client = ref.read(supabaseClientProvider);
      final me = client.auth.currentUser?.id;
      if (me == null) return;
      List<Map<String, dynamic>> members;
      String targetType;
      if (widget.origin == ComposerOrigin.squad) {
        final list = ref.read(squadMembersProvider(widget.destinationId)).valueOrNull ??
            (await ref.read(squadRepositoryProvider).members(widget.destinationId)).valueOrNull ??
            [];
        members = list.map((m) => {'user_id': m.userId}).toList();
        targetType = 'squad_announcement';
      } else {
        final r = await ref.read(communityRepositoryProvider).members(widget.destinationId);
        members = r.valueOrNull ?? [];
        targetType = 'community_announcement';
      }
      final rows = [
        for (final m in members)
          if (m['user_id'] != me)
            {
              'user_id': m['user_id'],
              'type': targetType,
              'title': widget.destinationName,
              'body': _body.text.trim().length > 120
                  ? '${_body.text.trim().substring(0, 120)}…'
                  : _body.text.trim(),
              'actor_id': me,
              'target_type': 'post',
              'target_id': postId,
              'category': widget.origin == ComposerOrigin.squad ? 'squad' : 'community',
            },
      ];
      if (rows.isNotEmpty) {
        await client.from('notifications').insert(rows);
      }
    } catch (_) {
      // Notification delivery is best-effort — the announcement itself already succeeded.
    }
  }

  Future<void> _submit() async {
    final text = _body.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Write your announcement');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    final repo = ref.read(postRepositoryProvider);
    final result = await repo.createTextPost(
      body: text,
      squadId: widget.origin == ComposerOrigin.squad ? widget.destinationId : null,
      communityId: widget.origin == ComposerOrigin.community ? widget.destinationId : null,
      postType: 'text',
      isAnnouncement: true,
      isPinned: _pin,
    );

    if (!mounted) return;

    await result.when(
      success: (post) async {
        if (_notify) await _notifyMembers(post.id);
        if (widget.origin == ComposerOrigin.squad) {
          ref.invalidate(squadPostFeedProvider(widget.destinationId));
        }
        if (!mounted) return;
        setState(() => _loading = false);
        Navigator.of(context).pop(true);
      },
      failure: (e, _) async {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = ErrorHandler.userMessage(e);
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return _SheetChrome(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DestinationHeader(
            name: widget.destinationName,
            subtitle: widget.destinationSubtitle ?? '',
            avatarUrl: widget.destinationAvatarUrl,
            onClose: () => Navigator.of(context).pop(),
          ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Create an announcement', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700)),
                Text('Important updates for your ${widget.origin == ComposerOrigin.squad ? "squad" : "community"}',
                    style: AppTextStyles.caption),
                const SizedBox(height: 10),
                TextField(
                  controller: _body,
                  maxLines: 6,
                  minLines: 4,
                  maxLength: _maxLen,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Write your announcement…',
                    border: InputBorder.none,
                  ),
                  style: AppTextStyles.body,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _ToggleRow(
            icon: Icons.notifications_active_outlined,
            title: 'Notify squad members',
            subtitle: 'Members will get a push notification',
            value: _notify,
            onChanged: (v) => setState(() => _notify = v),
          ),
          const SizedBox(height: 8),
          _ToggleRow(
            icon: Icons.push_pin_outlined,
            title: 'Pin announcement',
            subtitle: 'Keep this announcement at the top',
            value: _pin,
            onChanged: (v) => setState(() => _pin = v),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: AppTextStyles.caption.copyWith(color: AppColors.error)),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: KxButton(label: 'Announce', onPressed: _submit, loading: _loading),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Text(
                  'Only ${widget.origin == ComposerOrigin.squad ? "squad" : "community"} members can see this announcement',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.body.copyWith(fontSize: 14, fontWeight: FontWeight.w600)),
                Text(subtitle, style: AppTextStyles.caption.copyWith(fontSize: 11)),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged, activeColor: AppColors.primary),
        ],
      ),
    );
  }
}
