import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/constants.dart';
import '../../../../core/config/dependency_injection.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/kx_button.dart';
import '../../../../core/widgets/kx_text_field.dart';
import '../providers/auth_provider.dart';
import '../../../../core/errors/error_handler.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _username = TextEditingController();
  final _gamerName = TextEditingController();
  String? _playerType;
  String _country = 'CM';
  DateTime? _dob;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _username.dispose();
    _gamerName.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_dob == null) {
      setState(() => _error = 'Date of birth is required (must be 13+)');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await ref.read(authControllerProvider.notifier).signUp(
          email: _email.text.trim(),
          password: _password.text,
          username: _username.text.trim(),
          gamerName: _gamerName.text.trim().isEmpty ? null : _gamerName.text.trim(),
          playerType: _playerType,
          country: _country,
          dateOfBirth: _dob,
        );

    if (!mounted) return;
    setState(() => _loading = false);

    result.when(
      success: (_) {
        final hasSession =
            ref.read(supabaseClientProvider).auth.currentSession != null;
        if (hasSession) {
          context.go(Routes.onboarding);
        } else {
          context.go(Routes.emailVerification, extra: _email.text.trim());
        }
      },
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
            colors: [Color(0xFF0F0F12), Color(0xFF16122A), Color(0xFF0F1A1A)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => context.go(Routes.login),
                    ),
                  ),
                  Center(
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.secondary],
                        ),
                      ),
                      child: const Icon(Icons.sports_esports_rounded, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.asset(
                            'assets/images/logo.png',
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text('JOIN KONEX', style: AppTextStyles.brandSmall),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Create your gamer identity', style: AppTextStyles.display.copyWith(fontSize: 26)),
                  const SizedBox(height: 8),
                  Text(
                    'Pick a username, prove you’re 13+, and get into communities for the games you play.',
                    style: AppTextStyles.bodySecondary,
                  ),
                  const SizedBox(height: 24),

                KxTextField(
                  controller: _email,
                  label: 'Email',
                  keyboardType: TextInputType.emailAddress,
                  validator: Validators.email,
                ),
                const SizedBox(height: 12),
                KxTextField(
                  controller: _username,
                  label: 'Username (unique)',
                  validator: Validators.username,
                ),
                const SizedBox(height: 12),
                KxTextField(
                  controller: _gamerName,
                  label: 'Gamer name',
                ),
                const SizedBox(height: 12),
                KxTextField(
                  controller: _password,
                  label: 'Password',
                  obscureText: true,
                  validator: Validators.password,
                ),
                const SizedBox(height: 12),
                KxTextField(
                  controller: _confirmPassword,
                  label: 'Confirm password',
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (value != _password.text) {
                      return "Passwords don't match.";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _playerType,
                  decoration: const InputDecoration(labelText: 'Player type'),
                  items: AppConstants.playerTypes
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => setState(() => _playerType = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _country,
                  decoration: const InputDecoration(labelText: 'Country'),
                  items: AppConstants.countryOptions
                      .map(
                        (c) => DropdownMenuItem(
                          value: c['code'],
                          child: Text('${c['label']} (${c['code']})'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _country = v);
                  },
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Date of birth'),
                  subtitle: Text(
                    _dob == null
                        ? 'Required · Must be 13+'
                        : '${_dob!.year}-${_dob!.month.toString().padLeft(2, '0')}-${_dob!.day.toString().padLeft(2, '0')}',
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime(now.year - 16),
                      firstDate: DateTime(now.year - 100),
                      lastDate: DateTime(now.year - 13, now.month, now.day),
                    );
                    if (picked != null) setState(() => _dob = picked);
                  },
                ),
                if (_dob == null)
                  Text(
                    'You must select your date of birth (13+).',
                    style: AppTextStyles.caption.copyWith(color: Colors.orangeAccent),
                  ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: AppTextStyles.caption.copyWith(color: Colors.redAccent)),
                ],
                const SizedBox(height: 24),
                KxButton(label: 'Sign up', onPressed: _submit, loading: _loading),
                const SizedBox(height: 12),
                KxTextButton(
                  label: 'Already have an account? Sign in',
                  onPressed: () => context.go(Routes.login),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }
}
