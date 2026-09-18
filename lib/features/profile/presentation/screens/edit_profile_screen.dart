import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/config/constants.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/kx_button.dart';
import '../../../../core/widgets/kx_text_field.dart';
import '../providers/profile_provider.dart';
import 'manage_games_screen.dart';
import 'privacy_settings_screen.dart';
import '../../../../core/errors/error_handler.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _gamerName = TextEditingController();
  final _username = TextEditingController();
  final _bio = TextEditingController();
  final _countryController = TextEditingController();
  String? _playerType;
  String? _country;
  bool _loading = false;
  String? _error;
  bool _initialized = false;

  @override
  void dispose() {
    _gamerName.dispose();
    _username.dispose();
    _bio.dispose();
    _countryController.dispose();
    super.dispose();
  }

  void _initFromProfile() {
    if (_initialized) return;
    final profile = ref.read(myProfileProvider).valueOrNull;
    if (profile == null) return;
    _gamerName.text = profile.gamerName ?? '';
    _username.text = profile.username;
    _bio.text = profile.bio ?? '';
    _playerType = profile.playerType;
    _country = profile.country;
    _countryController.text = profile.country ?? 'CM';
    _initialized = true;
  }

  Future<void> _pickBanner() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 85,
    );
    if (file == null) return;
    setState(() => _loading = true);
    final repo = ref.read(profileRepositoryProvider);
    final upload = await repo.uploadBanner(file.path);
    await upload.when(
      success: (url) async {
        await repo.updateProfile(bannerUrl: url);
        ref.invalidate(myProfileProvider);
      },
      failure: (e, _) {
        setState(() => _error = ErrorHandler.userMessage(e));
      },
    );
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      imageQuality: 85,
    );
    if (file == null) return;
    setState(() => _loading = true);
    final repo = ref.read(profileRepositoryProvider);
    final upload = await repo.uploadAvatar(file.path);
    await upload.when(
      success: (url) async {
        await repo.updateProfile(avatarUrl: url);
        ref.invalidate(myProfileProvider);
      },
      failure: (e, _) {
        setState(() => _error = ErrorHandler.userMessage(e));
      },
    );
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await ref.read(profileRepositoryProvider).updateProfile(
          gamerName: _gamerName.text.trim(),
          bio: _bio.text.trim(),
          playerType: _playerType,
          country: _country,
        );
    if (!mounted) return;
    setState(() => _loading = false);
    result.when(
      success: (_) {
        ref.invalidate(myProfileProvider);
        Navigator.of(context).pop(true);
      },
      failure: (e, _) => setState(() => _error = ErrorHandler.userMessage(e)),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(myProfileProvider);
    _initFromProfile();

    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: TextButton.icon(
              onPressed: _loading ? null : _pickAvatar,
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Change avatar'),
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _loading ? null : _pickBanner,
            icon: const Icon(Icons.image_outlined),
            label: const Text('Change banner'),
          ),
          KxTextField(controller: _gamerName, label: 'Gamer name'),
          const SizedBox(height: 12),
          KxTextField(controller: _username, label: 'Username (unique)'),
          Text(
            '3–24 chars, a-z, 0-9, underscore. Checked on server.',
            style: AppTextStyles.caption,
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _loading
                  ? null
                  : () async {
                      setState(() => _loading = true);
                      final r = await ref
                          .read(profileRepositoryProvider)
                          .changeUsername(_username.text.trim());
                      if (!mounted) return;
                      setState(() => _loading = false);
                      r.when(
                        success: (_) {
                          ref.invalidate(myProfileProvider);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Username updated')),
                          );
                        },
                        failure: (e, _) => setState(() => _error = ErrorHandler.userMessage(e)),
                      );
                    },
              child: const Text('Change username'),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.sports_esports_outlined),
            title: const Text('Manage games'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ManageGamesScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Privacy'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PrivacySettingsScreen()),
              );
            },
          ),
          const SizedBox(height: 12),
          KxTextField(
            controller: _bio,
            label: 'Bio',
            maxLines: 3,
            maxLength: AppConstants.maxBioLength,
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
          KxTextField(
            controller: _countryController,
            label: 'Country code',
            onChanged: (v) => _country = v,
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: AppTextStyles.caption.copyWith(color: Colors.redAccent)),
            ),
          const SizedBox(height: 24),
          KxButton(label: 'Save', onPressed: _save, loading: _loading),
        ],
      ),
    );
  }
}
