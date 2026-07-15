import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/theme/theme.dart';
import 'package:mobile_app/features/maintenance/widgets/invoice_widget.dart';

class CustomerAppointmentDetailScreen extends StatefulWidget {
  final Map<String, dynamic> appointment;

  const CustomerAppointmentDetailScreen({super.key, required this.appointment});

  @override
  State<CustomerAppointmentDetailScreen> createState() =>
      _CustomerAppointmentDetailScreenState();
}

class _CustomerAppointmentDetailScreenState
    extends State<CustomerAppointmentDetailScreen> {
  bool _isCancelling = false;

  bool _canCancelAppointment(Map<String, dynamic> appointment) {
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

    if (confirmed != true || _isCancelling) return;

    setState(() => _isCancelling = true);
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
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCancelling = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not cancel appointment: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final apt = widget.appointment;
    final status = apt['status']?.toString() ?? 'UNKNOWN';
    final DateTime date = DateTime.parse(apt['appointmentDate']).toLocal();
    final String formattedDate =
        '${DateFormat('HH:mm').format(date)} — ${DateFormat('EEE, dd MMM yyyy').format(date)}';
    final String branchName =
        apt['branchName']?.toString() ??
        apt['branch']?['name']?.toString() ??
        'Unknown branch';
    final String note = apt['note'] ?? 'No note';

    final invoiceJson = apt['invoiceDetails']?.toString();

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('Appointment Details'),
        centerTitle: true,
        backgroundColor: AppColors.canvas,
        surfaceTintColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Appointment Info Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.edge),
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
                            fontSize: 18,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildStatusBadge(status),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _infoRow(Icons.access_time_rounded, 'Time', formattedDate),
                  const SizedBox(height: 8),
                  if (apt['vehicleName'] != null)
                    _infoRow(
                      Icons.two_wheeler_rounded,
                      'Vehicle',
                      '${apt['vehicleName']} (${apt['vehiclePlate'] ?? ''})',
                    ),
                  const SizedBox(height: 8),
                  _infoRow(Icons.notes_rounded, 'Note', note),
                  if (_canCancelAppointment(apt)) ...[
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isCancelling
                            ? null
                            : () => _cancelAppointment(apt),
                        icon: _isCancelling
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.cancel_outlined, size: 18),
                        label: Text(
                          _isCancelling
                              ? 'Cancelling...'
                              : 'Cancel appointment',
                        ),
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

            // Temporary Bill section
            if ((status == 'PAYING' || status == 'COMPLETED') &&
                invoiceJson != null &&
                invoiceJson.trim().isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                status == 'PAYING'
                    ? 'TEMPORARY BILL (PLEASE PAY AT BRANCH)'
                    : 'PAID BILL',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.inkMuted,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              InvoiceWidget(jsonData: invoiceJson),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.inkMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: AppColors.inkMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
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
}
