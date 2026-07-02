import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/api_client.dart';

class TemporaryInvoiceScreen extends StatefulWidget {
  final int rescueId;
  final Map<String, dynamic> rescueData;
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
    required this.rescueData,
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
      final List<Map<String, dynamic>> items = widget.cart.values.map((item) {
        return {
          'sparePartId': (item['part']['id'] as int) < 0 ? null : item['part']['id'],
          'name': item['part']['name'],
          'quantity': item['quantity'],
          'price': item['part']['price'],
        };
      }).toList();

      double totalTransportFee = 0;
      if (widget.needStaffTravel) totalTransportFee += widget.distanceKm * 2 * widget.staffTravelPricePerKm;
      if (widget.needVehicleTransport) totalTransportFee += widget.distanceKm * 2 * widget.transportPricePerKm;

      final payload = {
        'items': items,
        'laborCost': widget.laborCost,
        'staffCode': widget.staffCode,
        'timeMultiplier': widget.timeMultiplier,
        'distanceKm': widget.distanceKm,
        'transportFee': totalTransportFee,
      };

      await ApiClient.post('/rescues/${widget.rescueId}/complete', payload);

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('🎉 Completed!', textAlign: TextAlign.center),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 60),
              SizedBox(height: 16),
              Text('Customer has paid successfully!', textAlign: TextAlign.center),
              SizedBox(height: 8),
              Text('Repair history has been saved to the system.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13)),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
                onPressed: () {
                  Navigator.pop(ctx);  // Close dialog
                  Navigator.pop(context, true); // Go back to bill screen
                },
                child: const Text('Done'),
              ),
            )
          ],
        ),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'VND', decimalDigits: 0);
    final now = DateTime.now();
    final dateStr = DateFormat('HH:mm - dd/MM/yyyy').format(now);

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Temporary Invoice'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ─── Header ───
              const Text('CAREBIKE', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.red, letterSpacing: 3)),
              const Text('Motorcycle Rescue Service', style: TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 4),
              Text('Date: $dateStr', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                height: 2,
                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300, width: 0.5), color: Colors.grey.shade300),
              ),

              // ─── Customer Info ───
              _buildInfoSection('CUSTOMER INFORMATION', [
                _buildInfoRow('Name', widget.customerName),
                _buildInfoRow('Phone', widget.customerPhone),
                _buildInfoRow('Vehicle', widget.vehicleName),
                _buildInfoRow('Plate', widget.vehiclePlate),
              ]),
              const SizedBox(height: 12),

              // ─── Staff Info ───
              _buildInfoSection('STAFF INFORMATION', [
                _buildInfoRow('Staff Code', widget.staffCode),
                _buildInfoRow('Name', widget.staffName),
              ]),
              const SizedBox(height: 12),

              // ─── Service List ───
              Align(
                alignment: Alignment.centerLeft,
                child: Text('SERVICES USED', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey.shade700)),
              ),
              const Divider(),
              // Labor fee
              _buildBillRow(
                'Rescue labor fee ${widget.timeMultiplier > 1 ? "(Night shift x2)" : ""}',
                formatter.format(widget.laborCost * widget.timeMultiplier),
              ),

              // Services / Spare parts
              ...widget.cart.values.map((item) {
                final p = item['part'];
                final qty = item['quantity'] as int;
                final price = (p['price'] as num).toDouble() * widget.timeMultiplier;
                return _buildBillRow(
                  '${p['name']} x$qty',
                  formatter.format(price * qty),
                );
              }),

              // Transport
              if (widget.needStaffTravel)
                _buildBillRow(
                  'Staff travel (${widget.distanceKm.toStringAsFixed(1)}km × Round trip)',
                  formatter.format(widget.distanceKm * 2 * widget.staffTravelPricePerKm),
                ),
              if (widget.needVehicleTransport)
                _buildBillRow(
                  'Vehicle towing (${widget.distanceKm.toStringAsFixed(1)}km × Round trip)',
                  formatter.format(widget.distanceKm * 2 * widget.transportPricePerKm),
                ),

              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                height: 2,
                color: Colors.black,
              ),

              // ─── Total ───
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('TOTAL', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
                  Text(formatter.format(widget.totalAmount), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: Colors.red.shade700)),
                ],
              ),
              const SizedBox(height: 8),

              if (widget.timeMultiplier > 1)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
                  child: const Text('⚠️ Order is calculated at Night Shift rate (10 PM - 6 AM): Multiplier x2', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.deepOrange)),
                ),

              const SizedBox(height: 24),

              // ─── DONE Button ───
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _completeRescue,
                  icon: _isSubmitting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.done_all),
                  label: Text(_isSubmitting ? 'PROCESSING...' : 'CONFIRM PAID & COMPLETED', style: const TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey.shade700)),
        const Divider(),
        ...children,
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(width: 90, child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _buildBillRow(String label, String amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          Text(amount, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
        ],
      ),
    );
  }
}
