import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:intl/intl.dart';

import '../providers/auth_provider.dart';
import '../services/web_socket_service.dart';

class CustomerAppointmentScreen extends StatefulWidget {
  const CustomerAppointmentScreen({super.key});

  @override
  State<CustomerAppointmentScreen> createState() => _CustomerAppointmentScreenState();
}

class _CustomerAppointmentScreenState extends State<CustomerAppointmentScreen> {
  List<dynamic> appointments = [];
  bool isLoading = true;
  StreamSubscription? _wsSubscription;

  @override
  void initState() {
    super.initState();
    _fetchAppointments();
    
    // Lắng nghe sự kiện WebSocket từ luồng stream toàn cục
    _wsSubscription = WebSocketService.appointmentStreamController.stream.listen((updatedData) {
      if (mounted) {
        // Tự động reload danh sách mà không cần kéo pull-to-refresh
        _fetchAppointments();
      }
    });
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchAppointments() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final customerId = authProvider.mysqlUser?['userId'];
      final user = FirebaseAuth.instance.currentUser;

      if (customerId == null || user == null) {
        setState(() => isLoading = false);
        return;
      }

      String? token = await user.getIdToken();
      final response = await http.get(
        Uri.parse('http://10.0.2.2:8080/api/appointments/customer/$customerId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        if (mounted) {
          setState(() {
            appointments = data;
            isLoading = false;
          });
        }
      } else {
        throw Exception("Failed to load");
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
      }
      debugPrint("Lỗi tải danh sách lịch hẹn: $e");
    }
  }

  Widget _buildStatusBadge(String status) {
    Color bgColor;
    Color textColor;
    String text;

    switch (status) {
      case 'PENDING':
        bgColor = Colors.orange.shade100;
        textColor = Colors.orange.shade800;
        text = 'Chờ xác nhận';
        break;
      case 'CONFIRMED':
        bgColor = Colors.green.shade100;
        textColor = Colors.green.shade800;
        text = 'Đã xác nhận';
        break;
      case 'COMPLETED':
        bgColor = Colors.blue.shade100;
        textColor = Colors.blue.shade800;
        text = 'Đã hoàn tất';
        break;
      case 'CANCELLED':
        bgColor = Colors.red.shade100;
        textColor = Colors.red.shade800;
        text = 'Đã hủy';
        break;
      default:
        bgColor = Colors.grey.shade200;
        textColor = Colors.grey.shade800;
        text = 'Không rõ';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch hẹn của tôi'),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : appointments.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calendar_today_outlined, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'Bạn chưa có lịch hẹn nào',
                        style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchAppointments,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: appointments.length,
                    itemBuilder: (context, index) {
                      final apt = appointments[index];
                      final DateTime date = DateTime.parse(apt['appointmentDate']).toLocal();
                      final String formattedDate = DateFormat('HH:mm - dd/MM/yyyy').format(date);
                      final String branchName = apt['branch']?['name'] ?? 'Chi nhánh không xác định';
                      final String note = apt['note'] ?? 'Không có ghi chú';

                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      branchName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  _buildStatusBadge(apt['status']),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Icon(Icons.access_time_rounded, size: 16, color: Colors.grey.shade600),
                                  const SizedBox(width: 8),
                                  Text(
                                    formattedDate,
                                    style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.notes, size: 16, color: Colors.grey.shade600),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      note,
                                      style: TextStyle(color: Colors.grey.shade700),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
