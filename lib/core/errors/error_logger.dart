import 'package:flutter/foundation.dart';

import '../config/app_config.dart';

/// Lightweight logger. Replace with Sentry/Crashlytics in production.
class ErrorLogger {
  static void log(
    Object error, {
    StackTrace? stack,
    String? context,
    AppConfig? config,
  }) {
    if (config != null && !config.enableLogging && config.isProduction) {
      // Still send to crash reporting in production when wired.
      return;
    }
    if (kDebugMode) {
      final ctx = context != null ? '[$context] ' : '';
      debugPrint('$ctx$error');
      if (stack != null) debugPrint(stack.toString());
    }
  }
}
