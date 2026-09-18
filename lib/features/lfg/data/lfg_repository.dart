import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/result.dart';
import '../../../core/network/base_repository.dart';
import '../domain/lfg_entity.dart';

class LfgRepository with BaseRepository {
  LfgRepository(this._client);
  final SupabaseClient _client;

  String get _uid {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('Not authenticated');
    return id;
  }

  Future<Result<String>> createLfg({
    required String body,
    required String gameName,
    String? mode,
    String? rankRequirement,
    String? platform,
    String region = 'CM',
    bool micRequired = false,
    int playersNeeded = 1,
  }) =>
      guard(() async {
        final post = await _client.from('posts').insert({
          'author_id': _uid,
          'body': body.trim(),
          'post_type': 'lfg',
          'visibility': 'public',
        }).select().single();

        await _client.from('lfg_details').insert({
          'post_id': post['id'],
          'game_name': gameName,
          'mode': mode,
          'rank_requirement': rankRequirement,
          'platform': platform,
          'region': region,
          'mic_required': micRequired,
          'players_needed': playersNeeded,
          'status': 'open',
        });
        return post['id'] as String;
      });

  Future<Result<void>> setLfgStatus(String postId, String status) => guard(() async {
        await _client.from('lfg_details').update({'status': status}).eq('post_id', postId);
      });

  Future<Result<List<LfgEntity>>> listOpenLfg({String? gameName}) => guard(() async {
        var q = _client
            .from('lfg_details')
            .select('''
              post_id, game_name, mode, rank_requirement, platform, region,
              mic_required, players_needed, status, created_at,
              posts!inner ( body, author_id, is_deleted, profiles!posts_author_id_fkey ( username, gamer_name ) )
            ''')
            .eq('status', 'open')
            .eq('posts.is_deleted', false);

        if (gameName != null && gameName.isNotEmpty) {
          q = q.eq('game_name', gameName);
        }

        final rows = await q.order('created_at', ascending: false).limit(30);
        return (rows as List).map((r) {
          final m = Map<String, dynamic>.from(r as Map);
          final post = m['posts'] as Map<String, dynamic>?;
          final profile = post?['profiles'] as Map<String, dynamic>?;
          final name = (profile?['gamer_name'] as String?)?.isNotEmpty == true
              ? profile!['gamer_name'] as String
              : profile?['username'] as String?;
          return LfgEntity(
            postId: m['post_id'] as String,
            gameName: m['game_name'] as String,
            mode: m['mode'] as String?,
            rankRequirement: m['rank_requirement'] as String?,
            platform: m['platform'] as String?,
            region: m['region'] as String? ?? 'CM',
            micRequired: m['mic_required'] as bool? ?? false,
            playersNeeded: m['players_needed'] as int? ?? 1,
            status: m['status'] as String? ?? 'open',
            body: post?['body'] as String?,
            authorId: post?['author_id'] as String?,
            authorName: name,
            createdAt: DateTime.tryParse(m['created_at'] as String? ?? ''),
          );
        }).toList();
      });

  Future<Result<String>> createPoll({
    required String question,
    required List<String> options,
    Duration? duration,
    bool allowChangeVote = false,
  }) =>
      guard(() async {
        final post = await _client.from('posts').insert({
          'author_id': _uid,
          'body': question.trim(),
          'post_type': 'poll',
          'visibility': 'public',
        }).select().single();

        final endsAt = duration != null
            ? DateTime.now().add(duration).toIso8601String()
            : null;

        final poll = await _client.from('polls').insert({
          'post_id': post['id'],
          'question': question.trim(),
          'ends_at': endsAt,
          'allow_change_vote': allowChangeVote,
        }).select().single();

        final pollId = poll['id'] as String;
        for (var i = 0; i < options.length; i++) {
          await _client.from('poll_options').insert({
            'poll_id': pollId,
            'label': options[i].trim(),
            'position': i,
          });
        }
        return post['id'] as String;
      });

  Future<Result<PollEntity?>> getPollForPost(String postId) => guard(() async {
        final poll = await _client.from('polls').select().eq('post_id', postId).maybeSingle();
        if (poll == null) return null;
        final pollId = poll['id'] as String;
        final opts = await _client
            .from('poll_options')
            .select()
            .eq('poll_id', pollId)
            .order('position');
        final myVote = await _client
            .from('poll_votes')
            .select('option_id')
            .eq('poll_id', pollId)
            .eq('user_id', _uid)
            .maybeSingle();

        return PollEntity(
          id: pollId,
          postId: postId,
          question: poll['question'] as String,
          endsAt: poll['ends_at'] != null
              ? DateTime.tryParse(poll['ends_at'] as String)
              : null,
          allowChangeVote: poll['allow_change_vote'] as bool? ?? false,
          myOptionId: myVote?['option_id'] as String?,
          options: (opts as List)
              .map((o) => PollOptionEntity(
                    id: o['id'] as String,
                    label: o['label'] as String,
                    voteCount: o['vote_count'] as int? ?? 0,
                    position: o['position'] as int? ?? 0,
                  ))
              .toList(),
        );
      });

  Future<Result<void>> vote(String pollId, String optionId, {bool allowChange = false}) =>
      guard(() async {
        final existing = await _client
            .from('poll_votes')
            .select()
            .eq('poll_id', pollId)
            .eq('user_id', _uid)
            .maybeSingle();
        if (existing != null) {
          if (!allowChange) return;
          await _client.from('poll_votes').update({
            'option_id': optionId,
          }).eq('poll_id', pollId).eq('user_id', _uid);
        } else {
          await _client.from('poll_votes').insert({
            'poll_id': pollId,
            'option_id': optionId,
            'user_id': _uid,
          });
        }
      });

  Future<Result<List<BadgeEntity>>> getUserBadges(String userId) => guard(() async {
        final rows = await _client
            .from('user_badges')
            .select('badge_id, badges ( id, code, name, description, icon_url )')
            .eq('user_id', userId);
        return (rows as List).map((r) {
          final b = r['badges'] as Map<String, dynamic>?;
          return BadgeEntity(
            id: b?['id'] as String? ?? '',
            code: b?['code'] as String? ?? '',
            name: b?['name'] as String? ?? '',
            description: b?['description'] as String?,
            iconUrl: b?['icon_url'] as String?,
          );
        }).where((b) => b.id.isNotEmpty).toList();
      });
}
