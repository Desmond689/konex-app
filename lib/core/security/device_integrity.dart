import 'dart:io';

import 'package:flutter/foundation.dart';

/// Best-effort integrity signals. Not a substitute for a maintained native package
/// (safe_device / freeRASP) before store release.
class DeviceIntegrity {
  static Future<IntegrityReport> check() async {
    if (kIsWeb) {
      return const IntegrityReport(compromised: false, reasons: []);
    }
    final reasons = <String>[];
    try {
      if (Platform.isAndroid) {
        const suPaths = [
          '/system/bin/su',
          '/system/xbin/su',
          '/sbin/su',
          '/system/app/Superuser.apk',
          '/system/app/SuperSU.apk',
          '/data/local/xbin/su',
          '/data/local/bin/su',
        ];
        for (final path in suPaths) {
          if (File(path).existsSync()) {
            reasons.add('su_binary:$path');
            break;
          }
        }
        // Emulator heuristics
        final model = Platform.environment['ANDROID_MODEL'] ??
            Platform.environment['MODEL'] ??
            '';
        final finger = Platform.environment['FINGERPRINT'] ?? '';
        if (finger.toLowerCase().contains('generic') ||
            model.toLowerCase().contains('sdk_gphone') ||
            model.toLowerCase().contains('emulator')) {
          reasons.add('emulator_heuristic');
        }
      }
      if (Platform.isIOS) {
        // Common jailbreak artifacts (presence is only a weak signal)
        const jb = [
          '/Applications/Cydia.app',
          '/Library/MobileSubstrate/MobileSubstrate.dylib',
          '/bin/bash',
          '/usr/sbin/sshd',
          '/etc/apt',
        ];
        for (final path in jb) {
          if (File(path).existsSync()) {
            reasons.add('jailbreak_artifact:$path');
            break;
          }
        }
      }
    } catch (_) {}
    return IntegrityReport(
      compromised: reasons.isNotEmpty,
      reasons: reasons,
    );
  }
}

class IntegrityReport {
  const IntegrityReport({required this.compromised, required this.reasons});
  final bool compromised;
  final List<String> reasons;
}
