/// App-wide constants for KONEX.
class AppConstants {
  static const String appName = 'KONEX';
  static const int minPasswordLength = 8;
  static const int maxPostTextLength = 2000;
  static const int maxBioLength = 160;
  static const int maxUsernameLength = 24;
  static const int minAgeYears = 13;

  /// Max clip size before api.video upload.
  static const int maxVideoUploadBytes = 50 * 1024 * 1024; // 50 MB

  /// Pure WebRTC group voice — hard ceiling for mesh topology.
  static const int maxCallParticipants = 8;

  static const String secureKeyAuthToken = 'kx_auth_token';
  static const String secureKeyRefreshToken = 'kx_refresh_token';
  static const String secureKeyUserSession = 'kx_user_id';
  static const String secureKeyBiometricEnabled = 'kx_biometric';

  /// Local (non-secure) shared_preferences keys.
  static const String localKeyOnboardingDone = 'kx_onboarding_done';
  static const String localKeyDataSaver = 'kx_data_saver';
  static const String localKeyThemeMode = 'kx_theme_mode';
  static const String localKeyVerificationDeviceId = 'kx_verification_device_id';

  static const int minUsernameLength = 3;

  /// Page size used for paginated feed/list queries.
  static const int feedPageSize = 20;

  static const List<String> playerTypes = [
    'Mobile',
    'Console',
    'PC',
  ];

  /// ISO-ish country codes shown on signup / profile (code — label).
  static const List<Map<String, String>> countryOptions = [
    {'code': 'CM', 'label': 'Cameroon'},
    {'code': 'NG', 'label': 'Nigeria'},
    {'code': 'GH', 'label': 'Ghana'},
    {'code': 'KE', 'label': 'Kenya'},
    {'code': 'ZA', 'label': 'South Africa'},
    {'code': 'CI', 'label': "Côte d'Ivoire"},
    {'code': 'SN', 'label': 'Senegal'},
    {'code': 'US', 'label': 'United States'},
    {'code': 'GB', 'label': 'United Kingdom'},
    {'code': 'FR', 'label': 'France'},
    {'code': 'DE', 'label': 'Germany'},
    {'code': 'CA', 'label': 'Canada'},
    {'code': 'OTHER', 'label': 'Other'},
  ];

  static const List<String> supportedPlatforms = [
    'Mobile',
    'PC',
    'PlayStation',
    'Xbox',
    'Nintendo Switch',
    'Cross-play',
    'Other',
  ];

  static const List<String> supportedGames = [
    'Call of Duty Mobile',
    'PUBG Mobile',
    'Free Fire',
    'FIFA / EA FC',
    'Fortnite',
    'League of Legends',
    'Valorant',
    'eFootball',
    'Mobile Legends',
    'Other',
  ];
}
