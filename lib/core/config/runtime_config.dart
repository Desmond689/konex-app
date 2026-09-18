import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_config.dart';
import 'environment_config.dart';

/// Runtime resolved behavior for the current environment.
final environmentBehaviorProvider = Provider<EnvironmentBehavior>((ref) {
  final config = ref.watch(appConfigProvider);
  return EnvironmentBehavior.resolve(config.environment);
});
