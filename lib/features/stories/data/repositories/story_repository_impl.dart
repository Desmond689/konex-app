import 'dart:io';

import '../../../../core/errors/result.dart';
import '../../../../core/network/base_repository.dart';
import '../../domain/entities/story_entity.dart';
import '../datasources/story_remote_data_source.dart';

class StoryRepository with BaseRepository {
  StoryRepository(this._remote);
  final StoryRemoteDataSource _remote;

  Future<Result<List<StoryRing>>> homeRings() =>
      guard(() => _remote.fetchHomeStoryRings());

  Future<Result<List<StoryEntity>>> userStories(String userId) =>
      guard(() => _remote.fetchUserStories(userId));

  Future<Result<StoryEntity>> create({
    required String mediaType,
    String? mediaUrl,
    String? textContent,
    String? backgroundColor,
    String privacy = 'everyone',
    String? communityId,
  }) =>
      guard(() => _remote.createStory(
            mediaType: mediaType,
            mediaUrl: mediaUrl,
            textContent: textContent,
            backgroundColor: backgroundColor,
            privacy: privacy,
            communityId: communityId,
          ));

  Future<Result<String>> uploadMedia(File file, String mediaType) =>
      guard(() => _remote.uploadStoryMedia(file, mediaType));

  Future<Result<void>> markViewed(String storyId) =>
      guard(() => _remote.markViewed(storyId));

  Future<Result<void>> delete(String storyId) =>
      guard(() => _remote.deleteStory(storyId));
}
