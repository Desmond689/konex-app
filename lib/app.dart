import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/constants.dart';
import 'core/deep_links/deep_link_router.dart';
import 'core/notifications/push_notification_service.dart';
import 'core/router/app_router.dart' show appRouterProvider, rootNavigatorKey;
import 'core/router/routes.dart';
import 'core/security/app_lock_controller.dart';
import 'core/services/presence_service.dart';
import 'core/theme/app_theme.dart';
import 'features/calls/presentation/providers/call_controller.dart';

class KonexApp extends ConsumerStatefulWidget {
  const KonexApp({super.key});

  @override
  ConsumerState<KonexApp> createState() => _KonexAppState();
}

class _KonexAppState extends ConsumerState<KonexApp>
    with WidgetsBindingObserver {
  StreamSubscription<Uri>? _linkSub;
  final _appLinks = AppLinks();
  final _presence = PresenceService(Supabase.instance.client);
  Timer? _banCheckTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(callControllerProvider.notifier).navigatorKey = rootNavigatorKey;
      ref.read(appLockProvider.notifier).bootstrap();
      _initPush();
      _initDeepLinks();
      _presence.start();
      _startBanStatusChecks();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _linkSub?.cancel();
    _banCheckTimer?.cancel();
    _presence.stop();
    super.dispose();
  }

  void _startBanStatusChecks() {
    _banCheckTimer?.cancel();
    _banCheckTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _checkBanStatus(),
    );
    _checkBanStatus();
  }

  Future<void> _checkBanStatus() async {
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser?.id;
    if (uid == null) return;

    try {
      final profile = await client
          .from('profiles')
          .select('is_banned')
          .eq('id', uid)
          .maybeSingle()
          .timeout(const Duration(seconds: 6));
      final banned = profile?['is_banned'] as bool? ?? false;
      final router = ref.read(appRouterProvider);
      final location = router.routeInformationProvider.value.uri.path;
      if (banned && location != Routes.suspended) {
        router.go(Routes.suspended);
      } else if (!banned && location == Routes.suspended) {
        router.go(Routes.home);
      }
    } catch (error) {
      debugPrint('Ban status check failed: $error');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      ref.read(appLockProvider.notifier).onAppPaused();
      _presence.stop();
    } else if (state == AppLifecycleState.resumed) {
      final lock = ref.read(appLockProvider);
      if (lock.enabled && lock.locked) {
        ref.read(appLockProvider.notifier).unlock();
      }
      final ctx = rootNavigatorKey.currentContext;
      if (ctx != null) {
        DeepLinkRouter.consumePending(ctx);
      }
      _presence.start();
    }
  }

  Future<void> _initDeepLinks() async {
    if (kIsWeb) return;
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) {
        await _openLink(initial);
      }
      await _linkSub?.cancel();
      _linkSub = _appLinks.uriLinkStream.listen(_openLink);
    } catch (e) {
      debugPrint('Deep link init failed: $e');
    }
  }

  Future<void> _openLink(Uri uri) async {
    // Handle auth callback: konex://auth/callback
    if (uri.scheme.toLowerCase() == 'konex' &&
        uri.host.toLowerCase() == 'auth' &&
        uri.path == '/callback') {
      await _handleAuthCallback(uri);
      return;
    }

    // Handle all other konex:// links (invite, profile, post, party, game, etc.)
    // Convert konex://path to https://konex-app-rho.vercel.app/path for the parser
    if (uri.scheme.toLowerCase() == 'konex') {
      final path = uri.path.isNotEmpty ? uri.path : '/';
      final parsingUri = Uri.parse('https://konex-app-rho.vercel.app$path${uri.query.isNotEmpty ? '?${uri.query}' : ''}');
      final ctx = rootNavigatorKey.currentContext;
      if (ctx == null) {
        // Defer until navigator is ready
        DeepLinkRouter.pendingPath =
            DeepLinkRouter.parsePath(parsingUri.path)?.routePath;
        return;
      }
      final loggedIn = Supabase.instance.client.auth.currentUser != null;
      await DeepLinkRouter.handle(ctx, parsingUri, isLoggedIn: loggedIn);
      return;
    }

    // Fallback for any other schemes (shouldn't happen with app_links)
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null) {
      // Defer until navigator is ready
      DeepLinkRouter.pendingPath =
          DeepLinkRouter.parsePath(uri.path)?.routePath;
      return;
    }
    final loggedIn = Supabase.instance.client.auth.currentUser != null;
    await DeepLinkRouter.handle(ctx, uri, isLoggedIn: loggedIn);
  }

  Future<void> _handleAuthCallback(Uri uri) async {
    final client = Supabase.instance.client;
    try {
      final code = uri.queryParameters['code'];
      final tokenHash = uri.queryParameters['token_hash'];
      final type = uri.queryParameters['type'];
      final isRecovery = type == 'recovery';

      if (code != null && code.isNotEmpty) {
        await client.auth.exchangeCodeForSession(code);
      } else if (tokenHash != null &&
          tokenHash.isNotEmpty &&
          type != null &&
          type.isNotEmpty) {
        await client.auth.verifyOTP(
          tokenHash: tokenHash,
          // Recovery links must be verified with OtpType.recovery, not the
          // hardcoded signup type — using the wrong type here was rejecting
          // valid password-reset links.
          type: isRecovery ? OtpType.recovery : OtpType.signup,
        );
      } else {
        throw StateError('Email verification link is incomplete.');
      }
      final ctx = rootNavigatorKey.currentContext;
      if (ctx != null) {
        // A recovery link's whole purpose is to let the user set a new
        // password — send them there instead of onboarding.
        ref.read(appRouterProvider).go(isRecovery ? '/reset-password' : '/onboarding');
      }
    } catch (error, stack) {
      debugPrint('Auth callback failed: $error');
      debugPrint('$stack');
      final ctx = rootNavigatorKey.currentContext;
      if (ctx != null) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(
            content:
                Text('This link is invalid or has expired. Please request a new one.'),
          ),
        );
      }
    }
  }

  Future<void> _initPush() async {
    if (kIsWeb) return;

    final client = Supabase.instance.client;
    final push = PushNotificationService(client);

    Future<void> startPush() async {
      await push.start(
        onOpenRoute: (route) {
          ref.read(appRouterProvider).go(route);
        },
        onIncomingCall: (callId) {
          ref
              .read(callControllerProvider.notifier)
              .handleIncomingFromPush(callId);
        },
      );
    }

    if (client.auth.currentUser != null) {
      await startPush();
    }

    client.auth.onAuthStateChange.listen((data) async {
      if (data.session != null) {
        await startPush();
        final ctx = rootNavigatorKey.currentContext;
        if (ctx != null) DeepLinkRouter.consumePending(ctx);
      } else {
        await push.clearToken();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final lock = ref.watch(appLockProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: router,
      builder: (context, child) {
        return Stack(
          children: [
            child ?? const SizedBox.shrink(),
            if (lock.enabled && lock.locked)
              const Positioned.fill(child: _AppLockOverlay()),
          ],
        );
      },
    );
  }
}

class _AppLockOverlay extends ConsumerWidget {
  const _AppLockOverlay();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: Colors.black.withValues(alpha: 0.92),
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 48, color: Colors.white),
              const SizedBox(height: 16),
              const Text(
                'KONEX is locked',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => ref.read(appLockProvider.notifier).unlock(),
                icon: const Icon(Icons.fingerprint),
                label: const Text('Unlock'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
