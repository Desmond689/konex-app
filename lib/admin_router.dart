import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/config/dependency_injection.dart';
import 'core/router/routes.dart';
import 'features/admin/presentation/screens/admin_login_screen.dart';
import 'features/admin/presentation/screens/admin_dashboard_screen.dart';

final adminRootNavigatorKey = GlobalKey<NavigatorState>();

/// Two routes, one redirect rule: signed in → admin dashboard, otherwise →
/// login. There's no onboarding concept here (staff already have accounts;
/// nobody goes through the player onboarding flow to get admin access) and
/// no mobile shell/tab bar — AdminDashboardScreen already handles its own
/// sub-navigation via Navigator.push, so it doesn't need named sub-routes.
final adminRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: adminRootNavigatorKey,
    initialLocation: Routes.admin,
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final loggedIn = ref.read(sessionManagerProvider).isAuthenticated;
      final loc = state.matchedLocation;

      if (!loggedIn) {
        return loc == Routes.login ? null : Routes.login;
      }
      if (loc == Routes.login) return Routes.admin;
      return null;
    },
    routes: [
      GoRoute(path: Routes.login, builder: (_, __) => const AdminLoginScreen()),
      GoRoute(path: Routes.admin, builder: (_, __) => const AdminDashboardScreen()),
    ],
  );
});
