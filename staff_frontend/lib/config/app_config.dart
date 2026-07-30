import 'package:flutter/foundation.dart' show kIsWeb;

class AppConfig {
  /// Explicit build-time override (used in dev):
  ///   flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000
  ///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000   (Android emulator)
  static const String _envBase =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');

  /// Base URL of the FastAPI backend.
  ///
  /// Resolution order:
  ///   1. `--dart-define=API_BASE_URL=…` if provided (dev/CI).
  ///   2. On web with no override: the page's own origin — so a `flutter build
  ///      web` served by the backend (e.g. behind the Cloudflare tunnel) talks
  ///      to the same host it was loaded from, with no "connect to server" step.
  ///   3. Native fallback (the server-setup screen normally supplies the URL).
  static String get apiBaseUrl {
    if (_envBase.isNotEmpty) return _envBase;
    if (kIsWeb) return Uri.base.origin;
    return 'http://localhost:8000';
  }

  /// Shown in the permanent footer on every page.
  static const String appCreator = 'Arif Asad Ali';
}
