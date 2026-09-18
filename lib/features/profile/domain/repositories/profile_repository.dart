import '../../../../core/errors/result.dart';
import '../entities/profile_entity.dart';

abstract class ProfileRepository {
  Future<Result<ProfileEntity>> getProfile(String userId);
  Future<Result<ProfileEntity>> getMyProfile();
  Future<Result<ProfileEntity>> updateProfile({
    String? gamerName,
    String? bio,
    String? country,
    String? playerType,
    String? avatarUrl,
    String? bannerUrl,
  });
  Future<Result<String>> uploadAvatar(String localPath);
  Future<Result<String>> uploadBanner(String localPath);
  Future<Result<List<String>>> getUserGames(String userId);
  Future<Result<void>> savePrivacy({
    required bool isPrivate,
    required String whoCanMessage,
    required String whoCanFollow,
    required String gamesVisibility,
    required String squadVisibility,
  });
  Future<Result<void>> changeUsername(String newUsername);
  Future<Result<List<Map<String, dynamic>>>> listFollowers(String userId);
  Future<Result<List<Map<String, dynamic>>>> listFollowing(String userId);
}
