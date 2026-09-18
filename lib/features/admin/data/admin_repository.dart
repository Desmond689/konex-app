import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/result.dart';
import '../../../core/network/base_repository.dart';
import '../domain/admin_entities.dart';

class AdminRepository with BaseRepository {
  AdminRepository(this._client);
  final SupabaseClient _client;

  String get _uid {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('Not authenticated');
    return id;
  }

  Future<Result<bool>> isStaff() => guard(() async {
        final row = await _client
            .from('profiles')
            .select('app_role')
            .eq('id', _uid)
            .maybeSingle();
        final role = row?['app_role'] as String? ?? 'user';
        return role == 'moderator' || role == 'admin' || role == 'super_admin';
      });

  /// The signed-in staffer's own app_role, for client-side action gating
  /// (mirrors `can()` in the web admin panel's AuthContext.jsx). The
  /// admin_set_role RPC is the real boundary; this just keeps the UI from
  /// showing buttons that would 403.
  Future<Result<String>> myRole() => guard(() async {
        final row = await _client
            .from('profiles')
            .select('app_role')
            .eq('id', _uid)
            .maybeSingle();
        return row?['app_role'] as String? ?? 'user';
      });

  Future<Result<AdminStats>> stats() => guard(() async {
        final users = await _client.from('profiles').select('id').count(CountOption.exact);
        final reports = await _client
            .from('reports')
            .select('id')
            .eq('status', 'open')
            .count(CountOption.exact);
        final posts = await _client
            .from('posts')
            .select('id')
            .eq('is_deleted', false)
            .count(CountOption.exact);
        final squads = await _client.from('squads').select('id').count(CountOption.exact);
        return AdminStats(
          totalUsers: users.count,
          openReports: reports.count,
          totalPosts: posts.count,
          totalSquads: squads.count,
        );
      });

  Future<Result<List<ReportEntity>>> openReports({int limit = 50}) => guard(() async {
        final rows = await _client
            .from('reports')
            .select('''
              id, reporter_id, target_type, target_id, reason, details, status, created_at,
              profiles!reports_reporter_id_fkey ( username )
            ''')
            .eq('status', 'open')
            .order('created_at', ascending: false)
            .limit(limit);
        return (rows as List)
            .map((r) => ReportEntity.fromMap(Map<String, dynamic>.from(r as Map)))
            .toList();
      });

  Future<Result<void>> resolveReport({
    required String reportId,
    required String action,
    String? reason,
    String? targetUserId,
    String? targetType,
    String? targetId,
  }) =>
      guard(() async {
        if (reportId.isNotEmpty && reportId != '00000000-0000-0000-0000-000000000000') {
          await _client.from('reports').update({
            'status': action == 'no_action' ? 'dismissed' : 'actioned',
            'reviewed_at': DateTime.now().toIso8601String(),
            'reviewed_by': _uid,
          }).eq('id', reportId);
        }

        await _client.from('moderation_actions').insert({
          if (reportId.isNotEmpty && reportId != '00000000-0000-0000-0000-000000000000')
            'report_id': reportId,
          'actor_id': _uid,
          'target_user_id': targetUserId,
          'target_type': targetType ?? 'unknown',
          'target_id': targetId,
          'action': action,
          'reason': reason,
        });

        await _client.from('audit_logs').insert({
          'actor_id': _uid,
          'action': action,
          'target_type': targetType,
          'target_id': targetId,
          'reason': reason,
          'metadata': {'report_id': reportId},
        });

        if (targetUserId != null) {
          if (action == 'ban') {
            await _client.from('profiles').update({
              'is_banned': true,
              'updated_at': DateTime.now().toIso8601String(),
            }).eq('id', targetUserId);
          } else if (action == 'restrict') {
            await _client.from('profiles').update({
              'is_restricted': true,
              'restricted_until':
                  DateTime.now().add(const Duration(days: 7)).toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            }).eq('id', targetUserId);
          } else if (action == 'suspend') {
            await _client.from('profiles').update({
              'is_restricted': true,
              'restricted_until':
                  DateTime.now().add(const Duration(days: 30)).toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            }).eq('id', targetUserId);
          } else if (action == 'restore') {
            await _client.from('profiles').update({
              'is_banned': false,
              'is_restricted': false,
              'restricted_until': null,
              'updated_at': DateTime.now().toIso8601String(),
            }).eq('id', targetUserId);
          }
        }

        if (action == 'remove_content' &&
            targetType == 'post' &&
            targetId != null) {
          await _client.from('posts').update({
            'is_deleted': true,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', targetId);
        }
      });

  Future<Result<List<Map<String, dynamic>>>> searchUsers(String query) =>
      guard(() async {
        // Escape PostgREST special chars in .or() filters
        final q = query.trim().replaceAll(RegExp(r'[%_,.]'), ' ').trim();
        if (q.isEmpty) return <Map<String, dynamic>>[];
        final rows = await _client
            .from('profiles')
            .select(
              'id, username, gamer_name, app_role, is_banned, is_restricted, is_verified, created_at',
            )
            .or('username.ilike.%$q%,gamer_name.ilike.%$q%')
            .limit(30);
        return List<Map<String, dynamic>>.from(rows as List);
      });

  Future<Result<void>> setUserRole(String userId, String role) => guard(() async {
        await _client.rpc('admin_set_role', params: {
          'p_user_id': userId,
          'p_role': role,
        });
        await _client.from('audit_logs').insert({
          'actor_id': _uid,
          'action': 'set_role',
          'target_type': 'profile',
          'target_id': userId,
          'reason': role,
        });
      });

  Future<Result<void>> setUserBan(String userId, bool banned) => guard(() async {
        await _client.rpc('admin_set_ban', params: {
          'p_user_id': userId,
          'p_banned': banned,
        });
        await _client.from('audit_logs').insert({
          'actor_id': _uid,
          'action': banned ? 'ban' : 'unban',
          'target_type': 'profile',
          'target_id': userId,
        });
      });

  Future<Result<void>> setUserVerified(String userId, bool verified) => guard(() async {
        await _client.rpc('admin_set_verified', params: {
          'p_user_id': userId,
          'p_verified': verified,
        });
        await _client.from('audit_logs').insert({
          'actor_id': _uid,
          'action': verified ? 'verify' : 'unverify',
          'target_type': 'profile',
          'target_id': userId,
        });
      });

  Future<Result<List<AuditLogEntity>>> recentAudit({int limit = 40}) =>
      guard(() async {
        final rows = await _client
            .from('audit_logs')
            .select()
            .order('created_at', ascending: false)
            .limit(limit);
        return (rows as List)
            .map((r) => AuditLogEntity.fromMap(Map<String, dynamic>.from(r as Map)))
            .toList();
      });
}
