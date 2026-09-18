/// Canonical KONEX link types. URLs only identify destination — permissions are separate.
enum DeepLinkType {
  profile,
  game,
  squad,
  post,
  lfg,
  event,
  squadInvite,
  communityInvite,
  unknown,
}

class DeepLinkTarget {
  const DeepLinkTarget({
    required this.type,
    this.id,
    this.slug,
    this.username,
    this.token,
    this.rawPath = '',
  });

  final DeepLinkType type;
  final String? id;
  final String? slug;
  final String? username;
  final String? token;
  final String rawPath;

  String get routePath {
    switch (type) {
      case DeepLinkType.profile:
        if (username != null) return '/u/$username';
        return id != null ? '/user/$id' : '/';
      case DeepLinkType.game:
        return slug != null ? '/game/$slug' : (id != null ? '/community/$id' : '/');
      case DeepLinkType.squad:
        return id != null ? '/squad/$id' : (slug != null ? '/squad/$slug' : '/');
      case DeepLinkType.post:
        return id != null ? '/post/$id' : '/';
      case DeepLinkType.lfg:
        return id != null ? '/lfg/$id' : '/lfg';
      case DeepLinkType.event:
        return id != null ? '/tournament/$id' : '/tournaments';
      case DeepLinkType.squadInvite:
        return token != null ? '/invite/squad/$token' : '/';
      case DeepLinkType.communityInvite:
        return token != null ? '/invite/community/$token' : '/';
      case DeepLinkType.unknown:
        return '/';
    }
  }
}

/// Build shareable URLs (canonical). Domain configurable.
abstract final class KonexLinks {
  static const String baseHost = 'https://konex-app-rho.vercel.app';

  static String profile(String username) => '$baseHost/u/${username.toLowerCase()}';
  static String profileById(String id) => '$baseHost/u/id/$id';
  static String game(String slug) => '$baseHost/game/$slug';
  static String squad({String? slug, String? id}) =>
      slug != null ? '$baseHost/squad/$slug' : '$baseHost/squad/$id';
  static String post(String id) => '$baseHost/post/$id';
  static String lfg(String id) => '$baseHost/lfg/$id';
  static String event(String id) => '$baseHost/event/$id';
  static String squadInvite(String token) => '$baseHost/invite/squad/$token';
}
