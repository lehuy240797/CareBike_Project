import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/theme/theme.dart';

class TemporaryInvoiceScreen extends StatefulWidget {
  final int rescueId;
  final String customerName;
  final String customerPhone;
  final String vehicleName;
  final String vehiclePlate;
  final String staffCode;
  final String staffName;
  final Map<int, Map<String, dynamic>> cart;
  final double laborCost;
  final double timeMultiplier;
  final bool needStaffTravel;
  final double staffTravelPricePerKm;
  final bool needVehicleTransport;
  final double distanceKm;
  final double transportPricePerKm;
  final double totalAmount;

  const TemporaryInvoiceScreen({
    super.key,
    required this.rescueId,
    required this.customerName,
    required this.customerPhone,
    required this.vehicleName,
    required this.vehiclePlate,
    required this.staffCode,
    required this.staffName,
    required this.cart,
    required this.laborCost,
    required this.timeMultiplier,
    required this.needStaffTravel,
    required this.staffTravelPricePerKm,
    required this.needVehicleTransport,
    required this.distanceKm,
    required this.transportPricePerKm,
    required this.totalAmount,
  });

  @override
  State<TemporaryInvoiceScreen> createState() => _TemporaryInvoiceScreenState();
}

class _TemporaryInvoiceScreenState extends State<TemporaryInvoiceScreen> {
  bool _isSubmitting = false;

  Future<void> _completeRescue() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      final items = widget.cart.values.map((item) {
        final part = item['part'] as Map<String, dynamic>;
        final id = part['id'] as int;
        return {
          'sparePartId': id < 0 ? null : id,
          'name': part['name'],
          'quantity': item['quantity'],
          'price': part['price'],
        };
      }).toList();

      double transportFee = 0;
      if (widget.needStaffTravel) {
        transportFee += widget.distanceKm * 2 * widget.staffTravelPricePerKm;
      }
      if (widget.needVehicleTransport) {
        transportFee += widget.distanceKm * 2 * widget.transportPricePerKm;
      }

      await ApiClient.post('/rescues/${widget.rescueId}/complete', {
        'items': items,
        'laborCost': widget.laborCost,
        'staffCode': widget.staffCode,
        'timeMultiplier': widget.timeMultiplier,
        'distanceKm': widget.distanceKm,
        'transportFee': transportFee,
      });

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Completed', textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_rounded,
                color: AppColors.success,
                size: 60,
              ),
              const SizedBox(height: 14),
              const Text(
                'Customer has paid successfully.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Repair history has been saved to the system.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.inkMuted, fontSize: 13),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context, true);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: 'VND',
      decimalDigits: 0,
    );
    final dateStr = DateFormat('HH:mm - dd/MM/yyyy').format(DateTime.now());

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('Temporary Invoice'),
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
        backgroundColor: AppColors.danger,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: AppStyles.card(radius: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _CareBikeBillLogo(size: 28),
              Text(
                'Motorcycle Rescue Service',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.inkMuted, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                'Date: $dateStr',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.inkMuted, fontSize: 12),
              ),
              const Divider(height: 28),
              _infoSection('CUSTOMER INFORMATION', [
                _infoRow('Name', widget.customerName),
                _infoRow('Phone', widget.customerPhone),
                _infoRow('Vehicle', widget.vehicleName),
                _infoRow('Plate', widget.vehiclePlate),
              ]),
              const SizedBox(height: 14),
              _infoSection('STAFF INFORMATION', [
                _infoRow('Staff Code', widget.staffCode),
                _infoRow('Name', widget.staffName),
              ]),
              const SizedBox(height: 14),
              Text(
                'SERVICES USED',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w800,
                  color: AppColors.inkMuted,
                  fontSize: 13,
                ),
              ),
              const Divider(),
              _billRow(
                'Rescue labor fee ${widget.timeMultiplier > 1 ? "(Night shift x2)" : ""}',
                formatter.format(widget.laborCost * widget.timeMultiplier),
              ),
              ...widget.cart.values.map((item) {
                final part = item['part'] as Map<String, dynamic>;
                final qty = item['quantity'] as int;
                final price =
                    (part['price'] as num).toDouble() * widget.timeMultiplier;
                return _billRow(
                  '${part['name']} x$qty',
                  formatter.format(price * qty),
                );
              }),
              if (widget.needStaffTravel)
                _billRow(
                  'Staff travel (${widget.distanceKm.toStringAsFixed(1)}km x round trip)',
                  formatter.format(
                    widget.distanceKm * 2 * widget.staffTravelPricePerKm,
                  ),
                ),
              if (widget.needVehicleTransport)
                _billRow(
                  'Vehicle towing (${widget.distanceKm.toStringAsFixed(1)}km x round trip)',
                  formatter.format(
                    widget.distanceKm * 2 * widget.transportPricePerKm,
                  ),
                ),
              const Divider(thickness: 1.5, height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'TOTAL',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
                  ),
                  Text(
                    formatter.format(widget.totalAmount),
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                      color: AppColors.danger,
                    ),
                  ),
                ],
              ),
              if (widget.timeMultiplier > 1) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.warningBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Night shift rate is active: multiplier x2.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.warning,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: _isSubmitting ? null : _completeRescue,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.done_all_rounded),
                  label: Text(
                    _isSubmitting
                        ? 'PROCESSING...'
                        : 'CONFIRM PAID & COMPLETED',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w800,
            color: AppColors.inkMuted,
            fontSize: 13,
          ),
        ),
        const Divider(),
        ...children,
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: TextStyle(color: AppColors.inkMuted, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _billRow(String label, String amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label, style: TextStyle(color: AppColors.ink)),
          ),
          Text(
            amount,
            style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink),
          ),
        ],
      ),
    );
  }
}

class _CareBikeBillLogo extends StatelessWidget {
  final double size;
  const _CareBikeBillLogo({required this.size});

  @override
  Widget build(BuildContext context) {
    TextStyle style(Color color) => GoogleFonts.montserrat(
      fontSize: size,
      fontWeight: FontWeight.w800,
      fontStyle: FontStyle.italic,
      color: color,
      letterSpacing: -0.8,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('CARE', style: style(AppColors.primary)),
        Text('BIKE', style: style(AppColors.ink)),
      ],
    );
  }
}
