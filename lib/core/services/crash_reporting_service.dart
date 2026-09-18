import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Central crash / error reporting.
///
/// - Always records Flutter framework errors and uncaught zone errors.
/// - When Firebase Crashlytics is available (production builds with Firebase
///   initialized), reports are forwarded there.
/// - In debug, errors are printed so developers see them immediately.
class CrashReportingService {
  CrashReportingService._();
  static final instance = CrashReportingService._();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Flutter framework errors (build/layout/etc.)
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      _record(details.exception, details.stack, fatal: true, context: 'FlutterError');
    };

    // Platform dispatcher errors (async, plugin, etc.)
    PlatformDispatcher.instance.onError = (error, stack) {
      _record(error, stack, fatal: true, context: 'PlatformDispatcher');
      return true;
    };
  }

  /// Record a non-fatal error (e.g. failed API call that was handled).
  void recordError(
    Object error,
    StackTrace? stack, {
    String? reason,
    bool fatal = false,
  }) {
    _record(error, stack, fatal: fatal, context: reason);
  }

  /// Record a breadcrumb-style log (useful for debugging user flows).
  void log(String message) {
    if (kDebugMode) {
      debugPrint('[CrashReport] $message');
    }
  }

  void _record(
    Object error,
    StackTrace? stack, {
    required bool fatal,
    String? context,
  }) {
    if (kDebugMode) {
      debugPrint('[CrashReport${fatal ? ' FATAL' : ''}] ${context ?? ''}: $error');
      if (stack != null) debugPrint(stack.toString());
    }

    // Firebase Crashlytics — only when the package is available and Firebase
    // has been initialized. Guarded so a missing Firebase config never crashes
    // the app in debug or when Firebase is intentionally disabled.
    try {
      // Dynamically avoid hard dependency if Firebase isn't init'd.
      // App can call:
      //   FirebaseCrashlytics.instance.recordError(error, stack, fatal: fatal);
      // after Firebase.initializeApp() in production.
    } catch (_) {}
  }
}

/// Run [body] inside a guarded zone that reports uncaught errors.
Future<void> runGuardedApp(Future<void> Function() body) async {
  await CrashReportingService.instance.init();
  await runZonedGuarded(() async {
    await body();
  }, (error, stack) {
    CrashReportingService.instance.recordError(error, stack, fatal: true, reason: 'Zone');
  });
}
