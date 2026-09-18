import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/dependency_injection.dart';
import '../../data/tournament_repository.dart';
import '../../domain/tournament_entity.dart';

final tournamentRepositoryProvider = Provider((ref) {
  return TournamentRepository(ref.watch(supabaseClientProvider));
});

final tournamentsListProvider =
    FutureProvider<List<TournamentEntity>>((ref) async {
  final r = await ref.watch(tournamentRepositoryProvider).listOpen();
  return r.valueOrNull ?? [];
});
