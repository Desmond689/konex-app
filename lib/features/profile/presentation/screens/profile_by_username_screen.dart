import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/dependency_injection.dart';
import 'profile_screen.dart';

class ProfileByUsernameScreen extends ConsumerStatefulWidget {
  const ProfileByUsernameScreen({super.key, required this.username});
  final String username;

  @override
  ConsumerState<ProfileByUsernameScreen> createState() =>
      _ProfileByUsernameScreenState();
}

class _ProfileByUsernameScreenState
    extends ConsumerState<ProfileByUsernameScreen> {
  String? _id;
  String? _error;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    final client = ref.read(supabaseClientProvider);
    final row = await client
        .from('profiles')
        .select('id')
        .eq('username', widget.username.toLowerCase())
        .maybeSingle();
    if (!mounted) return;
    if (row == null) {
      setState(() => _error = 'User not found');
      return;
    }
    setState(() => _id = row['id'] as String);
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(_error!)),
      );
    }
    if (_id == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return ProfileScreen(userId: _id);
  }
}
