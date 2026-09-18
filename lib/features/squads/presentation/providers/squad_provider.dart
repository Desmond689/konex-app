import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/dependency_injection.dart';
import '../../data/datasources/squad_remote_data_source.dart';
import '../../data/repositories/squad_repository_impl.dart';
import '../../domain/entities/squad_entity.dart';

final squadRemoteProvider = Provider((ref) {
  return SquadRemoteDataSource(ref.watch(supabaseClientProvider));
});

final squadRepositoryProvider = Provider<SquadRepository>((ref) {
  return SquadRepositoryImpl(ref.watch(squadRemoteProvider));
});

/// User's single active squad (null if none).
final myActiveSquadProvider = FutureProvider<SquadEntity?>((ref) async {
  final r = await ref.watch(squadRepositoryProvider).myActiveSquad();
  return r.valueOrNull;
});

final squadsDiscoverProvider =
    FutureProvider.family<List<SquadEntity>, String?>((ref, query) async {
  final r = await ref.watch(squadRepositoryProvider).listDiscover(query: query);
  return r.valueOrNull ?? [];
});

final squadByIdProvider =
    FutureProvider.family<SquadEntity?, String>((ref, id) async {
  final r = await ref.watch(squadRepositoryProvider).getSquad(id);
  return r.valueOrNull;
});

/// Cached squad posts (avoids FutureBuilder recreation on every rebuild).
final squadPostsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, squadId) async {
  final r = await ref.watch(squadRepositoryProvider).squadPosts(squadId);
  return r.valueOrNull ?? [];
});

/// Squad members list.
final squadMembersProvider =
    FutureProvider.family<List<SquadMemberEntity>, String>((ref, squadId) async {
  final r = await ref.watch(squadRepositoryProvider).members(squadId);
  return r.valueOrNull ?? [];
});

/// Pending join requests (owners/mods).
final squadPendingRequestsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, squadId) async {
  final r = await ref.watch(squadRepositoryProvider).pendingRequests(squadId);
  return r.valueOrNull ?? [];
});
