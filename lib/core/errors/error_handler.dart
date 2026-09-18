import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:postgrest/postgrest.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase_flutter;

import 'app_exception.dart';
import 'auth_exception.dart';
import 'database_exception.dart';
import 'network_exception.dart';
import 'validation_exception.dart';
import './error_handler.dart';

/// Central place to map raw errors → user-facing messages / AppException.
///
/// Network failures are split into:
/// - [NetworkException.noConnection] — device appears offline
/// - [NetworkException.serverUnreachable] — host/TLS/refused (often paused
///   Supabase project, bad URL, or rotated key — not the user's wifi)
/// - [NetworkException.timeout]
class ErrorHandler {
  static AppException map(Object error, [StackTrace? stack]) {
    if (error is AppException) return error;

    // Always surface the raw error in debug so "No internet" never hides
    // the real cause (paused project, bad key, DNS, TLS, etc.).
    if (kDebugMode) {
      debugPrint('RAW ERROR: $error');
      if (stack != null) debugPrint(stack.toString());
    }

    // Supabase AuthException (from the package) — map by status / message.
    if (error is supabase.AuthException) {
      return _mapSupabaseAuth(error);
    }
    if (error is PostgrestException) {
      return _mapPostgrest(error);
    }
    if (error is supabase_flutter.FunctionException) {
      if (error.status == 429) {
        return const AuthException(
          message: 'Too many requests. Please wait and try again later.',
          code: 'rate_limited',
        );
      }
      return const AuthException(
        message: 'Something went wrong. Please try again.',
        code: 'server_error',
      );
    }

    final msg = error.toString().toLowerCase();

    // Auth credential / session messages before generic network checks.
    if (msg.contains('invalid login credentials') ||
        msg.contains('invalid email or password') ||
        msg.contains('invalid_credentials')) {
      return AuthException.invalidCredentials();
    }
    if (msg.contains('email not confirmed') ||
        msg.contains('email_not_confirmed')) {
      return AuthException.emailNotConfirmed();
    }
    if (msg.contains('user already registered') ||
        msg.contains('already been registered') ||
        msg.contains('user_already_exists')) {
      return AuthException.userExists();
    }
    if (msg.contains('jwt') ||
        msg.contains('session') ||
        msg.contains('unauthorized') ||
        msg.contains('401')) {
      return AuthException.sessionExpired();
    }

    // Timeouts
    if (msg.contains('timeout') || msg.contains('timed out')) {
      return NetworkException.timeout(cause: error);
    }

    // True offline / no route indicators.
    if (_isLikelyOffline(error, msg)) {
      return NetworkException.noConnection(cause: error);
    }

    // Host lookup, connection refused, TLS, etc. → server unreachable
    // (do NOT call this "no internet" — the device may be online).
    if (_isServerUnreachable(error, msg)) {
      return NetworkException.serverUnreachable(cause: error);
    }

    // Catch-all for remaining low-level IO network errors.
    if (error is SocketException || error is HttpException) {
      return NetworkException.serverUnreachable(cause: error);
    }

    if (msg.contains('row-level security') ||
        msg.contains('permission denied') ||
        msg.contains('42501')) {
      return DatabaseException.rlsDenied();
    }
    if (msg.contains('unique') || msg.contains('duplicate')) {
      return const ValidationException(
        message: 'This value is already in use.',
        code: 'duplicate',
      );
    }

    if (kDebugMode) {
      debugPrint('Unhandled error mapped to unknown: $error');
    }

    return AppException(
      message: 'Something went wrong. Please try again.',
      code: 'unknown',
      cause: error,
    );
  }

  static String userMessage(Object error) {
    final mapped = map(error);
    return mapped.message;
  }

  // --- helpers ---

