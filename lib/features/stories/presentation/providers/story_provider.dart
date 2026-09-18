import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/dependency_injection.dart';
import '../../data/datasources/story_remote_data_source.dart';
import '../../data/repositories/story_repository_impl.dart';
import '../../domain/entities/story_entity.dart';

final storyRemoteProvider = Provider((ref) {
  return StoryRemoteDataSource(ref.watch(supabaseClientProvider));
});

final storyRepositoryProvider = Provider<StoryRepository>((ref) {
  return StoryRepository(ref.watch(storyRemoteProvider));
});

final homeStoryRingsProvider = FutureProvider<List<StoryRing>>((ref) async {
  final r = await ref.watch(storyRepositoryProvider).homeRings();
  return r.valueOrNull ?? [];
});

final userStoriesProvider =
    FutureProvider.family<List<StoryEntity>, String>((ref, userId) async {
  final r = await ref.watch(storyRepositoryProvider).userStories(userId);
  return r.valueOrNull ?? [];
});
