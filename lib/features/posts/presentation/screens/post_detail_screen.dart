import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/dependency_injection.dart';
import '../../../../core/deep_links/share_service.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/kx_error_view.dart';
import '../../domain/entities/post_entity.dart';
import '../widgets/post_card.dart';
import '../../../../core/errors/error_handler.dart';

class PostDetailScreen extends ConsumerStatefulWidget {
  const PostDetailScreen({super.key, required this.postId});
  final String postId;

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  PostEntity? _post;
  bool _loading = true;
  String? _error;

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
    try {
      final client = ref.read(supabaseClientProvider);
      final row = await client
          .from('posts')
          .select('''
            id, author_id, community_id, squad_id, post_type, body, visibility,
            like_count, comment_count, share_count, created_at, is_deleted,
            profiles!posts_author_id_fkey ( username, gamer_name, avatar_url ),
            communities ( name ),
            squads ( name ),
            post_media ( media:media_id ( media_url ) )
          ''')
          .eq('id', widget.postId)
          .maybeSingle();
      if (row == null || row['is_deleted'] == true) {
        setState(() {
          _post = null;
          _loading = false;
        });
        return;
      }
      final m = Map<String, dynamic>.from(row);
      final profile = m['profiles'] as Map<String, dynamic>?;
      final community = m['communities'] as Map<String, dynamic>?;
      final squad = m['squads'] as Map<String, dynamic>?;
      final mediaList = m['post_media'] as List? ?? [];
      final urls = <String>[];
      for (final pm in mediaList) {
        final media = (pm as Map)['media'];
        if (media is Map && media['media_url'] != null) {
          urls.add(media['media_url'] as String);
        }
      }
      setState(() {
        _post = PostEntity(
          id: m['id'] as String,
          authorId: m['author_id'] as String,
          authorUsername: profile?['username'] as String? ?? '',
          authorGamerName: profile?['gamer_name'] as String?,
          authorAvatarUrl: profile?['avatar_url'] as String?,
          communityId: m['community_id'] as String?,
          communityName: community?['name'] as String?,
          squadId: m['squad_id'] as String?,
          squadName: squad != null ? squad['name'] as String? : null,
          postType: m['post_type'] as String? ?? 'text',
          body: m['body'] as String?,
          mediaUrls: urls,
          visibility: m['visibility'] as String? ?? 'public',
          likeCount: m['like_count'] as int? ?? 0,
          commentCount: m['comment_count'] as int? ?? 0,
          shareCount: m['share_count'] as int? ?? 0,
          createdAt: DateTime.parse(m['created_at'] as String),
        );
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = ErrorHandler.userMessage(e);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Post'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () => ShareService.sharePost(context, widget.postId),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? KxErrorView(message: _error!, onRetry: _load)
              : _post == null
                  ? Center(
                      child: Text(
                        'This post is unavailable or was deleted.',
                        style: AppTextStyles.caption,
                      ),
                    )
                  : ListView(children: [PostCard(post: _post!)]),
    );
  }
}