  static AppException _mapSupabaseAuth(supabase.AuthException e) {
    final status = e.statusCode;
    final msg = e.message.toLowerCase();

    if (msg.contains('user already registered') ||
        msg.contains('already been registered')) {
      return const AuthException(
        message: 'This email is already registered. Try signing in instead.',
        code: 'email_exists',
      );
    }
    if (msg.contains('password') &&
        (msg.contains('weak') || msg.contains('at least'))) {
      return const AuthException(
        message:
            'Your password is too weak. Please choose a stronger password.',
        code: 'weak_password',
      );
    }
    if (status == '429' ||
        msg.contains('rate limit') ||
        msg.contains('too many')) {
      return const AuthException(
        message: 'Too many attempts. Please wait and try again later.',
        code: 'rate_limited',
      );
    }
    if (msg.contains('email') &&
        (msg.contains('invalid') || msg.contains('valid'))) {
      return const AuthException(
        message: 'Please enter a valid email address.',
        code: 'invalid_email',
      );
    }
    if (msg.contains('invalid login credentials') ||
        msg.contains('invalid email or password')) {
      return AuthException.invalidCredentials();
    }
    if (msg.contains('email not confirmed')) {
      return AuthException.emailNotConfirmed();
    }
    if (status == '401' || status == '403') {
      return AuthException.sessionExpired();
    }

    // AuthRetryableFetchException and similar often wrap network failures.
    if (msg.contains('failed host lookup') ||
        msg.contains('network request failed') ||
        msg.contains('connection refused') ||
        msg.contains('unable to connect') ||
        msg.contains('failed to connect')) {
      return NetworkException.serverUnreachable(cause: e);
    }
    if (msg.contains('timeout') || msg.contains('timed out')) {
      return NetworkException.timeout(cause: e);
    }

    return AuthException(
      message: 'Something went wrong. Please try again.',
      code: status ?? 'auth_error',
      cause: e,
    );
  }

  static AppException _mapPostgrest(PostgrestException e) {
    final constraint = '${e.code} ${e.message} ${e.details}'.toLowerCase();
    final raw = (e.message.isNotEmpty ? e.message : (e.details?.toString() ?? '')).trim();

    if (e.code == '23505' && constraint.contains('username')) {
      return const AuthException(
        message: 'That username is already taken. Please choose another one.',
        code: 'username_exists',
      );
    }
    if (e.code == '23505' && constraint.contains('email')) {
      return const AuthException(
        message: 'This email is already registered. Try signing in instead.',
        code: 'email_exists',
      );
    }
    if (e.code == '23505') {
      return AuthException(
        message: 'That value is already in use. Please try a different one.',
        code: 'duplicate',
        cause: e,
      );
    }
    if (e.code == '42501' || constraint.contains('row-level security') || constraint.contains('permission denied')) {
      return AuthException(
        message: 'You do not have permission to do that.',
        code: 'forbidden',
        cause: e,
      );
    }
    if (e.code == 'PGRST116' || constraint.contains('0 rows') || constraint.contains('not found')) {
      return AuthException(
        message: 'We could not find that item. It may have been deleted.',
        code: 'not_found',
        cause: e,
      );
    }
    if (e.code == '57014' || constraint.contains('statement timeout')) {
      return AuthException(
        message: 'The server took too long to respond. Please try again.',
        code: 'timeout',
        cause: e,
      );
    }
    // Prefer the Postgres/RPC message when it is already human-readable
    // (e.g. raise exception 'Not authorized' from our admin RPCs).
    if (raw.isNotEmpty &&
        !raw.toLowerCase().startsWith('json') &&
        raw.length < 180 &&
        !raw.contains('{')) {
      return AuthException(message: raw, code: e.code ?? 'db_error', cause: e);
    }
    return AuthException(
      message: 'Something went wrong on the server. Please try again.',
      code: e.code ?? 'server_error',
      cause: e,
    );
  }

  /// Indicators that the *device* has no usable network path.
  static bool _isLikelyOffline(Object error, String msg) {
    if (msg.contains('network is unreachable') ||
        msg.contains('no internet') ||
        msg.contains('socketexception: network is unreachable') ||
        msg.contains('os error: network is unreachable') ||
        msg.contains('software caused connection abort')) {
      return true;
    }
    if (error is SocketException) {
      final os = error.osError;
      // Common offline errno: ENETUNREACH (101), EHOSTUNREACH (113) on Linux;
      // ENETDOWN, etc. Message text is more portable across platforms.
      if (os != null) {
        final m = os.message.toLowerCase();
        if (m.contains('network is unreachable') ||
            m.contains('no route to host') ||
            m.contains('network down')) {
          return true;
        }
      }
    }
    return false;
  }

  /// Host/DNS/TLS/refused — backend or config problem, not "no internet".
  static bool _isServerUnreachable(Object error, String msg) {
    return msg.contains('failed host lookup') ||
        msg.contains('failed to connect') ||
        msg.contains('connection refused') ||
        msg.contains('connection reset') ||
        msg.contains('network request failed') ||
        msg.contains('unable to connect') ||
        msg.contains('certificate') ||
        msg.contains('handshake') ||
        msg.contains('ssl') ||
        msg.contains('tls') ||
        msg.contains('name or service not known') ||
        msg.contains('nodename nor servname provided');
  }
}
