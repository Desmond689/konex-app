import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/signup_screen.dart';
import '../../features/auth/presentation/screens/email_verification_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/onboarding_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';
import '../../features/auth/presentation/screens/suspended_screen.dart';
import '../../features/feed/presentation/screens/home_feed_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/presentation/screens/edit_profile_screen.dart';
import '../../features/communities/presentation/screens/communities_screen.dart';
import '../../features/communities/presentation/screens/community_detail_screen.dart';
import '../../features/squads/presentation/screens/squads_screen.dart';
import '../../features/squads/presentation/screens/squad_detail_screen.dart';
import '../../features/search/presentation/screens/search_screen.dart';
import '../../features/posts/presentation/screens/post_detail_screen.dart';
import '../../features/communities/presentation/screens/game_by_slug_screen.dart';
import '../../features/profile/presentation/screens/profile_by_username_screen.dart';
import '../../features/squads/presentation/screens/squad_invite_screen.dart';

import '../../features/posts/presentation/screens/saved_posts_screen.dart';
import '../../features/chat/presentation/screens/inbox_screen.dart';
import '../../features/chat/presentation/screens/chat_room_screen.dart';
import '../../features/lfg/presentation/screens/lfg_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/media/presentation/create_video_post_screen.dart';
import '../../features/admin/presentation/screens/admin_dashboard_screen.dart';
import '../../features/tournament/presentation/screens/tournaments_screen.dart';
import '../../features/tournament/presentation/screens/tournament_detail_screen.dart';
import '../../features/settings/presentation/data_saver_settings_tile.dart';
import '../../features/settings/presentation/biometric_settings_tile.dart';
import '../../features/profile/presentation/screens/privacy_settings_screen.dart';
import '../../features/settings/presentation/screens/delete_account_screen.dart';
import '../../features/profile/presentation/screens/manage_games_screen.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../widgets/kx_shell.dart';
import 'auth_guard.dart';
import 'routes.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: Routes.splash,
    debugLogDiagnostics: false,
    redirect: (context, state) => AuthGuard.redirect(context, state, ref),
    routes: [
      GoRoute(path: Routes.splash, builder: (_, __) => const SplashScreen()),
      GoRoute(path: Routes.login, builder: (_, __) => const LoginScreen()),
      GoRoute(path: Routes.signup, builder: (_, __) => const SignupScreen()),
      GoRoute(
        path: Routes.emailVerification,
        builder: (_, state) => EmailVerificationScreen(
          email: state.extra as String? ?? '',
        ),
      ),
      GoRoute(path: Routes.onboarding, builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: Routes.forgotPassword, builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(path: Routes.resetPassword, builder: (_, __) => const ResetPasswordScreen()),
      GoRoute(path: Routes.suspended, builder: (_, __) => const SuspendedScreen()),

      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          return KxShell(location: state.matchedLocation, child: child);
        },
        routes: [
          GoRoute(path: Routes.home, builder: (_, __) => const HomeFeedScreen()),
          GoRoute(path: Routes.communities, builder: (_, __) => const CommunitiesScreen()),
          GoRoute(path: Routes.squads, builder: (_, __) => const SquadsScreen()),
          GoRoute(path: Routes.inbox, builder: (_, __) => const InboxScreen()),
          GoRoute(path: Routes.profile, builder: (_, __) => const ProfileScreen()),
        ],
      ),

      GoRoute(path: Routes.search, builder: (_, __) => const SearchScreen()),
      GoRoute(
        path: Routes.discover,
        redirect: (_, __) => Routes.search,
      ),

      GoRoute(
        path: '/post/:id',
        builder: (_, state) => PostDetailScreen(postId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/game/:slug',
        builder: (_, state) => GameBySlugScreen(slug: state.pathParameters['slug']!),
      ),
      GoRoute(
        path: '/invite/squad/:token',
        builder: (_, state) => RedeemSquadInviteScreen(token: state.pathParameters['token']!),
      ),
      GoRoute(
        path: '/u/:username',
        builder: (_, state) => ProfileByUsernameScreen(username: state.pathParameters['username']!),
      ),

      GoRoute(path: Routes.saved, builder: (_, __) => const SavedPostsScreen()),
      GoRoute(path: Routes.lfg, builder: (_, __) => const LfgScreen()),
      GoRoute(
        path: '/community/:id',
        builder: (_, state) => CommunityDetailScreen(communityId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/user/:id',
        builder: (_, state) => ProfileScreen(userId: state.pathParameters['id']),
      ),
      GoRoute(
        path: '/squad/:id',
        builder: (_, state) => SquadDetailScreen(squadId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/chat/:id',
        builder: (_, state) => ChatRoomScreen(conversationId: state.pathParameters['id']!),
      ),
      GoRoute(path: Routes.editProfile, builder: (_, __) => const EditProfileScreen()),
      GoRoute(
        path: Routes.settings,
        builder: (ctx, __) => Consumer(
          builder: (ctx, ref, __) => Scaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: ListView(
            children: [
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Edit profile'),
                onTap: () => ctx.push(Routes.editProfile),
              ),
              ListTile(
                leading: const Icon(Icons.bookmark_outline),
                title: const Text('Saved posts'),
                onTap: () => ctx.push(Routes.saved),
              ),
              ListTile(
                leading: const Icon(Icons.group_add_outlined),
                title: const Text('Looking For Group'),
                onTap: () => ctx.push(Routes.lfg),
              ),
              ListTile(
                leading: const Icon(Icons.emoji_events_outlined),
                title: const Text('Tournaments'),
                onTap: () => ctx.push('/tournaments'),
              ),
              const DataSaverSettingsTile(),
              const BiometricSettingsTile(),
              ListTile(
                leading: const Icon(Icons.delete_forever_outlined),
                title: const Text('Delete account'),
                onTap: () => Navigator.of(ctx).push(
                  MaterialPageRoute(builder: (_) => const DeleteAccountScreen()),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.lock_outline),
                title: const Text('Privacy'),
                onTap: () => Navigator.of(ctx).push(
                  MaterialPageRoute(builder: (_) => const PrivacySettingsScreen()),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.sports_esports_outlined),
                title: const Text('Manage games'),
                onTap: () => Navigator.of(ctx).push(
                  MaterialPageRoute(builder: (_) => const ManageGamesScreen()),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.admin_panel_settings_outlined),
                title: const Text('Admin'),
                onTap: () => ctx.push(Routes.admin),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Log out', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: ctx,
                    builder: (dialogCtx) => AlertDialog(
                      title: const Text('Log out?'),
                      content: const Text('You can log back in any time.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(dialogCtx).pop(false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(dialogCtx).pop(true),
                          child: const Text('Log out', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await ref.read(authControllerProvider.notifier).signOut();
                    if (ctx.mounted) ctx.go(Routes.login);
                  }
                },
              ),
            ],
          ),
          ),
        ),
      ),
      GoRoute(
        path: Routes.admin,
        builder: (_, __) => const AdminDashboardScreen(),
      ),
      GoRoute(path: '/tournaments', builder: (_, __) => const TournamentsScreen()),
      GoRoute(
        path: '/tournament/:id',
        builder: (_, state) => TournamentDetailScreen(
          tournamentId: state.pathParameters['id']!,
        ),
      ),

      GoRoute(
        path: Routes.notifications,
        builder: (_, __) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/create-video',
        builder: (_, __) => const CreateVideoPostScreen(),
      ),
    ],
  );
});
