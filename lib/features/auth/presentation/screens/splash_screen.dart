import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/dependency_injection.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    if (!mounted) return;

    try {
      final session = ref.read(sessionManagerProvider);
      // validateSession already has its own 8s timeout + clears bad sessions.
      final valid = await session.validateSession();

      if (!mounted) return;
      if (!valid) {
        context.go(Routes.login);
        return;
      }
      // Don't decide onboarding-vs-home here — that decision already lives in
      // AuthGuard.redirect(), which every navigation (including this one)
      // passes through anyway. Always heading to home and letting AuthGuard
      // reroute to onboarding only when the (server-checked) flag actually
      // says incomplete keeps that decision in one place.
      context.go(Routes.home);
    } catch (_) {
      // Any unexpected failure (e.g. provider not ready, storage error)
      // must still leave the splash screen — otherwise the user is stuck
      // forever. Prefer login as the safe fallback.
      if (mounted) context.go(Routes.login);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F0F12),
              Color(0xFF1A1240),
              Color(0xFF0A1F1E),
            ],
          ),
        ),
        child: Center(
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.45),
                        blurRadius: 36,
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppColors.primary,
                      alignment: Alignment.center,
                      child: const Text(
                        'K',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text('KONEX', style: AppTextStyles.brand),
                const SizedBox(height: 8),
                Text(
                  'PLAY · SQUAD UP · COMPETE',
                  style: AppTextStyles.brandSmall.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
