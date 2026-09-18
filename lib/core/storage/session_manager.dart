import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

import '../errors/auth_exception.dart';
import 'secure_storage_service.dart';

/// Owns session lifecycle. Always verify with Supabase — never trust local flags alone.
class SessionManager {
  SessionManager({
    required SecureStorageService secureStorage,
    required SupabaseClient supabase,
  })  : _secure = secureStorage,
        _supabase = supabase;

  final SecureStorageService _secure;
  final SupabaseClient _supabase;

  Session? get currentSession => _supabase.auth.currentSession;
  User? get currentUser => _supabase.auth.currentUser;
  bool get isAuthenticated => currentSession != null;

  /// Persist tokens after successful auth.
  Future<void> persistSession(Session session) async {
    await _secure.saveAuthToken(session.accessToken);
    if (session.refreshToken != null) {
      await _secure.saveRefreshToken(session.refreshToken!);
    }
    if (session.user.id.isNotEmpty) {
      await _secure.saveUserId(session.user.id);
    }
  }

  /// Clear local + remote session.
  Future<void> clearSession() async {
    try {
      await _supabase.auth.signOut();
    } catch (_) {
      // Still clear local even if remote fails
    }
    await _secure.clearSecureData();
  }

  /// Validate session is still good (call on app resume / sensitive actions).
  Future<bool> validateSession() async {
    final session = currentSession;
    if (session == null) return false;
    try {
      final res = await _supabase.auth.getUser().timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          throw TimeoutException('Supabase auth check timed out');
        },
      );
      return res.user != null;
    } catch (_) {
      await clearSession();
      return false;
    }
  }

  Future<void> requireAuth() async {
    if (!await validateSession()) {
      throw AuthException.sessionExpired();
    }
  }
}
