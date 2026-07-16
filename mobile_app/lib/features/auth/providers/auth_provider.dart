import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/notifications/push_notification_service.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? _firebaseUser;
  Map<String, dynamic>? _mysqlUser;
  bool _isLoading = false;

  AuthProvider() {
    _auth.authStateChanges().listen((User? user) async {
      _firebaseUser = user;

      if (user != null) {
        // Control auto-login state:
        // Only sync with the server when the app restores the session itself (not via a button press).
        if (_mysqlUser == null && !_isLoading) {
          try {
            await _syncWithSpringBoot(user);
          } catch (e) {
            debugPrint("Session sync error: $e");
            await logout();
          }
        }
      } else {
        _mysqlUser = null;
        notifyListeners();
      }
    });
  }

  User? get firebaseUser => _firebaseUser;
  Map<String, dynamic>? get mysqlUser => _mysqlUser;
  bool get isLoading => _isLoading;

  bool get isGoogleAccount {
    if (_firebaseUser == null) return false;
    return _firebaseUser!.providerData.any(
      (info) => info.providerId == 'google.com',
    );
  }

  /**
   * CASE 1 & 3: SIGN IN WITH GOOGLE
   */
  Future<void> signInWithGoogle(BuildContext context) async {
    _isLoading =
        true; // Set the loading flag to lock the background auth-state listener.
    notifyListeners();
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 1. Sign in to Firebase
      UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );

      // 2. Send the token to Spring Boot to fetch user info
      await _syncWithSpringBoot(userCredential.user);
    } catch (e) {
      await logout();
      if (!context.mounted) return;
      _showErrorDialog(context, _getFriendlyErrorMessage(e.toString()));
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /**
   * CASE 2: REGISTER WITH THE STANDARD FORM
   */
  Future<bool> registerWithEmailForm(
    BuildContext context, {
    required String email,
    required String password,
    required String fullName,
    required String phone,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // Small delay to let Firebase propagate the new user token
      // (avoids clock-skew / replication-lag issues on emulators)
      await Future.delayed(const Duration(seconds: 2));

      // Force refresh to get a fresh, fully-propagated token
      String? token = await credential.user?.getIdToken(true);
      if (token == null) {
        throw Exception(
          "Unable to obtain authentication token. Please try again.",
        );
      }

      debugPrint("[CareBike] Register token length: ${token.length}");

      await credential.user?.sendEmailVerification();

      http.Response response = await http.post(
        Uri.parse('${ApiClient.baseUrl}/auth/register'),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'email': email,
          'fullName': fullName,
          'phone': phone,
        }),
      );

      // Retry once if 401 — token may not have propagated yet
      if (response.statusCode == 401) {
        debugPrint("[CareBike] Register got 401, retrying with fresh token...");
        await Future.delayed(const Duration(seconds: 2));
        token = await credential.user?.getIdToken(true);
        response = await http.post(
          Uri.parse('${ApiClient.baseUrl}/auth/register'),
          headers: {
            'Content-Type': 'application/json; charset=UTF-8',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'email': email,
            'fullName': fullName,
            'phone': phone,
          }),
        );
      }

      if (response.statusCode != 200 && response.statusCode != 201) {
        if (_auth.currentUser != null) {
          await credential.user?.delete();
        }
        final errorData = jsonDecode(utf8.decode(response.bodyBytes));
        throw Exception(
          errorData['message'] ?? "System is busy. Please try again later.",
        );
      }

      await logout();
      return true;
    } catch (e) {
      if (!context.mounted) return false;
      _showErrorDialog(context, _getFriendlyErrorMessage(e.toString()));
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /**
   * SIGN IN WITH THE STANDARD FORM
   */
  Future<void> signInWithEmailForm(
    BuildContext context,
    String email,
    String password,
  ) async {
    _isLoading = true;
    notifyListeners();
    try {
      UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await _syncWithSpringBoot(credential.user);
    } catch (e) {
      await _auth.signOut();
      if (!context.mounted) return;
      _showErrorDialog(context, _getFriendlyErrorMessage(e.toString()));
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> sendForgotPasswordEmail(
    BuildContext context,
    String email,
  ) async {
    if (email.trim().isEmpty) return;
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      _showSuccessDialog(
        context,
        "Sent Successfully",
        "A password reset link has been sent to your email. Please check your inbox or spam folder.",
      );
    } catch (e) {
      _showErrorDialog(context, _getFriendlyErrorMessage(e.toString()));
    }
  }

  Future<void> changePassword(
    BuildContext context,
    String currentPassword,
    String newPassword,
  ) async {
    if (_firebaseUser == null) return;

    if (isGoogleAccount) {
      _showErrorDialog(
        context,
        "Your account is protected by Google. To change your password, please do so on your Google Account Management page.",
        title: "Notification",
      );
      return;
    }

    try {
      AuthCredential credential = EmailAuthProvider.credential(
        email: _firebaseUser!.email!,
        password: currentPassword,
      );
      await _firebaseUser!.reauthenticateWithCredential(credential);
      await _firebaseUser!.updatePassword(newPassword);

      _showSuccessDialog(
        context,
        "Success",
        "Your password has been securely updated.",
      );
    } catch (e) {
      String errorMsg = e.toString();
      if (errorMsg.contains('wrong-password') ||
          errorMsg.contains('invalid-credential')) {
        _showErrorDialog(
          context,
          "The current password is incorrect. Please double check.",
        );
      } else {
        _showErrorDialog(context, _getFriendlyErrorMessage(errorMsg));
      }
    }
  }

  Future<void> _syncWithSpringBoot(User? user) async {
    if (user == null) return;

    String? token = await user.getIdToken();

    final response = await http.post(
      Uri.parse('${ApiClient.baseUrl}/auth/login'),
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token',
        'X-Client-Type': 'MOBILE',
      },
    );

    if (response.statusCode == 200) {
      _mysqlUser = jsonDecode(utf8.decode(response.bodyBytes));
      await PushNotificationService.instance.registerDeviceToken();
      notifyListeners();
    } else {
      final errorData = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(
        errorData['message'] ?? "Security reason: System denied access.",
      );
    }
  }

  Future<void> logout() async {
    try {
      await PushNotificationService.instance.unregisterDeviceToken();
      await _auth.signOut();
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.disconnect();
        await _googleSignIn.signOut();
      }
    } catch (e) {
      debugPrint("Session cleanup error on logout: $e");
    } finally {
      _mysqlUser = null;
      notifyListeners();
    }
  }

  String _getFriendlyErrorMessage(String rawError) {
    final error = rawError.toLowerCase();
    if (error.contains('email-already-in-use'))
      return "This email is already in use. Please log in or use another email.";
    if (error.contains('invalid-credential') ||
        error.contains('wrong-password') ||
        error.contains('user-not-found'))
      return "Incorrect login info. Please double check your email and password.";
    if (error.contains('user-disabled'))
      return "Your account has been temporarily disabled. Please contact support.";
    if (error.contains('too-many-requests'))
      return "Too many failed attempts. Please try again later for your safety.";
    if (error.contains('network-request-failed'))
      return "No network connection. Please check your Wifi/4G.";
    if (error.contains('invalid-email'))
      return "Invalid email format. For example: yourname@gmail.com";

    String cleanError = rawError
        .replaceAll(RegExp(r'^Exception:\s*'), '')
        .trim();
    if (cleanError.contains('PlatformException'))
      return "A connection error occurred. Please try again.";
    return cleanError.isNotEmpty
        ? cleanError
        : "System is under maintenance or encountering issues. Please try again later.";
  }

  void _showErrorDialog(
    BuildContext context,
    String message, {
    String title = "An error occurred",
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 15, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close", style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.green),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 15, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Confirm", style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}
