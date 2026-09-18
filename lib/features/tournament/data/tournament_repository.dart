import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/result.dart';
import '../../../core/network/base_repository.dart';
import '../domain/tournament_entity.dart';

/// Free tournaments only — no payments, wallet, or KYC.
class TournamentRepository with BaseRepository {
  TournamentRepository(this._client);
  final SupabaseClient _client;

  String get _uid {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('Not authenticated');
    return id;
  }

  Future<Result<List<TournamentEntity>>> listOpen() => guard(() async {
        final rows = await _client
            .from('tournaments')
            .select()
            .inFilter('status', ['open', 'locked', 'live'])
            .order('starts_at', ascending: true)
            .limit(40);

        final myEntries = await _client
            .from('tournament_entries')
            .select('tournament_id')
            .eq('user_id', _uid);
        final enteredIds = {
          for (final e in myEntries as List) e['tournament_id'] as String,
        };

        return (rows as List).map((r) {
          final m = Map<String, dynamic>.from(r as Map);
          return TournamentEntity.fromMap(
            m,
            isEntered: enteredIds.contains(m['id'] as String),
          );
        }).toList();
      });

  Future<Result<TournamentEntity>> getById(String id) => guard(() async {
        final m = await _client.from('tournaments').select().eq('id', id).single();
        final entry = await _client
            .from('tournament_entries')
            .select()
            .eq('tournament_id', id)
            .eq('user_id', _uid)
            .maybeSingle();
        return TournamentEntity.fromMap(
          Map<String, dynamic>.from(m),
          isEntered: entry != null,
        );
      });

  // The full-vs-not-full / already-entered check and the participant_count
  // increment happen together, server-side, inside a row lock — see
  // enter_tournament() in the migrations. Doing this as a client-side
  // read-then-write (fetch count, compare, write count+1) would race: two
  // people joining a nearly-full tournament at the same moment could both
  // read the same count and both write the same value, silently
  // undercounting entries and letting the tournament exceed its cap.
  Future<Result<void>> enter(String tournamentId) => guard(() async {
        await _client.rpc('enter_tournament', params: {
          'p_tournament_id': tournamentId,
        });
      });

  Future<Result<String>> createTournament({
    required String title,
    required String gameName,
    String? description,
    int maxParticipants = 16,
    DateTime? startsAt,
  }) =>
      guard(() async {
        final row = await _client.from('tournaments').insert({
          'title': title,
          'game_name': gameName,
          'description': description,
          'status': 'open',
          'max_participants': maxParticipants,
          'starts_at': startsAt?.toIso8601String(),
          'created_by': _uid,
        }).select().single();
        return row['id'] as String;
      });

  Future<Result<int>> generateBracket(String tournamentId) => guard(() async {
        final n = await _client.rpc('generate_tournament_bracket', params: {
          'p_tournament_id': tournamentId,
        });
        return (n as int?) ?? 0;
      });

  Future<Result<void>> setMatchWinner(String matchId, String winnerId) => guard(() async {
        await _client.rpc('advance_match_winner', params: {
          'p_match_id': matchId,
          'p_winner_id': winnerId,
        });
      });

}
