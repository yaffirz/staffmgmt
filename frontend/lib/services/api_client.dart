import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'server_config_store.dart';
import 'token_store.dart';

/// Thrown for any non-2xx response, carrying the backend's `detail` message.
class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

/// The single outbound gateway. Every request flows through here; the base URL
/// is resolved from the user-configured server, and the JWT is attached
/// automatically — no screen ever touches headers.
class ApiClient {
  final TokenStore _tokenStore;
  final ServerConfigStore _serverStore;
  ApiClient(this._tokenStore, this._serverStore);

  Future<Uri> _uri(String path) async {
    final base = (await _serverStore.readBaseUrl()) ?? AppConfig.apiBaseUrl;
    return Uri.parse('$base$path');
  }

  Future<Map<String, String>> _headers({bool auth = true}) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (auth) {
      final token = await _tokenStore.readToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  Future<dynamic> get(String path, {bool auth = true}) async {
    final res =
        await http.get(await _uri(path), headers: await _headers(auth: auth));
    return _process(res);
  }

  Future<dynamic> post(
    String path,
    Map<String, dynamic> body, {
    bool auth = true,
  }) async {
    final res = await http.post(
      await _uri(path),
      headers: await _headers(auth: auth),
      body: jsonEncode(body),
    );
    return _process(res);
  }

  Future<dynamic> put(
    String path,
    Map<String, dynamic> body, {
    bool auth = true,
  }) async {
    final res = await http.put(
      await _uri(path),
      headers: await _headers(auth: auth),
      body: jsonEncode(body),
    );
    return _process(res);
  }

  Future<dynamic> patch(
    String path,
    Map<String, dynamic> body, {
    bool auth = true,
  }) async {
    final res = await http.patch(
      await _uri(path),
      headers: await _headers(auth: auth),
      body: jsonEncode(body),
    );
    return _process(res);
  }

  Future<dynamic> delete(String path, {bool auth = true}) async {
    final res = await http.delete(
      await _uri(path),
      headers: await _headers(auth: auth),
    );
    return _process(res);
  }

  /// Uploads CSV text as a multipart file (field name `file`) — used by the
  /// bulk-import endpoints.
  Future<dynamic> postCsv(String path, String csv) async {
    final req = http.MultipartRequest('POST', await _uri(path));
    final headers = await _headers();
    headers.remove('Content-Type'); // multipart sets its own boundary
    req.headers.addAll(headers);
    req.files.add(
      http.MultipartFile.fromString('file', csv, filename: 'upload.csv'),
    );
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    return _process(res);
  }

  dynamic _process(http.Response res) {
    final contentType = res.headers['content-type'] ?? '';
    final isJson = contentType.contains('application/json');
    final dynamic decoded =
        (res.body.isNotEmpty && isJson) ? jsonDecode(res.body) : null;

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return decoded;
    }

    final detail = (decoded is Map && decoded['detail'] != null)
        ? decoded['detail'].toString()
        : 'Request failed (${res.statusCode})';
    throw ApiException(res.statusCode, detail);
  }
}
