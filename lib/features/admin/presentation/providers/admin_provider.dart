import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/dependency_injection.dart';
import '../../data/admin_repository.dart';
import '../../domain/admin_entities.dart';

final adminRepositoryProvider = Provider((ref) {
  return AdminRepository(ref.watch(supabaseClientProvider));
});

final isStaffProvider = FutureProvider<bool>((ref) async {
  final r = await ref.watch(adminRepositoryProvider).isStaff();
  return r.valueOrNull ?? false;
});

/// The signed-in staffer's own app_role ('user' if not staff / unknown).
/// Used to gate role-change actions in the UI the same way the web admin
/// panel's `can()` does.
final myStaffRoleProvider = FutureProvider<String>((ref) async {
  final r = await ref.watch(adminRepositoryProvider).myRole();
  return r.valueOrNull ?? 'user';
});

/// Mirrors `can()` in konex-admin-panel/src/lib/AuthContext.jsx so both
/// clients hide the same actions from the same roles. The database RPCs
/// (admin_set_role, etc.) enforce the real boundary — this only keeps the
/// UI honest.
bool canStaff(String role, String action) {
  const staffRoles = {'moderator', 'admin', 'super_admin'};
  switch (action) {
    case 'view_dashboard':
    case 'view_reports':
    case 'resolve_reports':
    case 'ban_users':
    case 'manage_games':
      return staffRoles.contains(role);
    case 'verify_users':
    case 'make_moderator':
      return role == 'admin' || role == 'super_admin';
    case 'make_admin':
      return role == 'super_admin';
    case 'change_super_admin':
      return false; // nobody does this from the UI, ever
    default:
      return false;
  }
}

final adminStatsProvider = FutureProvider<AdminStats>((ref) async {
  final r = await ref.watch(adminRepositoryProvider).stats();
  return r.valueOrNull ?? const AdminStats();
});

final openReportsProvider = FutureProvider<List<ReportEntity>>((ref) async {
  final r = await ref.watch(adminRepositoryProvider).openReports();
  return r.valueOrNull ?? [];
});

final auditLogsProvider = FutureProvider<List<AuditLogEntity>>((ref) async {
  final r = await ref.watch(adminRepositoryProvider).recentAudit();
  return r.valueOrNull ?? [];
});
