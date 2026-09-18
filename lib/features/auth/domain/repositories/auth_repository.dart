import '../../../../core/errors/result.dart';
import '../entities/auth_user_entity.dart';

abstract class AuthRepository {
  Future<Result<AuthUserEntity>> signUp({
    required String email,
    required String password,
    required String username,
    String? phone,
    DateTime? dateOfBirth,
    String? gamerName,
    String? country,
    String? playerType,
  });

  Future<Result<AuthUserEntity>> signIn({
    required String email,
    required String password,
  });

  Future<Result<void>> signOut();

  Future<Result<AuthUserEntity?>> getCurrentUser();

  Future<Result<void>> resetPassword(String email);

  Future<Result<void>> updatePassword(String newPassword);

  Stream<AuthUserEntity?> authStateChanges();
}
