import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../services/server_config_store.dart';

enum ServerStatus { loading, unconfigured, configured }

/// Owns the "which server are we talking to" state. The setup screen calls
/// [connect] (which tests /health before saving); the login screen can call
/// [changeServer] to reconfigure.
class ServerProvider extends ChangeNotifier {
  final ServerConfigStore _store;
  ServerProvider(this._store) {
    _load();
  }

  ServerStatus _status = ServerStatus.loading;
  String? _baseUrl;

  ServerStatus get status => _status;
  String? get baseUrl => _baseUrl;

  /// Prefill value for the setup field: last-used URL, or the build-time default.
  String get suggestedUrl => _baseUrl ?? AppConfig.apiBaseUrl;

  Future<void> _load() async {
    _baseUrl = await _store.readBaseUrl();
    _status = (_baseUrl == null || _baseUrl!.isEmpty)
        ? ServerStatus.unconfigured
        : ServerStatus.configured;
    notifyListeners();
  }

  /// Trim, default to http:// if no scheme given, and drop any trailing slash.
  static String normalize(String raw) {
    var u = raw.trim();
    if (u.isEmpty) return u;
    if (!u.startsWith('http://') && !u.startsWith('https://')) {
      u = 'http://$u';
    }
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }

  /// Tests the address, and on success saves it and flips to configured.
  /// Returns null on success, or a human-readable error message.
  Future<String?> connect(String rawUrl) async {
    final url = normalize(rawUrl);
    if (url.isEmpty) return 'Please enter a server address.';

    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return 'That doesn\'t look like a valid address.';
    }

    try {
      final res = await http
          .get(Uri.parse('$url/health'))
          .timeout(const Duration(seconds: 6));

      if (res.statusCode == 200) {
        final dynamic body = jsonDecode(res.body);
        if (body is Map && body['status'] == 'ok') {
          await _store.saveBaseUrl(url);
          _baseUrl = url;
          _status = ServerStatus.configured;
          notifyListeners();
          return null;
        }
      }
      return 'Reached that address, but it doesn\'t look like a Staff Portal server.';
    } on TimeoutException {
      return 'Timed out reaching that server. Check the address and that it is running.';
    } catch (_) {
      return 'Could not connect to that address. Check the URL and your network.';
    }
  }

  Future<void> changeServer() async {
    await _store.clear();
    _baseUrl = null;
    _status = ServerStatus.unconfigured;
    notifyListeners();
  }
}
