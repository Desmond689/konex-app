import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/kx_empty_state.dart';
import '../../../../core/widgets/kx_error_view.dart';
import '../../../../core/widgets/kx_verified_badge.dart';
import '../../../communities/presentation/providers/community_provider.dart';
import 'admin_create_game_screen.dart';
import 'admin_edit_game_screen.dart';
import '../../../../core/errors/error_handler.dart';

/// Staff: browse every game/community (highest members first) and edit
/// any of them — name, description, rules, category, and logo.
class AdminGamesScreen extends ConsumerStatefulWidget {
  const AdminGamesScreen({super.key});

  @override
  ConsumerState<AdminGamesScreen> createState() => _AdminGamesScreenState();
}

class _AdminGamesScreenState extends ConsumerState<AdminGamesScreen> {
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
    final games = ref.watch(adminAllGamesProvider(_query));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage games'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Create game',
            onPressed: () async {
              final ok = await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => const AdminCreateGameScreen()),
              );
              if (ok == true) ref.invalidate(adminAllGamesProvider(_query));
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search games',
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
          Expanded(
            child: games.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => KxErrorView(
                message: ErrorHandler.userMessage(e),
                onRetry: () => ref.invalidate(adminAllGamesProvider(_query)),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return KxEmptyState(
                    title: _query != null ? 'No matches' : 'No games yet',
                    subtitle: _query != null
                        ? 'No game matches "$_query".'
                        : 'Tap + to create the first one.',
                    icon: Icons.sports_esports_outlined,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(adminAllGamesProvider(_query)),
                  child: ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final c = list[i];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.surfaceElevated,
                          backgroundImage:
                              c.avatarUrl != null ? NetworkImage(c.avatarUrl!) : null,
                          child: c.avatarUrl == null
                              ? Text(c.name.isNotEmpty ? c.name[0].toUpperCase() : '?')
                              : null,
                        ),
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
                        trailing: const Icon(Icons.edit_outlined),
                        onTap: () async {
                          final ok = await Navigator.of(context).push<bool>(
                            MaterialPageRoute(
                              builder: (_) => AdminEditGameScreen(community: c),
                            ),
                          );
                          if (ok == true) ref.invalidate(adminAllGamesProvider(_query));
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
