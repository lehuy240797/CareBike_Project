import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:mobile_app/core/theme/theme.dart';
import 'package:mobile_app/core/theme/theme_controller.dart';
import 'package:mobile_app/features/auth/providers/auth_provider.dart';
import 'package:mobile_app/core/network/web_socket_service.dart';
import 'package:mobile_app/features/rescue/rescue_store.dart';
import 'package:mobile_app/features/branch/screens/branch_customer_intake_screen.dart';
import 'package:mobile_app/features/branch/screens/branch_rescue_screen.dart';
import 'package:mobile_app/features/branch/screens/branch_tire_assistant_screen.dart';
import 'package:mobile_app/features/branch/screens/branch_walk_in_repair_screen.dart';
import 'package:mobile_app/features/branch/widgets/sos_alert_dialog.dart';
import 'package:mobile_app/core/network/api_client.dart';

/// Main navigation screen for branch staff.
/// Includes a BottomNavigationBar, QR scanning, and feature tabs.
class BranchMobileDashboard extends StatefulWidget {
  const BranchMobileDashboard({super.key});

  @override
  State<BranchMobileDashboard> createState() => _BranchMobileDashboardState();
}

class _BranchMobileDashboardState extends State<BranchMobileDashboard> {
  int _currentIndex = 0;
  int _appointmentRefreshToken = 0;
  List<dynamic> _pendingAppointmentPreview = [];
  bool _isScanning = false;
  final MobileScannerController _scannerController = MobileScannerController();

  StreamSubscription<Map<String, dynamic>>? _sosSub;
  bool _rescueInit = false;
  bool _alertOpen = false;

  @override
  void initState() {
    super.initState();
    // Raise the emergency alarm for any brand-new, unaccepted SOS — from any tab.
    _sosSub = RescueStore.instance.onNewSos.listen(_handleNewSos);
  }

