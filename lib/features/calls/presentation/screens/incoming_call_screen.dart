import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/call_entity.dart';
import '../providers/call_controller.dart';

class IncomingCallScreen extends ConsumerWidget {
  const IncomingCallScreen({super.key, required this.call});
  final CallEntity call;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = call.peerName ?? call.squadName ?? 'Incoming call';
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
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(fontSize: 36),
                      )
                    : null,
              ),
              const SizedBox(height: 20),
              Text(name, style: AppTextStyles.title),
              const SizedBox(height: 8),
              Text(
                call.callType == 'squad'
                    ? 'Squad voice call'
                    : 'Incoming voice call',
                style: AppTextStyles.caption,
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _Action(
                    color: Colors.redAccent,
                    icon: Icons.call_end,
                    label: 'Decline',
                    onTap: () => ref
                        .read(callControllerProvider.notifier)
                        .declineIncoming(),
                  ),
                  _Action(
                    color: Colors.green,
                    icon: Icons.call,
                    label: 'Accept',
                    onTap: () => ref
                        .read(callControllerProvider.notifier)
                        .acceptIncoming(),
                  ),
                ],
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.color,
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: color,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Icon(icon, color: Colors.white, size: 32),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: AppTextStyles.caption),
      ],
    );
  }
}
