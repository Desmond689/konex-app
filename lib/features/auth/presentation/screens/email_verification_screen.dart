import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/config/dependency_injection.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/kx_button.dart';
import '../../../../core/errors/error_handler.dart';

class EmailVerificationScreen extends ConsumerStatefulWidget {
  const EmailVerificationScreen({super.key, required this.email});
  final String email;

  @override
  ConsumerState<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends ConsumerState<EmailVerificationScreen> {
  bool _resending = false;
  int _cooldown = 0;
  Timer? _cooldownTimer;
  String? _message;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _resend() async {
    if (_resending || _cooldown > 0 || widget.email.isEmpty) return;
    setState(() {
      _resending = true;
      _message = null;
    });
    try {
      final storage = ref.read(localStorageProvider);
      var deviceId = await storage.getVerificationDeviceId();
      if (deviceId == null || deviceId.isEmpty) {
        deviceId = const Uuid().v4();
        await storage.setVerificationDeviceId(deviceId);
      }
      await ref.read(supabaseClientProvider).functions.invoke(
        'resend-verification',
        body: {'email': widget.email, 'device_id': deviceId},
      );
      if (mounted) {
        setState(() {
          _message = 'Verification email sent.';
          _cooldown = 60;
        });
        _startCooldown();
      }
    } on FunctionException catch (error) {
      if (mounted) {
        setState(() {
          _message = error.status == 429
              ? 'Too many requests. Please try again later.'
              : ErrorHandler.userMessage(error);
        });
      }
    } catch (error) {
      if (mounted) setState(() => _message = ErrorHandler.userMessage(error));
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_cooldown <= 1) {
        timer.cancel();
        setState(() => _cooldown = 0);
      } else {
        setState(() => _cooldown--);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.mark_email_read_outlined, size: 64),
              const SizedBox(height: 20),
              Text('Verify your email', style: AppTextStyles.headline),
              const SizedBox(height: 12),
              Text(
                'We sent a verification link to ${widget.email}. Confirm it, then return here and sign in.',
                style: AppTextStyles.bodySecondary,
                textAlign: TextAlign.center,
              ),
              if (_message != null) ...[
                const SizedBox(height: 16),
                Text(_message!, style: AppTextStyles.caption),
              ],
              const SizedBox(height: 24),
              KxButton(
                label: _cooldown > 0
                    ? 'Resend in $_cooldown seconds'
                    : 'Resend verification email',
                loading: _resending,
                onPressed: _resend,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.go(Routes.login),
                child: const Text('Back to sign in'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
