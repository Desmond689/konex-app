import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/constants.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/kx_button.dart';
import '../../../../core/widgets/kx_text_field.dart';
import '../providers/lfg_provider.dart';
import '../../../../core/errors/error_handler.dart';

class CreateLfgScreen extends ConsumerStatefulWidget {
  const CreateLfgScreen({super.key});

  @override
  ConsumerState<CreateLfgScreen> createState() => _CreateLfgScreenState();
}

class _CreateLfgScreenState extends ConsumerState<CreateLfgScreen> {
  final _formKey = GlobalKey<FormState>();
  final _body = TextEditingController();
  final _mode = TextEditingController();
  final _rank = TextEditingController();
  String? _game;
  String? _platform;
  int _playersNeeded = 1;
  bool _mic = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _body.dispose();
    _mode.dispose();
    _rank.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_game == null) {
      setState(() => _error = 'Select a game');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final r = await ref.read(lfgRepositoryProvider).createLfg(
          body: _body.text.trim(),
          gameName: _game!,
          mode: _mode.text.trim().isEmpty ? null : _mode.text.trim(),
          rankRequirement: _rank.text.trim().isEmpty ? null : _rank.text.trim(),
          platform: _platform,
          micRequired: _mic,
          playersNeeded: _playersNeeded,
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
      appBar: AppBar(title: const Text('New LFG')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            DropdownButtonFormField<String>(
              initialValue: _game,
              decoration: const InputDecoration(labelText: 'Game'),
              items: AppConstants.supportedGames
                  .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                  .toList(),
              onChanged: (v) => setState(() => _game = v),
            ),
            const SizedBox(height: 12),
            KxTextField(
              controller: _body,
              label: 'Details',
              maxLines: 3,
              validator: (v) => Validators.required(v, 'Details'),
            ),
            const SizedBox(height: 12),
            KxTextField(controller: _mode, label: 'Mode (e.g. Ranked)'),
            const SizedBox(height: 12),
            KxTextField(controller: _rank, label: 'Rank requirement'),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _platform,
              decoration: const InputDecoration(labelText: 'Platform'),
              items: AppConstants.supportedPlatforms
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) => setState(() => _platform = v),
            ),
            const SizedBox(height: 12),
            Text('Players needed: $_playersNeeded', style: AppTextStyles.body),
            Slider(
              value: _playersNeeded.toDouble(),
              min: 1,
              max: 10,
              divisions: 9,
              label: '$_playersNeeded',
              onChanged: (v) => setState(() => _playersNeeded = v.round()),
            ),
            SwitchListTile(
              title: const Text('Mic required'),
              value: _mic,
              onChanged: (v) => setState(() => _mic = v),
            ),
            if (_error != null)
              Text(_error!, style: AppTextStyles.caption.copyWith(color: Colors.redAccent)),
            const SizedBox(height: 16),
            KxButton(label: 'Post LFG', onPressed: _submit, loading: _loading),
          ],
        ),
      ),
    );
  }
}
