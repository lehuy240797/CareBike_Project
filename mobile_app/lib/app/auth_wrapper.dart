import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:mobile_app/features/auth/screens/login_screen.dart';
import 'package:mobile_app/features/home/main_screen.dart';
import 'package:mobile_app/features/branch/screens/branch_dashboard.dart';
import 'package:mobile_app/features/auth/providers/auth_provider.dart';


class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // Listen to the token in device storage managed by Firebase Auth
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {

        // 1. While loading the token from the device
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: Color(0xFFF97316))),
          );
        }

        // 2. IF A SESSION IS FOUND (auto-login)
        if (snapshot.hasData && snapshot.data != null) {
          return Consumer<AuthProvider>(
            builder: (context, authProvider, child) {

              // Waiting for Spring Boot to process and return the role data
              if (authProvider.mysqlUser == null) {
                return const Scaffold(
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.orange),
                        SizedBox(height: 16),
                        Text("Synchronizing system data...", style: TextStyle(color: Colors.grey))
                      ],
                    ),
                  ),
                );
              }

              // 3. Role received from Spring Boot -> ROUTE THE USER
              final roleName = authProvider.mysqlUser?['role'];

              if (roleName == 'BRANCH') {
                return const BranchMobileDashboard(); // Go to the Branch Management screen
              }

              // Default: regular customer
              return const MainScreen();
            },
          );
        }

        // 4. If not signed in or signed out
        return const LoginScreen();
      },
    );
  }
}