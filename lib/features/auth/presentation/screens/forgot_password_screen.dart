import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/kx_button.dart';
import '../../../../core/widgets/kx_text_field.dart';
import '../providers/auth_provider.dart';
import '../../../../core/errors/error_handler.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _loading = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await ref
        .read(authControllerProvider.notifier)
        .requestPasswordReset(_email.text.trim());

    if (!mounted) return;
    setState(() => _loading = false);
    result.when(
      success: (_) => setState(() => _sent = true),
      failure: (e, _) => setState(() => _error = ErrorHandler.userMessage(e)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset password')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _sent ? _buildSentState() : _buildFormState(),
        ),
      ),
    );
  }

  Widget _buildSentState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        const Icon(Icons.mark_email_read_outlined, size: 56, color: AppColors.primary),
        const SizedBox(height: 16),
        Text('Check your email', style: AppTextStyles.display),
        const SizedBox(height: 8),
        Text(
          'If an account exists for ${_email.text.trim()}, we sent a link to reset your password.',
          style: AppTextStyles.bodySecondary,
        ),
        const SizedBox(height: 28),
        KxButton(label: 'Back to sign in', onPressed: () => Navigator.of(context).pop()),
      ],
    );
  }

  Widget _buildFormState() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Forgot your password?', style: AppTextStyles.display),
          const SizedBox(height: 8),
          Text(
            "Enter the email on your account and we'll send you a reset link.",
            style: AppTextStyles.bodySecondary,
          ),
          const SizedBox(height: 24),
          KxTextField(
            controller: _email,
            label: 'Email',
            keyboardType: TextInputType.emailAddress,
            validator: Validators.email,
            autofillHints: const [AutofillHints.email],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
              ),
              child: Text(_error!, style: AppTextStyles.caption.copyWith(color: AppColors.error)),
            ),
          ],
          const SizedBox(height: 24),
          KxButton(label: 'Send reset link', onPressed: _submit, loading: _loading),
        ],
      ),
    );
  }
}
