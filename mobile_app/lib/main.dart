import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:mobile_app/firebase_options.dart';

import 'package:mobile_app/features/auth/providers/auth_provider.dart';
import 'package:mobile_app/app/auth_wrapper.dart';
import 'package:mobile_app/core/notifications/push_notification_service.dart';
import 'package:mobile_app/core/theme/theme.dart';
import 'package:mobile_app/core/theme/theme_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // INITIALIZE FIREBASE
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await PushNotificationService.instance.initialize();
  // Load the saved light/dark preference before the first frame.
  await ThemeController.instance.load();
  runApp(const CareBikeApp());
}

class CareBikeApp extends StatelessWidget {
  const CareBikeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider.value(value: ThemeController.instance),
      ],
      // Rebuild the whole app (and re-resolve AppColors tokens) on toggle.
      child: Consumer<ThemeController>(
        builder: (context, themeController, _) => MaterialApp(
          title: 'CareBike',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeController.mode,
          home: const AuthWrapper(),
        ),
      ),
    );
  }
}
