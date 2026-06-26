import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../core/theme_controller.dart';
import '../../providers/auth_provider.dart';
import '../../services/web_socket_service.dart';
import '../../services/rescue_store.dart';
import 'branch_rescue_screen.dart';
import 'create_maintenance_screen.dart';
import 'sos_alert_dialog.dart';

/// Main navigation screen for branch staff.
/// Includes a BottomNavigationBar, QR scanning, and feature tabs.
class BranchMobileDashboard extends StatefulWidget {
  const BranchMobileDashboard({super.key});

  @override
  State<BranchMobileDashboard> createState() => _BranchMobileDashboardState();
}

class _BranchMobileDashboardState extends State<BranchMobileDashboard> {
  int _currentIndex = 0;
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
  void _onDetect(BarcodeCapture capture) async {
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

          // Navigate to the create-maintenance screen
          await Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => CreateMaintenanceScreen(
                customerId: customerId,
                customerName: customerName,
              ),
            ),
          );
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid QR code. Please scan the code from the CareBike app.'),
              backgroundColor: Colors.red,
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
  void _openQRScanner() {
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
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                child: MobileScanner(
                  controller: _scannerController,
                  onDetect: _onDetect,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeController>(); // rebuild on dark-mode toggle
    final auth = context.watch<AuthProvider>();
    final branchId = _getBranchId(auth);

    // Start the rescue radar once the branch id is known.
    if (branchId != null && !_rescueInit) {
      _rescueInit = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => RescueStore.instance.init(branchId));
    }

    final List<Widget> pages = [
      _BranchHomeTab(
        auth: auth,
        onScanQR: _openQRScanner,
        onViewRescues: () => setState(() => _currentIndex = 1),
      ),
      branchId != null
          ? BranchRescueScreen(branchId: branchId) 
          : const Center(child: Text('Loading branch data...')),
      branchId != null
          ? _BranchAppointmentTab(branchId: branchId)
          : const Center(child: Text('Loading branch data...')),
      _BranchProfileTab(),
    ];

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Container(
        width: 58, height: 58,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(colors: [Color(0xFFFB923C), Color(0xFFF97316), Color(0xFFEA580C)]),
          boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.45), blurRadius: 18, offset: const Offset(0, 8))],
        ),
        child: FloatingActionButton(
          onPressed: _openQRScanner,
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
              _buildNavItem(icon: Icons.engineering_rounded, label: 'Rescue', index: 1),
              const SizedBox(width: 48), // Center gap for the FAB
              _buildNavItem(icon: Icons.calendar_month_rounded, label: 'Bookings', index: 2),
              _buildNavItem(icon: Icons.person_rounded, label: 'Profile', index: 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({required IconData icon, required String label, required int index}) {
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
            width: 46, height: 28,
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
  final VoidCallback onScanQR;
  final VoidCallback onViewRescues;
  const _BranchHomeTab({required this.auth, required this.onScanQR, required this.onViewRescues});

  @override
  Widget build(BuildContext context) {
    final fullName = auth.mysqlUser?['fullName'];
    final email = auth.firebaseUser?.email;
    final displayName = (fullName != null && fullName.toString().isNotEmpty) ? fullName : email;

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
                  Text('CARE', style: GoogleFonts.montserrat(fontSize: 23, fontWeight: FontWeight.w800, fontStyle: FontStyle.italic, color: AppColors.primary, letterSpacing: -0.5)),
                  Text('BIKE', style: GoogleFonts.montserrat(fontSize: 23, fontWeight: FontWeight.w800, fontStyle: FontStyle.italic, color: AppColors.ink, letterSpacing: -0.5)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                decoration: BoxDecoration(color: AppColors.primaryMuted, borderRadius: BorderRadius.circular(20)),
                child: Text('STAFF', style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: AppColors.primaryDeep)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Hello,',
              style: GoogleFonts.poppins(fontSize: 25, fontWeight: FontWeight.w800, height: 1.1, letterSpacing: -0.5, color: AppColors.ink)),
          Text('$displayName',
              style: GoogleFonts.poppins(fontSize: 25, fontWeight: FontWeight.w800, height: 1.1, letterSpacing: -0.5, color: AppColors.ink)),
          const SizedBox(height: 5),
          Text('Branch management',
              style: TextStyle(fontSize: 14, color: AppColors.inkMuted, fontWeight: FontWeight.w500)),
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
                          value: '0',
                          icon: Icons.calendar_today_rounded,
                          color: const Color(0xFF2563EB),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _buildStatCard(
                          title: 'Urgent rescues',
                          value: '${sos.length}',
                          icon: Icons.speed_rounded,
                          color: const Color(0xFFDC2626),
                        ),
                      ),
                    ],
                  ),
                  if (sos.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildSosQueue(context, sos),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          // Scan customer QR card -> opens the existing QR scanner
          InkWell(
            onTap: onScanQR,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.edge),
                boxShadow: [BoxShadow(color: AppColors.primaryDeep.withValues(alpha: 0.07), blurRadius: 24, offset: const Offset(0, 8))],
              ),
              child: Row(
                children: [
                  Container(
                    width: 46, height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: AppColors.primaryMuted, borderRadius: BorderRadius.circular(14)),
                    child: Icon(Icons.qr_code_scanner_rounded, color: AppColors.primaryHover, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Scan customer QR', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink)),
                        const SizedBox(height: 2),
                        Text('Start a new maintenance record', style: TextStyle(fontSize: 12.5, color: AppColors.inkMuted, fontWeight: FontWeight.w500)),
                      ],
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

  Widget _buildStatCard({required String title, required String value, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.edge),
        boxShadow: [BoxShadow(color: AppColors.primaryDeep.withValues(alpha: 0.07), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44, height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 16),
          Text(value, style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.ink)),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(fontSize: 13, color: AppColors.inkMuted, fontWeight: FontWeight.w500)),
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
        boxShadow: [BoxShadow(color: AppColors.danger.withValues(alpha: 0.18), blurRadius: 22, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30, height: 30,
                alignment: Alignment.center,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFDC2626)),
                child: const Icon(Icons.sos_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text('SOS — NEEDS RESPONSE',
                    style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.danger, letterSpacing: 0.4)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(20)),
                child: Text('${sos.length}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...sos.take(4).map((r) => _buildSosTile(context, r)),
          if (sos.length > 4)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('+ ${sos.length - 4} more', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.danger)),
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
                child: Text(name, style: GoogleFonts.poppins(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.ink)),
              ),
              Text('#${r['id']}', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.danger, fontSize: 12.5)),
            ],
          ),
          const SizedBox(height: 5),
          Text('⚠️ $issue',
              maxLines: 2, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, color: AppColors.danger, fontWeight: FontWeight.w600, height: 1.3)),
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
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(ok ? 'Case #${r['id']} accepted.' : 'Could not accept the case.'),
                          backgroundColor: ok ? Colors.green : null,
                        ));
                      }
                    },
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 17),
                    label: const Text('Accept', style: TextStyle(fontWeight: FontWeight.w700)),
                    style: FilledButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11))),
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
                    side: BorderSide(color: AppColors.danger.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                  ),
                  child: const Text('View', style: TextStyle(fontWeight: FontWeight.w700)),
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
  const _BranchAppointmentTab({required this.branchId});

  @override
  State<_BranchAppointmentTab> createState() => _BranchAppointmentTabState();
}

