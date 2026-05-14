/// HTTP client for all backend API calls.

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // For Android emulator use 10.0.2.2, for iOS simulator use localhost
  // For physical device, use your computer's local IP address
  static const String _baseUrl = 'http://10.0.2.2:8000';

  static String? _token;

  /// Initialize token from SharedPreferences on app start.
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
  }

  /// Save auth token after login/signup.
  static Future<void> setToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  /// Clear auth token on logout.
  static Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  /// Check if user is authenticated.
  static bool get isAuthenticated => _token != null && _token!.isNotEmpty;

  /// Get stored token.
  static String? get token => _token;

  // ── HTTP Helpers ──────────────────────────────────────

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  static Future<Map<String, dynamic>> get(String path) async {
    final response = await http
        .get(Uri.parse('$_baseUrl$path'), headers: _headers)
        .timeout(const Duration(seconds: 15));
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl$path'),
          headers: _headers,
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> put(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await http
        .put(
          Uri.parse('$_baseUrl$path'),
          headers: _headers,
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> delete(String path) async {
    final response = await http
        .delete(Uri.parse('$_baseUrl$path'), headers: _headers)
        .timeout(const Duration(seconds: 15));
    return _handleResponse(response);
  }

  static Map<String, dynamic> _handleResponse(http.Response response) {
    final body = jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (body is List) {
        return {'data': body};
      }
      return body as Map<String, dynamic>;
    }

    final detail = body is Map ? body['detail'] ?? 'Unknown error' : 'Unknown error';
    throw ApiException(response.statusCode, detail.toString());
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';

  bool get isUnauthorized => statusCode == 401;
  bool get isNotFound => statusCode == 404;
  bool get isBadRequest => statusCode == 400;
}
