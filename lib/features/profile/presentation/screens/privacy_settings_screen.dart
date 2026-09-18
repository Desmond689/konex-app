import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/kx_button.dart';
import '../providers/profile_provider.dart';
import '../../../../core/errors/error_handler.dart';

class PrivacySettingsScreen extends ConsumerStatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  ConsumerState<PrivacySettingsScreen> createState() =>
      _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends ConsumerState<PrivacySettingsScreen> {
  bool _private = false;
  String _message = 'everyone';
  String _follow = 'everyone';
  String _games = 'everyone';
  String _squad = 'everyone';
  bool _loading = false;
  bool _inited = false;
  String? _error;

  void _init() {
    if (_inited) return;
    final p = ref.read(myProfileProvider).valueOrNull;
    if (p == null) return;
    _private = p.isPrivate;
    _message = p.whoCanMessage;
    _follow = p.whoCanFollow;
    _games = p.gamesVisibility;
    _squad = p.squadVisibility;
    _inited = true;
  }

  Future<void> _save() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final r = await ref.read(profileRepositoryProvider).savePrivacy(
          isPrivate: _private,
          whoCanMessage: _message,
          whoCanFollow: _follow,
          gamesVisibility: _games,
          squadVisibility: _squad,
        );
    if (!mounted) return;
    setState(() => _loading = false);
    r.when(
      success: (_) {
        ref.invalidate(myProfileProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Privacy saved')),
        );
        Navigator.pop(context);
      },
      failure: (e, _) => setState(() => _error = ErrorHandler.userMessage(e)),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(myProfileProvider);
    _init();

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('Private profile'),
            subtitle: Text(
              'Only limited info for people who don’t follow you',
              style: AppTextStyles.caption,
            ),
            value: _private,
            onChanged: (v) => setState(() => _private = v),
          ),
          const Divider(),
          Text('Who can message me', style: AppTextStyles.title),
          _radios(
            group: _message,
            options: const {
              'everyone': 'Everyone',
              'following': 'People I follow',
              'nobody': 'Nobody',
            },
            onChanged: (v) => setState(() => _message = v),
          ),
          const Divider(),
          Text('Who can follow me', style: AppTextStyles.title),
          _radios(
            group: _follow,
            options: const {
              'everyone': 'Everyone',
              'nobody': 'Nobody',
            },
            onChanged: (v) => setState(() => _follow = v),
          ),
          const Divider(),
          Text('Who can see my games', style: AppTextStyles.title),
          _radios(
            group: _games,
            options: const {
              'everyone': 'Everyone',
              'followers': 'Followers',
              'only_me': 'Only me',
            },
            onChanged: (v) => setState(() => _games = v),
          ),
          const Divider(),
          Text('Who can see my squad', style: AppTextStyles.title),
          _radios(
            group: _squad,
            options: const {
              'everyone': 'Everyone',
              'followers': 'Followers',
              'only_me': 'Only me',
            },
            onChanged: (v) => setState(() => _squad = v),
          ),
          if (_error != null)
            Text(_error!, style: AppTextStyles.caption.copyWith(color: Colors.redAccent)),
          const SizedBox(height: 16),
          KxButton(label: 'Save', onPressed: _save, loading: _loading),
        ],
      ),
    );
  }

  Widget _radios({
    required String group,
    required Map<String, String> options,
    required void Function(String) onChanged,
  }) {
    return RadioGroup<String>(
      groupValue: group,
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
      child: Column(
        children: options.entries
            .map(
              (e) => RadioListTile<String>(
                title: Text(e.value),
                value: e.key,
              ),
            )
            .toList(),
      ),
    );
  }
}
