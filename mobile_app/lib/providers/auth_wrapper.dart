import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import '../screens/auth/login_screen.dart';
import '../screens/main_screen.dart';
import '../screens/branch/branch_dashboard.dart';
import 'auth_provider.dart';


class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // Lắng nghe Token từ bộ nhớ điện thoại do Firebase Auth quản lý
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {

        // 1. Nếu đang tải Token từ thiết bị lên
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: Color(0xFF00796B))),
          );
        }

        // 2. NẾU TÌM THẤY PHIÊN ĐĂNG NHẬP (Auto-login)
        if (snapshot.hasData && snapshot.data != null) {
          return Consumer<AuthProvider>(
            builder: (context, authProvider, child) {

              // Đang chờ Spring Boot xử lý và trả về dữ liệu Role
              if (authProvider.mysqlUser == null) {
                return const Scaffold(
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.orange),
                        SizedBox(height: 16),
                        Text("Đang đồng bộ dữ liệu hệ thống...", style: TextStyle(color: Colors.grey))
                      ],
                    ),
                  ),
                );
              }

              // 3. Đã có Role từ Spring Boot -> THỰC HIỆN ĐỊNH TUYẾN
              final roleName = authProvider.mysqlUser?['role'];

              if (roleName == 'BRANCH') {
                return const BranchMobileDashboard(); // Vào trang Quản lý Chi nhánh
              }

              // Mặc định khách hàng thông thường
              return const MainScreen();
            },
          );
        }

        // 4. Nếu chưa đăng nhập hoặc đã bị đăng xuất
        return const LoginScreen();
      },
    );
  }
}