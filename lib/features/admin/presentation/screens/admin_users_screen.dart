import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/debounce.dart';
import '../providers/admin_provider.dart';

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  final _query = TextEditingController();
  final _debouncer = Debouncer(milliseconds: 400);
  List<Map<String, dynamic>> _users = [];
  bool _loading = false;

  @override
  void dispose() {
    _query.dispose();
    _debouncer.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    if (q.trim().length < 2) {
      setState(() => _users = []);
      return;
    }
    setState(() => _loading = true);
    final r = await ref.read(adminRepositoryProvider).searchUsers(q.trim());
    if (!mounted) return;
    setState(() {
      _users = r.valueOrNull ?? [];
      _loading = false;
    });
  }

  Future<void> _userActions(Map<String, dynamic> u) async {
    final id = u['id'] as String;
    final isVerified = u['is_verified'] == true;
    final myRoleResult = await ref.read(adminRepositoryProvider).myRole();
    final myRole = myRoleResult.valueOrNull ?? 'user';

    final tiles = <Widget>[];
    // Same gating as Users.jsx's actionsFor(): "make_moderator" covers
    // both the moderator promotion and the demotion-to-user option.
    if (canStaff(myRole, 'make_moderator')) {
      tiles.add(ListTile(
        title: const Text('Make moderator'),
        onTap: () => Navigator.pop(context, 'role:moderator'),
      ));
    }
    if (canStaff(myRole, 'make_admin')) {
      tiles.add(ListTile(
        title: const Text('Make admin'),
        onTap: () => Navigator.pop(context, 'role:admin'),
      ));
    }
    if (canStaff(myRole, 'make_moderator')) {
      tiles.add(ListTile(
        title: const Text('Set user'),
        onTap: () => Navigator.pop(context, 'role:user'),
      ));
    }
    if (canStaff(myRole, 'verify_users')) {
      tiles.add(ListTile(
        leading: Icon(isVerified ? Icons.verified : Icons.verified_outlined),
        title: Text(isVerified ? 'Remove verified badge' : 'Verify user'),
        onTap: () => Navigator.pop(context, isVerified ? 'unverify' : 'verify'),
      ));
    }
    if (canStaff(myRole, 'ban_users')) {
      tiles.add(ListTile(
        title: const Text('Ban'),
        onTap: () => Navigator.pop(context, 'ban'),
      ));
      tiles.add(ListTile(
        title: const Text('Restore'),
        onTap: () => Navigator.pop(context, 'restore'),
      ));
    }

    if (!mounted) return;
    if (tiles.isEmpty) return;

    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: tiles,
        ),
      ),
    );
    if (action == null) return;
    final repo = ref.read(adminRepositoryProvider);
    if (action.startsWith('role:')) {
      await repo.setUserRole(id, action.split(':')[1]);
    } else if (action == 'verify' || action == 'unverify') {
      await repo.setUserVerified(id, action == 'verify');
    } else if (action == 'ban' || action == 'restore') {
      final result = await repo.setUserBan(id, action == 'ban');
      String? banError;
      result.when(
        success: (_) {},
        failure: (error, _) => banError = error.toString(),
      );
      if (banError != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(banError!)),
        );
        return;
      }
    }
    await _search(_query.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _query,
          decoration: const InputDecoration(
            hintText: 'Search users...',
            border: InputBorder.none,
          ),
          onChanged: (v) => _debouncer.run(() => _search(v)),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _users.length,
              itemBuilder: (_, i) {
                final u = _users[i];
                final name = (u['gamer_name'] as String?)?.isNotEmpty == true
                    ? u['gamer_name']
                    : u['username'];
                final flags = [
                  if (u['is_banned'] == true) 'banned',
                  if (u['is_restricted'] == true) 'restricted',
                  u['app_role'] ?? 'user',
                ].join(' · ');
                return ListTile(
                  title: Row(
                    children: [
                      Flexible(child: Text('$name', overflow: TextOverflow.ellipsis)),
                      if (u['is_verified'] == true) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified, size: 16, color: Colors.lightBlueAccent),
                      ],
                    ],
                  ),
                  subtitle: Text('@${u['username']} · $flags', style: AppTextStyles.caption),
                  onTap: () => _userActions(u),
                );
              },
            ),
    );
  }
}
