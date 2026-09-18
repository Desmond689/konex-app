import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/kx_empty_state.dart';
import '../../../../core/widgets/kx_error_view.dart';
import '../providers/admin_provider.dart';
import '../../../../core/errors/error_handler.dart';

class AdminAuditScreen extends ConsumerWidget {
  const AdminAuditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(auditLogsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Audit log')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => KxErrorView(message: ErrorHandler.userMessage(e)),
        data: (list) {
          if (list.isEmpty) {
            return const KxEmptyState(
              title: 'No audit entries',
              icon: Icons.history,
            );
          }
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (_, i) {
              final a = list[i];
              return ListTile(
                title: Text(a.action),
                subtitle: Text(
                  [
                    if (a.targetType != null) a.targetType!,
                    if (a.reason != null) a.reason!,
                    DateFormat.MMMd().add_jm().format(a.createdAt.toLocal()),
                  ].join(' · '),
                  style: AppTextStyles.caption,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
