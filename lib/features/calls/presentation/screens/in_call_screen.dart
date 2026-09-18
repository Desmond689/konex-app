import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/call_entity.dart';
import '../providers/call_controller.dart';

class InCallScreen extends ConsumerStatefulWidget {
  const InCallScreen({super.key, required this.call});
  final CallEntity call;

  @override
  ConsumerState<InCallScreen> createState() => _InCallScreenState();
}

class _InCallScreenState extends ConsumerState<InCallScreen> {
  Timer? _timer;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _clock {
    final m = _elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = _elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(callControllerProvider);
    final call = widget.call;
    final title = call.callType == 'squad'
        ? (call.squadName ?? 'Squad call')
        : (call.peerName ?? 'In call');

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 24),
              Text(title, style: AppTextStyles.title),
              Text(_clock, style: AppTextStyles.caption),
              const Spacer(),
              if (call.callType == 'dm')
                CircleAvatar(
                  radius: 64,
                  backgroundColor: AppColors.surfaceElevated,
                  backgroundImage: call.peerAvatar != null
                      ? NetworkImage(call.peerAvatar!)
                      : null,
                  child: call.peerAvatar == null
                      ? Text(
                          (call.peerName ?? '?')[0].toUpperCase(),
                          style: const TextStyle(fontSize: 40),
                        )
                      : null,
                )
              else
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Voice channel · max ${call.maxParticipants}',
                    style: AppTextStyles.caption,
                  ),
                ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _Btn(
                    icon: state.muted ? Icons.mic_off : Icons.mic,
                    label: 'Mute',
                    onTap: () =>
                        ref.read(callControllerProvider.notifier).toggleMute(),
                  ),
                  _Btn(
                    icon: Icons.call_end,
                    label: call.callType == 'squad' ? 'Leave' : 'End',
                    color: Colors.redAccent,
                    onTap: () =>
                        ref.read(callControllerProvider.notifier).hangUp(),
                  ),
                  _Btn(
                    icon: state.speaker ? Icons.volume_up : Icons.volume_off,
                    label: 'Speaker',
                    onTap: () => ref
                        .read(callControllerProvider.notifier)
                        .toggleSpeaker(),
                  ),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  const _Btn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: color ?? AppColors.surfaceElevated,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: AppTextStyles.caption),
      ],
    );
  }
}
