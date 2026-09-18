import '../security/deep_link_sanitizer.dart';
import 'deep_link_models.dart';

class DeepLinkParser {
  /// Parse any konex URL / path into a typed target. Never grants permission.
  static DeepLinkTarget? parse(Uri? raw) {
    final uri = DeepLinkSanitizer.sanitize(raw);
    if (uri == null) return null;

    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) {
      return const DeepLinkTarget(type: DeepLinkType.unknown, rawPath: '/');
    }

    final a = segments[0].toLowerCase();
    final b = segments.length > 1 ? segments[1] : null;
    final c = segments.length > 2 ? segments[2] : null;

    switch (a) {
      case 'u':
      case 'user':
        if (b == 'id' && c != null) {
          return DeepLinkTarget(type: DeepLinkType.profile, id: c, rawPath: uri.path);
        }
        if (b != null) {
          return DeepLinkTarget(
            type: DeepLinkType.profile,
            username: b.toLowerCase(),
            rawPath: uri.path,
          );
        }
        break;
      case 'game':
      case 'community':
        if (b != null) {
          final isUuid = _looksUuid(b);
          return DeepLinkTarget(
            type: DeepLinkType.game,
            id: isUuid ? b : null,
            slug: isUuid ? null : b,
            rawPath: uri.path,
          );
        }
        break;
      case 'squad':
        if (b != null) {
          final isUuid = _looksUuid(b);
          return DeepLinkTarget(
            type: DeepLinkType.squad,
            id: isUuid ? b : null,
            slug: isUuid ? null : b,
            rawPath: uri.path,
          );
        }
        break;
      case 'post':
        if (b != null) {
          return DeepLinkTarget(type: DeepLinkType.post, id: b, rawPath: uri.path);
        }
        break;
      case 'lfg':
        if (b != null) {
          return DeepLinkTarget(type: DeepLinkType.lfg, id: b, rawPath: uri.path);
        }
        break;
      case 'event':
      case 'tournament':
        if (b != null) {
          return DeepLinkTarget(type: DeepLinkType.event, id: b, rawPath: uri.path);
        }
        break;
      case 'invite':
        if (b == 'squad' && c != null) {
          return DeepLinkTarget(
            type: DeepLinkType.squadInvite,
            token: c,
            rawPath: uri.path,
          );
        }
        if (b == 'community' && c != null) {
          return DeepLinkTarget(
            type: DeepLinkType.communityInvite,
            token: c,
            rawPath: uri.path,
          );
        }
        break;
    }
    return DeepLinkTarget(type: DeepLinkType.unknown, rawPath: uri.path);
  }

  static bool _looksUuid(String s) {
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(s);
  }
}
