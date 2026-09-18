import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/result.dart';
import '../../../core/network/base_repository.dart';

class SearchRepository with BaseRepository {
  SearchRepository(this._client);
  final SupabaseClient _client;

  Future<Result<Map<String, List<Map<String, dynamic>>>>> searchAll(
    String term, {
    int limit = 20,
  }) =>
      guard(() async {
        final t = term.trim();
        if (t.length < 2) {
          return {
            'users': <Map<String, dynamic>>[],
            'games': <Map<String, dynamic>>[],
            'squads': <Map<String, dynamic>>[],
            'posts': <Map<String, dynamic>>[],
            'lfg': <Map<String, dynamic>>[],
          };
        }

        final pattern = '%$t%';
        final exactUser = t.startsWith('@') ? t.substring(1) : t;

        final users = await _client
            .from('profiles')
            .select('id, username, gamer_name, avatar_url, is_verified')
            .or(
              'username.ilike.$pattern,gamer_name.ilike.$pattern,username.eq.$exactUser',
            )
            .eq('is_banned', false)
            .limit(limit);

        final games = await _client
            .from('communities')
            .select(
              'id, name, slug, game_name, member_count, is_official, is_private, avatar_url',
            )
            .or('name.ilike.$pattern,game_name.ilike.$pattern,slug.ilike.$pattern')
            .eq('is_archived', false)
            .limit(limit);

        // Public squads only in search (private = limited exposure)
        final squads = await _client
            .from('squads')
            .select('id, name, slug, member_count, is_public, primary_game, logo_url')
            .ilike('name', pattern)
            .eq('is_deleted', false)
            .eq('is_public', true)
            .limit(limit);

        final posts = await _client
            .from('posts')
            .select(
              'id, body, post_type, created_at, like_count, comment_count, '
              'author_id, community_id, '
              'profiles!posts_author_id_fkey ( username, gamer_name ), '
              'communities ( name )',
            )
            .ilike('body', pattern)
            .eq('is_deleted', false)
            .eq('visibility', 'public')
            .order('created_at', ascending: false)
            .limit(limit);

        final lfg = await _client
            .from('lfg_details')
            .select(
              'post_id, game_name, mode, region, players_needed, status, created_at, '
              'posts!lfg_details_post_id_fkey ( id, body )',
            )
            .or('game_name.ilike.$pattern,mode.ilike.$pattern')
            .eq('status', 'open')
            .order('created_at', ascending: false)
            .limit(limit);

        return {
          'users': _maps(users),
          'games': _maps(games),
          'squads': _maps(squads),
          'posts': _maps(posts),
          'lfg': _maps(lfg),
        };
      });

  List<Map<String, dynamic>> _maps(dynamic rows) =>
      (rows as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
}
