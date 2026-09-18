import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/dependency_injection.dart';
import '../storage/local_storage_service.dart';

/// Batch 10: Data Saver mode preferences.
class DataSaverService {
  DataSaverService(this._local);
  final LocalStorageService _local;

  Future<bool> isEnabled() => _local.getDataSaver();

  Future<void> setEnabled(bool value) => _local.setDataSaver(value);

  /// Lower image decode width when saver is on.
  int get imageCacheWidth => 720;

  bool get autoplayVideos => false; // when saver on, callers should respect

  bool get preloadAdjacentPages => false;
}

final dataSaverServiceProvider = Provider((ref) {
  return DataSaverService(ref.watch(localStorageProvider));
});

final dataSaverEnabledProvider = FutureProvider<bool>((ref) async {
  return ref.watch(dataSaverServiceProvider).isEnabled();
});
