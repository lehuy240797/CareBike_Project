import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/theme/theme.dart';
import 'package:mobile_app/features/branch/screens/branch_create_bill_screen.dart';
import 'package:mobile_app/features/rescue/rescue_store.dart';

class BranchRescueScreen extends StatefulWidget {
  final int branchId;
  const BranchRescueScreen({super.key, required this.branchId});

  @override
  State<BranchRescueScreen> createState() => _BranchRescueScreenState();
}

class _BranchRescueScreenState extends State<BranchRescueScreen> {
  RescueStore get _store => RescueStore.instance;

  @override
  void initState() {
    super.initState();
    // Idempotent — the dashboard usually starts this first; safe to call again.
    _store.init(widget.branchId);
  }

  // PHONE CALL (only works on a real device)
  Future<void> _callCustomer(String phone) async {
    final Uri uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot make calls on an emulator.')),
        );
      }
    }
  }

  // MAP: open a proper Google Maps URL for directions
  Future<void> _openGoogleMaps(double destLat, double destLng) async {
    final String googleMapsUrl =
        'https://www.google.com/maps/dir/?api=1&destination=$destLat,$destLng';
    final Uri uri = Uri.parse(googleMapsUrl);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No map app found on this device.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: could not launch the map.')),
        );
      }
    }
  }

  Future<void> _acceptRescue(int rescueId) async {
    final ok = await _store.accept(rescueId);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Case accepted! Switch to the "In progress" tab to view it.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('An error occurred while accepting the case.'),
        ),
      );
    }
  }

  Future<void> _openCreateBill(dynamic rescue) async {
    final customer = rescue['customer'];
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BranchCreateBillScreen(
          rescueId: rescue['id'] as int,
          customerName: customer?['fullName'] ?? 'Customer',
          rescueData: Map<String, dynamic>.from(rescue as Map),
        ),
      ),
    );
    if (result == true) {
      await _store.fetch();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        appBar: AppBar(
          title: const Text('Rescue Dispatch'),
          titleTextStyle: GoogleFonts.poppins(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
          backgroundColor: AppColors.danger,
          foregroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => _store.fetch(),
            ),
          ],
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelStyle: TextStyle(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
            tabs: [
              Tab(text: 'PENDING'),
              Tab(text: 'IN PROGRESS'),
              Tab(text: 'COMPLETED'),
            ],
          ),
        ),
        body: ListenableBuilder(
          listenable: _store,
          builder: (context, _) {
            if (_store.loading) {
              return Center(
                child: CircularProgressIndicator(color: AppColors.danger),
              );
            }
            return TabBarView(
              children: [
                _buildList(_store.pending, isPending: true, isCompleted: false),
                _buildList(
                  _store.accepted,
                  isPending: false,
                  isCompleted: false,
                ),
                _buildList(
                  _store.completed,
                  isPending: false,
                  isCompleted: true,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // SHARED LIST BUILDER FOR TABS
  Widget _buildList(
    List<dynamic> list, {
    required bool isPending,
    required bool isCompleted,
  }) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              size: 76,
              color: AppColors.edge,
            ),
            const SizedBox(height: 16),
            Text(
              isCompleted
                  ? 'No completed cases yet.'
                  : (isPending
                        ? 'No new rescue requests.'
                        : 'No cases in progress yet.'),
              style: GoogleFonts.poppins(
                color: AppColors.inkMuted,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      itemCount: list.length,
      itemBuilder: (context, index) {
        return _buildRescueCard(
          list[index],
          isPending: isPending,
          isCompleted: isCompleted,
        );
      },
    );
  }

  // INFO CARD
  Widget _buildRescueCard(
    dynamic r, {
    required bool isPending,
    required bool isCompleted,
  }) {
    final customer = r['customer'];
    final vehicle = r['vehicle'];
    final vehicleName = vehicle?['vehicleName'] ?? vehicle?['model'] ?? '';
    final accent = isCompleted
        ? AppColors.success
        : (isPending ? AppColors.danger : const Color(0xFF2563EB));

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.edge),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDeep.withValues(alpha: 0.07),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: accent, width: 5)),
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Request #${r['id']}',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                    fontSize: 16,
                  ),
                ),
                Icon(
                  isPending
                      ? Icons.warning_amber_rounded
                      : Icons.engineering_rounded,
                  color: isPending ? const Color(0xFFF59E0B) : accent,
                  size: 22,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(height: 1, color: AppColors.edge),
            const SizedBox(height: 12),
            Text(
              "Customer: ${customer['fullName'] ?? 'Anonymous'}",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: AppColors.dangerBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Text(
                "⚠️ Issue: ${r['issueDescription']}",
                style: TextStyle(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: AppColors.fieldFill,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "🏍️ Vehicle: ${vehicle['brand']} $vehicleName",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "🏷️ Plate: ${vehicle['licensePlate']}",
                    style: TextStyle(color: AppColors.inkMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Call & map buttons are always visible for staff (unless completed)
            if (!isCompleted)
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: FilledButton.icon(
                        onPressed: () => _callCustomer(customer['phone']),
                        icon: const Icon(Icons.phone_rounded, size: 18),
                        label: const Text('Call'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: FilledButton.icon(
                        onPressed: () =>
                            _openGoogleMaps(r['latitude'], r['longitude']),
                        icon: const Icon(Icons.map_rounded, size: 18),
                        label: const Text('Map'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

            if (isCompleted)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    'PAID & COMPLETED',
                    style: TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

            // On the Pending tab -> show the Accept button
            if (isPending) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  onPressed: () => _acceptRescue(r['id']),
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: const Text(
                    'ACCEPT THIS CASE',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ] else if (!isCompleted) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  onPressed: () => _openCreateBill(r),
                  icon: const Icon(Icons.receipt_long_rounded),
                  label: const Text(
                    'CREATE TEMPORARY BILL',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
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
          ],
        ),
      ),
    );
  }
}
