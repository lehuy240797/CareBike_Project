import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/theme/theme.dart';
import 'package:mobile_app/features/maintenance/models/maintenance.dart';
import 'package:mobile_app/features/auth/providers/auth_provider.dart'; // Get ID directly from Auth
import 'package:mobile_app/features/maintenance/widgets/invoice_widget.dart';

class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  List<MaintenanceRecord> _records = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    // Show the spinner immediately
    setState(() { _isLoading = true; _error = null; });

    try {
      // Read straight from the Provider to avoid context/delay issues
      final userId = context.read<AuthProvider>().mysqlUser?['userId'];
      if (userId == null) throw Exception('Not signed in.');

      final response = await ApiClient.get('/maintenance/customer/$userId');
      final data = ApiClient.parseResponse(response);

      if (data is List) {
        _records = data.map((e) => MaintenanceRecord.fromJson(e as Map<String, dynamic>)).toList();
      } else {
        _records = [];
      }
    } on ApiException catch (e) {
      // Catch 404 (no history -> new customer)
      if (e.statusCode == 404) {
        _records = []; // Empty list to show the "no history" UI
      } else {
        _error = e.message;
      }
    } catch (e) {
      _error = 'Could not load history: $e';
    } finally {
      // Always stop the spinner whether it succeeds or fails
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  String _totalCost() {
    final total = _records.fold<double>(0, (s, r) => s + (r.totalCost ?? 0));
    final n = total.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.');
    return '₫$n';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('Repair history'),
        centerTitle: true,
        backgroundColor: AppColors.canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _load,
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _error != null
                ? Center(child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_off_outlined, size: 52, color: AppColors.edge),
                      const SizedBox(height: 12),
                      Text(_error!, style: TextStyle(color: AppColors.inkMuted)),
                      const SizedBox(height: 12),
                      TextButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ))
                : _records.isEmpty
                    ? ListView(
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.6,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.build_circle_outlined, size: 72, color: AppColors.edge),
                                  SizedBox(height: 16),
                                  Text('No maintenance history yet',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.ink)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    : ListView(
                        physics: const AlwaysScrollableScrollPhysics(), // Always allow pull-to-refresh
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
                                    Text('THIS YEAR',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.faint, letterSpacing: 1)),
                                    const SizedBox(height: 2),
                                    Text('${_records.length} services · ${_totalCost()}',
                                        style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink)),
                                  ],
                                ),
                                Container(
                                  width: 40, height: 40,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(color: AppColors.primaryMuted, borderRadius: BorderRadius.circular(12)),
                                  child: Icon(Icons.build_rounded, size: 22, color: AppColors.primaryHover),
                                ),
                              ],
                            ),
                          ),
                          for (var i = 0; i < _records.length; i++) ...[
                            _RecordCard(record: _records[i], index: i),
                            const SizedBox(height: 12),
                          ],
                        ],
                      ),
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
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.edge),
        boxShadow: [BoxShadow(color: AppColors.primaryDeep.withValues(alpha: 0.06), blurRadius: 22, offset: const Offset(0, 8))],
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          children: [
            // ── Timeline strip ──────────────────────────────────────────
            Container(
              width: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.primaryLight, AppColors.primaryMuted], begin: Alignment.topCenter, end: Alignment.bottomCenter),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.build_rounded, size: 21, color: AppColors.primaryHover),
                  const SizedBox(height: 4),
                  Text('#${index + 1}',
                      style: TextStyle(fontSize: 10, color: AppColors.primaryDeep, fontWeight: FontWeight.w700)),
                ],
              ),
            ),

            // ── Details ─────────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(record.formattedDate,
                            style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink, fontSize: 13.5)),
                        Text(record.formattedCost,
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: AppColors.primaryHover, fontSize: 15)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (record.branchName != null) ...[
                          Icon(Icons.location_on_outlined, size: 14, color: AppColors.faint),
                          const SizedBox(width: 4),
                          Text(record.branchName!, style: TextStyle(color: AppColors.faint, fontSize: 11.5, fontWeight: FontWeight.w500)),
                          const SizedBox(width: 14),
                        ],
                        if (record.currentKm != null) ...[
                          Icon(Icons.speed_outlined, size: 14, color: AppColors.faint),
                          const SizedBox(width: 4),
                          Text('${record.currentKm} km', style: TextStyle(color: AppColors.faint, fontSize: 11.5, fontWeight: FontWeight.w500)),
                        ],
                      ],
                    ),
                    if (record.serviceDetails != null && record.serviceDetails!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                        decoration: BoxDecoration(
                          color: AppColors.fieldFill,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(record.serviceDetails!,
                          style: TextStyle(fontSize: 12, color: AppColors.inkMuted, height: 1.4),
                          maxLines: 3, overflow: TextOverflow.ellipsis,
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
    );
  }
}