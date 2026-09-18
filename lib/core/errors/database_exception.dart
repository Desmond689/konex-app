import 'app_exception.dart';

class DatabaseException extends AppException {
  const DatabaseException({
    required super.message,
    super.code,
    super.cause,
  });

  factory DatabaseException.rlsDenied() => const DatabaseException(
        message: 'You do not have permission to perform this action.',
        code: 'rls_denied',
      );

  factory DatabaseException.notFound() => const DatabaseException(
        message: 'Resource not found.',
        code: 'not_found',
      );
}
