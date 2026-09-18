import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/kx_empty_state.dart';
import '../../../../core/widgets/kx_error_view.dart';
import '../providers/lfg_provider.dart';
import 'create_lfg_screen.dart';
import '../../../../core/errors/error_handler.dart';

class LfgScreen extends ConsumerStatefulWidget {
  const LfgScreen({super.key, this.initialGame});
  final String? initialGame;

  @override
  ConsumerState<LfgScreen> createState() => _LfgScreenState();
}

class _LfgScreenState extends ConsumerState<LfgScreen> {
  String? _gameFilter;

  @override
  void initState() {
    super.initState();
    _gameFilter = widget.initialGame;
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(openLfgProvider(_gameFilter));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Looking For Group'),
        actions: [
          PopupMenuButton<String?>(
            icon: const Icon(Icons.filter_list),
            onSelected: (v) => setState(() => _gameFilter = v),
            itemBuilder: (_) => [
              const PopupMenuItem(value: null, child: Text('All games')),
              ...AppConstants.supportedGames.map(
                (g) => PopupMenuItem(value: g, child: Text(g)),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () async {
          final ok = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const CreateLfgScreen()),
          );
          if (ok == true) ref.invalidate(openLfgProvider(_gameFilter));
        },
        child: const Icon(Icons.add),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => KxErrorView(
          message: ErrorHandler.userMessage(e),
          onRetry: () => ref.invalidate(openLfgProvider(_gameFilter)),
        ),
        data: (list) {
          if (list.isEmpty) {
            return const KxEmptyState(
              title: 'No open LFG posts',
              subtitle: 'Post when you need teammates.',
              icon: Icons.group_add_outlined,
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(openLfgProvider(_gameFilter)),
            child: ListView.builder(
              itemCount: list.length,
              itemBuilder: (_, i) {
                final l = list[i];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    title: Text(l.gameName, style: AppTextStyles.title.copyWith(fontSize: 15)),
                    subtitle: Text(
                      [
                        if (l.mode != null) l.mode!,
                        if (l.rankRequirement != null) 'Rank: ${l.rankRequirement}',
                        if (l.platform != null) l.platform!,
                        'Need ${l.playersNeeded}',
                        if (l.micRequired) 'Mic required',
                        l.region,
                      ].join(' · '),
                      style: AppTextStyles.caption,
                    ),
                    trailing: l.authorId != null
                        ? IconButton(
                            icon: const Icon(Icons.chat_bubble_outline),
                            onPressed: () async {
                              // Navigate to user — DM from profile
                              context.push('/user/${l.authorId}');
                            },
                          )
                        : null,
                    isThreeLine: true,
                    onLongPress: () async {
                      // Author can close — simplified: anyone can try, RLS/post ownership on update
                      await ref.read(lfgRepositoryProvider).setLfgStatus(l.postId, 'closed');
                      ref.invalidate(openLfgProvider(_gameFilter));
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
