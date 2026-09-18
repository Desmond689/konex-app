import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/dependency_injection.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/kx_button.dart';
import '../../../../core/widgets/kx_text_field.dart';
import '../../../../core/errors/error_handler.dart';

/// Apple / GDPR in-app account deletion.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _confirm = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (_confirm.text.trim().toUpperCase() != 'DELETE') {
      setState(() => _error = 'Type DELETE to confirm');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final client = ref.read(supabaseClientProvider);
      await client.rpc('delete_own_account');
      try {
        await client.functions.invoke('delete-account');
      } catch (_) {}
      await client.auth.signOut();
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(
        const SnackBar(content: Text('Your account has been deleted')),
      );
      context.go(Routes.login);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ErrorHandler.userMessage(e);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Delete account')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'This removes your profile data, memberships, and access. '
            'Some legal/moderation records may be retained as required by law.',
            style: AppTextStyles.body,
          ),
          const SizedBox(height: 16),
          Text('Type DELETE to confirm', style: AppTextStyles.caption),
          KxTextField(controller: _confirm, label: 'Confirmation'),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: AppTextStyles.caption.copyWith(color: Colors.redAccent)),
          ],
          const SizedBox(height: 20),
          KxButton(
            label: 'Delete my account',
            loading: _loading,
            onPressed: _delete,
          ),
        ],
      ),
    );
  }
}
