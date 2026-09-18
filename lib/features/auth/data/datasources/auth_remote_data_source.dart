import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

import '../../../../core/errors/auth_exception.dart';
import '../../domain/entities/auth_user_entity.dart';

class AuthRemoteDataSource {
  AuthRemoteDataSource(this._client);
  final SupabaseClient _client;

  static const int minAgeYears = 13;

  Future<AuthUserEntity> signUp({
    required String email,
    required String password,
    required String username,
    String? phone,
    DateTime? dateOfBirth,
    String? gamerName,
    String? country,
    String? playerType,
  }) async {
    if (dateOfBirth == null) {
      throw AuthException(
        message: 'Date of birth is required',
        code: 'age_required',
      );
    }
    final now = DateTime.now();
    var age = now.year - dateOfBirth.year;
    if (now.month < dateOfBirth.month ||
        (now.month == dateOfBirth.month && now.day < dateOfBirth.day)) {
      age--;
    }
    if (age < minAgeYears) {
      throw AuthException(
        message: 'You must be at least $minAgeYears years old to use KONEX',
        code: 'underage',
      );
    }

    final res = await _client.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: 'https://konex-app-rho.vercel.app/auth/callback',
      data: {
        'username': username,
        if (phone != null) 'phone': phone,
        if (gamerName != null) 'gamer_name': gamerName,
        if (country != null) 'country': country,
        if (playerType != null) 'player_type': playerType,
        'date_of_birth': dateOfBirth.toIso8601String(),
      },
    );

    final user = res.user;
    if (user == null) {
      throw AuthException.invalidCredentials();
    }

    // The database trigger creates the profile exactly once from user metadata.
    return _mapUser(user, username: username, gamerName: gamerName);
  }

  Future<AuthUserEntity> signIn({
    required String email,
    required String password,
  }) async {
    final res = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    final user = res.user;
    if (user == null) throw AuthException.invalidCredentials();
    return _fetchProfile(user);
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<AuthUserEntity?> getCurrentUser() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    return _fetchProfile(user);
  }

  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(
      email,
      redirectTo: 'https://konex-app-rho.vercel.app/auth/callback?type=recovery',
    );
  }

  Future<void> updatePassword(String newPassword) async {
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  Stream<AuthUserEntity?> authStateChanges() {
    return _client.auth.onAuthStateChange.asyncMap((event) async {
      final user = event.session?.user;
      if (user == null) return null;
      try {
        return await _fetchProfile(user);
      } catch (_) {
        return _mapUser(user);
      }
    });
  }

  Future<AuthUserEntity> _fetchProfile(User user) async {
    final row = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (row == null) {
      return _mapUser(user);
    }

    return AuthUserEntity(
      id: user.id,
      email: user.email ?? row['email'] as String? ?? '',
      username: row['username'] as String?,
      gamerName: row['gamer_name'] as String?,
      phone: row['phone'] as String?,
      avatarUrl: row['avatar_url'] as String?,
      country: row['country'] as String?,
      playerType: row['player_type'] as String?,
      onboardingCompleted: row['onboarding_completed'] as bool? ?? false,
    );
  }

  AuthUserEntity _mapUser(
    User user, {
    String? username,
    String? gamerName,
  }) {
    final meta = user.userMetadata ?? {};
    return AuthUserEntity(
      id: user.id,
      email: user.email ?? '',
      username: username ?? meta['username'] as String?,
      gamerName: gamerName ?? meta['gamer_name'] as String?,
      phone: meta['phone'] as String?,
      country: meta['country'] as String?,
      playerType: meta['player_type'] as String?,
    );
  }
}
