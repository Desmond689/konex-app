import '../../../../core/errors/result.dart';
import '../../../../core/network/base_repository.dart';
import '../../domain/entities/profile_entity.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_remote_data_source.dart';

class ProfileRepositoryImpl with BaseRepository implements ProfileRepository {
  ProfileRepositoryImpl(this._remote);
  final ProfileRemoteDataSource _remote;

  @override
  Future<Result<ProfileEntity>> getProfile(String userId) =>
      guard(() => _remote.getProfile(userId));

  @override
  Future<Result<ProfileEntity>> getMyProfile() =>
      guard(() => _remote.getMyProfile());

  @override
  Future<Result<ProfileEntity>> updateProfile({
    String? gamerName,
    String? bio,
    String? country,
    String? playerType,
    String? avatarUrl,
    String? bannerUrl,
  }) =>
      guard(() => _remote.updateProfile(
            gamerName: gamerName,
            bio: bio,
            country: country,
            playerType: playerType,
            avatarUrl: avatarUrl,
            bannerUrl: bannerUrl,
          ));

  @override
  Future<Result<String>> uploadAvatar(String localPath) =>
      guard(() => _remote.uploadAvatar(localPath));

  @override
  Future<Result<String>> uploadBanner(String localPath) =>
      guard(() => _remote.uploadBanner(localPath));

  @override
  Future<Result<List<String>>> getUserGames(String userId) =>
      guard(() => _remote.getUserGames(userId));

  @override
  Future<Result<void>> savePrivacy({
    required bool isPrivate,
    required String whoCanMessage,
    required String whoCanFollow,
    required String gamesVisibility,
    required String squadVisibility,
  }) =>
      guard(() => _remote.savePrivacy(
            isPrivate: isPrivate,
            whoCanMessage: whoCanMessage,
            whoCanFollow: whoCanFollow,
            gamesVisibility: gamesVisibility,
            squadVisibility: squadVisibility,
          ));

  @override
  Future<Result<void>> changeUsername(String newUsername) =>
      guard(() => _remote.changeUsername(newUsername));

  @override
  Future<Result<List<Map<String, dynamic>>>> listFollowers(String userId) =>
      guard(() => _remote.listFollowers(userId));

  @override
  Future<Result<List<Map<String, dynamic>>>> listFollowing(String userId) =>
      guard(() => _remote.listFollowing(userId));
}
