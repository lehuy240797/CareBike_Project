import 'dart:async';
import 'package:flutter/foundation.dart';

import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/network/web_socket_service.dart';

/// Single source of truth for a branch's rescue (SOS) cases.
///
/// Owns the one rescue WebSocket subscription plus the pending/accepted lists,
/// so the dashboard (emergency popup + Home list) and the Rescue screen stay in
/// sync and never open duplicate sockets.
class RescueStore extends ChangeNotifier {
  RescueStore._();
  static final RescueStore instance = RescueStore._();

  int? _branchId;
  bool loading = true;
  List<dynamic> pending = [];
  List<dynamic> accepted = [];
  List<dynamic> completed = [];

  // Fires for every brand-new PENDING SOS so listeners can raise an alarm.
  final StreamController<Map<String, dynamic>> _newSos =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onNewSos => _newSos.stream;

  bool get isInitialized => _branchId != null;

  /// Start (once) for a branch: load existing cases, then open the radar.
  Future<void> init(int branchId) async {
    if (_branchId == branchId) return; // already running for this branch
    _branchId = branchId;
    await fetch();
    WebSocketService.connectBranch(branchId, _onRescue);
  }

  void _onRescue(Map<String, dynamic> r) {
    final id = r['id'];
    final alreadyKnown =
        pending.any((e) => e['id'] == id) ||
        accepted.any((e) => e['id'] == id) ||
        completed.any((e) => e['id'] == id);
    final status = (r['status'] ?? 'PENDING').toString().toUpperCase();

    pending.removeWhere((e) => e['id'] == id);
    accepted.removeWhere((e) => e['id'] == id);
    completed.removeWhere((e) => e['id'] == id);

    if (status == 'COMPLETED') {
      completed.insert(0, r);
    } else if (status == 'ACCEPTED') {
      accepted.insert(0, r);
    } else {
      pending.insert(0, r);
    }
    notifyListeners();

    if (!alreadyKnown && (status == 'PENDING' || status == 'ACCEPTED')) {
      _newSos.add(r);
    }
  }

  Future<void> fetch() async {
    final id = _branchId;
    if (id == null) return;
    try {
      final res = await ApiClient.get('/rescues/branch/$id');
      final data = ApiClient.parseResponse(res) as List;
      pending = data.where((r) => r['status'] == 'PENDING').toList();
      accepted = data.where((r) => r['status'] == 'ACCEPTED').toList();
      completed = data.where((r) => r['status'] == 'COMPLETED').toList();
    } catch (e) {
      debugPrint('Error loading the rescue list: $e');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Move a case from PENDING to ACCEPTED. Returns true on success.
  Future<bool> accept(int rescueId) async {
    try {
      await ApiClient.put('/rescues/$rescueId/accept', {});
      final i = pending.indexWhere((r) => r['id'] == rescueId);
      if (i != -1) {
        final item = pending.removeAt(i);
        item['status'] = 'ACCEPTED';
        accepted.insert(0, item);
      }
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error accepting the case: $e');
      return false;
    }
  }

  /// Tear down the socket when the branch session ends.
  void shutdown() {
    WebSocketService.disconnect();
    _branchId = null;
    pending = [];
    accepted = [];
    completed = [];
    loading = true;
  }
}