  @override
  void dispose() {
    _sosSub?.cancel();
    RescueStore.instance.shutdown();
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _handleNewSos(Map<String, dynamic> rescue) async {
    if (!mounted || _alertOpen) return;
    _alertOpen = true;
    await showSosAlert(
      context,
      rescue,
      onAccept: () => RescueStore.instance.accept(rescue['id']),
      onView: () => setState(() => _currentIndex = 1),
      onCall: () => _callPhone(rescue['customer']?['phone']),
    );
    _alertOpen = false;
  }

  Future<void> _callPhone(String? phone) async {
    if (phone == null) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  /// Extract the branch ID from stored user data
  int? _getBranchId(AuthProvider auth) {
    final userMap = auth.mysqlUser;
    return userMap?['branchId'] ??
        userMap?['branch']?['id'] ??
        userMap?['user']?['branchId'] ??
        userMap?['user']?['branch']?['id'] ??
        userMap?['branch_id'];
  }

  /// Handle QR detection
  void _onDetect(BarcodeCapture capture, int branchId) async {
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty && !_isScanning) {
      final String? code = barcodes.first.rawValue;
      if (code != null) {
        setState(() => _isScanning = true);
        _scannerController.stop();

        try {
          // Decode the customer QR data
          final Map<String, dynamic> qrData = jsonDecode(code);
          final int customerId = qrData['customerId'];
          final String customerName = qrData['fullName'] ?? 'Customer';

          if (!mounted) return;

          Navigator.pop(context);
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BranchCustomerIntakeScreen(
                branchId: branchId,
                customerId: customerId,
                customerName: customerName,
              ),
            ),
          );
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Invalid QR code. Please scan the code from the CareBike app.',
              ),
              backgroundColor: AppColors.danger,
            ),
          );
        } finally {
          if (mounted) {
            setState(() => _isScanning = false);
            _scannerController.start();
          }
        }
      }
    }
  }

  /// Open the QR-scanner BottomSheet
  void _openQRScanner(int branchId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            AppBar(
              title: const Text('Scan customer QR'),
              leading: const CloseButton(),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
                child: MobileScanner(
                  controller: _scannerController,
                  onDetect: (capture) => _onDetect(capture, branchId),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _pendingAptCount = 0;

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeController>(); // rebuild on dark-mode toggle
    final auth = context.watch<AuthProvider>();
    final branchId = _getBranchId(auth);

    // Start the rescue radar once the branch id is known.
    if (branchId != null && !_rescueInit) {
      _rescueInit = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => RescueStore.instance.init(branchId),
      );
    }

    final List<Widget> pages = [
      _BranchHomeTab(
        auth: auth,
        pendingAptCount: _pendingAptCount,
        pendingAppointments: _pendingAppointmentPreview,
        onWalkInRepair: () async {
          if (branchId == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Branch data is still loading.'),
                backgroundColor: AppColors.danger,
              ),
            );
            return;
          }
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => BranchWalkInRepairScreen(branchId: branchId),
            ),
          );
          if (created == true && mounted) {
            setState(() {
              _appointmentRefreshToken++;
              _currentIndex = 2;
            });
          }
        },
        onViewRescues: () => setState(() => _currentIndex = 1),
        onViewAppointments: () => setState(() => _currentIndex = 2),
        onTireAssistant: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BranchTireAssistantScreen()),
          );
        },
      ),
      branchId != null
          ? BranchRescueScreen(branchId: branchId)
          : const Center(child: Text('Loading branch data...')),
      branchId != null
          ? _BranchAppointmentTab(
              branchId: branchId,
              refreshToken: _appointmentRefreshToken,
              onPendingCountChanged: (count) {
                if (mounted) setState(() => _pendingAptCount = count);
              },
              onPendingAppointmentsChanged: (items) {
                if (mounted) {
                  setState(() => _pendingAppointmentPreview = items);
                }
              },
            )
          : const Center(child: Text('Loading branch data...')),
      _BranchProfileTab(),
    ];

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: IndexedStack(index: _currentIndex, children: pages),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFFFB923C), Color(0xFFF97316), Color(0xFFEA580C)],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.45),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: branchId == null ? null : () => _openQRScanner(branchId),
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          highlightElevation: 0,
          shape: const CircleBorder(),
          child: const Icon(Icons.qr_code_scanner, size: 28),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(icon: Icons.home_rounded, label: 'Home', index: 0),
              _buildNavItem(
                icon: Icons.engineering_rounded,
                label: 'Rescue',
                index: 1,
              ),
              const SizedBox(width: 48), // Center gap for the FAB
              _buildNavItem(
                icon: Icons.calendar_month_rounded,
                label: 'Bookings',
                index: 2,
              ),
              _buildNavItem(
                icon: Icons.person_rounded,
                label: 'Profile',
                index: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? AppColors.primaryDeep : AppColors.inkMuted;
    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      highlightColor: Colors.transparent,
      splashColor: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 46,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primaryMuted : Colors.transparent,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Home tab: greeting and overview stats
class _BranchHomeTab extends StatelessWidget {
  final AuthProvider auth;
  final VoidCallback onWalkInRepair;
  final VoidCallback onTireAssistant;
  final VoidCallback onViewRescues;
  final VoidCallback onViewAppointments;
  final int pendingAptCount;
  final List<dynamic> pendingAppointments;

  const _BranchHomeTab({
    required this.auth,
    required this.onWalkInRepair,
    required this.onTireAssistant,
    required this.onViewRescues,
    required this.onViewAppointments,
    required this.pendingAptCount,
    required this.pendingAppointments,
  });

  @override
  Widget build(BuildContext context) {
    final fullName = auth.mysqlUser?['fullName'];
    final email = auth.firebaseUser?.email;
    final displayName = (fullName != null && fullName.toString().isNotEmpty)
        ? fullName
        : email;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        children: [
          // Brand header: CAREBIKE wordmark + STAFF badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'CARE',
                    style: GoogleFonts.montserrat(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      fontStyle: FontStyle.italic,
                      color: AppColors.primary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    'BIKE',
                    style: GoogleFonts.montserrat(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      fontStyle: FontStyle.italic,
                      color: AppColors.ink,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryMuted,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'STAFF',
                  style: GoogleFonts.poppins(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: AppColors.primaryDeep,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Hello,',
            style: GoogleFonts.poppins(
              fontSize: 25,
              fontWeight: FontWeight.w800,
              height: 1.1,
              letterSpacing: -0.5,
              color: AppColors.ink,
            ),
          ),
          Text(
            '$displayName',
            style: GoogleFonts.poppins(
              fontSize: 25,
              fontWeight: FontWeight.w800,
              height: 1.1,
              letterSpacing: -0.5,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Branch management',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.inkMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          // Live rescue stats + SOS queue — rebuilds whenever the store changes.
          ListenableBuilder(
            listenable: RescueStore.instance,
            builder: (context, _) {
              final sos = RescueStore.instance.pending;
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          title: 'Pending appointments',
                          value: '$pendingAptCount',
                          icon: Icons.calendar_today_rounded,
                          color: const Color(0xFF2563EB),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _buildStatCard(
                          title: 'Urgent rescues',
                          value: '${sos.length}',
                          icon: Icons.sos_rounded,
                          color: const Color(0xFFDC2626),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _homeActionCard(
                    icon: Icons.person_add_alt_1_rounded,
                    title: 'Walk-in repair',
                    subtitle: 'Create order for customer without account',
                    onTap: onWalkInRepair,
                  ),
                  const SizedBox(height: 12),
                  _homeActionCard(
                    icon: Icons.center_focus_strong_rounded,
                    title: 'AI tire assistant',
                    subtitle: 'Quick tire scan with replacement options',
                    onTap: onTireAssistant,
                  ),
                  if (sos.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildSosQueue(context, sos),
                  ],
                  if (pendingAppointments.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildAppointmentQueue(context, pendingAppointments),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _homeActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.edge),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryDeep.withValues(alpha: 0.07),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primaryMuted,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: AppColors.primaryHover, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.inkMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.hairline),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.edge),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDeep.withValues(alpha: 0.07),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.inkMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Red, attention-grabbing list of unaccepted SOS cases on the dashboard.
  Widget _buildSosQueue(BuildContext context, List<dynamic> sos) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.dangerBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: AppColors.danger.withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFDC2626),
                ),
                child: const Icon(
                  Icons.sos_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'SOS — NEEDS RESPONSE',
                  style: GoogleFonts.poppins(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.danger,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${sos.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...sos.take(4).map((r) => _buildSosTile(context, r)),
          if (sos.length > 4)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '+ ${sos.length - 4} more',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.danger,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAppointmentQueue(
    BuildContext context,
    List<dynamic> appointments,
  ) {
    const amber = Color(0xFFF59E0B);
    final isDark = ThemeController.instance.isDark;
    final amberBg = isDark
        ? Color.alphaBlend(amber.withValues(alpha: 0.13), AppColors.surface)
        : AppColors.warningBg;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: amberBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: amber.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: amber.withValues(alpha: isDark ? 0.08 : 0.16),
            blurRadius: isDark ? 14 : 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: amber,
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'APPOINTMENTS — WAITING CONFIRM',
                  style: GoogleFonts.poppins(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFB45309),
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: amber,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${appointments.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...appointments.take(4).map((apt) => _buildAppointmentTile(apt)),
          if (appointments.length > 4)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '+ ${appointments.length - 4} more',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFB45309),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAppointmentTile(dynamic apt) {
    final name =
        apt['customerName']?.toString() ??
        apt['customer']?['fullName']?.toString() ??
        'Customer';
    final note = apt['note']?.toString();
    final date = DateTime.tryParse(apt['appointmentDate']?.toString() ?? '');
    final time = date == null
        ? 'No time'
        : DateFormat('HH:mm - dd/MM/yyyy').format(date.toLocal());

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: const Border(
          left: BorderSide(color: Color(0xFFF59E0B), width: 4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: GoogleFonts.poppins(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ),
              Text(
                '#${apt['id']}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFD97706),
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            time,
            style: TextStyle(
              fontSize: 12.5,
              color: AppColors.inkMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (note != null && note.trim().isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              note,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.inkMuted,
                height: 1.3,
              ),
            ),
          ],
          const SizedBox(height: 11),
          SizedBox(
            height: 40,
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onViewAppointments,
              icon: const Icon(Icons.calendar_today_rounded, size: 17),
              label: const Text(
                'View in bookings',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSosTile(BuildContext context, dynamic r) {
    final customer = (r['customer'] as Map?) ?? const {};
    final name = customer['fullName'] ?? 'Anonymous rider';
    final issue = r['issueDescription'] ?? 'Emergency assistance requested';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: AppColors.danger, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: GoogleFonts.poppins(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ),
              Text(
                '#${r['id']}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.danger,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            '⚠️ $issue',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              color: AppColors.danger,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: FilledButton.icon(
                    onPressed: () async {
                      final ok = await RescueStore.instance.accept(r['id']);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              ok
                                  ? 'Case #${r['id']} accepted.'
                                  : 'Could not accept the case.',
                            ),
                            backgroundColor: ok ? Colors.green : null,
                          ),
                        );
                      }
                    },
                    icon: const Icon(
                      Icons.check_circle_outline_rounded,
                      size: 17,
                    ),
                    label: const Text(
                      'Accept',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              SizedBox(
                height: 40,
                child: OutlinedButton(
                  onPressed: onViewRescues,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: BorderSide(
                      color: AppColors.danger.withValues(alpha: 0.5),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                  ),
                  child: const Text(
                    'View',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Appointments tab: fetch and show pending appointments
class _BranchAppointmentTab extends StatefulWidget {
  final int branchId;
  final int refreshToken;
  final ValueChanged<int>? onPendingCountChanged;
  final ValueChanged<List<dynamic>>? onPendingAppointmentsChanged;

  const _BranchAppointmentTab({
    required this.branchId,
    this.refreshToken = 0,
    this.onPendingCountChanged,
    this.onPendingAppointmentsChanged,
  });

  @override
  State<_BranchAppointmentTab> createState() => _BranchAppointmentTabState();
}

class _BranchAppointmentTabState extends State<_BranchAppointmentTab> {
  List<dynamic> _pendingApts = [];
  List<dynamic> _confirmedApts = [];
  List<dynamic> _completedApts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAppointments();

    // Initialize WebSocket connection to listen for new appointments in real-time
    WebSocketService.connectBranchAppointments(widget.branchId, (
      updatedAppointment,
    ) {
      if (mounted) {
        _fetchAppointments();
        final status = updatedAppointment['status']?.toString().toUpperCase();
        if (status == 'PENDING') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('≡ƒÜ¿ New maintenance appointment! Please check.'),
              backgroundColor: Colors.blue,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 4),
            ),
          );
        } else if (status == 'COMPLETED') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('✅ Customer has paid their bill!'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    });
  }

  @override
  void didUpdateWidget(covariant _BranchAppointmentTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      _fetchAppointments();
    }
  }

  @override
  void dispose() {
    WebSocketService.disconnect();
    super.dispose();
  }

  Future<void> _fetchAppointments() async {
    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.firebaseUser;
      if (user == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      String? token = await user.getIdToken();

      final response = await http.get(
        Uri.parse(
          '${ApiClient.baseUrl}/appointments/branch/${widget.branchId}',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json; charset=UTF-8',
        },
      );
      final walkInResponse = await http.get(
        Uri.parse(
          '${ApiClient.baseUrl}/walk-in-repairs/branch/${widget.branchId}',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json; charset=UTF-8',
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is! List) {
          throw Exception("Unexpected appointments response");
        }

        final walkIns = walkInResponse.statusCode == 200
            ? jsonDecode(utf8.decode(walkInResponse.bodyBytes))
            : [];
        final combined = [...decoded, if (walkIns is List) ...walkIns];

        final appointments = await _attachInvoiceVehicleInfo(combined, token!);

        final pendingApts = appointments
            .where((apt) => _appointmentStatus(apt) == 'PENDING')
            .toList();
        final confirmedApts = appointments
            .where(
              (apt) =>
                  _appointmentStatus(apt) == 'CONFIRMED' ||
                  _appointmentStatus(apt) == 'PAYING',
            )
            .toList();
        final completedApts = appointments
            .where((apt) => _appointmentStatus(apt) == 'COMPLETED')
            .toList();

        pendingApts.sort(_sortByDateThenIdDesc);
        confirmedApts.sort(_sortByDateThenIdDesc);
        completedApts.sort(_sortByCompletedBillDesc);

        if (mounted) {
          setState(() {
            _pendingApts = pendingApts;
            _confirmedApts = confirmedApts;
            _completedApts = completedApts;
            _isLoading = false;
          });
          widget.onPendingCountChanged?.call(pendingApts.length);
          widget.onPendingAppointmentsChanged?.call(
            List<dynamic>.from(pendingApts),
          );
        }
      } else {
        throw Exception("Failed to retrieve data");
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint("Error retrieving appointments: $e");
    }
  }

  String _appointmentStatus(dynamic appointment) {
    if (appointment is! Map) return '';
    return appointment['status']?.toString().toUpperCase() ?? '';
  }

  int _sortByDateThenIdDesc(dynamic a, dynamic b) {
    final aDate = DateTime.tryParse(a['appointmentDate']?.toString() ?? '');
    final bDate = DateTime.tryParse(b['appointmentDate']?.toString() ?? '');
    final dateCompare = (bDate ?? DateTime(1900)).compareTo(
      aDate ?? DateTime(1900),
    );
    if (dateCompare != 0) return dateCompare;
    return (_asInt(b['id']) ?? 0).compareTo(_asInt(a['id']) ?? 0);
  }

  int _sortByCompletedBillDesc(dynamic a, dynamic b) {
    final aTime = _completedBillTime(a);
    final bTime = _completedBillTime(b);
    final timeCompare = (bTime ?? DateTime(1900)).compareTo(
      aTime ?? DateTime(1900),
    );
    if (timeCompare != 0) return timeCompare;
    return (_asInt(b['id']) ?? 0).compareTo(_asInt(a['id']) ?? 0);
  }

  DateTime? _completedBillTime(dynamic appointment) {
    if (appointment is! Map) return null;

    final completedAt = DateTime.tryParse(
      appointment['completedAt']?.toString() ?? '',
    );
    if (completedAt != null) return completedAt;

    final appointmentInvoice = appointment['appointmentInvoice'];
    if (appointmentInvoice is Map) {
      final serviceDate = DateTime.tryParse(
        appointmentInvoice['serviceDate']?.toString() ?? '',
      );
      if (serviceDate != null) return serviceDate;

      final invoiceDate = _parseBillDate(appointmentInvoice['date']);
      if (invoiceDate != null) return invoiceDate;
    }

    final inlineInvoice = _parseInvoiceDetails(appointment['invoiceDetails']);
    if (inlineInvoice != null) {
      final invoiceDate = _parseBillDate(inlineInvoice['date']);
      if (invoiceDate != null) return invoiceDate;
    }

    return null;
  }

  Map<String, dynamic>? _parseInvoiceDetails(dynamic value) {
    final text = value?.toString();
    if (text == null || !text.trimLeft().startsWith('{')) return null;
    try {
      final decoded = jsonDecode(text);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  DateTime? _parseBillDate(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    final isoDate = DateTime.tryParse(text);
    if (isoDate != null) return isoDate;

    for (final pattern in ['HH:mm - dd/MM/yyyy', 'dd/MM/yyyy']) {
      try {
        return DateFormat(pattern).parseStrict(text);
      } catch (_) {
        // Try the next known bill date format.
      }
    }
    return null;
  }

  Future<List<dynamic>> _attachInvoiceVehicleInfo(
    List<dynamic> appointments,
    String token,
  ) async {
    final enriched = appointments
        .whereType<Map>()
        .map((appointment) => Map<String, dynamic>.from(appointment))
        .toList();
    final customerIds = enriched
        .map(
          (appointment) => _asInt(
            appointment['customer']?['id'] ?? appointment['customerId'],
          ),
        )
        .whereType<int>()
        .toSet();

    final invoiceByAppointmentId = <int, Map<String, dynamic>>{};
    final invoicesByCustomerId = <int, List<Map<String, dynamic>>>{};

    for (final customerId in customerIds) {
      try {
        final response = await http.get(
          Uri.parse('${ApiClient.baseUrl}/maintenance/customer/$customerId'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json; charset=UTF-8',
          },
        );

        if (response.statusCode != 200) continue;

        final records = jsonDecode(utf8.decode(response.bodyBytes));
        if (records is! List) continue;

        for (final record in records) {
          if (record is! Map) continue;
          final invoice = _parseInvoice(record['serviceDetails']);
          if (invoice == null) continue;

          invoice['serviceDate'] = record['serviceDate'];
          invoicesByCustomerId.putIfAbsent(customerId, () => []).add(invoice);

          final appointmentId = _asInt(invoice['appointmentId']);
          if (appointmentId == null) continue;
          invoiceByAppointmentId[appointmentId] = invoice;
        }
      } catch (e) {
        debugPrint(
          'Could not load maintenance invoice for customer $customerId: $e',
        );
      }
    }

    for (final appointment in enriched) {
      final invoice =
          invoiceByAppointmentId[_asInt(appointment['id'])] ??
          _findInvoiceByDate(
            appointment,
            invoicesByCustomerId[_asInt(appointment['customerId'])] ?? [],
          );
      if (invoice == null) continue;

      appointment['invoiceVehicleName'] = invoice['vehicleName'];
      appointment['invoiceVehiclePlate'] = invoice['vehiclePlate'];
      appointment['invoiceCustomerPhone'] = invoice['customerPhone'];
    }

    return enriched;
  }

  Map<String, dynamic>? _parseInvoice(dynamic serviceDetails) {
    if (serviceDetails is! String || serviceDetails.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(serviceDetails);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  Map<String, dynamic>? _findInvoiceByDate(
    Map<String, dynamic> appointment,
    List<Map<String, dynamic>> invoices,
  ) {
    final appointmentDate = DateTime.tryParse(
      appointment['appointmentDate']?.toString() ?? '',
    );
    if (appointmentDate == null) return null;

    for (final invoice in invoices) {
      final serviceDate = DateTime.tryParse(
        invoice['serviceDate']?.toString() ?? '',
      );
      if (serviceDate == null) continue;
      if (serviceDate.year == appointmentDate.year &&
          serviceDate.month == appointmentDate.month &&
          serviceDate.day == appointmentDate.day) {
        return invoice;
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        appBar: AppBar(
          title: const Text(
            'Manage Appointments',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          automaticallyImplyLeading: false,
          backgroundColor: AppColors.danger,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _fetchAppointments,
            ),
          ],
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            indicatorWeight: 4,
            tabs: [
              Tab(text: 'WAITING CONFIRMATION'),
              Tab(text: 'PROCESSING'),
              Tab(text: 'COMPLETED'),
            ],
          ),
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator(color: AppColors.primary))
            : TabBarView(
                children: [
                  _buildList(_pendingApts, isPending: true),
                  _buildList(_confirmedApts, isConfirmed: true),
                  _buildList(_completedApts, isCompleted: true),
                ],
              ),
      ),
    );
  }

  Widget _buildList(
    List<dynamic> list, {
    bool isPending = false,
    bool isConfirmed = false,
    bool isCompleted = false,
  }) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 80,
              color: AppColors.success,
            ),
            const SizedBox(height: 16),
            Text(
              isCompleted
                  ? 'No completed appointments yet.'
                  : (isPending
                        ? 'No new appointments.'
                        : 'No processing appointments yet.'),
              style: TextStyle(color: AppColors.inkMuted, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchAppointments,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final apt = list[index];
          final isWalkIn = apt['type']?.toString() == 'WALK_IN';
          final DateTime date = DateTime.parse(
            apt['appointmentDate'],
          ).toLocal();
          final String formattedDate = DateFormat(
            'HH:mm - dd/MM/yyyy',
          ).format(date);
          final String customerName =
              apt['customer']?['fullName'] ?? apt['customerName'] ?? 'Customer';
          String? nonEmptyText(dynamic value) {
            final text = value?.toString().trim() ?? '';
            return text.isEmpty || text.toLowerCase() == 'null' ? null : text;
          }

          final rawVehicle = apt['vehicle'];
          final vehicle = rawVehicle is Map
              ? rawVehicle
              : const <String, dynamic>{};
          final invoiceVehicleName = nonEmptyText(apt['invoiceVehicleName']);
          final invoiceVehiclePlate = nonEmptyText(apt['invoiceVehiclePlate']);
          final hasInvoiceVehicle =
              invoiceVehicleName != null &&
              invoiceVehicleName.trim().isNotEmpty &&
              invoiceVehiclePlate != null &&
              invoiceVehiclePlate.trim().isNotEmpty;
          final invoiceVehicleInfo = hasInvoiceVehicle
              ? '${invoiceVehicleName.trim()} - ${invoiceVehiclePlate.trim()}'
              : null;
          final appointmentVehicleBrand = nonEmptyText(
            apt['vehicleBrand'] ?? vehicle['brand'],
          );
          final appointmentVehicleName = nonEmptyText(
            apt['vehicleName'] ?? vehicle['vehicleName'] ?? vehicle['model'],
          );
          final appointmentVehiclePlate = nonEmptyText(
            apt['vehiclePlate'] ?? vehicle['licensePlate'],
          );
          final appointmentVehicleTitle = [
            appointmentVehicleBrand,
            appointmentVehicleName,
          ].whereType<String>().join(' ').trim();
          final appointmentVehicleInfo = appointmentVehicleTitle.isNotEmpty
              ? [
                  appointmentVehicleTitle,
                  appointmentVehiclePlate,
                ].whereType<String>().join(' - ')
              : appointmentVehiclePlate;
          final vehicleInfo =
              invoiceVehicleInfo ?? appointmentVehicleInfo ?? 'No vehicle data';

          Color borderColor = AppColors.inkMuted;
          Color statusBg = AppColors.fieldFill;
          IconData statusIcon = Icons.calendar_today;
          if (isPending) {
            borderColor = AppColors.primary;
            statusBg = AppColors.primaryLight;
            statusIcon = Icons.warning_amber_rounded;
          }
          if (isConfirmed) {
            borderColor = AppColors.info;
            statusBg = AppColors.info.withValues(alpha: 0.12);
            statusIcon = Icons.build;
          }
          if (isCompleted) {
            borderColor = AppColors.success;
            statusBg = AppColors.successBg;
            statusIcon = Icons.check_circle;
          }

          return Card(
            elevation: 0,
            color: AppColors.surface,
            surfaceTintColor: Colors.transparent,
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AppColors.edge),
            ),
            child: Container(
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: borderColor, width: 6)),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryDeep.withValues(alpha: 0.07),
                    blurRadius: 18,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${isWalkIn ? 'Walk-in' : 'Appointment'} #${apt['id']}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: borderColor,
                          fontSize: 16,
                        ),
                      ),
                      Icon(statusIcon, color: borderColor),
                    ],
                  ),
                  Divider(color: AppColors.edge),
                  Text(
                    'Customer: $customerName',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: AppColors.inkMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        formattedDate,
                        style: TextStyle(
                          color: AppColors.inkMuted,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.fieldFill,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.edge),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Vehicle: $vehicleInfo',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                        if (apt['note'] != null &&
                            apt['note'].toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Note: ${apt['note']}',
                              style: TextStyle(color: AppColors.inkMuted),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (isCompleted) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle, color: AppColors.success),
                          const SizedBox(width: 8),
                          Text(
                            'PAID & COMPLETED',
                            style: TextStyle(
                              color: AppColors.success,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (isPending) ...[
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => _updateAppointmentStatus(
                              context,
                              apt['id'],
                              'CONFIRMED',
                            ),
                            icon: const Icon(Icons.check_circle_outline),
                            label: const Text(
                              'CONFIRM',
                              style: TextStyle(fontSize: 12),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () => _updateAppointmentStatus(
                            context,
                            apt['id'],
                            'CANCELLED',
                          ),
                          child: Text(
                            'Decline',
                            style: TextStyle(color: AppColors.danger),
                          ),
                        ),
                      ],
                    ),
                  ] else if (isConfirmed) ...[
                    if (_appointmentStatus(apt) == 'PAYING') ...[
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () async {
                            try {
                              final response = isWalkIn
                                  ? await ApiClient.put(
                                      '/walk-in-repairs/${apt['id']}/complete',
                                      {},
                                    )
                                  : await ApiClient.put(
                                      '/appointments/${apt['id']}/pay',
                                      {},
                                    );
                              ApiClient.parseResponse(response);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text(
                                      'Payment completed successfully!',
                                      /*
                                      'Thanh toán thành công!',
                                      */
                                    ),
                                    backgroundColor: AppColors.success,
                                  ),
                                );
                                _fetchAppointments();
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error: $e'),
                                    backgroundColor: AppColors.danger,
                                  ),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.payment_rounded),
                          label: const Text(
                            'CONFIRM PAID & COMPLETE',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.success,
                          ),
                        ),
                      ),
                    ] else ...[
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () async {
                            final customerId =
                                apt['customer']?['id'] ?? apt['customerId'];
                            if (customerId == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('Customer data missing.'),
                                  backgroundColor: AppColors.danger,
                                ),
                              );
                              return;
                            }
                            final completed = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BranchMaintenanceBillScreen(
                                  branchId: widget.branchId,
                                  customerId: customerId as int,
                                  customerName: customerName,
                                  appointment: apt,
                                ),
                              ),
                            );
                            if (completed == true && mounted) {
                              _fetchAppointments();
                            }
                          },
                          icon: const Icon(Icons.receipt_long_rounded),
                          label: const Text(
                            'CREATE TEMPORARY BILL',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.info,
                          ),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _updateAppointmentStatus(
    BuildContext context,
    int appointmentId,
    String newStatus,
  ) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.firebaseUser;
      if (user == null) return;

      String? token = await user.getIdToken();

      final response = await http.put(
        Uri.parse('${ApiClient.baseUrl}/appointments/$appointmentId/status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode({'status': newStatus}),
      );

      if (!context.mounted) return;

      if (response.statusCode == 200) {
        _fetchAppointments();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Appointment status updated successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        throw Exception("Server communication failed.");
      }
    } catch (e) {
      debugPrint('Status update error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('System Error: Cannot update status.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }
}

/// Profile interface: Account information and session control
class _BranchProfileTab extends StatelessWidget {
  const _BranchProfileTab();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: true,
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 92,
              height: 92,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppColors.primaryBright, AppColors.primaryHover],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryHover.withValues(alpha: 0.4),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.storefront_rounded,
                size: 44,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: Text(
              'Branch staff',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
          ),
          const SizedBox(height: 32),
          InkWell(
            onTap: () => context.read<AuthProvider>().logout(),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.edge),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.logout_rounded,
                      size: 21,
                      color: AppColors.danger,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Text(
                      'Log out',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.danger,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: AppColors.hairline),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
