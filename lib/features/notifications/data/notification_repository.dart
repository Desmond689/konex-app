import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/result.dart';
import '../../../core/network/base_repository.dart';
import '../domain/notification_entity.dart';

class NotificationRepository with BaseRepository {
  NotificationRepository(this._client);
  final SupabaseClient _client;

  String get _uid => _client.auth.currentUser!.id;

  Future<Result<List<NotificationEntity>>> list({
    String? category,
    int page = 0,
    int pageSize = 30,
  }) =>
      guard(() async {
        var q = _client
            .from('notifications')
            .select('''
              id, type, title, body, actor_id, target_type, target_id,
              is_read, created_at, category, group_key, actor_count,
              profiles!notifications_actor_id_fkey ( username, gamer_name, avatar_url )
            ''')
            .eq('user_id', _uid);
        if (category != null && category != 'all') {
          q = q.eq('category', category);
        }
        final from = page * pageSize;
        final to = from + pageSize - 1;
        final rows = await q
            .order('created_at', ascending: false)
            .range(from, to);
        return (rows as List)
            .map((r) =>
                NotificationEntity.fromMap(Map<String, dynamic>.from(r as Map)))
            .toList();
      });

  Future<Result<int>> unreadCount() => guard(() async {
        final n = await _client.rpc('unread_notification_count');
        return (n as int?) ?? 0;
      });

  Future<Result<void>> markRead(String id) => guard(() async {
        await _client
            .from('notifications')
            .update({'is_read': true})
            .eq('id', id)
            .eq('user_id', _uid);
      });

  Future<Result<void>> markAllRead() => guard(() async {
        await _client.rpc('mark_all_notifications_read');
      });

  Future<Result<NotificationPreferences>> getPreferences() => guard(() async {
        final row = await _client
            .from('notification_preferences')
            .select()
            .eq('user_id', _uid)
            .maybeSingle();
        return NotificationPreferences.fromMap(
          row == null ? null : Map<String, dynamic>.from(row),
        );
      });

  Future<Result<void>> savePreferences(NotificationPreferences prefs) =>
      guard(() async {
        await _client.from('notification_preferences').upsert(prefs.toMap(_uid));
      });

  Future<Result<void>> setQuietMode(Duration duration) => guard(() async {
        final until = DateTime.now().toUtc().add(duration);
        await _client.from('notification_preferences').upsert({
          'user_id': _uid,
          'quiet_until': until.toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      });

  Future<Result<void>> clearQuietMode() => guard(() async {
        await _client.from('notification_preferences').upsert({
          'user_id': _uid,
          'quiet_until': null,
          'updated_at': DateTime.now().toIso8601String(),
        });
      });
}
