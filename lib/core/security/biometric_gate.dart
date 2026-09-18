import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import '../storage/secure_storage_service.dart';

/// Batch 11: Optional biometric lock before sensitive actions (payments, settings).
class BiometricGate {
  BiometricGate(this._secure, {LocalAuthentication? auth})
      : _auth = auth ?? LocalAuthentication();

  final SecureStorageService _secure;
  final LocalAuthentication _auth;

  Future<bool> isEnabled() => _secure.isBiometricEnabled();

  Future<void> setEnabled(bool value) => _secure.setBiometricEnabled(value);

  Future<bool> canCheck() async {
    try {
      return await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
    } on PlatformException {
      return false;
    }
  }

  /// Returns true if unlocked or biometric not required.
  Future<bool> requireUnlock({String reason = 'Unlock KONEX'}) async {
    if (!await isEnabled()) return true;
    return _authenticate(reason);
  }

  /// Prompts biometric auth right now, regardless of whether the lock is
  /// currently enabled in storage. Use this when *turning on* the setting,
  /// since [requireUnlock] would short-circuit to true (nothing is enabled
  /// yet at that point) and skip the prompt entirely.
  Future<bool> authenticateNow({String reason = 'Confirm to enable'}) {
    return _authenticate(reason);
  }

  Future<bool> _authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
    } on PlatformException {
      return false;
    }
  }
}
