import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/kx_button.dart';
import '../../../../core/widgets/kx_text_field.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/errors/error_handler.dart';

/// The admin console's own sign-in screen. Deliberately not the player-facing
/// LoginScreen: that one always routes to Routes.home on success (which
/// doesn't exist in the admin router) and links out to signup/forgot-password
/// routes this app doesn't declare — neither of which makes sense for a
/// staff-only tool anyway. Same auth call underneath, just no player-facing
/// copy or dead links.
class AdminLoginScreen extends ConsumerStatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  ConsumerState<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends ConsumerState<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await ref.read(authControllerProvider.notifier).signIn(
          email: _email.text.trim(),
          password: _password.text,
        );

    if (!mounted) return;
    setState(() => _loading = false);

    result.when(
      success: (_) => context.go(Routes.admin),
      failure: (e, _) => setState(() => _error = ErrorHandler.userMessage(e)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F0F12),
              Color(0xFF16122A),
              Color(0xFF0F1A1A),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
              child: ConstrainedBox(
                // Caps the form width on wide browser windows — the same
                // centered-column layout the mobile screens use would
                // otherwise stretch full-width on desktop.
                constraints: const BoxConstraints(maxWidth: 380),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: const LinearGradient(
                              colors: [AppColors.primary, AppColors.secondary],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.45),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.admin_panel_settings_outlined,
                            size: 36,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Center(child: Text('KONEX', style: AppTextStyles.brand)),
                      const SizedBox(height: 6),
                      Center(
                        child: Text(
                          'ADMIN CONSOLE',
                          style: AppTextStyles.brandSmall.copyWith(fontSize: 11),
                        ),
                      ),
                      const SizedBox(height: 40),
                      Text('Staff sign in', style: AppTextStyles.display),
                      const SizedBox(height: 8),
                      Text(
                        'Sign in with your KONEX account. Access is limited to '
                        'moderator, admin, and super_admin roles.',
                        style: AppTextStyles.bodySecondary,
                      ),
                      const SizedBox(height: 32),
                      KxTextField(
                        controller: _email,
                        label: 'Email',
                        keyboardType: TextInputType.emailAddress,
                        validator: Validators.email,
                        autofillHints: const [AutofillHints.email],
                      ),
                      const SizedBox(height: 16),
                      KxTextField(
                        controller: _password,
                        label: 'Password',
                        obscureText: true,
                        validator: Validators.password,
                        autofillHints: const [AutofillHints.password],
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.error.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            _error!,
                            style: AppTextStyles.caption.copyWith(color: AppColors.error),
                          ),
                        ),
                      ],
                      const SizedBox(height: 28),
                      KxButton(
                        label: 'Sign in',
                        onPressed: _submit,
                        loading: _loading,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
