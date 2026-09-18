
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/dependency_injection.dart';
import '../../../core/security/app_lock_controller.dart';
import '../../../core/security/biometric_gate.dart';
import '../../../core/theme/app_text_styles.dart';

class BiometricSettingsTile extends ConsumerStatefulWidget {
  const BiometricSettingsTile({super.key});

  @override
  ConsumerState<BiometricSettingsTile> createState() => _BiometricSettingsTileState();
}

class _BiometricSettingsTileState extends ConsumerState<BiometricSettingsTile> {
  bool? _enabled;
  bool _supported = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final gate = BiometricGate(ref.read(secureStorageProvider));
    final supported = await gate.canCheck();
    final enabled = await gate.isEnabled();
    if (mounted) {
      setState(() {
        _supported = supported;
        _enabled = enabled;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_supported) {
      return ListTile(
        title: const Text('Biometric lock'),
        subtitle: Text('Not available on this device', style: AppTextStyles.caption),
      );
    }
    return SwitchListTile(
      title: const Text('Biometric lock'),
      subtitle: Text(
        'Require Face ID / fingerprint when opening or returning to the app',
        style: AppTextStyles.caption,
      ),
      value: _enabled ?? false,
      onChanged: (v) async {
        final gate = BiometricGate(ref.read(secureStorageProvider));
        if (v) {
          // Confirm with a real Face ID / fingerprint prompt before turning
          // this on. requireUnlock() can't be used here — it checks whether
          // the lock is already enabled, which it isn't yet, so it would
          // return true instantly without ever prompting.
          final ok = await gate.authenticateNow(reason: 'Enable biometric lock');
          if (!ok) return;
        }
        await gate.setEnabled(v);
        // Only mark the app as freshly-locked when turning the setting off→
        // never immediately after the user just unlocked it above, or the
        // lock screen slams down over Settings before they can leave it.
        await ref.read(appLockProvider.notifier).setEnabled(v, locked: false);
        if (!mounted) return;
        setState(() => _enabled = v);
      },
    );
  }
}
