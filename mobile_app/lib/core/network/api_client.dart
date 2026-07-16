import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

/// Centralized HTTP client for all CareBike API calls.
/// Local development uses adb reverse, so WiFi changes do not require code edits.
class ApiClient {
  static const String serverIp = '127.0.0.1';
  static const String baseUrl = 'http://$serverIp:8080/api';

  // ── Auth headers ───────────────────────────────────────────────────────────
  static Future<Map<String, String>> _authHeaders() async {
    final user = FirebaseAuth.instance.currentUser;
    final token = user != null ? await user.getIdToken() : null;
    return {
      'Content-Type': 'application/json; charset=UTF-8',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ── Core HTTP methods ────────────────────────────────────────────────────────

  static Future<http.Response> get(String path) async {
    final headers = await _authHeaders();
    return http.get(Uri.parse('$baseUrl$path'), headers: headers);
  }

  static Future<http.Response> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final headers = await _authHeaders();
    return http.post(
      Uri.parse('$baseUrl$path'),
      headers: headers,
      body: jsonEncode(body),
    );
  }

  static Future<http.Response> put(
    String path,
    Map<String, dynamic> body,
  ) async {
    final headers = await _authHeaders();
    return http.put(
      Uri.parse('$baseUrl$path'),
      headers: headers,
      body: jsonEncode(body),
    );
  }

  // ── Response parsing helpers ─────────────────────────────────────────────────

  /// Decode JSON. Throws ApiException if status >= 400.
  static dynamic parseResponse(http.Response response) {
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode >= 400) {
      final msg = decoded is Map
          ? (decoded['message'] ?? decoded['error'] ?? decoded.toString())
          : decoded.toString();
      throw ApiException(response.statusCode, msg.toString());
    }
    return decoded;
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;
  const ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}
