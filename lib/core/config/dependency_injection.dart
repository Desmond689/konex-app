import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../storage/local_storage_service.dart';
import '../storage/secure_storage_service.dart';
import '../storage/session_manager.dart';
import '../services/connectivity_service.dart';
import 'app_config.dart';

/// Supabase client provider. Initialized in main() after AppConfig.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

final localStorageProvider = Provider<LocalStorageService>((ref) {
  return LocalStorageService();
});

final sessionManagerProvider = Provider<SessionManager>((ref) {
  return SessionManager(
    secureStorage: ref.watch(secureStorageProvider),
    supabase: ref.watch(supabaseClientProvider),
  );
});

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService();
});

/// Convenience: current AppConfig
final configProvider = Provider<AppConfig>((ref) => ref.watch(appConfigProvider));
