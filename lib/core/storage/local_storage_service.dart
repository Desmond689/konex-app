import 'package:shared_preferences/shared_preferences.dart';

import '../config/constants.dart';

/// Non-sensitive preferences (onboarding, data-saver, theme).
class LocalStorageService {
  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  SharedPreferences get prefs {
    if (_prefs == null) {
      throw StateError(
          'LocalStorageService not initialized. Call init() first.');
    }
    return _prefs!;
  }

  Future<bool> getOnboardingDone() async {
    await init();
    return prefs.getBool(AppConstants.localKeyOnboardingDone) ?? false;
  }

  Future<void> setOnboardingDone(bool value) async {
    await init();
    await prefs.setBool(AppConstants.localKeyOnboardingDone, value);
  }

  Future<bool> getDataSaver() async {
    await init();
    return prefs.getBool(AppConstants.localKeyDataSaver) ?? false;
  }

  Future<void> setDataSaver(bool value) async {
    await init();
    await prefs.setBool(AppConstants.localKeyDataSaver, value);
  }

  Future<String?> getThemeMode() async {
    await init();
    return prefs.getString(AppConstants.localKeyThemeMode);
  }

  Future<void> setThemeMode(String mode) async {
    await init();
    await prefs.setString(AppConstants.localKeyThemeMode, mode);
  }

  Future<String?> getVerificationDeviceId() async {
    await init();
    return prefs.getString(AppConstants.localKeyVerificationDeviceId);
  }

  Future<void> setVerificationDeviceId(String value) async {
    await init();
    await prefs.setString(AppConstants.localKeyVerificationDeviceId, value);
  }
}
