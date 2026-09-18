import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/config/constants.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/kx_button.dart';
import '../../../../core/widgets/kx_text_field.dart';
import '../../domain/entities/squad_entity.dart';
import '../providers/squad_provider.dart';
import '../../../../core/errors/error_handler.dart';

class EditSquadScreen extends ConsumerStatefulWidget {
  const EditSquadScreen({super.key, required this.squad});

  final SquadEntity squad;

  @override
  ConsumerState<EditSquadScreen> createState() => _EditSquadScreenState();
}

class _EditSquadScreenState extends ConsumerState<EditSquadScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _desc;
  late final TextEditingController _rules;
  String? _game;
  String? _category;
  late bool _isPublic;
  late bool _requireApproval;
  bool _loading = false;
  String? _error;
  String? _logoPath;
  String? _existingLogoUrl;
  String? _uploadingLogo;

  @override
  void initState() {
    super.initState();
    // Widget fields aren't available until after the constructor runs, so
    // these are set here rather than as field initializers.
    final s = widget.squad;
    _name = TextEditingController(text: s.name);
    _desc = TextEditingController(text: s.description ?? '');
    _rules = TextEditingController(text: s.rules ?? '');
    _game = s.primaryGame;
    _category = s.category;
    _isPublic = s.isPublic;
    _requireApproval = s.requireApproval;
    _existingLogoUrl = s.logoUrl;
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _rules.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      imageQuality: 85,
    );
    if (file == null) return;
    setState(() => _logoPath = file.path);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    String? logoUrl = _existingLogoUrl;
    if (_logoPath != null) {
      setState(() => _uploadingLogo = 'Uploading logo...');
      final uploadResult = await ref.read(squadRepositoryProvider).uploadLogo(_logoPath!);
      if (!mounted) return;
      final result = await uploadResult.when(
        success: (url) async => url,
        failure: (e, _) {
          setState(() => _error = 'Logo upload failed: $e');
          return null;
        },
      );
      if (result == null) {
        setState(() {
          _loading = false;
          _uploadingLogo = null;
        });
        return;
      }
      logoUrl = result;
    }

    final result = await ref.read(squadRepositoryProvider).updateSquad(
          squadId: widget.squad.id,
          name: _name.text.trim(),
          description: _desc.text.trim(),
          rules: _rules.text.trim(),
          primaryGame: _game ?? '',
          category: _category,
          isPublic: _isPublic,
          requireApproval: _requireApproval,
          logoUrl: logoUrl,
        );
    if (!mounted) return;
    setState(() => _loading = false);
    result.when(
      success: (_) => Navigator.of(context).pop(true),
      failure: (e, _) => setState(() => _error = ErrorHandler.userMessage(e)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit squad')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (_logoPath != null) ...[
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(50),
                    image: DecorationImage(
                      image: FileImage(File(_logoPath!)),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: _pickLogo,
                  child: const Text('Change logo'),
                ),
              ),
              const SizedBox(height: 12),
            ] else if (_existingLogoUrl != null && _existingLogoUrl!.isNotEmpty) ...[
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(50),
                    image: DecorationImage(
                      image: NetworkImage(_existingLogoUrl!),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: _pickLogo,
                  child: const Text('Change logo'),
                ),
              ),
              const SizedBox(height: 12),
            ] else ...[
              Center(
                child: OutlinedButton.icon(
                  onPressed: _pickLogo,
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('Upload squad logo'),
                ),
              ),
              const SizedBox(height: 12),
            ],
            KxTextField(
              controller: _name,
              label: 'Squad name',
              validator: (v) => Validators.required(v, 'Name'),
            ),
            const SizedBox(height: 12),
            KxTextField(controller: _desc, label: 'Description', maxLines: 3),
            const SizedBox(height: 12),
            KxTextField(controller: _rules, label: 'Rules (optional)', maxLines: 3),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _game,
              decoration: const InputDecoration(labelText: 'Primary game'),
              items: AppConstants.supportedGames
                  .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                  .toList(),
              onChanged: (v) => setState(() => _game = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Type'),
              items: const [
                DropdownMenuItem(value: 'competitive', child: Text('Competitive')),
                DropdownMenuItem(value: 'casual', child: Text('Casual')),
                DropdownMenuItem(value: 'friends', child: Text('Friends')),
                DropdownMenuItem(value: 'community', child: Text('Community')),
                DropdownMenuItem(value: 'esports', child: Text('Esports')),
              ],
              onChanged: (v) => setState(() => _category = v),
            ),
            SwitchListTile(
              title: const Text('Public squad'),
              subtitle: Text('Visible in Discover', style: AppTextStyles.caption),
              value: _isPublic,
              onChanged: (v) => setState(() => _isPublic = v),
            ),
            if (_isPublic)
              SwitchListTile(
                title: const Text('Require approval'),
                subtitle: Text(
                  'Off = instant join. On = owner/mod must approve.',
                  style: AppTextStyles.caption,
                ),
                value: _requireApproval,
                onChanged: (v) => setState(() => _requireApproval = v),
              ),
            if (!_isPublic)
              Text(
                'Private squads are invite/request only.',
                style: AppTextStyles.caption,
              ),
            if (_error != null)
              Text(_error!, style: AppTextStyles.caption.copyWith(color: Colors.redAccent)),
            if (_uploadingLogo != null)
              Text(_uploadingLogo!, style: AppTextStyles.caption.copyWith(color: Colors.blueAccent)),
            const SizedBox(height: 16),
            KxButton(label: 'Save changes', onPressed: _submit, loading: _loading),
          ],
        ),
      ),
    );
  }
}
