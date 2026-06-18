import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/web_socket_service.dart';

import '../widgets/rescue_bottom_sheet.dart';
import 'tabs/home_tab.dart';
import 'tabs/vehicles_tab.dart';
import 'tabs/history_tab.dart';
import 'tabs/profile_tab.dart';
import './branch/branch_map_screen.dart';
import './customer_appointment_screen.dart';

/// The root screen shown after successful login.
/// Contains a Material 3 NavigationBar with 4 tabs and a side Drawer.
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  static const _tabs = [
    HomeTab(),
    VehiclesTab(),
    HistoryTab(),
    ProfileTab(),
  ];

  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home_rounded),
      label: 'Trang chủ',
    ),
    NavigationDestination(
      icon: Icon(Icons.motorcycle_outlined),
      selectedIcon: Icon(Icons.motorcycle_rounded),
      label: 'Xe của tôi',
    ),
    NavigationDestination(
      icon: Icon(Icons.history_outlined),
      selectedIcon: Icon(Icons.history_rounded),
      label: 'Lịch sử',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline_rounded),
      selectedIcon: Icon(Icons.person_rounded),
      label: 'Cá nhân',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _setupGlobalWebSocket();
  }

  void _setupGlobalWebSocket() {
    Future.microtask(() {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final int? customerId = authProvider.mysqlUser?['userId'];

      if (customerId != null) {
        WebSocketService.connectCustomer(customerId, (updatedAppointment) {
          if (!mounted) return;

          String statusVi = '';
          Color notiColor = Colors.green;

          switch (updatedAppointment['status']) {
            case 'CONFIRMED':
              statusVi = 'đã được chi nhánh xác nhận nhận xe';
              notiColor = Colors.green.shade700;
              break;
            case 'CANCELLED':
              statusVi = 'đã bị từ chối';
              notiColor = Colors.red.shade700;
              break;
            case 'COMPLETED':
              statusVi = 'đã hoàn tất quá trình sửa chữa';
              notiColor = Colors.blue.shade700;
              break;
          }

          if (statusVi.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.notifications_active, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Lịch hẹn của bạn $statusVi!',
                        style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                backgroundColor: notiColor,
                duration: const Duration(seconds: 4),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                margin: const EdgeInsets.all(12),
              ),
            );
          }
        });
      }
    });
  }

  @override
  void dispose() {
    WebSocketService.disconnect();
    super.dispose();
  }

  // =========================================================================
  // GIAO DIỆN DRAWER (TOGGLE MENU BÊN TRÁI)
  // =========================================================================
  Widget _buildDrawer(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final auth = context.watch<AuthProvider>();
    final name = auth.mysqlUser?['fullName'] ?? auth.firebaseUser?.email ?? 'Khách hàng';
    final email = auth.firebaseUser?.email ?? 'Chưa cập nhật email';

    return Drawer(
      backgroundColor: scheme.surface,
      child: Column(
        children: [
          // ── Header Drawer (Có nền Gradient sang trọng) ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 60, bottom: 24, left: 24, right: 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [scheme.primary, scheme.tertiary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: CircleAvatar(
                    radius: 36,
                    backgroundColor: scheme.primaryContainer,
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'C',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: scheme.onPrimaryContainer),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  name,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.8)),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // ── Danh sách Menu ──
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                _buildDrawerItem(
                  context,
                  icon: Icons.map_outlined,
                  title: 'Bản đồ Chi nhánh',
                  subtitle: 'Tìm địa chỉ & xem khoảng cách',
                  onTap: () {
                    Navigator.pop(context); // Đóng menu trượt trước khi chuyển trang
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const BranchMapScreen()));
                  },
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.calendar_month,
                  title: 'Lịch hẹn của tôi',
                  subtitle: 'Theo dõi tiến độ bảo dưỡng',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerAppointmentScreen()));
                  },
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.support_agent_rounded,
                  title: 'Cứu hộ 24/7',
                  subtitle: 'Gọi hỗ trợ khẩn cấp',
                  iconColor: Colors.red.shade400,
                  onTap: () {
                    Navigator.pop(context);
                    RescueBottomSheet.show(context);
                  },
                ),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8), child: Divider()),
                _buildDrawerItem(
                  context,
                  icon: Icons.local_activity_outlined,
                  title: 'Ưu đãi & Voucher',
                  onTap: () { Navigator.pop(context); },
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.headset_mic_outlined,
                  title: 'Trung tâm trợ giúp',
                  onTap: () { Navigator.pop(context); },
                ),
              ],
            ),
          ),

          // ── Footer ──
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text('CareBike Phiên bản 1.0.0', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildDrawerItem(BuildContext context, {required IconData icon, required String title, String? subtitle, required VoidCallback onTap, Color? iconColor}) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (iconColor ?? scheme.primary).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor ?? scheme.primary, size: 22),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: scheme.onSurface, fontSize: 15)),
      subtitle: subtitle != null ? Text(subtitle, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)) : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _buildDrawer(context), // <--- Gắn Drawer vào Scaffold gốc
      body: IndexedStack(
        index: _currentIndex,
        children: _tabs,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: _destinations,
        elevation: 3,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        animationDuration: const Duration(milliseconds: 300),
      ),
    );
  }
}