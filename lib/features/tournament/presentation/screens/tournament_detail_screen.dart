import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/kx_button.dart';
import '../../../../core/widgets/kx_error_view.dart';
import '../../domain/tournament_entity.dart';
import '../providers/tournament_provider.dart';
import '../../../../core/errors/error_handler.dart';

final tournamentDetailProvider =
    FutureProvider.family<TournamentEntity?, String>((ref, id) async {
  final r = await ref.watch(tournamentRepositoryProvider).getById(id);
  return r.valueOrNull;
});

class TournamentDetailScreen extends ConsumerStatefulWidget {
  const TournamentDetailScreen({super.key, required this.tournamentId});
  final String tournamentId;

  @override
  ConsumerState<TournamentDetailScreen> createState() =>
      _TournamentDetailScreenState();
}

class _TournamentDetailScreenState
    extends ConsumerState<TournamentDetailScreen> {
  bool _joining = false;
  String? _actionError;

  Future<void> _enter() async {
    setState(() {
      _joining = true;
      _actionError = null;
    });
    final r = await ref
        .read(tournamentRepositoryProvider)
        .enter(widget.tournamentId);
    if (!mounted) return;
    setState(() => _joining = false);
    r.when(
      success: (_) {
        ref.invalidate(tournamentDetailProvider(widget.tournamentId));
        ref.invalidate(tournamentsListProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You joined this tournament')),
        );
      },
      failure: (e, _) => setState(() => _actionError = e.toString()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(tournamentDetailProvider(widget.tournamentId));

    return async.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: KxErrorView(
          message: ErrorHandler.userMessage(e),
          onRetry: () =>
              ref.invalidate(tournamentDetailProvider(widget.tournamentId)),
        ),
      ),
      data: (t) {
        if (t == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Tournament not found')),
          );
        }
        final dateStr = t.startsAt != null
            ? DateFormat.yMMMd().add_jm().format(t.startsAt!.toLocal())
            : 'TBD';
        final spotsLeft =
            (t.maxParticipants - t.participantCount).clamp(0, 1 << 30);

        return Scaffold(
          appBar: AppBar(title: Text(t.title)),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(t.gameName, style: AppTextStyles.title),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text(t.status.toUpperCase())),
                  Chip(label: Text(t.bracketType.replaceAll('_', ' '))),
                  if (t.isEntered)
                    const Chip(
                      label: Text('Joined'),
                      backgroundColor: AppColors.primary,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (t.description != null && t.description!.isNotEmpty) ...[
                Text(t.description!, style: AppTextStyles.body),
                const SizedBox(height: 16),
              ],
              _InfoRow(label: 'Starts', value: dateStr),
              _InfoRow(
                label: 'Players',
                value: '${t.participantCount} / ${t.maxParticipants}',
              ),
              _InfoRow(label: 'Spots left', value: '$spotsLeft'),
              if (_actionError != null) ...[
                const SizedBox(height: 12),
                Text(
                  _actionError!,
                  style: AppTextStyles.caption.copyWith(color: Colors.redAccent),
                ),
              ],
              const SizedBox(height: 24),
              if (t.isEntered)
                Text(
                  'You are entered. Check back when the bracket goes live.',
                  style: AppTextStyles.body,
                )
              else if (t.isOpen && spotsLeft > 0)
                KxButton(
                  label: 'Join tournament',
                  loading: _joining,
                  onPressed: _enter,
                )
              else if (!t.isOpen)
                Text(
                  'This tournament is not open for entry (${t.status}).',
                  style: AppTextStyles.body,
                )
              else
                Text('Tournament is full.', style: AppTextStyles.body),
            ],
          ),
        );
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: AppTextStyles.caption),
          ),
          Expanded(child: Text(value, style: AppTextStyles.body)),
        ],
      ),
    );
  }
}
