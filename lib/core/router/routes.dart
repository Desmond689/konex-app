/// Central registry for all application routes.
abstract final class Routes {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String emailVerification = '/email-verification';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';
  static const String suspended = '/suspended';

  static const String home = '/home';
  static const String discover = '/discover';
  static const String communities = '/communities';
  static const String squads = '/squads';
  static const String inbox = '/inbox';
  static const String profile = '/profile';

  static const String search = '/search';
  static const String notifications = '/notifications';
  static const String settings = '/settings';
  static const String saved = '/saved';
  static const String editProfile = '/profile/edit';
  static const String lfg = '/lfg';
  static const String admin = '/admin';

  static const String communityDetail = '/community/:id';
  static const String squadDetail = '/squad/:id';
  static const String chatDetail = '/chat/:id';
  static const String userProfile = '/user/:id';
  static const String postDetail = '/post/:id';
  static const String tournamentDetail = '/tournament/:id';
}
