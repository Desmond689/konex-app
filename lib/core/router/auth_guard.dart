import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/dependency_injection.dart';
import 'routes.dart';

/// Redirect logic for go_router based on auth + onboarding state.
class AuthGuard {
  static Future<String?> redirect(BuildContext context, GoRouterState state, Ref ref) async {
    final sessionManager = ref.read(sessionManagerProvider);
    final local = ref.read(localStorageProvider);

    final loggedIn = sessionManager.isAuthenticated;
    var onboardingDone = await local.getOnboardingDone();

    // Local storage alone isn't reliable: a reinstall, a new device, or the
    // user clearing app storage all reset it to false even though the
    // profiles row already has onboarding_completed = true, which re-asks
    // onboarding for someone who already finished it. Whenever local
    // storage says "incomplete", check the server value and let it win —
    // then sync local storage so we don't pay this round trip every route
    // change.
    // CRITICAL: this query MUST be time-bounded. Without a timeout the
    // entire go_router redirect hangs forever on a slow/offline network,
    // which leaves the user stuck on the splash screen indefinitely.
    if (loggedIn && !onboardingDone) {
      try {
        final client = ref.read(supabaseClientProvider);
        final uid = client.auth.currentUser?.id;
        if (uid != null) {
          final row = await client
              .from('profiles')
              .select('onboarding_completed')
              .eq('id', uid)
              .maybeSingle()
              .timeout(const Duration(seconds: 6));
          final serverDone = row?['onboarding_completed'] as bool? ?? false;
          if (serverDone) {
            onboardingDone = true;
            await local.setOnboardingDone(true);
          }
        }
      } catch (_) {
        // Offline, timeout, or request failed — fall back to the local value
        // so a network hiccup doesn't strand a logged-in user on a redirect
        // loop or freeze the splash screen.
      }
    }

    final loc = state.matchedLocation;

    // The recovery deep link signs the user into a real session before this
    // screen is shown, so without this check the "onboarding done -> leave
    // auth screens" rule below would immediately bounce them off it toward
    // home before they set a new password.
    if (loc == Routes.resetPassword) {
      return loggedIn ? null : Routes.login;
    }

    final isAuthRoute = loc == Routes.login ||
        loc == Routes.signup ||
        loc == Routes.emailVerification ||
        loc == Routes.splash ||
        loc == Routes.onboarding ||
        loc == Routes.forgotPassword;

    if (!loggedIn) {
      if (isAuthRoute) return null;
      return Routes.login;
    }

    // Banned accounts must never reach the application shell. Check the
    // server flag on every redirect so an admin unban takes effect without
    // requiring a reinstall or a stale local cache.
    try {
      final client = ref.read(supabaseClientProvider);
      final uid = client.auth.currentUser?.id;
      if (uid != null) {
        final profile = await client
            .from('profiles')
            .select('is_banned')
            .eq('id', uid)
            .maybeSingle()
            .timeout(const Duration(seconds: 6));
        final isBanned = profile?['is_banned'] as bool? ?? false;
        if (isBanned && loc != Routes.suspended) return Routes.suspended;
        if (!isBanned && loc == Routes.suspended) return Routes.home;
      }
    } catch (_) {
      // Preserve normal navigation during a transient network failure. The
      // server-side policies still protect banned accounts' data and actions.
    }

    // Logged in but onboarding incomplete
    if (!onboardingDone && loc != Routes.onboarding) {
      return Routes.onboarding;
    }

    // Logged in + onboarding done → leave auth screens
    if (onboardingDone && isAuthRoute) {
      return Routes.home;
    }

    return null;
  }
}
