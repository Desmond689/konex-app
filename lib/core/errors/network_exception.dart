import 'app_exception.dart';

class NetworkException extends AppException {
  const NetworkException({
    required super.message,
    super.code,
    super.cause,
  });

  /// Device has no network interface / is offline.
  factory NetworkException.noConnection({Object? cause}) => NetworkException(
        message: 'No internet connection. Check your network and try again.',
        code: 'no_connection',
        cause: cause,
      );

  /// Host lookup, TLS, connection refused, or other server-side reachability
  /// failure. Internet may be fine; the backend URL/key or project status is
  /// the usual culprit (paused Supabase project, rotated key, bad env).
  factory NetworkException.serverUnreachable({Object? cause}) =>
      NetworkException(
        message:
            'Unable to reach the server. The service may be temporarily '
            'unavailable or misconfigured. Please try again later.',
        code: 'server_unreachable',
        cause: cause,
      );

  factory NetworkException.timeout({Object? cause}) => NetworkException(
        message: 'Request timed out. Please try again.',
        code: 'timeout',
        cause: cause,
      );
}
