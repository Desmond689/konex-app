import '../../../../core/errors/result.dart';
import '../../../../core/network/base_repository.dart';
import '../../domain/entities/squad_entity.dart';
import '../datasources/squad_remote_data_source.dart';

abstract class SquadRepository {
  Future<Result<SquadEntity?>> myActiveSquad();
  Future<Result<List<SquadEntity>>> listDiscover({String? query, String? game});
  Future<Result<List<SquadEntity>>> mySquads();
  Future<Result<SquadEntity>> getSquad(String id);
  Future<Result<SquadEntity>> createSquad({
    required String name,
    String? description,
    String? rules,
    String? primaryGame,
    String? category,
    bool isPublic,
    bool requireApproval,
    String? logoUrl,
  });
  Future<Result<SquadEntity>> updateSquad({
    required String squadId,
    String? name,
    String? description,
    String? rules,
    String? primaryGame,
    String? category,
    bool? isPublic,
    bool? requireApproval,
    String? logoUrl,
  });
  Future<Result<void>> deleteSquad(String squadId);
  Future<Result<String>> uploadLogo(String filePath);
  Future<Result<void>> requestJoin(String squadId, {String? message});
  Future<Result<void>> leave(String squadId);
  Future<Result<void>> transferOwnership(String squadId, String newOwnerId);
  Future<Result<void>> removeMember(String squadId, String userId, {bool ban});
  Future<Result<void>> approveRequest(String squadId, String userId);
  Future<Result<void>> rejectRequest(String squadId, String userId);
  Future<Result<List<SquadMemberEntity>>> members(String squadId);
  Future<Result<List<Map<String, dynamic>>>> pendingRequests(String squadId);
  Future<Result<List<Map<String, dynamic>>>> squadPosts(String squadId);
  Future<Result<void>> createSquadPost({
    required String squadId,
    required String body,
    bool announcement,
  });
}

class SquadRepositoryImpl with BaseRepository implements SquadRepository {
  SquadRepositoryImpl(this._remote);
  final SquadRemoteDataSource _remote;

  @override
  Future<Result<SquadEntity?>> myActiveSquad() =>
      guard(() => _remote.myActiveSquad());

  @override
  Future<Result<List<SquadEntity>>> listDiscover({String? query, String? game}) =>
      guard(() => _remote.listDiscover(query: query, game: game));

  @override
  Future<Result<List<SquadEntity>>> mySquads() =>
      guard(() => _remote.mySquads());

  @override
  Future<Result<SquadEntity>> getSquad(String id) =>
      guard(() => _remote.getSquad(id));

  @override
  Future<Result<SquadEntity>> createSquad({
    required String name,
    String? description,
    String? rules,
    String? primaryGame,
    String? category,
    bool isPublic = true,
    bool requireApproval = true,
    String? logoUrl,
  }) =>
      guard(() => _remote.createSquad(
            name: name,
            description: description,
            rules: rules,
            primaryGame: primaryGame,
            category: category,
            isPublic: isPublic,
            requireApproval: requireApproval,
            logoUrl: logoUrl,
          ));

  @override
  Future<Result<SquadEntity>> updateSquad({
    required String squadId,
    String? name,
    String? description,
    String? rules,
    String? primaryGame,
    String? category,
    bool? isPublic,
    bool? requireApproval,
    String? logoUrl,
  }) =>
      guard(() => _remote.updateSquad(
            squadId: squadId,
            name: name,
            description: description,
            rules: rules,
            primaryGame: primaryGame,
            category: category,
            isPublic: isPublic,
            requireApproval: requireApproval,
            logoUrl: logoUrl,
          ));

  @override
  Future<Result<void>> deleteSquad(String squadId) =>
      guard(() => _remote.deleteSquad(squadId));

  @override
  Future<Result<String>> uploadLogo(String filePath) =>
      guard(() => _remote.uploadLogo(filePath));

  @override
  Future<Result<void>> requestJoin(String squadId, {String? message}) =>
      guard(() => _remote.requestJoin(squadId, message: message));

  @override
  Future<Result<void>> leave(String squadId) =>
      guard(() => _remote.leave(squadId));

  @override
  Future<Result<void>> transferOwnership(String squadId, String newOwnerId) =>
      guard(() => _remote.transferOwnership(squadId, newOwnerId));

  @override
  Future<Result<void>> removeMember(String squadId, String userId, {bool ban = false}) =>
      guard(() => _remote.removeMember(squadId, userId, ban: ban));

  @override
  Future<Result<void>> approveRequest(String squadId, String userId) =>
      guard(() => _remote.approveRequest(squadId, userId));

  @override
  Future<Result<void>> rejectRequest(String squadId, String userId) =>
      guard(() => _remote.rejectRequest(squadId, userId));

  @override
  Future<Result<List<SquadMemberEntity>>> members(String squadId) =>
      guard(() => _remote.members(squadId));

  @override
  Future<Result<List<Map<String, dynamic>>>> pendingRequests(String squadId) =>
      guard(() => _remote.pendingRequests(squadId));

  @override
  Future<Result<List<Map<String, dynamic>>>> squadPosts(String squadId) =>
      guard(() => _remote.squadPosts(squadId));

  @override
  Future<Result<void>> createSquadPost({
    required String squadId,
    required String body,
    bool announcement = false,
  }) =>
      guard(() => _remote.createSquadPost(
            squadId: squadId,
            body: body,
            announcement: announcement,
          ));
}
