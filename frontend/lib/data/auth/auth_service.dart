import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../models/user_profile.dart';

class AuthException implements Exception {
  AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// PostgreSQL-backed auth via FastAPI (`/auth/*`). No Firestore.
class AuthService {
  AuthService({http.Client? client}) : _client = client ?? http.Client();

  static const String _tokenKey = 'sukaseafood_access_token';

  final http.Client _client;
  String? _token;

  String? get token => _token;
  bool get hasToken => _token != null && _token!.isNotEmpty;

  Uri _uri(String path) => Uri.parse('${AppConstants.apiBaseUrl}$path');

  Future<void> restoreSession() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
  }

  Future<void> _persistToken(String? token) async {
    _token = token;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (token == null || token.isEmpty) {
      await prefs.remove(_tokenKey);
    } else {
      await prefs.setString(_tokenKey, token);
    }
  }

  Future<UserProfile> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final http.Response response = await _client.post(
      _uri('/auth/signup'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(<String, String>{
        'name': name.trim(),
        'email': email.trim().toLowerCase(),
        'password': password,
      }),
    );
    return _parseAuthResponse(response);
  }

  Future<UserProfile> signIn({
    required String email,
    required String password,
  }) async {
    final http.Response response = await _client.post(
      _uri('/auth/login'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(<String, String>{
        'email': email.trim().toLowerCase(),
        'password': password,
      }),
    );
    return _parseAuthResponse(response);
  }

  Future<UserProfile?> loadCurrentUser() async {
    if (!hasToken) return null;
    final http.Response response = await _client.get(
      _uri('/auth/me'),
      headers: <String, String>{
        'Authorization': 'Bearer $_token',
        'Content-Type': 'application/json',
      },
    );
    if (response.statusCode == 401) {
      await signOut();
      return null;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException(_extractError(response));
    }
    final Map<String, dynamic> body =
        jsonDecode(response.body) as Map<String, dynamic>;
    return UserProfile.fromJson(body);
  }

  Future<void> signOut() => _persistToken(null);

  Future<UserProfile> _parseAuthResponse(http.Response response) async {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException(_extractError(response));
    }
    final Map<String, dynamic> body =
        jsonDecode(response.body) as Map<String, dynamic>;
    final String? token = body['access_token'] as String?;
    if (token == null || token.isEmpty) {
      throw AuthException('Server did not return an access token.');
    }
    await _persistToken(token);
    final Map<String, dynamic> user =
        body['user'] as Map<String, dynamic>? ?? <String, dynamic>{};
    return UserProfile.fromJson(user);
  }

  String _extractError(http.Response response) {
    try {
      final Object? decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final Object? detail = decoded['detail'];
        if (detail is String && detail.isNotEmpty) return detail;
        if (detail is List && detail.isNotEmpty) {
          final Object first = detail.first;
          if (first is Map && first['msg'] != null) {
            return first['msg'].toString();
          }
        }
      }
    } catch (_) {}
    if (response.statusCode == 0) {
      return 'Cannot reach the API. Is the backend running?';
    }
    return 'Request failed (${response.statusCode}).';
  }
}
