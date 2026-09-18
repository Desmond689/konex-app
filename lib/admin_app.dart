import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'admin_router.dart';
import 'core/theme/app_theme.dart';

/// Root widget for the admin console. Deliberately much smaller than
/// [KonexApp] (see app.dart) — no deep-link listener, no push notifications,
/// no presence heartbeat, no biometric app lock, no call controller. Those
/// all exist to serve the mobile player experience; an admin dashboard
/// running in a browser tab needs none of them, and several (deep links,
/// biometric prompts) don't have meaningful web equivalents anyway.
class AdminApp extends ConsumerWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(adminRouterProvider);
    return MaterialApp.router(
      title: 'KONEX Admin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: router,
    );
  }
}
