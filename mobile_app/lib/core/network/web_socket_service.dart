import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import 'dart:async';
import 'package:mobile_app/core/network/api_client.dart';

class WebSocketService {
  static StompClient? _stompClient;
  static StompClient? _branchAppointmentStompClient;
  static final StreamController<Map<String, dynamic>> appointmentStreamController = StreamController<Map<String, dynamic>>.broadcast();

  /// Function to initialize connection and listen for customer orders
  static void connectCustomer(int customerId, Function(Map<String, dynamic>) onStatusUpdated) {
    // If there is an old connection, disconnect it to avoid loops (Memory leak)
    disconnect();

    _stompClient = StompClient(
      config: StompConfig(
        url: 'ws://${ApiClient.serverIp}:8080/ws',
        onConnect: (StompFrame frame) {
          debugPrint('Connected to WebSocket (Customer ID: $customerId)');

          // Listen to the correct channel of this Customer
          _stompClient?.subscribe(
            destination: '/topic/customers/$customerId/appointments',
            callback: (StompFrame frame) {
              if (frame.body != null) {
                final Map<String, dynamic> updatedData = jsonDecode(frame.body!);
                // Call callback function to pass data out to main UI (Show SnackBar)
                onStatusUpdated(updatedData);
                // Send signal to Stream so list screen (CustomerAppointmentScreen) automatically reloads
                appointmentStreamController.add(updatedData);
              }
            },
          );
        },
        onWebSocketError: (dynamic error) => debugPrint('WS Error: $error'),
        reconnectDelay: const Duration(seconds: 5), // Auto reconnect if disconnected
      ),
    );

    _stompClient?.activate();
  }

  /// Function to listen for RESCUE cases specifically for Branch
  static void connectBranch(int branchId, Function(Map<String, dynamic>) onRescueReceived) {
    disconnect(); // Disconnect old connection if any

    _stompClient = StompClient(
      config: StompConfig(
        url: 'ws://${ApiClient.serverIp}:8080/ws',
        onConnect: (StompFrame frame) {
          debugPrint('📡 Rescue Radar turned on (Branch ID: $branchId)');

          // Listen to the Rescue channel of this branch (Exactly the same as React)
          _stompClient?.subscribe(
            destination: '/topic/branches/$branchId/rescues',
            callback: (StompFrame frame) {
              if (frame.body != null) {
                final Map<String, dynamic> newRescue = jsonDecode(frame.body!);
                onRescueReceived(newRescue); // Fire data to UI
              }
            },
          );
        },
        onWebSocketError: (dynamic error) => debugPrint('WS Branch Error: $error'),
        reconnectDelay: const Duration(seconds: 5),
      ),
    );

    _stompClient?.activate();
  }

  /// Function to listen for MAINTENANCE APPOINTMENTS specifically for Branch
  static void connectBranchAppointments(int branchId, Function(Map<String, dynamic>) onAppointmentReceived) {
    if (_branchAppointmentStompClient != null && _branchAppointmentStompClient!.connected) {
      _branchAppointmentStompClient?.deactivate();
    }

    _branchAppointmentStompClient = StompClient(
      config: StompConfig(
        url: 'ws://${ApiClient.serverIp}:8080/ws',
        onConnect: (StompFrame frame) {
          debugPrint('📡 Listening to Appointments (Branch ID: $branchId)');
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
        onWebSocketError: (dynamic error) => debugPrint('WS Branch Appointments Error: $error'),
        reconnectDelay: const Duration(seconds: 5),
      ),
    );

    _branchAppointmentStompClient?.activate();
  }

  static void disconnect() {
    if (_stompClient != null && _stompClient!.connected) {
      _stompClient?.deactivate();
      debugPrint('Disconnected WebSocket (Customer/Rescue).');
    }
    if (_branchAppointmentStompClient != null && _branchAppointmentStompClient!.connected) {
      _branchAppointmentStompClient?.deactivate();
      debugPrint('Disconnected WebSocket (Branch Appointments).');
    }
  }
}