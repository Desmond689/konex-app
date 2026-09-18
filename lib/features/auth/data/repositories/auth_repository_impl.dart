import '../../../../core/errors/result.dart';
import '../../../../core/network/base_repository.dart';
import '../../../../core/storage/session_manager.dart';
import '../../domain/entities/auth_user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';

class AuthRepositoryImpl with BaseRepository implements AuthRepository {
  AuthRepositoryImpl({
    required AuthRemoteDataSource remote,
    required SessionManager sessionManager,
  })  : _remote = remote,
        _session = sessionManager;

  final AuthRemoteDataSource _remote;
  final SessionManager _session;

  @override
  Future<Result<AuthUserEntity>> signUp({
    required String email,
    required String password,
    required String username,
    String? phone,
    DateTime? dateOfBirth,
    String? gamerName,
    String? country,
    String? playerType,
  }) {
    return guard(() async {
      final user = await _remote.signUp(
        email: email,
        password: password,
        username: username,
        phone: phone,
        dateOfBirth: dateOfBirth,
        gamerName: gamerName,
        country: country,
        playerType: playerType,
      );
      final session = _session.currentSession;
      if (session != null) await _session.persistSession(session);
      return user;
    });
  }

  @override
  Future<Result<AuthUserEntity>> signIn({
    required String email,
    required String password,
  }) {
    return guard(() async {
      final user = await _remote.signIn(email: email, password: password);
      final session = _session.currentSession;
      if (session != null) await _session.persistSession(session);
      return user;
    });
  }

  @override
  Future<Result<void>> signOut() {
    return guard(() async {
      await _remote.signOut();
      await _session.clearSession();
    });
  }

  @override
  Future<Result<AuthUserEntity?>> getCurrentUser() {
    return guard(() => _remote.getCurrentUser());
  }

  @override
  Future<Result<void>> resetPassword(String email) {
    return guard(() => _remote.resetPassword(email));
  }

  @override
  Future<Result<void>> updatePassword(String newPassword) {
    return guard(() => _remote.updatePassword(newPassword));
  }

  @override
  Stream<AuthUserEntity?> authStateChanges() => _remote.authStateChanges();
}
