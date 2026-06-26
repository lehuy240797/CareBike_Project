import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import 'dart:async';

class WebSocketService {
  static StompClient? _stompClient;
  static StompClient? _branchAppointmentStompClient;
  static final StreamController<Map<String, dynamic>> appointmentStreamController = StreamController<Map<String, dynamic>>.broadcast();

  /// Open the connection and listen for the customer's orders
  static void connectCustomer(int customerId, Function(Map<String, dynamic>) onStatusUpdated) {
    // Disconnect any existing connection to avoid duplicates (memory leak)
    disconnect();

    _stompClient = StompClient(
      config: StompConfig(
        // Use 10.0.2.2 for the Android emulator; on a real device use your LAN IP (e.g. 192.168.1.x)
        url: 'ws://10.0.2.2:8080/ws',
        onConnect: (StompFrame frame) {
          debugPrint('WebSocket connected (Customer ID: $customerId)');

          // Subscribe to this customer's channel
          _stompClient?.subscribe(
            destination: '/topic/customers/$customerId/appointments',
            callback: (StompFrame frame) {
              if (frame.body != null) {
                final Map<String, dynamic> updatedData = jsonDecode(frame.body!);
                // Call the callback to pass data to the main UI (show SnackBar)
                onStatusUpdated(updatedData);
                // Emit to the stream so the list screen (CustomerAppointmentScreen) reloads automatically
                appointmentStreamController.add(updatedData);
              }
            },
          );
        },
        onWebSocketError: (dynamic error) => debugPrint('WS error: $error'),
        reconnectDelay: const Duration(seconds: 5), // Auto-reconnect if the network drops
      ),
    );

    _stompClient?.activate();
  }

  /// Listen for RESCUE cases for a specific branch
  static void connectBranch(int branchId, Function(Map<String, dynamic>) onRescueReceived) {
    // Reset only the rescue/customer client — leave the appointments client alone
    // so a rescue connection doesn't tear down the appointments listener.
    if (_stompClient != null && _stompClient!.connected) {
      _stompClient?.deactivate();
    }

    _stompClient = StompClient(
      config: StompConfig(
        url: 'ws://10.0.2.2:8080/ws', // Remember to use your LAN IP on a real device
        onConnect: (StompFrame frame) {
          debugPrint('📡 Rescue radar enabled (Branch ID: $branchId)');

          // Subscribe to this branch's rescue channel (same as the React side)
          _stompClient?.subscribe(
            destination: '/topic/branches/$branchId/rescues',
            callback: (StompFrame frame) {
              if (frame.body != null) {
                final Map<String, dynamic> newRescue = jsonDecode(frame.body!);
                onRescueReceived(newRescue); // Push data to the UI
              }
            },
          );
        },
        onWebSocketError: (dynamic error) => debugPrint('WS Branch error: $error'),
        reconnectDelay: const Duration(seconds: 5),
      ),
    );

    _stompClient?.activate();
  }

  /// Listen for MAINTENANCE APPOINTMENTS for a specific branch
  static void connectBranchAppointments(int branchId, Function(Map<String, dynamic>) onAppointmentReceived) {
    if (_branchAppointmentStompClient != null && _branchAppointmentStompClient!.connected) {
      _branchAppointmentStompClient?.deactivate();
    }

    _branchAppointmentStompClient = StompClient(
      config: StompConfig(
        url: 'ws://10.0.2.2:8080/ws',
        onConnect: (StompFrame frame) {
          debugPrint('📡 Appointment listener enabled (Branch ID: $branchId)');
          _branchAppointmentStompClient?.subscribe(
            destination: '/topic/branches/$branchId/appointments',
            callback: (StompFrame frame) {
              if (frame.body != null) {
                final Map<String, dynamic> newAppointment = jsonDecode(frame.body!);
                onAppointmentReceived(newAppointment);
              }
            },
          );
        },
        onWebSocketError: (dynamic error) => debugPrint('WS Branch Appointments error: $error'),
        reconnectDelay: const Duration(seconds: 5),
      ),
    );

    _branchAppointmentStompClient?.activate();
  }

  static void disconnect() {
    if (_stompClient != null && _stompClient!.connected) {
      _stompClient?.deactivate();
      debugPrint('WebSocket disconnected (Customer/Rescue).');
    }
    if (_branchAppointmentStompClient != null && _branchAppointmentStompClient!.connected) {
      _branchAppointmentStompClient?.deactivate();
      debugPrint('WebSocket disconnected (Branch Appointments).');
    }
  }
}