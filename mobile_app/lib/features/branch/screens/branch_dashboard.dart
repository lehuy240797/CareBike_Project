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
import 'package:mobile_app/features/branch/screens/branch_rescue_screen.dart';
import 'package:mobile_app/features/branch/screens/create_maintenance_screen.dart';
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
  bool _isScanning = false;
  final MobileScannerController _scannerController = MobileScannerController();

  StreamSubscription<Map<String, dynamic>>? _sosSub;
  bool _rescueInit = false;
  bool _alertOpen = false;

  @override
  void initState() {
    super.initState();
    // Raise the emergency alarm for any brand-new, unaccepted SOS ΓÇö from any tab.
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
          // Live rescue stats + SOS queue ΓÇö rebuilds whenever the store changes.
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
                child: Text('SOS ΓÇö NEEDS RESPONSE',
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
          Text('ΓÜá∩╕Å $issue',
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
  List<dynamic> _pendingApts = [];
  List<dynamic> _confirmedApts = [];
  List<dynamic> _completedApts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAppointments();
    
    // Initialize WebSocket connection to listen for new appointments in real-time
    WebSocketService.connectBranchAppointments(widget.branchId, (newAppointment) {
      if (mounted) {
        setState(() {
          _pendingApts.insert(0, newAppointment);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('≡ƒÜ¿ New maintenance appointment! Please check.'),
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
      
      final pendingRes = await http.get(
        Uri.parse('${ApiClient.baseUrl}/appointments/branch/${widget.branchId}?status=PENDING'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      );
      final confirmedRes = await http.get(
        Uri.parse('${ApiClient.baseUrl}/appointments/branch/${widget.branchId}?status=CONFIRMED'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      );
      final completedRes = await http.get(
        Uri.parse('${ApiClient.baseUrl}/appointments/branch/${widget.branchId}?status=COMPLETED'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      );

      if (pendingRes.statusCode == 200 && confirmedRes.statusCode == 200) {
        if (mounted) {
          setState(() {
            _pendingApts = jsonDecode(utf8.decode(pendingRes.bodyBytes));
            _confirmedApts = jsonDecode(utf8.decode(confirmedRes.bodyBytes));
            _completedApts = completedRes.statusCode == 200 ? jsonDecode(utf8.decode(completedRes.bodyBytes)) : [];
            
            _pendingApts.sort((a, b) => b['id'].compareTo(a['id']));
            _confirmedApts.sort((a, b) => b['id'].compareTo(a['id']));
            _completedApts.sort((a, b) => b['id'].compareTo(a['id']));
            
            _isLoading = false;
          });
        }
      } else {
        throw Exception("Failed to retrieve data");
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint("Error retrieving appointments: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          title: const Text('Manage Appointments', style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
          automaticallyImplyLeading: false,
          backgroundColor: Colors.red.shade700,
          foregroundColor: Colors.white,
          actions: [
            IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchAppointments)
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
            ? const Center(child: CircularProgressIndicator(color: Colors.red))
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

  Widget _buildList(List<dynamic> list, {bool isPending = false, bool isConfirmed = false, bool isCompleted = false}) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 80, color: Colors.green.shade300),
            const SizedBox(height: 16),
            Text(isCompleted ? 'No completed appointments yet.' : (isPending ? 'No new appointments.' : 'No processing appointments yet.'), style: const TextStyle(color: Colors.grey, fontSize: 16)),
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
          final DateTime date = DateTime.parse(apt['appointmentDate']).toLocal();
          final String formattedDate = DateFormat('HH:mm - dd/MM/yyyy').format(date);
          final String customerName = apt['customer']?['fullName'] ?? apt['customerName'] ?? 'Customer';
          final vehicle = apt['vehicle'] ?? {};
          final vehicleInfo = vehicle.isNotEmpty ? '${vehicle['brand']} ${vehicle['model']} - ${vehicle['licensePlate']}' : 'No vehicle data';

          Color borderColor = Colors.grey;
          IconData statusIcon = Icons.calendar_today;
          if (isPending) { borderColor = Colors.orange; statusIcon = Icons.warning_amber_rounded; }
          if (isConfirmed) { borderColor = Colors.blue; statusIcon = Icons.build; }
          if (isCompleted) { borderColor = Colors.green; statusIcon = Icons.check_circle; }

          return Card(
            elevation: 4,
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: borderColor, width: 6)),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Appointment #${apt['id']}', style: TextStyle(fontWeight: FontWeight.bold, color: borderColor, fontSize: 16)),
                      Icon(statusIcon, color: borderColor),
                    ],
                  ),
                  const Divider(),
                  Text('Customer: $customerName', style: const TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(formattedDate, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('≡ƒÜÖ Vehicle: $vehicleInfo', style: const TextStyle(fontWeight: FontWeight.w600)),
                        if (apt['note'] != null && apt['note'].toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text('≡ƒô¥ Note: ${apt['note']}'),
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
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8)
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle, color: Colors.green),
                          SizedBox(width: 8),
                          Text('PAID & COMPLETED', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ] else if (isPending) ...[
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => _updateAppointmentStatus(context, apt['id'], 'CONFIRMED'),
                            icon: const Icon(Icons.check_circle_outline),
                            label: const Text('CONFIRM', style: TextStyle(fontSize: 12)),
                            style: FilledButton.styleFrom(backgroundColor: Colors.orange.shade600),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () => _updateAppointmentStatus(context, apt['id'], 'CANCELLED'),
                          child: const Text('Decline', style: TextStyle(color: Colors.red)),
                        )
                      ],
                    ),
                  ] else if (isConfirmed) ...[
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => _updateAppointmentStatus(context, apt['id'], 'COMPLETED'),
                        icon: const Icon(Icons.done_all),
                        label: const Text('COMPLETE MAINTENANCE', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: FilledButton.styleFrom(backgroundColor: Colors.blue.shade700),
                      ),
                    ),
                  ]
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _updateAppointmentStatus(BuildContext context, int appointmentId, String newStatus) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.firebaseUser;
      if (user == null) return;
      
      String? token = await user.getIdToken();
      
      final response = await http.put(
        Uri.parse('${ApiClient.baseUrl}/appointments/$appointmentId/status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'status': newStatus}),
      );

      if (response.statusCode == 200) {
        _fetchAppointments();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Γ£à Appointment status updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception("Server communication failed.");
      }
    } catch (e) {
      debugPrint('Status update error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('System Error: Cannot update status.'), backgroundColor: Colors.red),
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
