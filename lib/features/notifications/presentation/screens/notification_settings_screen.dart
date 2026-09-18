import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/notification_entity.dart';
import '../providers/notification_provider.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  NotificationPreferences? _prefs;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await ref.read(notificationRepositoryProvider).getPreferences();
    if (!mounted) return;
    setState(() {
      _prefs = r.valueOrNull ?? const NotificationPreferences();
      _loading = false;
    });
  }

  Future<void> _save(NotificationPreferences p) async {
    setState(() => _prefs = p);
    await ref.read(notificationRepositoryProvider).savePreferences(p);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _prefs == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final p = _prefs!;
    return Scaffold(
      appBar: AppBar(title: const Text('Notification settings')),
      body: ListView(
        children: [
          const ListTile(
            title: Text('Push categories'),
            subtitle: Text('Security alerts cannot be turned off'),
          ),
          _sw('Likes', p.likes, (v) => _save(p.copyWith(likes: v))),
          _sw('Comments', p.comments, (v) => _save(p.copyWith(comments: v))),
          _sw('Replies', p.replies, (v) => _save(p.copyWith(replies: v))),
          _sw('Followers', p.follows, (v) => _save(p.copyWith(follows: v))),
          _sw('Mentions', p.mentions, (v) => _save(p.copyWith(mentions: v))),
          _sw('Reposts', p.reposts, (v) => _save(p.copyWith(reposts: v))),
          _sw('Squad activity', p.squads, (v) => _save(p.copyWith(squads: v))),
          _sw('Community announcements', p.communities,
              (v) => _save(p.copyWith(communities: v))),
          _sw('LFG activity', p.lfg, (v) => _save(p.copyWith(lfg: v))),
          _sw('Messages', p.messages, (v) => _save(p.copyWith(messages: v))),
          SwitchListTile(
            title: const Text('Security alerts'),
            subtitle: const Text('Always on'),
            value: true,
            onChanged: null,
          ),
          const Divider(),
          const ListTile(title: Text('Quiet mode')),
          if (p.quietUntil != null && p.quietUntil!.isAfter(DateTime.now()))
            ListTile(
              title: Text('Muted until ${p.quietUntil!.toLocal()}'),
              trailing: TextButton(
                onPressed: () async {
                  await ref.read(notificationRepositoryProvider).clearQuietMode();
                  await _load();
                },
                child: const Text('Turn off'),
              ),
            )
          else
            ...[
              ListTile(
                title: const Text('Mute 1 hour'),
                onTap: () async {
                  await ref
                      .read(notificationRepositoryProvider)
                      .setQuietMode(const Duration(hours: 1));
                  await _load();
                },
              ),
              ListTile(
                title: const Text('Mute 8 hours'),
                onTap: () async {
                  await ref
                      .read(notificationRepositoryProvider)
                      .setQuietMode(const Duration(hours: 8));
                  await _load();
                },
              ),
              ListTile(
                title: const Text('Mute until tomorrow'),
                onTap: () async {
                  final now = DateTime.now();
                  final until = DateTime(now.year, now.month, now.day + 1, 8);
                  await ref
                      .read(notificationRepositoryProvider)
                      .setQuietMode(until.difference(now));
                  await _load();
                },
              ),
            ],
          const Divider(),
          const ListTile(
            title: Text('Who can message me'),
            subtitle: Text('Message requests apply when restricted'),
          ),
          RadioGroup<String>(
            groupValue: p.whoCanMessage,
            onChanged: (v) => _save(p.copyWith(whoCanMessage: v)),
            child: Column(
              children: [
                RadioListTile<String>(
                  title: const Text('Everyone'),
                  value: 'everyone',
                ),
                RadioListTile<String>(
                  title: const Text('People I follow'),
                  value: 'following',
                ),
                RadioListTile<String>(
                  title: const Text('Nobody'),
                  value: 'nobody',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sw(String title, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      title: Text(title),
      value: value,
      onChanged: onChanged,
    );
  }
}
