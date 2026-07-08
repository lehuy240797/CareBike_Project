import 'package:shared_preferences/shared_preferences.dart';

/// Thin wrapper around shared_preferences for persisting session data.
class AppStorage {
  static const _keyToken    = 'access_token';
  static const _keyUserId   = 'user_id';
  static const _keyUsername = 'username';
  static const _keyFullName = 'full_name';
  static const _keyRole     = 'role';

  // ── Write ────────────────────────────────────────────────────────────────────

  static Future<void> saveSession({
    required String token,
    required int userId,
    required String username,
    required String fullName,
    required String role,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
    await prefs.setInt(_keyUserId, userId);
    await prefs.setString(_keyUsername, username);
    await prefs.setString(_keyFullName, fullName);
    await prefs.setString(_keyRole, role);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyUsername);
    await prefs.remove(_keyFullName);
    await prefs.remove(_keyRole);
  }

  // ── Read ─────────────────────────────────────────────────────────────────────

  static Future<String?> getToken()    async => (await SharedPreferences.getInstance()).getString(_keyToken);
  static Future<int?>    getUserId()   async => (await SharedPreferences.getInstance()).getInt(_keyUserId);
  static Future<String?> getUsername() async => (await SharedPreferences.getInstance()).getString(_keyUsername);
  static Future<String?> getFullName() async => (await SharedPreferences.getInstance()).getString(_keyFullName);
  static Future<String?> getRole()     async => (await SharedPreferences.getInstance()).getString(_keyRole);

  static Future<bool> hasSession() async => (await getToken()) != null;
}
