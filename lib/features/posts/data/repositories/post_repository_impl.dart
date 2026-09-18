import '../../../../core/config/constants.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/network/base_repository.dart';
import '../../domain/entities/post_entity.dart';
import '../../domain/repositories/post_repository.dart';
import '../datasources/post_remote_data_source.dart';

class PostRepositoryImpl with BaseRepository implements PostRepository {
  PostRepositoryImpl(this._remote);
  final PostRemoteDataSource _remote;

  @override
  Future<Result<List<PostEntity>>> getLatestFeed({int page = 0, int pageSize = AppConstants.feedPageSize}) =>
      guard(() => _remote.getLatestFeed(page: page, pageSize: pageSize));

  @override
  Future<Result<List<PostEntity>>> getFollowingFeed({int page = 0, int pageSize = AppConstants.feedPageSize}) =>
      guard(() => _remote.getFollowingFeed(page: page, pageSize: pageSize));

  @override
  Future<Result<List<PostEntity>>> getForYouFeed({int page = 0, int pageSize = AppConstants.feedPageSize, String? communityFilter}) =>
      guard(() => _remote.getForYouFeed(page: page, pageSize: pageSize, communityFilter: communityFilter));

  @override
  Future<Result<List<PostEntity>>> getUserPosts(String userId, {int page = 0}) =>
      guard(() => _remote.getUserPosts(userId, page: page));

  @override
  Future<Result<List<PostEntity>>> getPostsByIds(List<String> ids) =>
      guard(() => _remote.getPostsByIds(ids));

  @override
  Future<Result<List<PostEntity>>> getSquadPosts(String squadId, {int page = 0}) =>
      guard(() => _remote.getSquadPosts(squadId, page: page));

  @override
  Future<Result<List<PostEntity>>> getCommunityPosts(String communityId, {int page = 0}) =>
      guard(() => _remote.getCommunityPosts(communityId, page: page));

  @override
  Future<Result<PostEntity>> createTextPost({
    required String body,
    String? communityId,
    String? squadId,
    String postType = 'text',
    bool isAnnouncement = false,
    bool isPinned = false,
    String visibility = 'public',
  }) =>
      guard(() => _remote.createTextPost(
            body: body,
            communityId: communityId,
            squadId: squadId,
            postType: postType,
            isAnnouncement: isAnnouncement,
            isPinned: isPinned,
            visibility: visibility,
          ));

  @override
  Future<Result<PostEntity>> createImagePost({
    required String body,
    required String localImagePath,
    String? communityId,
    String? squadId,
    String postType = 'image',
  }) =>
      guard(() => _remote.createImagePost(
            body: body,
            localImagePath: localImagePath,
            communityId: communityId,
            squadId: squadId,
            postType: postType,
          ));

  @override
  Future<Result<PostEntity>> createMultiImagePost({
    required String body,
    required List<String> localImagePaths,
    String? communityId,
    String? squadId,
    String postType = 'image',
  }) =>
      guard(() => _remote.createMultiImagePost(
            body: body,
            localImagePaths: localImagePaths,
            communityId: communityId,
            squadId: squadId,
            postType: postType,
          ));

  @override
  Future<Result<void>> deletePost(String postId) => guard(() => _remote.deletePost(postId));

  @override
  Future<Result<void>> likePost(String postId) => guard(() => _remote.likePost(postId));

  @override
  Future<Result<void>> unlikePost(String postId) => guard(() => _remote.unlikePost(postId));

  @override
  Future<Result<void>> savePost(String postId) => guard(() => _remote.savePost(postId));

  @override
  Future<Result<void>> unsavePost(String postId) => guard(() => _remote.unsavePost(postId));

  @override
  Future<Result<List<CommentEntity>>> getComments(String postId, {String? postAuthorId}) =>
      guard(() => _remote.getComments(postId, postAuthorId: postAuthorId));

  @override
  Future<Result<CommentEntity>> addComment(
    String postId,
    String body, {
    String? parentId,
    String? mediaUrl,
    String? postAuthorId,
  }) =>
      guard(() => _remote.addComment(
            postId,
            body,
            parentId: parentId,
            mediaUrl: mediaUrl,
            postAuthorId: postAuthorId,
          ));

  @override
  Future<Result<void>> likeComment(String commentId) =>
      guard(() => _remote.likeComment(commentId));

  @override
  Future<Result<void>> unlikeComment(String commentId) =>
      guard(() => _remote.unlikeComment(commentId));

  @override
  Future<Result<void>> softDeleteComment(String commentId) =>
      guard(() => _remote.softDeleteComment(commentId));

  @override
  Future<Result<String>> uploadCommentImage(List<int> bytes) =>
      guard(() => _remote.uploadCommentImage(bytes));
}
