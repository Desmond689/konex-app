import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/call_entity.dart';
import '../providers/call_controller.dart';

class OutgoingCallScreen extends ConsumerWidget {
  const OutgoingCallScreen({super.key, required this.call});
  final CallEntity call;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(callControllerProvider);
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              const Spacer(),
              CircleAvatar(
                radius: 56,
                backgroundColor: AppColors.surfaceElevated,
                backgroundImage: call.peerAvatar != null
                    ? NetworkImage(call.peerAvatar!)
                    : null,
                child: call.peerAvatar == null
                    ? Text(
                        (call.peerName ?? '?').isNotEmpty
                            ? call.peerName![0].toUpperCase()
                            : '?',
                        style: const TextStyle(fontSize: 36),
                      )
                    : null,
              ),
              const SizedBox(height: 20),
              Text(call.peerName ?? 'Calling…', style: AppTextStyles.title),
              const SizedBox(height: 8),
              Text('Calling…', style: AppTextStyles.caption),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _RoundBtn(
                    icon: state.muted ? Icons.mic_off : Icons.mic,
                    label: 'Mute',
                    onTap: () =>
                        ref.read(callControllerProvider.notifier).toggleMute(),
                  ),
                  _RoundBtn(
                    icon: Icons.call_end,
                    label: 'Cancel',
                    color: Colors.redAccent,
                    onTap: () => ref
                        .read(callControllerProvider.notifier)
                        .cancelOutgoing(),
                  ),
                  _RoundBtn(
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

class _RoundBtn extends StatelessWidget {
  const _RoundBtn({
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
