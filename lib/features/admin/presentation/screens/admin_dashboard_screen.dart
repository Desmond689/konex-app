import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/kx_error_view.dart';
import '../providers/admin_provider.dart';
import 'admin_reports_screen.dart';
import 'admin_users_screen.dart';
import 'admin_audit_screen.dart';
import 'admin_create_game_screen.dart';
import 'admin_games_screen.dart';
import '../../../../core/errors/error_handler.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staff = ref.watch(isStaffProvider);
    final stats = ref.watch(adminStatsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Admin')),
      body: staff.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => KxErrorView(message: ErrorHandler.userMessage(e)),
        data: (ok) {
          if (!ok) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Staff only. Set profiles.app_role to moderator/admin in Supabase for your user.',
                  style: AppTextStyles.bodySecondary,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              stats.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const SizedBox.shrink(),
                data: (s) => Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _StatCard(label: 'Users', value: '${s.totalUsers}'),
                    _StatCard(label: 'Open reports', value: '${s.openReports}'),
                    _StatCard(label: 'Posts', value: '${s.totalPosts}'),
                    _StatCard(label: 'Squads', value: '${s.totalSquads}'),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: const Icon(Icons.sports_esports_outlined),
                title: const Text('Create game'),
                subtitle: const Text('Game = Community in one step'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AdminCreateGameScreen()),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.videogame_asset_outlined),
                title: const Text('Manage games'),
                subtitle: const Text('Search, edit, and add logos to any game'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AdminGamesScreen()),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Report queue'),
                subtitle: const Text('Review and action reports'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AdminReportsScreen()),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.people_outline),
                title: const Text('User management'),
                subtitle: const Text('Search, ban, roles'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AdminUsersScreen()),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('Audit log'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AdminAuditScreen()),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: AppTextStyles.headline),
          Text(label, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}
