import '../../../../core/config/constants.dart';
import '../../../../core/errors/result.dart';
import '../entities/post_entity.dart';

abstract class PostRepository {
  Future<Result<List<PostEntity>>> getLatestFeed({int page = 0, int pageSize = AppConstants.feedPageSize});
  Future<Result<List<PostEntity>>> getFollowingFeed({int page = 0, int pageSize = AppConstants.feedPageSize});
  Future<Result<List<PostEntity>>> getForYouFeed({int page = 0, int pageSize = AppConstants.feedPageSize, String? communityFilter});
  Future<Result<List<PostEntity>>> getUserPosts(String userId, {int page = 0});
  Future<Result<List<PostEntity>>> getPostsByIds(List<String> ids);
  Future<Result<List<PostEntity>>> getSquadPosts(String squadId, {int page = 0});
  Future<Result<List<PostEntity>>> getCommunityPosts(String communityId, {int page = 0});
  Future<Result<PostEntity>> createTextPost({
    required String body,
    String? communityId,
    String? squadId,
    String postType = 'text',
    bool isAnnouncement = false,
    bool isPinned = false,
    String visibility = 'public',
  });
  Future<Result<PostEntity>> createImagePost({
    required String body,
    required String localImagePath,
    String? communityId,
    String? squadId,
    String postType = 'image',
  });
  Future<Result<PostEntity>> createMultiImagePost({
    required String body,
    required List<String> localImagePaths,
    String? communityId,
    String? squadId,
    String postType = 'image',
  });
  Future<Result<void>> deletePost(String postId);
  Future<Result<void>> likePost(String postId);
  Future<Result<void>> unlikePost(String postId);
  Future<Result<void>> savePost(String postId);
  Future<Result<void>> unsavePost(String postId);
  Future<Result<List<CommentEntity>>> getComments(String postId, {String? postAuthorId});
  Future<Result<CommentEntity>> addComment(
    String postId,
    String body, {
    String? parentId,
    String? mediaUrl,
    String? postAuthorId,
  });
  Future<Result<void>> likeComment(String commentId);
  Future<Result<void>> unlikeComment(String commentId);
  Future<Result<void>> softDeleteComment(String commentId);
  Future<Result<String>> uploadCommentImage(List<int> bytes);
}
