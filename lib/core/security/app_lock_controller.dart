import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/dependency_injection.dart';
import '../storage/secure_storage_service.dart';
import 'biometric_gate.dart';

/// App-level biometric lock. When enabled in settings, the UI is gated on
/// resume / cold start until [unlock] succeeds.
class AppLockController extends StateNotifier<AppLockState> {
  AppLockController(this._storage)
      : _gate = BiometricGate(_storage),
        super(const AppLockState());

  final SecureStorageService _storage;
  final BiometricGate _gate;

  Future<void> bootstrap() async {
    if (kIsWeb) {
      state = const AppLockState(enabled: false, locked: false);
      return;
    }
    final enabled = await _storage.isBiometricEnabled();
    state = AppLockState(enabled: enabled, locked: enabled);
  }

  Future<void> onAppPaused() async {
    if (!state.enabled) return;
    state = state.copyWith(locked: true);
  }

  Future<bool> unlock({String reason = 'Unlock KONEX'}) async {
    if (!state.enabled) {
      state = state.copyWith(locked: false);
      return true;
    }
    final ok = await _gate.requireUnlock(reason: reason);
    if (ok) {
      state = state.copyWith(locked: false);
    }
    return ok;
  }

  /// [locked] controls whether the lock overlay should appear immediately.
  /// Pass `false` right after the user has just confirmed with a live
  /// biometric prompt (e.g. when turning the setting on) — they're already
  /// unlocked and shouldn't be dropped straight onto the lock screen they
  /// have no way to dismiss. Defaults to mirroring [enabled] for the normal
  /// case of disabling the lock.
  Future<void> setEnabled(bool enabled, {bool? locked}) async {
    await _storage.setBiometricEnabled(enabled);
    state = AppLockState(enabled: enabled, locked: locked ?? enabled);
  }
}

class AppLockState {
  const AppLockState({this.enabled = false, this.locked = false});
  final bool enabled;
  final bool locked;

  AppLockState copyWith({bool? enabled, bool? locked}) => AppLockState(
        enabled: enabled ?? this.enabled,
        locked: locked ?? this.locked,
      );
}

final appLockProvider =
    StateNotifierProvider<AppLockController, AppLockState>((ref) {
  return AppLockController(ref.watch(secureStorageProvider));
});
