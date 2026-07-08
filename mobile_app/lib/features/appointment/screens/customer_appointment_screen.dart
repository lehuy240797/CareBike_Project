import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mobile_app/core/theme/theme.dart';
import 'package:mobile_app/features/auth/providers/auth_provider.dart';
import 'package:mobile_app/core/network/web_socket_service.dart';
import 'package:mobile_app/core/network/api_client.dart';

class CustomerAppointmentScreen extends StatefulWidget {
  final bool embedded;

  const CustomerAppointmentScreen({super.key, this.embedded = false});

  @override
  State<CustomerAppointmentScreen> createState() =>
      _CustomerAppointmentScreenState();
}

class _CustomerAppointmentScreenState extends State<CustomerAppointmentScreen> {
  List<dynamic> appointments = [];
  bool isLoading = true;
  StreamSubscription? _wsSubscription;

  @override
  void initState() {
    super.initState();
    _fetchAppointments();

    // Listen to WebSocket events from the global stream
    _wsSubscription = WebSocketService.appointmentStreamController.stream
        .listen((updatedData) {
          if (mounted) {
            // Auto-reload the list without pull-to-refresh
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
      final customerId = _currentCustomerId(authProvider.mysqlUser);
      final user = FirebaseAuth.instance.currentUser;

      if (customerId == null || user == null) {
        setState(() => isLoading = false);
        return;
      }

      String? token = await user.getIdToken();
      final response = await http.get(
        Uri.parse('${ApiClient.baseUrl}/appointments/customer/$customerId'),
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
      debugPrint("Error loading the appointment list: $e");
    }
  }

  int? _currentCustomerId(Map<String, dynamic>? user) {
    final value = user?['userId'] ?? user?['id'] ?? user?['user']?['id'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  Widget _buildStatusBadge(String status) {
    Color bgColor;
    Color textColor;
    String text;

    switch (status) {
      case 'PENDING':
        bgColor = AppColors.primaryMuted;
        textColor = AppColors.primaryDeep;
        text = 'Pending';
        break;
      case 'CONFIRMED':
        bgColor = AppColors.successBg;
        textColor = AppColors.success;
        text = 'Confirmed';
        break;
      case 'COMPLETED':
        bgColor = const Color(0xFFEFF4FF);
        textColor = const Color(0xFF2563EB);
        text = 'Completed';
        break;
      case 'CANCELLED':
        bgColor = AppColors.dangerBg;
        textColor = AppColors.danger;
        text = 'Cancelled';
        break;
      default:
        bgColor = const Color(0xFFF1EDE8);
        textColor = AppColors.inkMuted;
        text = 'Unknown';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = isLoading
        ? Center(child: CircularProgressIndicator(color: AppColors.primary))
        : appointments.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 64,
                  color: AppColors.edge,
                ),
                const SizedBox(height: 16),
                Text(
                  'You have no appointments yet',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkMuted,
                  ),
                ),
              ],
            ),
          )
        : RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _fetchAppointments,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              itemCount: appointments.length,
              itemBuilder: (context, index) {
                final apt = appointments[index];
                final DateTime date = DateTime.parse(
                  apt['appointmentDate'],
                ).toLocal();
                final String formattedDate =
                    '${DateFormat('HH:mm').format(date)} — ${DateFormat('EEE, dd MMM yyyy').format(date)}';
                final String branchName =
                    apt['branchName']?.toString() ??
                    apt['branch']?['name']?.toString() ??
                    'Unknown branch';
                final String note = apt['note'] ?? 'No note';

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.edge),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryDeep.withValues(alpha: 0.06),
                        blurRadius: 22,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              branchName,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: AppColors.ink,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildStatusBadge(apt['status']),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 16,
                            color: AppColors.inkMuted,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            formattedDate,
                            style: TextStyle(
                              color: AppColors.ink,
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.notes_rounded,
                            size: 16,
                            color: AppColors.inkMuted,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              note,
                              style: TextStyle(
                                color: AppColors.inkMuted,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          );

    if (widget.embedded) {
      return ColoredBox(color: AppColors.canvas, child: content);
    }

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('My Appointments'),
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 19,
          fontWeight: FontWeight.w800,
          color: AppColors.ink,
        ),
        centerTitle: true,
        backgroundColor: AppColors.canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(13),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: AppColors.edge),
              ),
              child: Icon(
                Icons.arrow_back_rounded,
                size: 22,
                color: AppColors.ink,
              ),
            ),
          ),
        ),
      ),
      body: content,
    );
  }
}
