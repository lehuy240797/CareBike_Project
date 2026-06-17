import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';

class WebSocketService {
  static StompClient? _stompClient;

  /// Hàm khởi tạo kết nối và lắng nghe đơn hàng của khách
  static void connectCustomer(int customerId, Function(Map<String, dynamic>) onStatusUpdated) {
    // Nếu đang có kết nối cũ thì ngắt đi để tránh lặp (Memory leak)
    disconnect();

    _stompClient = StompClient(
      config: StompConfig(
        // Dùng 10.0.2.2 cho máy ảo Android, nếu test máy thật phải dùng IP LAN (VD: 192.168.1.x)
        url: 'ws://10.0.2.2:8080/ws',
        onConnect: (StompFrame frame) {
          debugPrint('Đã kết nối WebSocket (Khách hàng ID: $customerId)');

          // Lắng nghe đúng kênh của Khách hàng này
          _stompClient?.subscribe(
            destination: '/topic/customers/$customerId/appointments',
            callback: (StompFrame frame) {
              if (frame.body != null) {
                final Map<String, dynamic> updatedData = jsonDecode(frame.body!);
                // Gọi hàm callback để truyền data ra ngoài giao diện
                onStatusUpdated(updatedData);
              }
            },
          );
        },
        onWebSocketError: (dynamic error) => debugPrint('Lỗi WS: $error'),
        reconnectDelay: const Duration(seconds: 5), // Tự động kết nối lại nếu rớt mạng
      ),
    );

    _stompClient?.activate();
  }

  /// Hàm lắng nghe ca CỨU HỘ dành riêng cho Chi nhánh
  static void connectBranch(int branchId, Function(Map<String, dynamic>) onRescueReceived) {
    disconnect(); // Ngắt kết nối cũ nếu có

    _stompClient = StompClient(
      config: StompConfig(
        url: 'ws://10.0.2.2:8080/ws', // Nhớ đổi thành IP LAN nếu test máy thật
        onConnect: (StompFrame frame) {
          debugPrint('📡 Đã bật Radar Cứu hộ (Chi nhánh ID: $branchId)');

          // Lắng nghe kênh Cứu hộ của chi nhánh này (Giống y hệt bên React)
          _stompClient?.subscribe(
            destination: '/topic/branches/$branchId/rescues',
            callback: (StompFrame frame) {
              if (frame.body != null) {
                final Map<String, dynamic> newRescue = jsonDecode(frame.body!);
                onRescueReceived(newRescue); // Bắn dữ liệu ra giao diện
              }
            },
          );
        },
        onWebSocketError: (dynamic error) => debugPrint('Lỗi WS Branch: $error'),
        reconnectDelay: const Duration(seconds: 5),
      ),
    );

    _stompClient?.activate();
  }

  static void disconnect() {
    if (_stompClient != null && _stompClient!.connected) {
      _stompClient?.deactivate();
      debugPrint('Đã ngắt kết nối WebSocket.');
    }
  }
}