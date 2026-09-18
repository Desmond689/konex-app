import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/kx_empty_state.dart';
import '../../../../core/widgets/kx_error_view.dart';
import '../providers/admin_provider.dart';
import '../../../../core/errors/error_handler.dart';

class AdminReportsScreen extends ConsumerWidget {
  const AdminReportsScreen({super.key});

  Future<void> _action(
    BuildContext context,
    WidgetRef ref,
    String reportId,
    String targetType,
    String targetId,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('No action / dismiss'),
              onTap: () => Navigator.pop(ctx, 'no_action'),
            ),
            ListTile(
              title: const Text('Remove content'),
              onTap: () => Navigator.pop(ctx, 'remove_content'),
            ),
            ListTile(
              title: const Text('Warn'),
              onTap: () => Navigator.pop(ctx, 'warn'),
            ),
            ListTile(
              title: const Text('Restrict (7 days)'),
              onTap: () => Navigator.pop(ctx, 'restrict'),
            ),
            ListTile(
              title: const Text('Suspend (30 days)'),
              onTap: () => Navigator.pop(ctx, 'suspend'),
            ),
            ListTile(
              title: const Text('Ban user'),
              onTap: () => Navigator.pop(ctx, 'ban'),
            ),
          ],
        ),
      ),
    );
    if (action == null) return;

    final targetUserId = targetType == 'profile' ? targetId : null;
    await ref.read(adminRepositoryProvider).resolveReport(
          reportId: reportId,
          action: action,
          targetType: targetType,
          targetId: targetId,
          targetUserId: targetUserId,
          reason: 'Moderator action: $action',
        );
    ref.invalidate(openReportsProvider);
    ref.invalidate(adminStatsProvider);
    ref.invalidate(auditLogsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(openReportsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Report queue')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => KxErrorView(
          message: ErrorHandler.userMessage(e),
          onRetry: () => ref.invalidate(openReportsProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return const KxEmptyState(
              title: 'Queue clear',
              subtitle: 'No open reports.',
              icon: Icons.check_circle_outline,
            );
          }
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (_, i) {
              final r = list[i];
              return ListTile(
                title: Text('${r.targetType} · ${r.reason}'),
                subtitle: Text(
                  'by @${r.reporterUsername ?? r.reporterId.substring(0, 8)} · '
                  '${DateFormat.MMMd().add_jm().format(r.createdAt.toLocal())}\n'
                  '${r.details ?? ''}',
                  style: AppTextStyles.caption,
                ),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _action(
                  context,
                  ref,
                  r.id,
                  r.targetType,
                  r.targetId,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
