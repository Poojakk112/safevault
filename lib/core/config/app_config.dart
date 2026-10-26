/// App-wide constants.
class AppConfig {
  AppConfig._();

  /// URL of the FastAPI backend.
  ///
  /// 10.0.2.2 is how the Android emulator reaches `localhost` on your laptop.
  /// Override when running:
  ///   flutter run --dart-define=API_BASE_URL=https://your-api.onrender.com
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );
}

/// Names of the Hive boxes (local databases) used by the app.
class HiveBoxes {
  HiveBoxes._();

  /// Encrypted box holding an offline copy of the user's vault.
  static const String vaultCache = 'vault_cache';

  /// Plain box holding app settings (theme, biometric lock, reminders).
  static const String settings = 'settings';
}
