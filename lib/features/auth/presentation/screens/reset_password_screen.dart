import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/kx_button.dart';
import '../../../../core/widgets/kx_text_field.dart';
import '../providers/auth_provider.dart';
import '../../../../core/errors/error_handler.dart';

/// Shown when a password-recovery deep link has just signed the user into a
/// temporary recovery session. They must set a new password before doing
/// anything else — AuthGuard keeps them here until they do.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String? _confirmValidator(String? value) {
    if (value != _password.text) return 'Passwords do not match';
    return null;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final result =
        await ref.read(authControllerProvider.notifier).updatePassword(_password.text);

    if (!mounted) return;
    setState(() => _loading = false);
    result.when(
      success: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password updated')),
        );
        context.go(Routes.home);
      },
      failure: (e, _) => setState(() => _error = ErrorHandler.userMessage(e)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set a new password'), automaticallyImplyLeading: false),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Choose a new password', style: AppTextStyles.display),
                const SizedBox(height: 8),
                Text(
                  "You're signed in with a one-time recovery link. Set a new password to finish.",
                  style: AppTextStyles.bodySecondary,
                ),
                const SizedBox(height: 24),
                KxTextField(
                  controller: _password,
                  label: 'New password',
                  obscureText: true,
                  validator: Validators.password,
                  autofillHints: const [AutofillHints.newPassword],
                ),
                const SizedBox(height: 16),
                KxTextField(
                  controller: _confirm,
                  label: 'Confirm new password',
                  obscureText: true,
                  validator: _confirmValidator,
                  autofillHints: const [AutofillHints.newPassword],
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
                    child:
                        Text(_error!, style: AppTextStyles.caption.copyWith(color: AppColors.error)),
                  ),
                ],
                const SizedBox(height: 24),
                KxButton(label: 'Update password', onPressed: _submit, loading: _loading),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
