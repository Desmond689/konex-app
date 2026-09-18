import 'app_config.dart';

/// Base sealed class for environment-specific behavior.
sealed class EnvironmentBehavior {
  const EnvironmentBehavior();

  bool get shouldLogDebugInfo;
  bool get useMocks;
  bool get enableAnalytics;
  bool get enableCertificatePinning;
  bool get strictSessionValidation;

  static EnvironmentBehavior resolve(AppEnvironment environment) {
    return switch (environment) {
      AppEnvironment.development => const DevelopmentBehavior(),
      AppEnvironment.staging => const StagingBehavior(),
      AppEnvironment.production => const ProductionBehavior(),
    };
  }
}

class DevelopmentBehavior extends EnvironmentBehavior {
  const DevelopmentBehavior();

  @override
  bool get shouldLogDebugInfo => true;

  @override
  bool get useMocks => false; // Prefer real Supabase even in dev when possible

  @override
  bool get enableAnalytics => false;

  @override
  bool get enableCertificatePinning => false;

  @override
  bool get strictSessionValidation => false;
}

class StagingBehavior extends EnvironmentBehavior {
  const StagingBehavior();

  @override
  bool get shouldLogDebugInfo => true;

  @override
  bool get useMocks => false;

  @override
  bool get enableAnalytics => true;

  @override
  bool get enableCertificatePinning => true;

  @override
  bool get strictSessionValidation => true;
}

class ProductionBehavior extends EnvironmentBehavior {
  const ProductionBehavior();

  @override
  bool get shouldLogDebugInfo => false;

  @override
  bool get useMocks => false;

  @override
  bool get enableAnalytics => true;

  @override
  bool get enableCertificatePinning => true;

  @override
  bool get strictSessionValidation => true;
}
