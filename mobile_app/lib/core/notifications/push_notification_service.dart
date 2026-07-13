import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/firebase_options.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  StreamSubscription<String>? _tokenRefreshSubscription;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await _messaging.setAutoInitEnabled(true);
    await _requestPermission();

    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen((token) {
      _sendTokenToServer(token);
    });

    FirebaseMessaging.onMessage.listen((message) {
      debugPrint('[CareBike] Foreground FCM received: ${message.data}');
    });

    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }
  }

  Future<void> registerDeviceToken() async {
    try {
      final token = await _messaging.getToken();
      if (token == null) return;
      await _sendTokenToServer(token);
    } catch (e) {
      debugPrint('[CareBike] Could not register FCM token: $e');
    }
  }

  Future<void> unregisterDeviceToken() async {
    try {
      final token = await _messaging.getToken();
      if (token == null || FirebaseAuth.instance.currentUser == null) return;

      final response = await ApiClient.post('/notifications/tokens/remove', {
        'token': token,
        'platform': 'ANDROID',
      });
      if (response.statusCode >= 400) {
        debugPrint('[CareBike] Could not remove FCM token: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[CareBike] FCM token cleanup skipped: $e');
    }
  }

  Future<void> dispose() async {
    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;
    _initialized = false;
  }

  Future<void> _requestPermission() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> _sendTokenToServer(String token) async {
    if (FirebaseAuth.instance.currentUser == null) return;

    try {
      final response = await ApiClient.post('/notifications/tokens', {
        'token': token,
        'platform': 'ANDROID',
      });
      if (response.statusCode >= 400) {
        debugPrint('[CareBike] FCM token registration failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[CareBike] FCM token registration skipped: $e');
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('[CareBike] Notification opened: ${message.data}');
  }
}
