import '../../../core/errors/result.dart';

abstract class SocialRepository {
  Future<Result<void>> follow(String userId);
  Future<Result<void>> unfollow(String userId);
  Future<Result<void>> block(String userId);
  Future<Result<void>> unblock(String userId);
  Future<Result<void>> report({
    required String targetType,
    required String targetId,
    required String reason,
    String? details,
  });
}
