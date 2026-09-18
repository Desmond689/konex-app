import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Defines the three distinct build environments.
/// Each must map to a SEPARATE Supabase project in production usage.
enum AppEnvironment { development, staging, production }

/// Immutable configuration object.
/// Created once at app startup and injected via Riverpod.
class AppConfig {
  final AppEnvironment environment;
  final String supabaseUrl;
  final String supabaseAnonKey;
  final bool enableLogging;
  final String appVersion;
  final String buildNumber;

  const AppConfig._({
    required this.environment,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.enableLogging,
    required this.appVersion,
    required this.buildNumber,
  });

  /// Strict async initialization.
  /// Throws [StateError] if critical configs are missing.
  static Future<AppConfig> initialize() async {
    await dotenv.load(fileName: '.env');

    final rawEnvironment = dotenv.env['APP_ENV'] ?? 'development';
    final environment = AppEnvironment.values.firstWhere(
      (e) => e.name == rawEnvironment,
      orElse: () => throw StateError('Invalid APP_ENV: $rawEnvironment'),
    );

    final url = dotenv.env['SUPABASE_URL'];
    final anonKey = dotenv.env['SUPABASE_ANON_KEY'];

    if (url == null || url.isEmpty || url.contains('placeholder')) {
      throw StateError(
        'SUPABASE_URL missing or still placeholder. '
        'Copy .env.example → .env and set a real project URL.',
      );
    }
    if (anonKey == null || anonKey.isEmpty || anonKey.contains('placeholder')) {
      throw StateError(
        'SUPABASE_ANON_KEY missing or still placeholder. '
        'Only the anon/public key may ship in the client.',
      );
    }

    return AppConfig._(
      environment: environment,
      supabaseUrl: url,
      supabaseAnonKey: anonKey,
      enableLogging: _parseBool(dotenv.env['ENABLE_LOGGING']),
      appVersion: dotenv.env['APP_VERSION'] ?? '0.1.0',
      buildNumber: dotenv.env['BUILD_NUMBER'] ?? '1',
    );
  }

  bool get isProduction => environment == AppEnvironment.production;
  bool get isDevelopment => environment == AppEnvironment.development;

  static bool _parseBool(String? value) {
    if (value == null) return false;
    return value.toLowerCase() == 'true';
  }
}

/// Global Riverpod provider. Overridden in main() with the initialized value.
final appConfigProvider = Provider<AppConfig>((ref) {
  throw UnimplementedError('AppConfig must be overridden at app startup');
});
