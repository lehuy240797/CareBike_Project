import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

class InvoiceWidget extends StatelessWidget {
  final String jsonData;

  const InvoiceWidget({super.key, required this.jsonData});

  @override
  Widget build(BuildContext context) {
    try {
      final parsed = jsonDecode(jsonData);
      final Map<String, dynamic> data = Map<String, dynamic>.from(parsed);

      final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'VNĐ', decimalDigits: 0);
      
      // Parse values safely
      final customerName = data['customerName']?.toString() ?? '';
      final customerPhone = data['customerPhone']?.toString() ?? '';
      final vehicleName = data['vehicleName']?.toString() ?? '';
      final vehiclePlate = data['vehiclePlate']?.toString() ?? '';
      final staffCode = data['staffCode']?.toString() ?? '';
      final staffName = data['staffName']?.toString() ?? staffCode;
      final dateStr = data['date']?.toString() ?? '';
      
      final laborCost = (data['laborCost'] is num) ? (data['laborCost'] as num).toDouble() : 0.0;
      final transportFee = (data['transportFee'] is num) ? (data['transportFee'] as num).toDouble() : 0.0;
      final distanceKm = (data['distanceKm'] is num) ? (data['distanceKm'] as num).toDouble() : 0.0;
      final timeMultiplier = (data['timeMultiplier'] is num) ? (data['timeMultiplier'] as num).toDouble() : 1.0;
      final totalAmount = (data['totalAmount'] is num) ? (data['totalAmount'] as num).toDouble() : 0.0;
      
      final List<dynamic> items = data['items'] is List ? (data['items'] as List) : [];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'CAREBIKE',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Color(0xFFD32F2F),
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Motorcycle Rescue Service',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600, letterSpacing: 0.5),
          ),
          if (dateStr.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Date: $dateStr', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          ],
          const SizedBox(height: 24),
          const Divider(thickness: 1, height: 1),
          const SizedBox(height: 16),
          
          _buildSectionTitle('CUSTOMER INFORMATION'),
          _buildInfoRow('Name', customerName),
          _buildInfoRow('Phone', customerPhone),
          _buildInfoRow('Vehicle', vehicleName),
          _buildInfoRow('Plate', vehiclePlate),
          
          const SizedBox(height: 16),
          const Divider(thickness: 1, height: 1),
          const SizedBox(height: 16),
          
          _buildSectionTitle('STAFF INFORMATION'),
          _buildInfoRow('Staff Code', staffCode),
          _buildInfoRow('Name', staffName),
          
          const SizedBox(height: 16),
          const Divider(thickness: 1, height: 1),
          const SizedBox(height: 16),
          
          _buildSectionTitle('SERVICES USED'),
          if (laborCost > 0)
            _buildPriceRow('Rescue labor fee', laborCost, currencyFormat),
          
          ...items.map((itemDynamic) {
            final item = itemDynamic as Map<String, dynamic>? ?? {};
            final name = item['name']?.toString() ?? '';
            final qty = (item['quantity'] is num) ? (item['quantity'] as num).toInt() : 1;
            final price = (item['price'] is num) ? (item['price'] as num).toDouble() : 0.0;
            final itemTotal = price * qty;
            return _buildPriceRow('$name x$qty', itemTotal, currencyFormat);
          }),
          
          if (transportFee > 0)
            _buildPriceRow('Staff travel (${distanceKm.toStringAsFixed(1)}km - Round trip)', transportFee, currencyFormat),
          
          const SizedBox(height: 16),
          const Divider(thickness: 2, height: 1, color: Colors.black87),
          const SizedBox(height: 16),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('TOTAL', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              Text(
                currencyFormat.format(totalAmount),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFFD32F2F)),
              ),
            ],
          ),
        ],
      ),
    );
    } catch (e, stack) {
      // If ANY error occurs during parsing or layout (like missing fields or wrong types), fallback to raw text
      // We also display the error at the top so we can debug it
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("UI Error: ${e.toString()}", style: const TextStyle(color: Colors.red, fontSize: 12)),
          const SizedBox(height: 8),
          Text(jsonData, style: const TextStyle(fontSize: 14, height: 1.6)),
        ]
      );
    }
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.grey.shade700, letterSpacing: 0.5),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, double amount, NumberFormat format) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
          const SizedBox(width: 16),
          Text(format.format(amount), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
