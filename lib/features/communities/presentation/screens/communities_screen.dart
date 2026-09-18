import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/kx_empty_state.dart';
import '../../../../core/widgets/kx_error_view.dart';
import '../../../../core/widgets/kx_verified_badge.dart';
import '../providers/community_provider.dart';
import '../../../../core/errors/error_handler.dart';

/// Games & Communities (same entity). My games + Discover, with search.
class CommunitiesScreen extends ConsumerStatefulWidget {
  const CommunitiesScreen({super.key});

  @override
  ConsumerState<CommunitiesScreen> createState() => _CommunitiesScreenState();
}

class _CommunitiesScreenState extends ConsumerState<CommunitiesScreen> {
  final _searchController = TextEditingController();
  String? _query;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _query = value.trim().isEmpty ? null : value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final mine = ref.watch(myCommunitiesProvider);
    final discover = ref.watch(communitiesDiscoverProvider(_query));

    return Scaffold(
      appBar: AppBar(title: const Text('Games')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myCommunitiesProvider);
          ref.invalidate(communitiesDiscoverProvider(_query));
        },
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('My games', style: AppTextStyles.title),
            ),
            mine.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text('$e'),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'No games yet. Join from Discover or during signup.',
                      style: AppTextStyles.caption,
                    ),
                  );
                }
                return Column(
                  children: list
                      .map(
                        (c) => ListTile(
                          leading: _logo(c.avatarUrl, c.name),
                          title: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(child: Text(c.name, overflow: TextOverflow.ellipsis)),
                              if (c.isOfficial) ...[
                                const SizedBox(width: 4),
                                const KxVerifiedBadge(),
                              ],
                            ],
                          ),
                          subtitle: Text(
                            '${c.memberCount} members',
                            style: AppTextStyles.caption,
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push('/community/${c.id}'),
                        ),
                      )
                      .toList(),
                );
              },
            ),
            const Divider(height: 32),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text('Discover games', style: AppTextStyles.title),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search communities',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _debounce?.cancel();
                            setState(() => _query = null);
                          },
                        ),
                  filled: true,
                  fillColor: AppColors.surfaceElevated,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                ),
              ),
            ),
            const SizedBox(height: 8),
            discover.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => KxErrorView(message: ErrorHandler.userMessage(e)),
              data: (list) {
                if (list.isEmpty) {
                  return KxEmptyState(
                    title: _query != null ? 'No matches' : 'No games yet',
                    subtitle: _query != null
                        ? 'No community matches "$_query".'
                        : 'Platform admins add official games from Admin.',
                    icon: Icons.sports_esports_outlined,
                  );
                }
                return Column(
                  children: list
                      .map(
                        (c) => ListTile(
                          leading: _logo(c.avatarUrl, c.name),
                          title: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(child: Text(c.name, overflow: TextOverflow.ellipsis)),
                              if (c.isOfficial) ...[
                                const SizedBox(width: 4),
                                const KxVerifiedBadge(),
                              ],
                            ],
                          ),
                          subtitle: Text(
                            [
                              '${c.memberCount} members',
                              if (c.category != null) c.category!,
                            ].join(' · '),
                            style: AppTextStyles.caption,
                          ),
                          trailing: c.isMember
                              ? const Chip(label: Text('Joined'))
                              : const Icon(Icons.chevron_right),
                          onTap: () => context.push('/community/${c.id}'),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _logo(String? url, String name) {
    return CircleAvatar(
      backgroundColor: AppColors.surfaceElevated,
      backgroundImage: url != null ? NetworkImage(url) : null,
      child: url == null
          ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?')
          : null,
    );
  }
}
