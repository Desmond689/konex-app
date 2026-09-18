/// Certificate pinning configuration.
///
/// Set pins via `--dart-define=CERT_PIN_SHA256=sha256/....` (space-separated).
/// Empty pins = no-op (safe for debug).
///
/// When enabled, installs [HttpOverrides.global] so all `dart:io` HttpClient
/// traffic is created through a pinning-aware client. Supabase / http package
/// traffic that uses `dart:io` inherits this. True SPKI pinning still needs
/// native network-security-config / App Transport Security for full coverage;
/// this layer rejects clear bypass of bad certificates and marks pinned builds.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';

List<String> _pinsFromEnvironment() {
  const raw = String.fromEnvironment('CERT_PIN_SHA256', defaultValue: '');
  if (raw.trim().isEmpty) return const [];
  return raw
      .split(RegExp(r'\s+'))
      .map((e) => e.trim())
      .where((e) => e.startsWith('sha256/'))
      .toList();
}

List<String> get kCertificatePins => _pinsFromEnvironment();

const kPinnedHosts = <String>[
  'supabase.co',
];

bool get isCertificatePinningActive => kCertificatePins.isNotEmpty;

/// Call from main() after AppConfig load.
Future<void> initializeCertificatePinning({
  required bool enabled,
  String? supabaseUrl,
}) async {
  if (!enabled || kDebugMode) return;
  if (kCertificatePins.isEmpty) {
    assert(() {
      // ignore: avoid_print
      print('KONEX: certificate pins not configured (CERT_PIN_SHA256)');
      return true;
    }());
    return;
  }

  final host = supabaseUrl != null ? Uri.tryParse(supabaseUrl)?.host : null;
  final pinnedHostSuffixes = <String>{
    ...kPinnedHosts,
    if (host != null) host,
  };

  HttpOverrides.global = _PinningHttpOverrides(
    pins: kCertificatePins,
    hostSuffixes: pinnedHostSuffixes.toList(),
  );

  assert(() {
    // ignore: avoid_print
    print(
      'KONEX: cert pinning ACTIVE for $pinnedHostSuffixes '
      'pins=${kCertificatePins.length}',
    );
    return true;
  }());
}

class _PinningHttpOverrides extends HttpOverrides {
  _PinningHttpOverrides({required this.pins, required this.hostSuffixes});
  final List<String> pins;
  final List<String> hostSuffixes;

  bool _shouldPin(String host) {
    return hostSuffixes.any((s) => host == s || host.endsWith('.$s'));
  }

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    // Never accept bad certs for pinned hosts (or globally when pinning on).
    client.badCertificateCallback = (cert, host, port) {
      if (_shouldPin(host)) {
        // Reject — pin list is enforced at release via native configs;
        // invalid chains must never proceed in a pinning-enabled build.
        return false;
      }
      return false;
    };
    client.userAgent = '${client.userAgent ?? 'Dart'}; konex-pinning=1';
    return client;
  }
}
