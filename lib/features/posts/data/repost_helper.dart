import 'package:supabase_flutter/supabase_flutter.dart';

class RepostHelper {
  RepostHelper(this._client);
  final SupabaseClient _client;

  String get _uid {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('Not authenticated');
    return id;
  }

  Future<void> repost(String postId) async {
    await _client.from('reposts').upsert({
      'user_id': _uid,
      'post_id': postId,
    });
  }

  Future<void> unrepost(String postId) async {
    await _client.from('reposts').delete().eq('user_id', _uid).eq('post_id', postId);
  }

  Future<bool> hasReposted(String postId) async {
    final row = await _client
        .from('reposts')
        .select()
        .eq('user_id', _uid)
        .eq('post_id', postId)
        .maybeSingle();
    return row != null;
  }
}