class _BranchAppointmentTabState extends State<_BranchAppointmentTab> {
  List<dynamic> _appointments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAppointments();
    
    // Open a WebSocket to listen for new booking requests in real time
    WebSocketService.connectBranchAppointments(widget.branchId, (newAppointment) {
      if (mounted) {
        setState(() {
          // Push the new booking to the top and refresh the UI without re-calling the API
          _appointments.insert(0, newAppointment);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🚨 New maintenance booking! Please check.'),
            backgroundColor: Colors.blue,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 4),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    // Disconnect the WebSocket to free resources when this tab is disposed
    WebSocketService.disconnect();
    super.dispose();
  }

  Future<void> _fetchAppointments() async {
    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.firebaseUser;
      if (user == null) return;

      String? token = await user.getIdToken();
      
      // Load the list from the backend: both Pending and Confirmed
      final pendingRes = await http.get(
        Uri.parse('http://10.0.2.2:8080/api/appointments/branch/${widget.branchId}?status=PENDING'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      );
      final confirmedRes = await http.get(
        Uri.parse('http://10.0.2.2:8080/api/appointments/branch/${widget.branchId}?status=CONFIRMED'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      );

      if (pendingRes.statusCode == 200 && confirmedRes.statusCode == 200) {
        final List<dynamic> pendingData = jsonDecode(utf8.decode(pendingRes.bodyBytes));
        final List<dynamic> confirmedData = jsonDecode(utf8.decode(confirmedRes.bodyBytes));
        
        // Merge the two lists and sort by ID (newest first)
        final combined = [...pendingData, ...confirmedData];
        combined.sort((a, b) => b['id'].compareTo(a['id']));

        if (mounted) {
          setState(() {
            _appointments = combined;
            _isLoading = false;
          });
        }
      } else {
        throw Exception("Failed to fetch data");
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint("Error fetching appointments: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('Appointment Management'),
        centerTitle: true,
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _appointments.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline_rounded, size: 64, color: AppColors.edge),
                      const SizedBox(height: 16),
                      Text('No pending appointments',
                          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.inkMuted)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _fetchAppointments,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    itemCount: _appointments.length,
                    itemBuilder: (context, index) {
                      final apt = _appointments[index];
                      final DateTime date = DateTime.parse(apt['appointmentDate']).toLocal();
                      final String formattedDate = DateFormat('HH:mm - dd/MM/yyyy').format(date);
                      final String customerName = apt['customer']?['fullName'] ?? apt['customerName'] ?? 'Customer';
                      final String status = apt['status'];
                      final confirmed = status == 'CONFIRMED';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.edge),
                          boxShadow: [BoxShadow(color: AppColors.primaryDeep.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 8))],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => _showAppointmentActionSheet(context, apt),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  width: 46, height: 46,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: (confirmed ? AppColors.success : AppColors.primary).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(Icons.person_rounded, color: confirmed ? AppColors.success : AppColors.primary, size: 23),
                                ),
                                const SizedBox(width: 13),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(customerName, style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14.5, color: AppColors.ink)),
                                      const SizedBox(height: 5),
                                      Row(
                                        children: [
                                          Icon(Icons.access_time_rounded, size: 14, color: AppColors.faint),
                                          const SizedBox(width: 4),
                                          Text(formattedDate, style: TextStyle(color: AppColors.faint, fontSize: 12, fontWeight: FontWeight.w500)),
                                        ],
                                      ),
                                      const SizedBox(height: 7),
                                      _buildStatusBadge(status),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right_rounded, color: AppColors.hairline),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  /// Build the status label for a booking
  Widget _buildStatusBadge(String status) {
    Color color;
    Color bg;
    String text;
    switch (status) {
      case 'PENDING':
        color = AppColors.primaryDeep;
        bg = AppColors.primaryMuted;
        text = 'Pending';
        break;
      case 'CONFIRMED':
        color = AppColors.success;
        bg = AppColors.successBg;
        text = 'Vehicle received';
        break;
      default:
        color = AppColors.inkMuted;
        bg = const Color(0xFFF1EDE8);
        text = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }

  /// Update appointment status via the backend API and refresh the UI locally
  Future<void> _updateAppointmentStatus(BuildContext context, int appointmentId, String newStatus) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.firebaseUser;
      if (user == null) return;
      
      String? token = await user.getIdToken();
      
      // Call the API to update data on the server
      final response = await http.put(
        Uri.parse('http://10.0.2.2:8080/api/appointments/$appointmentId/status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'status': newStatus}),
      );

      if (response.statusCode == 200) {
        // Close the BottomSheet
        if (mounted) Navigator.pop(context);

        // Update local state so the UI changes instantly without a GET
        setState(() {
          final index = _appointments.indexWhere((a) => a['id'] == appointmentId);
          if (index != -1) {
            // If completed or cancelled, remove from the list; otherwise update the label.
            if (newStatus == 'COMPLETED' || newStatus == 'CANCELLED') {
              _appointments.removeAt(index);
            } else {
              _appointments[index]['status'] = newStatus;
            }
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Status updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception("Server communication failed.");
      }
    } catch (e) {
      debugPrint('Error updating status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('System error: could not update the status.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// BottomSheet with business action buttons
  void _showAppointmentActionSheet(BuildContext context, dynamic apt) {
    final status = apt['status'];
    final customerName = apt['customer']?['fullName'] ?? 'Anonymous customer';
    final vehicle = apt['vehicle'] ?? {};
    final vehicleInfo = vehicle.isNotEmpty ? '${vehicle['brand']} ${vehicle['model']} - ${vehicle['licensePlate']}' : 'No vehicle data';

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: AppColors.edge, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 18),
              Text('Handle appointment #${apt['id']}', style: GoogleFonts.poppins(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.ink)),
              const SizedBox(height: 16),
              Text('👤 Customer: $customerName', style: TextStyle(fontSize: 15, color: AppColors.ink, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Text('🛵 Vehicle: $vehicleInfo', style: TextStyle(fontSize: 15, color: AppColors.inkMuted)),
              const SizedBox(height: 8),
              Text('📝 Note: ${apt['note'] ?? 'None'}', style: TextStyle(fontSize: 15, fontStyle: FontStyle.italic, color: AppColors.inkMuted)),
              const SizedBox(height: 24),

              if (status == 'PENDING')
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: () => _updateAppointmentStatus(context, apt['id'], 'CONFIRMED'),
                    icon: const Icon(Icons.check_circle_rounded),
                    label: const Text('Confirm vehicle received'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.success,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              if (status == 'CONFIRMED')
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: () => _updateAppointmentStatus(context, apt['id'], 'COMPLETED'),
                    icon: const Icon(Icons.done_all_rounded),
                    label: const Text('Complete maintenance'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: TextButton.icon(
                  onPressed: () => _updateAppointmentStatus(context, apt['id'], 'CANCELLED'),
                  icon: const Icon(Icons.cancel_rounded),
                  label: const Text('Reject / Cancel'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    backgroundColor: AppColors.dangerBg,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Profile tab: account info and session controls
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
              width: 92, height: 92,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [AppColors.primaryBright, AppColors.primaryHover], begin: Alignment.topLeft, end: Alignment.bottomRight),
                boxShadow: [BoxShadow(color: AppColors.primaryHover.withValues(alpha: 0.4), blurRadius: 24, offset: const Offset(0, 10))],
              ),
              child: const Icon(Icons.storefront_rounded, size: 44, color: Colors.white),
            ),
          ),
          const SizedBox(height: 14),
          Center(child: Text('Branch staff', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink))),
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
                    width: 40, height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                    child: Icon(Icons.logout_rounded, size: 21, color: AppColors.danger),
                  ),
                  const SizedBox(width: 13),
                  Expanded(child: Text('Log out', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.danger))),
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