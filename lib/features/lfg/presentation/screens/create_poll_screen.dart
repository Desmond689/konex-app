import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/kx_button.dart';
import '../../../../core/widgets/kx_text_field.dart';
import '../providers/lfg_provider.dart';
import '../../../../core/errors/error_handler.dart';

class CreatePollScreen extends ConsumerStatefulWidget {
  const CreatePollScreen({super.key});

  @override
  ConsumerState<CreatePollScreen> createState() => _CreatePollScreenState();
}

class _CreatePollScreenState extends ConsumerState<CreatePollScreen> {
  final _question = TextEditingController();
  final _options = <TextEditingController>[
    TextEditingController(),
    TextEditingController(),
  ];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _question.dispose();
    for (final c in _options) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final q = _question.text.trim();
    final opts = _options.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();
    if (q.isEmpty) {
      setState(() => _error = 'Question required');
      return;
    }
    if (opts.length < 2) {
      setState(() => _error = 'At least 2 options');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final r = await ref.read(lfgRepositoryProvider).createPoll(
          question: q,
          options: opts,
          duration: const Duration(days: 1),
        );
    if (!mounted) return;
    setState(() => _loading = false);
    r.when(
      success: (_) => Navigator.of(context).pop(true),
      failure: (e, _) => setState(() => _error = ErrorHandler.userMessage(e)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create poll')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          KxTextField(
            controller: _question,
            label: 'Question',
            validator: (v) => Validators.required(v, 'Question'),
          ),
          const SizedBox(height: 16),
          Text('Options', style: AppTextStyles.title),
          ..._options.map(
            (c) => Padding(
              padding: const EdgeInsets.only(top: 8),
              child: KxTextField(controller: c, label: 'Option'),
            ),
          ),
          TextButton(
            onPressed: () {
              if (_options.length >= 6) return;
              setState(() => _options.add(TextEditingController()));
            },
            child: const Text('Add option'),
          ),
          if (_error != null)
            Text(_error!, style: AppTextStyles.caption.copyWith(color: Colors.redAccent)),
          const SizedBox(height: 16),
          KxButton(label: 'Post poll', onPressed: _submit, loading: _loading),
        ],
      ),
    );
  }
}
