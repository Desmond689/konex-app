import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../providers/profile_provider.dart';
import '../../../../core/errors/error_handler.dart';

enum FollowListMode { followers, following }

class FollowListScreen extends ConsumerStatefulWidget {
  const FollowListScreen({
    super.key,
    required this.userId,
    required this.mode,
  });

  final String userId;
  final FollowListMode mode;

  @override
  ConsumerState<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends ConsumerState<FollowListScreen> {
  List<Map<String, dynamic>> _rows = [];
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
    final repo = ref.read(profileRepositoryProvider);
    final r = widget.mode == FollowListMode.followers
        ? await repo.listFollowers(widget.userId)
        : await repo.listFollowing(widget.userId);
    if (!mounted) return;
    r.when(
      success: (list) => setState(() {
        _rows = list;
        _loading = false;
      }),
      failure: (e, _) => setState(() {
        _error = ErrorHandler.userMessage(e);
        _loading = false;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title =
        widget.mode == FollowListMode.followers ? 'Followers' : 'Following';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _rows.isEmpty
                  ? Center(child: Text('No one yet', style: AppTextStyles.caption))
                  : ListView.builder(
                      itemCount: _rows.length,
                      itemBuilder: (_, i) {
                        final r = _rows[i];
                        final p = r['profiles'] as Map<String, dynamic>?;
                        final id = p?['id'] as String? ??
                            r['follower_id'] as String? ??
                            r['following_id'] as String? ??
                            '';
                        final name = (p?['gamer_name'] as String?)?.isNotEmpty == true
                            ? p!['gamer_name'] as String
                            : p?['username'] as String? ?? 'User';
                        final username = p?['username'] as String? ?? '';
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: p?['avatar_url'] != null
                                ? NetworkImage(p!['avatar_url'] as String)
                                : null,
                            child: p?['avatar_url'] == null
                                ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?')
                                : null,
                          ),
                          title: Text(name),
                          subtitle: Text('@$username'),
                          onTap: id.isEmpty ? null : () => context.push('/user/$id'),
                        );
                      },
                    ),
    );
  }
}
