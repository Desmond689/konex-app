import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/kx_button.dart';
import '../../../../core/widgets/kx_text_field.dart';
import '../../../communities/domain/community_entity.dart';
import '../../../communities/presentation/providers/community_provider.dart';
import '../../../../core/errors/error_handler.dart';

/// Staff: edit an existing game/community — name, description, rules,
/// category, and logo. The same screen also lets staff attach a logo to
/// a game that was created before logo uploads existed.
class AdminEditGameScreen extends ConsumerStatefulWidget {
  const AdminEditGameScreen({super.key, required this.community});

  final CommunityEntity community;

  @override
  ConsumerState<AdminEditGameScreen> createState() => _AdminEditGameScreenState();
}

class _AdminEditGameScreenState extends ConsumerState<AdminEditGameScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _desc;
  late final TextEditingController _rules;
  String? _category;
  bool _isPrivate = false;
  bool _requireApproval = false;
  bool _loading = false;
  String? _error;
  String? _logoPath;
  String? _existingLogoUrl;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    final c = widget.community;
    _name = TextEditingController(text: c.name);
    _desc = TextEditingController(text: c.description ?? '');
    _rules = TextEditingController(text: c.rules ?? '');
    _category = c.category;
    _isPrivate = c.isPrivate;
    _requireApproval = c.requireApproval;
    _existingLogoUrl = c.avatarUrl;
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

    String? avatarUrl;
    if (_logoPath != null) {
      setState(() => _statusMessage = 'Uploading logo...');
      final uploadResult =
          await ref.read(communityRepositoryProvider).uploadLogo(_logoPath!);
      if (!mounted) return;
      final url = uploadResult.when(
        success: (u) => u,
        failure: (e, _) {
          setState(() => _error = 'Logo upload failed: $e');
          return null;
        },
      );
      if (url == null) {
        setState(() {
          _loading = false;
          _statusMessage = null;
        });
        return;
      }
      avatarUrl = url;
    }

    setState(() => _statusMessage = 'Saving...');
    final result = await ref.read(communityRepositoryProvider).adminUpdateGame(
          communityId: widget.community.id,
          name: _name.text.trim(),
          description: _desc.text.trim(),
          rules: _rules.text.trim(),
          category: _category,
          avatarUrl: avatarUrl,
          isPrivate: _isPrivate,
          requireApproval: _requireApproval,
        );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _statusMessage = null;
    });
    result.when(
      success: (_) {
        ref.invalidate(officialGamesProvider);
        ref.invalidate(communitiesDiscoverProvider(null));
        ref.invalidate(adminAllGamesProvider(null));
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Game community updated')),
        );
      },
      failure: (e, _) => setState(() => _error = ErrorHandler.userMessage(e)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Edit ${widget.community.name}')),
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
                    borderRadius: BorderRadius.circular(20),
                    image: DecorationImage(
                      image: FileImage(File(_logoPath!)),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(onPressed: _pickLogo, child: const Text('Change logo')),
              ),
              const SizedBox(height: 12),
            ] else if (_existingLogoUrl != null && _existingLogoUrl!.isNotEmpty) ...[
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    image: DecorationImage(
                      image: NetworkImage(_existingLogoUrl!),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(onPressed: _pickLogo, child: const Text('Change logo')),
              ),
              const SizedBox(height: 12),
            ] else ...[
              Center(
                child: OutlinedButton.icon(
                  onPressed: _pickLogo,
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('Upload game logo'),
                ),
              ),
              const SizedBox(height: 12),
            ],
            KxTextField(
              controller: _name,
              label: 'Game name',
              validator: (v) => Validators.required(v, 'Name'),
            ),
            const SizedBox(height: 12),
            KxTextField(controller: _desc, label: 'Description', maxLines: 3),
            const SizedBox(height: 12),
            KxTextField(controller: _rules, label: 'Community rules', maxLines: 4),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: const [
                DropdownMenuItem(value: 'fps', child: Text('FPS')),
                DropdownMenuItem(value: 'battle_royale', child: Text('Battle Royale')),
                DropdownMenuItem(value: 'sports', child: Text('Sports')),
                DropdownMenuItem(value: 'moba', child: Text('MOBA')),
                DropdownMenuItem(value: 'sandbox', child: Text('Sandbox')),
                DropdownMenuItem(value: 'other', child: Text('Other')),
              ],
              onChanged: (v) => setState(() => _category = v),
            ),
            SwitchListTile(
              title: const Text('Private community'),
              subtitle: Text(
                'Off = listed in Discover. On = invite/request only.',
                style: AppTextStyles.caption,
              ),
              value: _isPrivate,
              onChanged: (v) => setState(() => _isPrivate = v),
            ),
            SwitchListTile(
              title: const Text('Require approval to join'),
              value: _requireApproval,
              onChanged: (v) => setState(() => _requireApproval = v),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: AppTextStyles.caption.copyWith(color: Colors.redAccent)),
            ],
            if (_statusMessage != null) ...[
              const SizedBox(height: 8),
              Text(_statusMessage!, style: AppTextStyles.caption.copyWith(color: Colors.blueAccent)),
            ],
            const SizedBox(height: 20),
            KxButton(label: 'Save changes', onPressed: _submit, loading: _loading),
          ],
        ),
      ),
    );
  }
}
