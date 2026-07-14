import '../models/auth_user.dart';
import 'api_client.dart';
import 'token_store.dart';

class AuthService {
  final ApiClient _api;
  final TokenStore _tokenStore;

  AuthService(this._api, this._tokenStore);

  /// Validates credentials, stores the JWT, then resolves the full user
  /// (the login response omits username, so we confirm via /auth/me).
  Future<AuthUser> login(String username, String password) async {
    final data = await _api.post(
      '/api/v1/auth/login',
      {'username': username, 'password': password},
      auth: false,
    ) as Map<String, dynamic>;

    await _tokenStore.saveToken(data['access_token'] as String);
    return fetchCurrentUser();
  }

  Future<AuthUser> fetchCurrentUser() async {
    final data = await _api.get('/api/v1/auth/me') as Map<String, dynamic>;
    return AuthUser.fromJson(data);
  }

  Future<void> logout() => _tokenStore.clear();

  Future<String?> storedToken() => _tokenStore.readToken();
}
