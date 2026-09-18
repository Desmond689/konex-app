import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/dependency_injection.dart';
import '../../../../core/widgets/kx_empty_state.dart';
import '../../domain/entities/post_entity.dart';
import '../providers/post_provider.dart';
import '../widgets/post_card.dart';

class SavedPostsScreen extends ConsumerStatefulWidget {
  const SavedPostsScreen({super.key});

  @override
  ConsumerState<SavedPostsScreen> createState() => _SavedPostsScreenState();
}

class _SavedPostsScreenState extends ConsumerState<SavedPostsScreen> {
  List<PostEntity> _posts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final client = ref.read(supabaseClientProvider);
    final uid = client.auth.currentUser?.id;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final saves = await client
          .from('saves')
          .select('post_id')
          .eq('user_id', uid)
          .order('created_at', ascending: false);

      final ids = (saves as List).map((s) => s['post_id'] as String).toList();
      if (ids.isEmpty) {
        if (!mounted) return;
        setState(() {
          _posts = [];
          _loading = false;
        });
        return;
      }

      final remote = ref.read(postRemoteProvider);
      final loaded = await remote.getPostsByIds(ids);
      final all = [
        for (final p in loaded) p.copyWith(savedByMe: true),
      ];
      if (!mounted) return;
      setState(() {
        _posts = all;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _posts = [];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saved')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _posts.isEmpty
              ? const KxEmptyState(
                  title: 'No saved posts',
                  subtitle: 'Bookmark posts to find them here.',
                  icon: Icons.bookmark_border,
                )
              : ListView.builder(
                  itemCount: _posts.length,
                  itemBuilder: (_, i) =>
                      PostCard(key: ValueKey(_posts[i].id), post: _posts[i]),
                ),
    );
  }
}
