import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/kx_button.dart';
import 'social_provider.dart';
import '../../../core/errors/error_handler.dart';

const kReportReasons = [
  'Spam',
  'Harassment',
  'Hate / abusive behavior',
  'Sexual / inappropriate content',
  'Violence',
  'Scams',
  'Impersonation',
  'Other',
];

Future<bool> showReportDialog(
  BuildContext context, {
  required String targetType,
  required String targetId,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => _ReportDialog(targetType: targetType, targetId: targetId),
  );
  return result ?? false;
}

class _ReportDialog extends ConsumerStatefulWidget {
  const _ReportDialog({required this.targetType, required this.targetId});
  final String targetType;
  final String targetId;

  @override
  ConsumerState<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends ConsumerState<_ReportDialog> {
  String? _reason;
  final _details = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_reason == null) return;
    setState(() => _loading = true);
    final r = await ref.read(socialRepositoryProvider).report(
          targetType: widget.targetType,
          targetId: widget.targetId,
          reason: _reason!,
          details: _details.text.trim().isEmpty ? null : _details.text.trim(),
        );
    if (!mounted) return;
    setState(() => _loading = false);
    r.when(
      success: (_) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report submitted. Thanks.')),
        );
      },
      failure: (e, _) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorHandler.userMessage(e))),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Report'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Why are you reporting this?', style: AppTextStyles.bodySecondary),
            const SizedBox(height: 8),
            RadioGroup<String>(
              groupValue: _reason,
              onChanged: (v) => setState(() => _reason = v),
              child: Column(
                children: [
                  ...kReportReasons.map(
                    (r) => RadioListTile<String>(
                      dense: true,
                      title: Text(r, style: AppTextStyles.body),
                      value: r,
                    ),
                  ),
                ],
              ),
            ),
            TextField(
              controller: _details,
              maxLines: 2,
              decoration: const InputDecoration(hintText: 'Optional details'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        KxButton(
          label: 'Submit',
          onPressed: _reason == null ? null : _submit,
          loading: _loading,
          expanded: false,
        ),
      ],
    );
  }
}
