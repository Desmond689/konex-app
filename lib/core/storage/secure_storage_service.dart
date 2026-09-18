import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/constants.dart';
import '../errors/storage_exception.dart';

/// Thin wrapper around FlutterSecureStorage.
/// Only auth tokens / user id / biometric flag should live here.
class SecureStorageService {
  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  final FlutterSecureStorage _storage;

  Future<void> saveAuthToken(String token) async {
    try {
      await _storage.write(key: AppConstants.secureKeyAuthToken, value: token);
    } catch (e) {
      throw StorageException(
        message: 'Failed to save auth token: $e',
        bucketName: 'secure_keychain',
      );
    }
  }

  Future<String?> getAuthToken() async {
    try {
      return await _storage.read(key: AppConstants.secureKeyAuthToken);
    } catch (e) {
      throw StorageException(
        message: 'Failed to read auth token: $e',
        bucketName: 'secure_keychain',
      );
    }
  }

  Future<void> saveRefreshToken(String token) async {
    try {
      await _storage.write(
        key: AppConstants.secureKeyRefreshToken,
        value: token,
      );
    } catch (e) {
      throw StorageException(
        message: 'Failed to save refresh token: $e',
        bucketName: 'secure_keychain',
      );
    }
  }

  Future<String?> getRefreshToken() async {
    try {
      return await _storage.read(key: AppConstants.secureKeyRefreshToken);
    } catch (e) {
      throw StorageException(
        message: 'Failed to read refresh token: $e',
        bucketName: 'secure_keychain',
      );
    }
  }

  Future<void> saveUserId(String userId) async {
    await _storage.write(
      key: AppConstants.secureKeyUserSession,
      value: userId,
    );
  }

  Future<String?> getUserId() async {
    return _storage.read(key: AppConstants.secureKeyUserSession);
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(
      key: AppConstants.secureKeyBiometricEnabled,
      value: enabled.toString(),
    );
  }

  Future<bool> isBiometricEnabled() async {
    final v = await _storage.read(key: AppConstants.secureKeyBiometricEnabled);
    return v == 'true';
  }

  /// Clears all secure data (logout / session expiry).
  Future<void> clearSecureData() async {
    try {
      await _storage.deleteAll();
    } catch (e) {
      throw StorageException(
        message: 'Failed to clear secure storage.',
        bucketName: 'secure_keychain',
      );
    }
  }
}
