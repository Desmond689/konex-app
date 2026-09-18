import 'app_exception.dart';

class AuthException extends AppException {
  const AuthException({
    required super.message,
    super.code,
    super.cause,
  });

  factory AuthException.invalidCredentials() => const AuthException(
        message: 'Invalid email or password.',
        code: 'invalid_credentials',
      );

  factory AuthException.sessionExpired() => const AuthException(
        message: 'Session expired. Please sign in again.',
        code: 'session_expired',
      );

  factory AuthException.emailNotConfirmed() => const AuthException(
        message: 'Please confirm your email before continuing.',
        code: 'email_not_confirmed',
      );

  factory AuthException.userExists() => const AuthException(
        message: 'An account with this email already exists.',
        code: 'user_exists',
      );
}
