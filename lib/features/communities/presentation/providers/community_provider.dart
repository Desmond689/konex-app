import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/dependency_injection.dart';
import '../../data/community_repository.dart';
import '../../domain/community_entity.dart';

final communityRepositoryProvider = Provider((ref) {
  return CommunityRepository(ref.watch(supabaseClientProvider));
});

final communitiesDiscoverProvider =
    FutureProvider.family<List<CommunityEntity>, String?>((ref, q) async {
  final r = await ref.watch(communityRepositoryProvider).listDiscover(query: q);
  return r.valueOrNull ?? [];
});

final myCommunitiesProvider = FutureProvider<List<CommunityEntity>>((ref) async {
  final r = await ref.watch(communityRepositoryProvider).myCommunities();
  return r.valueOrNull ?? [];
});

final officialGamesProvider = FutureProvider<List<CommunityEntity>>((ref) async {
  final r = await ref.watch(communityRepositoryProvider).listOfficialGames();
  return r.valueOrNull ?? [];
});

final communityByIdProvider =
    FutureProvider.family<CommunityEntity?, String>((ref, id) async {
  final r = await ref.watch(communityRepositoryProvider).getById(id);
  return r.valueOrNull;
});

/// Admin > Manage games: every community, official or not, highest
/// member count first. Keyed by the search query.
final adminAllGamesProvider =
    FutureProvider.family<List<CommunityEntity>, String?>((ref, q) async {
  final r = await ref.watch(communityRepositoryProvider).adminListAllGames(query: q);
  return r.valueOrNull ?? [];
});
