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
import 'package:mobile_app/features/appointment/screens/customer_appointment_detail_screen.dart';
import 'package:mobile_app/core/network/api_client.dart';

class CustomerAppointmentScreen extends StatefulWidget {
  final bool embedded;
  final bool isMainTab;

  const CustomerAppointmentScreen({
    super.key,
    this.embedded = false,
    this.isMainTab = false,
  });

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
          'Content-Type': 'application/json; charset=UTF-8',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        data.sort(_sortCustomerAppointments);
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

  int _sortCustomerAppointments(dynamic a, dynamic b) {
    final priorityCompare = _appointmentPriority(
      a,
    ).compareTo(_appointmentPriority(b));
    if (priorityCompare != 0) return priorityCompare;

    final aDate = DateTime.tryParse(a['appointmentDate']?.toString() ?? '');
    final bDate = DateTime.tryParse(b['appointmentDate']?.toString() ?? '');
    final dateCompare = (bDate ?? DateTime(1900)).compareTo(
      aDate ?? DateTime(1900),
    );
    if (dateCompare != 0) return dateCompare;

    return _asInt(b['id']).compareTo(_asInt(a['id']));
  }

  int _appointmentPriority(dynamic appointment) {
    final status = appointment is Map
        ? appointment['status']?.toString().toUpperCase()
        : null;
    switch (status) {
      case 'PENDING':
      case 'CONFIRMED':
        return 0;
      default:
        return 1;
    }
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  bool _canCancelAppointment(dynamic appointment) {
    if (appointment is! Map) return false;
    final status = appointment['status']?.toString().toUpperCase();
    final invoiceDetails = appointment['invoiceDetails']?.toString().trim();
    return (status == 'PENDING' || status == 'CONFIRMED') &&
        (invoiceDetails == null || invoiceDetails.isEmpty);
  }

  Future<void> _cancelAppointment(Map<String, dynamic> appointment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel appointment?'),
        content: const Text(
          'You can cancel before the branch creates a bill for this appointment.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cancel appointment'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final response = await ApiClient.put(
        '/appointments/${appointment['id']}/cancel',
        {},
      );
      ApiClient.parseResponse(response);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Appointment cancelled.'),
          backgroundColor: AppColors.success,
        ),
      );
      await _fetchAppointments();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not cancel appointment: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
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
      case 'PAYING':
        bgColor = const Color(0xFFFFF3CD);
        textColor = const Color(0xFF856404);
        text = 'Paying';
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
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                CustomerAppointmentDetailScreen(
                                  appointment: Map<String, dynamic>.from(apt),
                                ),
                          ),
                        ).then((updated) {
                          if (updated == true && mounted) _fetchAppointments();
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(18),
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
                            if (_canCancelAppointment(apt)) ...[
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () => _cancelAppointment(
                                    Map<String, dynamic>.from(apt),
                                  ),
                                  icon: const Icon(
                                    Icons.cancel_outlined,
                                    size: 18,
                                  ),
                                  label: const Text('Cancel appointment'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.danger,
                                    side: BorderSide(color: AppColors.danger),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
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
        leadingWidth: widget.isMainTab ? 0 : 64,
        automaticallyImplyLeading: !widget.isMainTab,
        leading: widget.isMainTab
            ? const SizedBox.shrink()
            : Padding(
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
