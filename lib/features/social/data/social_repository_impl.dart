import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/result.dart';
import '../../../core/network/base_repository.dart';
import '../domain/social_repository.dart';

class SocialRepositoryImpl with BaseRepository implements SocialRepository {
  SocialRepositoryImpl(this._client);
  final SupabaseClient _client;

  String get _uid {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('Not authenticated');
    return id;
  }

  @override
  Future<Result<void>> follow(String userId) => guard(() async {
        await _client.from('follows').upsert({
          'follower_id': _uid,
          'following_id': userId,
        });
      });

  @override
  Future<Result<void>> unfollow(String userId) => guard(() async {
        await _client
            .from('follows')
            .delete()
            .eq('follower_id', _uid)
            .eq('following_id', userId);
      });

  @override
  Future<Result<void>> block(String userId) => guard(() async {
        await _client.from('blocks').upsert({
          'blocker_id': _uid,
          'blocked_id': userId,
        });
        // Also unfollow both ways
        await _client
            .from('follows')
            .delete()
            .eq('follower_id', _uid)
            .eq('following_id', userId);
        await _client
            .from('follows')
            .delete()
            .eq('follower_id', userId)
            .eq('following_id', _uid);
      });

  @override
  Future<Result<void>> unblock(String userId) => guard(() async {
        await _client
            .from('blocks')
            .delete()
            .eq('blocker_id', _uid)
            .eq('blocked_id', userId);
      });

  @override
  Future<Result<void>> report({
    required String targetType,
    required String targetId,
    required String reason,
    String? details,
  }) =>
      guard(() async {
        await _client.from('reports').insert({
          'reporter_id': _uid,
          'target_type': targetType,
          'target_id': targetId,
          'reason': reason,
          if (details != null) 'details': details,
        });
      });
}
