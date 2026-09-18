import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_app.dart';
import 'core/config/app_config.dart';
import 'core/config/dependency_injection.dart';
import 'core/services/crash_reporting_service.dart';
import 'core/storage/local_storage_service.dart';
import 'core/storage/secure_supabase_local_storage.dart';

/// Entry point for the admin console web build. This is a *separate* app
/// target from lib/main.dart, not a route inside the mobile app — same
/// Supabase project, same admin screens/providers, same role checks, but
/// without ever pulling in anything mobile-only, most importantly:
///
///   - core/security/certificate_pinning.dart, which `import 'dart:io'`
///     unconditionally. dart:io has no web implementation at all, so if
///     this build ever imports that file (even transitively), it fails to
///     compile for web outright. Pinning is a mobile hardening technique
///     anyway — a browser already validates TLS certificates itself.
///   - push notifications, deep-link handling, the biometric app lock, and
///     WebRTC calls (see app.dart / KonexApp) — none of that applies to an
///     admin dashboard in a browser tab.
///
/// Build/run with:
///   flutter run -d chrome -t lib/admin_main.dart
///   flutter build web -t lib/admin_main.dart -o build/admin_web
Future<void> main() async {
  await runGuardedApp(() async {
    WidgetsFlutterBinding.ensureInitialized();

    final config = await AppConfig.initialize();

    final secureLocalStorage = SecureSupabaseLocalStorage();

    await Supabase.initialize(
      url: config.supabaseUrl,
      publishableKey: config.supabaseAnonKey,
      authOptions: FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        localStorage: secureLocalStorage,
      ),
    );

    final localStorage = LocalStorageService();
    await localStorage.init();

    runApp(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(config),
          localStorageProvider.overrideWithValue(localStorage),
        ],
        child: const AdminApp(),
      ),
    );
  });
}
