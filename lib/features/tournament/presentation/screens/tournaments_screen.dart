import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/kx_empty_state.dart';
import '../../../../core/widgets/kx_error_view.dart';
import '../providers/tournament_provider.dart';
import '../../../../core/errors/error_handler.dart';

class TournamentsScreen extends ConsumerWidget {
  const TournamentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(tournamentsListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Tournaments')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => KxErrorView(
          message: ErrorHandler.userMessage(e),
          onRetry: () => ref.invalidate(tournamentsListProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return const KxEmptyState(
              title: 'No open tournaments',
              subtitle: 'Free community events will show up here. Staff can create them.',
              icon: Icons.emoji_events_outlined,
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(tournamentsListProvider);
              await ref.read(tournamentsListProvider.future);
            },
            child: ListView.builder(
              itemCount: list.length,
              itemBuilder: (_, i) {
                final t = list[i];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    title: Text(t.title, style: AppTextStyles.title.copyWith(fontSize: 15)),
                    subtitle: Text(
                      '${t.gameName} · Free · '
                      '${t.participantCount}/${t.maxParticipants} · ${t.status}',
                      style: AppTextStyles.caption,
                    ),
                    trailing: t.isEntered
                        ? const Chip(label: Text('Joined'))
                        : TextButton(
                            child: const Text('Join'),
                            onPressed: () async {
                              final r = await ref
                                  .read(tournamentRepositoryProvider)
                                  .enter(t.id);
                              if (!context.mounted) return;
                              r.when(
                                success: (_) {
                                  ref.invalidate(tournamentsListProvider);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Joined tournament')),
                                  );
                                },
                                failure: (e, _) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('$e')),
                                  );
                                },
                              );
                            },
                          ),
                    onTap: () => context.push('/tournament/${t.id}'),
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
