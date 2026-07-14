import 'package:flutter/foundation.dart';

import '../models/auth_user.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';

enum AuthStatus { unknown, authenticating, authenticated, unauthenticated }

/// Single source of truth for auth state. Screens read [status]/[user]/[error]
/// and react; they never call services directly.
class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  AuthProvider(this._authService);

  AuthStatus _status = AuthStatus.unknown;
  AuthUser? _user;
  String? _error;

  AuthStatus get status => _status;
  AuthUser? get user => _user;
  String? get error => _error;

  /// Called once at startup: restore a session from a stored token if valid.
  Future<void> tryAutoLogin() async {
    final token = await _authService.storedToken();
    if (token == null || token.isEmpty) {
      _set(AuthStatus.unauthenticated);
      return;
    }
    try {
      _user = await _authService.fetchCurrentUser();
      _set(AuthStatus.authenticated);
    } catch (_) {
      await _authService.logout(); // token expired or invalid
      _set(AuthStatus.unauthenticated);
    }
  }

  Future<void> login(String username, String password) async {
    _error = null;
    _set(AuthStatus.authenticating);
    try {
      _user = await _authService.login(username, password);
      _set(AuthStatus.authenticated);
    } on ApiException catch (e) {
      _error = e.message;
      _set(AuthStatus.unauthenticated);
    } catch (_) {
      _error = 'Could not reach the server. Is the API running?';
      _set(AuthStatus.unauthenticated);
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    _user = null;
    _error = null;
    _set(AuthStatus.unauthenticated);
  }

  void _set(AuthStatus status) {
    _status = status;
    notifyListeners();
  }
}
