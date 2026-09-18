import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/kx_empty_state.dart';
import '../../../../core/widgets/kx_error_view.dart';
import '../providers/squad_provider.dart';
import 'create_squad_screen.dart';
import '../../../../core/errors/error_handler.dart';

/// Squads tab: if user has a squad → open it immediately.
/// Otherwise show Discover + Create only (no multi-squad list).
class SquadsScreen extends ConsumerStatefulWidget {
  const SquadsScreen({super.key});

  @override
  ConsumerState<SquadsScreen> createState() => _SquadsScreenState();
}

class _SquadsScreenState extends ConsumerState<SquadsScreen> {
  bool _redirecting = false;

  @override
  Widget build(BuildContext context) {
    final mine = ref.watch(myActiveSquadProvider);

    return mine.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Squads')),
        body: KxErrorView(
          message: ErrorHandler.userMessage(e),
          onRetry: () => ref.invalidate(myActiveSquadProvider),
        ),
      ),
      data: (squad) {
        if (squad != null) {
          // Enter own squad immediately — no list of other squads
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_redirecting && mounted) {
              _redirecting = true;
              context.go('/squad/${squad.id}');
            }
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return _DiscoverScaffold(ref: ref);
      },
    );
  }
}

class _DiscoverScaffold extends StatelessWidget {
  const _DiscoverScaffold({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final discover = ref.watch(squadsDiscoverProvider(null));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Find a squad'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Create squad',
            onPressed: () async {
              final ok = await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => const CreateSquadScreen()),
              );
              if (ok == true) {
                ref.invalidate(myActiveSquadProvider);
                ref.invalidate(squadsDiscoverProvider(null));
              }
            },
          ),
        ],
      ),
      body: discover.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => KxErrorView(
          message: ErrorHandler.userMessage(e),
          onRetry: () => ref.invalidate(squadsDiscoverProvider(null)),
        ),
        data: (list) {
          if (list.isEmpty) {
            return KxEmptyState(
              title: 'No public squads yet',
              subtitle: 'Create the first one — you can only be in one squad.',
              icon: Icons.shield_outlined,
              action: TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CreateSquadScreen()),
                  );
                },
                child: const Text('Create squad'),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(squadsDiscoverProvider(null));
              await ref.read(squadsDiscoverProvider(null).future);
            },
            child: ListView.builder(
              itemCount: list.length,
              itemBuilder: (_, i) {
                final s = list[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.surfaceElevated,
                    backgroundImage:
                        s.logoUrl != null ? NetworkImage(s.logoUrl!) : null,
                    child: s.logoUrl == null
                        ? Text(s.name.isNotEmpty ? s.name[0].toUpperCase() : '?')
                        : null,
                  ),
                  title: Text(s.name),
                  subtitle: Text(
                    [
                      if (s.primaryGame != null) s.primaryGame!,
                      '${s.memberCount} members',
                      s.requireApproval ? 'Approval' : 'Instant join',
                    ].join(' · '),
                    style: AppTextStyles.caption,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/squad/${s.id}'),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
