import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class KxLoadingOverlay extends StatelessWidget {
  const KxLoadingOverlay({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }
}
