import 'package:shared_preferences/shared_preferences.dart';

/// Persists the backend server URL the user connects to, so they only enter it
/// once. Read fresh on each request by ApiClient.
class ServerConfigStore {
  static const _key = 'server_url';

  Future<String?> readBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  Future<void> saveBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, url);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
