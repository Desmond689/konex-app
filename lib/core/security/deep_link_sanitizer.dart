/// Validate/sanitize deep links before navigation or auth handling.
class DeepLinkSanitizer {
  static const allowedHosts = {
    'konex-app-rho.vercel.app',
    'konex.page.link',
  };

  static const allowedSchemes = {'https', 'konex'};

  /// Returns a safe path/query map or null if rejected.
  static Uri? sanitize(Uri? uri) {
    if (uri == null) return null;

    if (!allowedSchemes.contains(uri.scheme.toLowerCase())) {
      return null;
    }

    if (uri.scheme == 'https') {
      final host = uri.host.toLowerCase();
      final ok = allowedHosts.any((h) => host == h || host.endsWith('.$h'));
      if (!ok) return null;
    }

    // Block obvious injection vectors in path
    final path = uri.path;
    if (path.contains('..') || path.contains('//')) return null;

    // Strip dangerous query keys often used in open-redirect / session attacks
    final cleaned = Map<String, String>.from(uri.queryParameters)
      ..removeWhere((k, v) {
        final key = k.toLowerCase();
        return key.contains('token') ||
            key.contains('access') ||
            key.contains('refresh') ||
            key == 'redirect' ||
            key == 'url';
      });

    return uri.replace(queryParameters: cleaned.isEmpty ? null : cleaned);
  }
}
