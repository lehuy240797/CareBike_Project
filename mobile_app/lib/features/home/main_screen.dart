import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mobile_app/core/theme/theme.dart';
import 'package:mobile_app/core/theme/theme_controller.dart';
import 'package:mobile_app/features/auth/providers/auth_provider.dart';
import 'package:mobile_app/core/network/web_socket_service.dart';

import 'package:mobile_app/features/rescue/widgets/rescue_bottom_sheet.dart';
import 'package:mobile_app/features/home/screens/home_tab.dart';
import 'package:mobile_app/features/vehicle/screens/vehicles_tab.dart';
import 'package:mobile_app/features/maintenance/screens/history_tab.dart';
import 'package:mobile_app/features/profile/screens/profile_tab.dart';
import 'package:mobile_app/features/branch/screens/branch_map_screen.dart';
import 'package:mobile_app/features/inspection/screens/inspection_flow.dart';

/// The root screen shown after successful login.
/// Contains a Material 3 NavigationBar with 4 tabs and a side Drawer.
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  int? _connectedCustomerId;
  int _historyRefreshKey = 0;
  int _homeRefreshKey = 0;

  @override
  void initState() {
    super.initState();
    _setupGlobalWebSocket();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _setupGlobalWebSocket();
  }

  void _setupGlobalWebSocket() {
    Future.microtask(() {
      if (!mounted) return;
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final int? customerId = _currentCustomerId(authProvider.mysqlUser);

      if (customerId != null && customerId != _connectedCustomerId) {
        _connectedCustomerId = customerId;
        WebSocketService.connectCustomer(customerId, (updatedAppointment) {
          if (!mounted) return;

          String statusVi = '';
          Color notiColor = Colors.green;

          switch (updatedAppointment['status']) {
            case 'CONFIRMED':
              statusVi = 'has been confirmed by the branch';
              notiColor = Colors.green.shade700;
              break;
            case 'CANCELLED':
              statusVi = 'has been declined';
              notiColor = Colors.red.shade700;
              break;
            case 'COMPLETED':
              statusVi = 'repair process is completed';
              notiColor = Colors.blue.shade700;
              break;
          }

          if (statusVi.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(
                      Icons.notifications_active,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Your appointment $statusVi!',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                backgroundColor: notiColor,
                duration: const Duration(seconds: 4),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                margin: const EdgeInsets.all(12),
              ),
            );
          }
        });
      }
    });
  }

  int? _currentCustomerId(Map<String, dynamic>? user) {
    final value = user?['userId'] ?? user?['id'] ?? user?['user']?['id'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  @override
  void dispose() {
    WebSocketService.disconnect();
    super.dispose();
  }

  // =========================================================================
  // DRAWER UI (LEFT TOGGLE MENU)
  // =========================================================================
  Widget _buildDrawer(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final name =
        auth.mysqlUser?['fullName'] ?? auth.firebaseUser?.email ?? 'Customer';
    final email = auth.firebaseUser?.email ?? 'Email not updated';

    return Drawer(
      backgroundColor: AppColors.canvas,
      child: Column(
        children: [
          // ── Drawer header (brand gradient background) ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(
              top: 60,
              bottom: 26,
              left: 24,
              right: 24,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFFB923C),
                  Color(0xFFF97316),
                  Color(0xFFEA580C),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                Container(
                  width: 76,
                  height: 76,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'C',
                    style: GoogleFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryHover,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  name,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  email,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // ── Menu list ──
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                _buildDrawerItem(
                  context,
                  icon: Icons.map_outlined,
                  title: 'Branch Map',
                  subtitle: 'Find addresses & check distances',
                  onTap: () {
                    Navigator.pop(
                      context,
                    ); // Close the drawer before navigating
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const BranchMapScreen(),
                      ),
                    );
                  },
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.support_agent_rounded,
                  title: 'Rescue 24/7',
                  subtitle: 'Call emergency support',
                  iconColor: AppColors.danger,
                  iconBg: AppColors.dangerBg,
                  onTap: () {
                    Navigator.pop(context);
                    RescueBottomSheet.show(context);
                  },
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Divider(),
                ),
              ],
            ),
          ),

          // ── Footer ──
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'CareBike Version 1.0.0',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    Color? iconColor,
    Color? iconBg,
  }) {
    return ListTile(
      leading: Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: iconBg ?? AppColors.primaryMuted,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor ?? AppColors.primaryHover, size: 22),
      ),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
          fontSize: 15,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.inkMuted,
                fontWeight: FontWeight.w500,
              ),
            )
          : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Depend on the theme so a dark-mode toggle rebuilds this screen (and the
    // tabs below), re-resolving the AppColors design tokens.
    context.watch<ThemeController>();

    // Fresh (non-const) instances each build so the IndexedStack children are
    // not short-circuited and actually repaint on toggle. State is preserved by
    // the persistent State objects, so no data is re-fetched.
    final tabs = <Widget>[
      HomeTab(key: ValueKey(_homeRefreshKey)),
      VehiclesTab(),
      HistoryTab(key: ValueKey(_historyRefreshKey)),
      ProfileTab(),
    ];

    return Scaffold(
      resizeToAvoidBottomInset: false,
      drawer: _buildDrawer(
        context,
      ), // <--- Attach the drawer to the root Scaffold
      body: IndexedStack(index: _currentIndex, children: tabs),

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
          onPressed: () => openInspectionSheet(context),
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          highlightElevation: 0,
          shape: const CircleBorder(),
          child: const Icon(Icons.photo_camera_rounded, size: 27),
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
                icon: Icons.motorcycle_rounded,
                label: 'My Vehicles',
                index: 1,
              ),
              const SizedBox(width: 48), // Center gap for the camera FAB
              _buildNavItem(
                icon: Icons.history_rounded,
                label: 'History',
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
      onTap: () => setState(() {
        _currentIndex = index;
        if (index == 0) _homeRefreshKey++;
        if (index == 2) _historyRefreshKey++;
      }),
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
