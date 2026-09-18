import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/chat/domain/entities/chat_entity.dart';
import '../../features/chat/presentation/providers/chat_provider.dart';
import '../theme/app_text_styles.dart';
import '../widgets/kx_button.dart';

/// Pick conversations and send a shared link as a message body.
Future<void> showSendOnKonexSheet(
  BuildContext context,
  WidgetRef ref, {
  required String url,
  String? previewText,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => UncontrolledProviderScope(
      container: ProviderScope.containerOf(context),
      child: _SendSheet(url: url, previewText: previewText),
    ),
  );
}

class _SendSheet extends ConsumerStatefulWidget {
  const _SendSheet({required this.url, this.previewText});
  final String url;
  final String? previewText;

  @override
  ConsumerState<_SendSheet> createState() => _SendSheetState();
}

class _SendSheetState extends ConsumerState<_SendSheet> {
  final _selected = <String>{};
  bool _sending = false;

  @override
  Widget build(BuildContext context) {
    final inbox = ref.watch(inboxProvider);

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.55,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Text('Send on KONEX', style: AppTextStyles.title),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                widget.previewText ?? widget.url,
                style: AppTextStyles.caption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
            const Divider(),
            Expanded(
              child: inbox.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('$e')),
                data: (List<ConversationEntity> list) {
                  if (list.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No conversations yet. Open someone’s profile and tap Message first.',
                          style: AppTextStyles.caption,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final c = list[i];
                      final selected = _selected.contains(c.id);
                      return CheckboxListTile(
                        value: selected,
                        secondary: CircleAvatar(
                          backgroundImage: c.avatarUrl != null
                              ? NetworkImage(c.avatarUrl!)
                              : null,
                          child: c.avatarUrl == null
                              ? Text((c.title ?? '?').isNotEmpty
                                  ? (c.title!)[0].toUpperCase()
                                  : '?')
                              : null,
                        ),
                        title: Text(c.title ?? (c.type == 'squad' ? 'Squad chat' : 'Chat')),
                        subtitle: c.lastMessage != null
                            ? Text(c.lastMessage!, maxLines: 1, overflow: TextOverflow.ellipsis)
                            : null,
                        onChanged: (v) {
                          setState(() {
                            if (v == true) {
                              _selected.add(c.id);
                            } else {
                              _selected.remove(c.id);
                            }
                          });
                        },
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: KxButton(
                label: _selected.isEmpty ? 'Select chats' : 'Send (${_selected.length})',
                loading: _sending,
                onPressed: _selected.isEmpty
                    ? null
                    : () async {
                        setState(() => _sending = true);
                        final repo = ref.read(chatRepositoryProvider);
                        final body =
                            '${widget.previewText ?? 'Shared on KONEX'}\n${widget.url}';
                        for (final id in _selected) {
                          await repo.sendMessage(id, body);
                        }
                        if (!context.mounted) return;
                        setState(() => _sending = false);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Sent on KONEX')),
                        );
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
