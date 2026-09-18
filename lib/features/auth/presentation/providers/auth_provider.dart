import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/dependency_injection.dart';
import '../../../../core/errors/result.dart';
import '../../data/datasources/auth_remote_data_source.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/auth_user_entity.dart';
import '../../domain/repositories/auth_repository.dart';

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return AuthRemoteDataSource(ref.watch(supabaseClientProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    remote: ref.watch(authRemoteDataSourceProvider),
    sessionManager: ref.watch(sessionManagerProvider),
  );
});

final authStateProvider = StreamProvider<AuthUserEntity?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

final currentUserProvider = FutureProvider<AuthUserEntity?>((ref) async {
  final result = await ref.watch(authRepositoryProvider).getCurrentUser();
  return result.valueOrNull;
});

class AuthController extends StateNotifier<AsyncValue<AuthUserEntity?>> {
  AuthController(this._repo) : super(const AsyncValue.data(null));

  final AuthRepository _repo;

  Future<Result<AuthUserEntity>> signIn({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    final result = await _repo.signIn(email: email, password: password);
    result.when(
      success: (user) => state = AsyncValue.data(user),
      failure: (e, st) => state = AsyncValue.error(e, st ?? StackTrace.current),
    );
    return result;
  }

  Future<Result<AuthUserEntity>> signUp({
    required String email,
    required String password,
    required String username,
    String? phone,
    DateTime? dateOfBirth,
    String? gamerName,
    String? country,
    String? playerType,
  }) async {
    state = const AsyncValue.loading();
    final result = await _repo.signUp(
      email: email,
      password: password,
      username: username,
      phone: phone,
      dateOfBirth: dateOfBirth,
      gamerName: gamerName,
      country: country,
      playerType: playerType,
    );
    result.when(
      success: (user) => state = AsyncValue.data(user),
      failure: (e, st) => state = AsyncValue.error(e, st ?? StackTrace.current),
    );
    return result;
  }

  Future<void> signOut() async {
    await _repo.signOut();
    state = const AsyncValue.data(null);
  }

  Future<Result<void>> requestPasswordReset(String email) {
    return _repo.resetPassword(email);
  }

  Future<Result<void>> updatePassword(String newPassword) {
    return _repo.updatePassword(newPassword);
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<AuthUserEntity?>>((ref) {
  return AuthController(ref.watch(authRepositoryProvider));
});
