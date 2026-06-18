import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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
        // Kiểm soát trạng thái đăng nhập tự động:
        // Đảm bảo chỉ thực hiện đồng bộ với server khi ứng dụng tự khởi tạo phiên bản (không qua tương tác nút nhấn).
        if (_mysqlUser == null && !_isLoading) {
          try {
            await _syncWithSpringBoot(user);
          } catch (e) {
            debugPrint("Lỗi đồng bộ phiên làm việc: $e");
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
    return _firebaseUser!.providerData.any((info) => info.providerId == 'google.com');
  }

  /**
   * TRƯỜNG HỢP 1 & 3: ĐĂNG NHẬP BẰNG GOOGLE
   */
  Future<void> signInWithGoogle(BuildContext context) async {
    _isLoading = true; // Kích hoạt cờ tải dữ liệu để khóa luồng lắng nghe trạng thái nền.
    notifyListeners();
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 1. Đăng nhập vào Firebase
      UserCredential userCredential = await _auth.signInWithCredential(credential);

      // 2. Gửi Token xuống Spring Boot để lấy thông tin
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
   * TRƯỜNG HỢP 2: ĐĂNG KÝ BẰNG FORM TRUYỀN THỐNG
   */
  Future<bool> registerWithEmailForm(BuildContext context, {
    required String email,
    required String password,
    required String fullName,
    required String phone
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
          email: email.trim(),
          password: password
      );

      String? token = await credential.user?.getIdToken();
      await credential.user?.sendEmailVerification();

      final response = await http.post(
        Uri.parse('http://10.0.2.2:8080/api/auth/register'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'email': email, 'fullName': fullName, 'phone': phone}),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        if (_auth.currentUser != null) {
          await credential.user?.delete();
        }
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? "Hệ thống đang bận. Vui lòng thử lại sau.");
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
   * ĐĂNG NHẬP BẰNG FORM TRUYỀN THỐNG
   */
  Future<void> signInWithEmailForm(BuildContext context, String email, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      UserCredential credential = await _auth.signInWithEmailAndPassword(
          email: email.trim(),
          password: password
      );
      await _syncWithSpringBoot(credential.user);
    } catch (e) {
      if (!context.mounted) return;
      await _auth.signOut();
      _showErrorDialog(context, _getFriendlyErrorMessage(e.toString()));
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> sendForgotPasswordEmail(BuildContext context, String email) async {
    if (email.trim().isEmpty) return;
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      _showSuccessDialog(context, "Gửi thành công", "Liên kết đặt lại mật khẩu đã được gửi vào hòm thư của bạn. Vui lòng kiểm tra hộp thư đến hoặc mục thư rác.");
    } catch (e) {
      _showErrorDialog(context, _getFriendlyErrorMessage(e.toString()));
    }
  }

  Future<void> changePassword(BuildContext context, String currentPassword, String newPassword) async {
    if (_firebaseUser == null) return;

    if (isGoogleAccount) {
      _showErrorDialog(
          context,
          "Tài khoản của bạn đang được bảo vệ bởi Google. Để thay đổi mật khẩu, vui lòng thao tác trên trang Quản lý tài khoản Google của bạn.",
          title: "Thông báo"
      );
      return;
    }

    try {
      AuthCredential credential = EmailAuthProvider.credential(
          email: _firebaseUser!.email!,
          password: currentPassword
      );
      await _firebaseUser!.reauthenticateWithCredential(credential);
      await _firebaseUser!.updatePassword(newPassword);

      _showSuccessDialog(context, "Thành công", "Mật khẩu của bạn đã được cập nhật an toàn.");
    } catch (e) {
      String errorMsg = e.toString();
      if (errorMsg.contains('wrong-password') || errorMsg.contains('invalid-credential')) {
        _showErrorDialog(context, "Mật khẩu hiện tại không chính xác. Vui lòng kiểm tra lại.");
      } else {
        _showErrorDialog(context, _getFriendlyErrorMessage(errorMsg));
      }
    }
  }

  Future<void> _syncWithSpringBoot(User? user) async {
    if (user == null) return;

    String? token = await user.getIdToken();

    final response = await http.post(
      Uri.parse('http://10.0.2.2:8080/api/auth/login'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
        'X-Client-Type': 'MOBILE',
      },
    );

    if (response.statusCode == 200) {
      _mysqlUser = jsonDecode(response.body);
      notifyListeners();
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? "Lý do bảo mật: Hệ thống từ chối quyền truy cập.");
    }
  }

  Future<void> logout() async {
    try {
      await _auth.signOut();
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.disconnect();
        await _googleSignIn.signOut();
      }
    } catch (e) {
      debugPrint("Lỗi dọn dẹp phiên đăng xuất: $e");
    } finally {
      _mysqlUser = null;
      notifyListeners();
    }
  }

  String _getFriendlyErrorMessage(String rawError) {
    final error = rawError.toLowerCase();
    if (error.contains('email-already-in-use')) return "Email này đã được sử dụng. Vui lòng đăng nhập hoặc dùng một email khác.";
    if (error.contains('invalid-credential') || error.contains('wrong-password') || error.contains('user-not-found')) return "Thông tin đăng nhập không chính xác. Vui lòng kiểm tra lại email hoặc mật khẩu.";
    if (error.contains('user-disabled')) return "Tài khoản của bạn đã bị tạm khóa. Vui lòng liên hệ tổng đài để được hỗ trợ.";
    if (error.contains('too-many-requests')) return "Bạn đã thao tác sai quá nhiều lần. Vui lòng thử lại sau ít phút để bảo đảm an toàn.";
    if (error.contains('network-request-failed')) return "Không có kết nối mạng. Vui lòng kiểm tra lại Wifi/4G của bạn.";
    if (error.contains('invalid-email')) return "Định dạng email không hợp lệ. Ví dụ đúng: tenban@gmail.com";

    String cleanError = rawError.replaceAll(RegExp(r'^Exception:\s*'), '').trim();
    if (cleanError.contains('PlatformException')) return "Đã xảy ra sự cố kết nối với hệ thống đăng nhập. Vui lòng thử lại.";
    return cleanError.isNotEmpty ? cleanError : "Hệ thống đang bảo trì hoặc gặp sự cố. Vui lòng thử lại sau.";
  }

  void _showErrorDialog(BuildContext context, String message, {String title = "Đã xảy ra lỗi"}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text(message, style: const TextStyle(fontSize: 15, height: 1.4)),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Đóng", style: TextStyle(fontSize: 16)))],
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
            Text(title, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text(message, style: const TextStyle(fontSize: 15, height: 1.4)),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Xác nhận", style: TextStyle(fontSize: 16)))],
      ),
    );
  }
}