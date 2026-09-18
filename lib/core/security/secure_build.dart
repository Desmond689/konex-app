/// Batch 11: Release build / obfuscation guidance (documented for CI).
///
/// Build with:
/// ```bash
/// flutter build apk --release --obfuscate --split-debug-info=build/symbols
/// flutter build appbundle --release --obfuscate --split-debug-info=build/symbols
/// flutter build ipa --release --obfuscate --split-debug-info=build/symbols
/// ```
///
/// Store `build/symbols` securely (not in public git) for crash symbolication.
///
/// Android: enable ProGuard/R8 in `android/app/build.gradle`:
///   minifyEnabled true
///   shrinkResources true
///
/// Never put service_role or api.video keys in --dart-define for release clients.
library;

const kObfuscationEnabledInReleaseDocs = true;
