import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/config/environment_config.dart';
import 'core/security/certificate_pinning.dart';
import 'core/config/dependency_injection.dart';
import 'core/services/crash_reporting_service.dart';
import 'core/storage/local_storage_service.dart';
import 'core/storage/secure_supabase_local_storage.dart';

Future<void> main() async {
  await runGuardedApp(() async {
    WidgetsFlutterBinding.ensureInitialized();

    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    // Firebase initialization intentionally disabled in this sandbox.
    // Production: Firebase.initializeApp() then enable Crashlytics.

    // Everything below runs before runApp(). If ANY of it throws (bad/missing
    // .env values, Supabase.initialize() failing or hanging on a bad network,
    // a secure-storage read error on the device, etc.) and we don't catch it
    // here, runZonedGuarded's handler below just logs it and returns —
    // runApp() never fires, Flutter never draws a first frame, and the OS
    // splash screen (on Android 12+, just the app's launcher icon) is left
    // on screen forever with zero visible error. This try/catch guarantees
    // something is always drawn, even when startup fails.
    try {
      final config = await AppConfig.initialize();

      final behavior = EnvironmentBehavior.resolve(
        config.environment,
      );

      await initializeCertificatePinning(
        enabled: behavior.enableCertificatePinning && !kDebugMode,
        supabaseUrl: config.supabaseUrl,
      );

      final secureLocalStorage = SecureSupabaseLocalStorage();

      await Supabase.initialize(
        url: config.supabaseUrl,
        publishableKey: config.supabaseAnonKey,
        authOptions: FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
          localStorage: secureLocalStorage,
        ),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException(
          'Supabase.initialize() timed out — check network/SUPABASE_URL',
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
          child: const KonexApp(),
        ),
      );
    } catch (error, stack) {
      CrashReportingService.instance.recordError(
        error,
        stack,
        fatal: true,
        reason: 'Startup failed before runApp()',
      );
      runApp(_StartupErrorApp(error: error));
    }
  });
}

/// Shown only if app startup throws before the real app can build.
/// Without this, a startup failure leaves the screen stuck on the OS splash
/// forever instead of surfacing what went wrong.
class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF0F0F12),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline,
                    color: Colors.redAccent, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Konex failed to start',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '$error',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
