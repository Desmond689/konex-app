import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/data_saver_service.dart';
import '../../../core/theme/app_text_styles.dart';

class DataSaverSettingsTile extends ConsumerWidget {
  const DataSaverSettingsTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dataSaverEnabledProvider);

    return async.when(
      loading: () => const ListTile(
        title: Text('Data Saver'),
        trailing: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (enabled) {
        return SwitchListTile(
          title: const Text('Data Saver'),
          subtitle: Text(
            'Lower image quality, less preloading, no autoplay video',
            style: AppTextStyles.caption,
          ),
          value: enabled,
          onChanged: (v) async {
            await ref.read(dataSaverServiceProvider).setEnabled(v);
            ref.invalidate(dataSaverEnabledProvider);
          },
        );
      },
    );
  }
}
