import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/network/web_socket_service.dart';
import 'package:mobile_app/core/theme/theme.dart';
import 'package:mobile_app/features/appointment/screens/customer_appointment_screen.dart';
import 'package:mobile_app/features/maintenance/models/maintenance.dart';
import 'package:mobile_app/features/maintenance/widgets/invoice_widget.dart';
import 'package:mobile_app/features/auth/providers/auth_provider.dart'; // Get ID directly from Auth

class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  List<MaintenanceRecord> _rescueRecords = [];
  List<MaintenanceRecord> _serviceRecords = [];
  bool _isLoading = true;
  String? _error;
  StreamSubscription? _wsSubscription;

  @override
  void initState() {
    super.initState();
    _load();
    _wsSubscription = WebSocketService.appointmentStreamController.stream
        .listen((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    // Show the spinner immediately
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Read straight from the Provider to avoid context/delay issues
      final userId = _currentCustomerId();
      if (userId == null) throw Exception('Not signed in.');

      final response = await ApiClient.get('/maintenance/customer/$userId');
      final data = ApiClient.parseResponse(response);

      if (data is List) {
        _rescueRecords = [];
        _serviceRecords = [];
        for (var e in data) {
          final record = MaintenanceRecord.fromJson(e as Map<String, dynamic>);
          if (record.serviceDetails != null && record.serviceDetails!.contains('"sourceType":"APPOINTMENT"')) {
            _serviceRecords.add(record);
          } else {
            _rescueRecords.add(record);
          }
        }
        
        int compareRecords(MaintenanceRecord a, MaintenanceRecord b) {
          final dateCompare = b.serviceDate.compareTo(a.serviceDate);
          if (dateCompare != 0) return dateCompare;
          return b.id.compareTo(a.id);
        }
        
        _rescueRecords.sort(compareRecords);
        _serviceRecords.sort(compareRecords);
      } else {
        _rescueRecords = [];
        _serviceRecords = [];
      }
    } on ApiException catch (e) {
      // Catch 404 (no history -> new customer)
      if (e.statusCode == 404) {
        _rescueRecords = [];
        _serviceRecords = []; // Empty list to show the "no history" UI
      } else {
        _error = e.message;
      }
    } catch (e) {
      _error = 'Could not load history: $e';
    } finally {
      // Always stop the spinner whether it succeeds or fails
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _totalCost(List<MaintenanceRecord> records) {
    final total = records.fold<double>(0, (s, r) => s + (r.totalCost ?? 0));
    final n = total
        .toStringAsFixed(0)
        .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.');
    return '₫$n';
  }

  int? _currentCustomerId() {
    final user = context.read<AuthProvider>().mysqlUser;
    final value = user?['userId'] ?? user?['id'] ?? user?['user']?['id'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        appBar: AppBar(
          title: const Text('History'),
          centerTitle: true,
          backgroundColor: AppColors.canvas,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          bottom: TabBar(
            labelColor: AppColors.primaryDeep,
            unselectedLabelColor: AppColors.inkMuted,
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w800),
            tabs: const [
              Tab(text: 'Rescue'),
              Tab(text: 'Appointment'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildRecordTab(_rescueRecords, 'No rescue history yet'),
            _buildRecordTab(_serviceRecords, 'No appointment history yet'),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordTab(List<MaintenanceRecord> records, String emptyMessage) {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            )
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.cloud_off_outlined,
                    size: 52,
                    color: AppColors.edge,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(color: AppColors.inkMuted),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _load,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : records.isEmpty
          ? ListView(
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.build_circle_outlined,
                          size: 72,
                          color: AppColors.edge,
                        ),
                        SizedBox(height: 16),
                        Text(
                          emptyMessage,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          : ListView(
              physics:
                  const AlwaysScrollableScrollPhysics(), // Always allow pull-to-refresh
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                // Summary header
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'THIS YEAR',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.faint,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${records.length} records · ${_totalCost(records)}',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.primaryMuted,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.build_rounded,
                          size: 22,
                          color: AppColors.primaryHover,
                        ),
                      ),
                    ],
                  ),
                ),
                for (var i = 0; i < records.length; i++) ...[
                  _RecordCard(record: records[i], index: i),
                  const SizedBox(height: 12),
                ],
              ],
            ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  final MaintenanceRecord record;
  final int index;
  const _RecordCard({required this.record, required this.index});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => _HistoryBillScreen(record: record)),
        );
      },
      child: Container(
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
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            children: [
              // ── Timeline strip ──────────────────────────────────────────
              Container(
                width: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primaryLight, AppColors.primaryMuted],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.receipt_long_rounded,
                      size: 21,
                      color: AppColors.primaryHover,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '#${index + 1}',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.primaryDeep,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Details ─────────────────────────────────────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              record.formattedDate,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                          Text(
                            record.formattedCost,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryHover,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.inkMuted,
                            size: 20,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (record.branchName != null) ...[
                            Icon(
                              Icons.location_on_outlined,
                              size: 14,
                              color: AppColors.faint,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              record.branchName!,
                              style: TextStyle(
                                color: AppColors.faint,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 14),
                          ],
                          if (record.currentKm != null) ...[
                            Icon(
                              Icons.speed_outlined,
                              size: 14,
                              color: AppColors.faint,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${record.currentKm} km',
                              style: TextStyle(
                                color: AppColors.faint,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (record.serviceDetails != null &&
                          record.serviceDetails!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.fieldFill,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _previewDetails(record.serviceDetails!),
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.inkMuted,
                              height: 1.4,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _previewDetails(String details) {
    final invoice = _tryDecodeInvoice(details);
    if (invoice == null) return details;

    final items = invoice['items'];
    if (items is List && items.isNotEmpty) {
      return items
          .map((item) {
            final map = item is Map ? item : const {};
            final name = map['name']?.toString() ?? 'Service';
            final quantity = map['quantity']?.toString() ?? '1';
            return '$name x$quantity';
          })
          .join(', ');
    }

    final laborCost = invoice['laborCost'];
    return laborCost is num ? 'Rescue labor fee' : 'Tap to view bill';
  }
}

class _HistoryBillScreen extends StatelessWidget {
  final MaintenanceRecord record;
  const _HistoryBillScreen({required this.record});

  @override
  Widget build(BuildContext context) {
    final invoiceJson = _isInvoiceJson(record.serviceDetails)
        ? record.serviceDetails!.trim()
        : null;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('Bill Details'),
        centerTitle: true,
        backgroundColor: AppColors.canvas,
        surfaceTintColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: invoiceJson != null
            ? InvoiceWidget(jsonData: invoiceJson)
            : _SimpleBillCard(record: record),
      ),
    );
  }
}

class _SimpleBillCard extends StatelessWidget {
  final MaintenanceRecord record;
  const _SimpleBillCard({required this.record});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: AppStyles.card(radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CareBikeBillLogo(size: 28),
          Text(
            'Maintenance Service Bill',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.inkMuted, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            'Date: ${record.formattedDate}',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.inkMuted, fontSize: 12),
          ),
          const Divider(height: 28),
          _billRow('Branch', record.branchName ?? 'N/A'),
          if (record.currentKm != null)
            _billRow('Current km', '${record.currentKm} km'),
          if (record.serviceDetails != null &&
              record.serviceDetails!.trim().isNotEmpty) ...[
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
            Text(
              record.serviceDetails!.trim(),
              style: TextStyle(color: AppColors.ink, height: 1.45),
            ),
          ],
          const Divider(thickness: 1.5, height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TOTAL',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
              ),
              Text(
                record.formattedCost,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  color: AppColors.primaryHover,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _billRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(label, style: TextStyle(color: AppColors.inkMuted)),
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
}

bool _isInvoiceJson(String? details) => _tryDecodeInvoice(details) != null;

Map<String, dynamic>? _tryDecodeInvoice(String? details) {
  final text = details?.trim();
  if (text == null || text.isEmpty) return null;

  try {
    final decoded = jsonDecode(text);
    if (decoded is! Map<String, dynamic>) return null;

    final looksLikeInvoice =
        decoded.containsKey('totalAmount') ||
        decoded.containsKey('items') ||
        decoded.containsKey('customerName');
    return looksLikeInvoice ? decoded : null;
  } catch (_) {
    return null;
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
