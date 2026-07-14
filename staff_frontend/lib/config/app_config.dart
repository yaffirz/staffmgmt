class AppConfig {
  /// Base URL of the FastAPI backend.
  ///
  /// Default targets a desktop browser hitting the local stack.
  /// Override per target without editing code:
  ///   flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000
  ///   flutter run            --dart-define=API_BASE_URL=http://10.0.2.2:8000     (Android emulator)
  ///   flutter run            --dart-define=API_BASE_URL=http://192.168.1.X:8000  (physical phone on your LAN)
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  /// Shown in the permanent footer on every page.
  static const String appCreator = 'Arif Asad Ali';
}
