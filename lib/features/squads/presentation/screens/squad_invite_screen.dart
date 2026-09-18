import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/dependency_injection.dart';
import '../../../../core/deep_links/deep_link_models.dart';
import '../../../../core/deep_links/share_service.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/kx_button.dart';
import '../../../../core/errors/error_handler.dart';

class SquadInviteScreen extends ConsumerStatefulWidget {
  const SquadInviteScreen({super.key, required this.squadId, this.squadName});
  final String squadId;
  final String? squadName;

  @override
  ConsumerState<SquadInviteScreen> createState() => _SquadInviteScreenState();
}

class _SquadInviteScreenState extends ConsumerState<SquadInviteScreen> {
  String? _token;
  bool _loading = false;
  String? _error;

  Future<void> _create() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final client = ref.read(supabaseClientProvider);
      final tok = await client.rpc(
        'create_squad_invite',
        params: {
          'p_squad_id': widget.squadId,
          'p_expires_hours': 168,
          'p_max_uses': null,
        },
      );
      setState(() {
        _token = tok as String;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = ErrorHandler.userMessage(e);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = _token != null ? KonexLinks.squadInvite(_token!) : null;
    return Scaffold(
      appBar: AppBar(title: const Text('Invite to squad')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.squadName ?? 'Squad', style: AppTextStyles.title),
            const SizedBox(height: 8),
            Text(
              'Creates a revocable invite token. Never grants owner/mod rights.',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: 20),
            KxButton(
              label: _token == null ? 'Generate invite link' : 'Generate new link',
              loading: _loading,
              onPressed: _create,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: AppTextStyles.caption.copyWith(color: Colors.redAccent)),
            ],
            if (url != null) ...[
              const SizedBox(height: 24),
              SelectableText(url, style: AppTextStyles.body),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: url));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Invite link copied')),
                          );
                        }
                      },
                      child: const Text('Copy invite'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => ShareService.showShareSheet(
                        context,
                        url: url,
                        title: 'Join my squad on KONEX',
                      ),
                      child: const Text('Share invite'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class RedeemSquadInviteScreen extends ConsumerStatefulWidget {
  const RedeemSquadInviteScreen({super.key, required this.token});
  final String token;

  @override
  ConsumerState<RedeemSquadInviteScreen> createState() =>
      _RedeemSquadInviteScreenState();
}

class _RedeemSquadInviteScreenState extends ConsumerState<RedeemSquadInviteScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _redeem());
  }

  Future<void> _redeem() async {
    try {
      final client = ref.read(supabaseClientProvider);
      final sid = await client.rpc(
        'redeem_squad_invite',
        params: {'p_token': widget.token},
      );
      if (!mounted) return;
      context.go('/squad/$sid');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = ErrorHandler.userMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Squad invite')),
      body: Center(
        child: _error != null
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => context.go('/squads'),
                      child: const Text('Back to squads'),
                    ),
                  ],
                ),
              )
            : const CircularProgressIndicator(),
      ),
    );
  }
}
