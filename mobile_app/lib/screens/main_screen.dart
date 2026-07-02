import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'package:google_fonts/google_fonts.dart';

import '../core/theme.dart';
import '../core/theme_controller.dart';
import '../providers/auth_provider.dart';
import '../services/web_socket_service.dart';

import '../widgets/rescue_bottom_sheet.dart';
import '../widgets/ai_assistant_bottom_sheet.dart';
import 'tabs/home_tab.dart';
import 'tabs/vehicles_tab.dart';
import 'tabs/history_tab.dart';
import 'tabs/profile_tab.dart';
import 'chat/chat_screen.dart';
import './branch/branch_map_screen.dart';
import './customer_appointment_screen.dart';
import './inspection/inspection_flow.dart';

/// The root screen shown after successful login.
/// Contains a Material 3 NavigationBar with 4 tabs + 1 Center FAB and a side Drawer.
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  // State cho AI Vision
  bool _isLoading = false;
  File? _selectedImage;
  List<dynamic> _detections = [];

  // Thêm một Dummy Tab (SizedBox.shrink) vào vị trí giữa (index 2) để nhường chỗ cho Nút AI
  static const _tabs = [
    HomeTab(),
    VehiclesTab(),
    SizedBox.shrink(), // Tab tàng hình
    HistoryTab(),
    ProfileTab(),
  ];

  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home_rounded),
      label: 'Home',
    ),
    NavigationDestination(
      icon: Icon(Icons.motorcycle_outlined),
      selectedIcon: Icon(Icons.motorcycle_rounded),
      label: 'My Vehicles',
    ),
    // Dummy Destination tạo khoảng trống giữa thanh NavigationBar
    NavigationDestination(
      icon: SizedBox(height: 24),
      label: '',
    ),
    NavigationDestination(
      icon: Icon(Icons.history_outlined),
      selectedIcon: Icon(Icons.history_rounded),
      label: 'History',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline_rounded),
      selectedIcon: Icon(Icons.person_rounded),
      label: 'Profile',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _setupGlobalWebSocket();
  }

  // =========================================================================
  // HÀM HIỂN THỊ KẾT QUẢ KHOANH ĐỎ DƯỚI DẠNG DIALOG
  // =========================================================================
  void _showResultDialog(double originalWidth, double originalHeight) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Kết quả quét AI', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Hệ thống đã khoanh đỏ các khu vực phát hiện lỗi:'),
            const SizedBox(height: 10),
            // Trọng tâm: Đè cây cọ vẽ lên trên tấm ảnh gốc
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CustomPaint(
                foregroundPainter: BoundingBoxPainter(_detections, originalWidth, originalHeight),
                child: Image.file(_selectedImage!),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // HÀM GỌI API AI VISION (PYTHON SERVER)
  // =========================================================================
  Future<void> _analyzeTire() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile == null) return;

    setState(() {
      _selectedImage = File(pickedFile.path);
      _isLoading = true;
    });

    try {
      var request = http.MultipartRequest(
          'POST',
          Uri.parse('http://172.16.3.175:8000/api/vision/analyze') // Giữ nguyên IP máy ảo
      );

      request.files.add(
          await http.MultipartFile.fromPath('file', _selectedImage!.path)
      );

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        var jsonResult = jsonDecode(response.body);

        // Giải mã kích thước gốc của bức ảnh để tính tỷ lệ thu phóng (Scale)
        var decodedImage = await decodeImageFromList(_selectedImage!.readAsBytesSync());

        setState(() {
          _detections = jsonResult['detections'];
          _isLoading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Phát hiện ${jsonResult['total_defects_found']} lỗi trên phụ tùng!'),
              backgroundColor: Colors.green.shade700,
            ),
          );

          // Bật Dialog và truyền chiều dài/rộng gốc của ảnh vào
          _showResultDialog(decodedImage.width.toDouble(), decodedImage.height.toDouble());
        }
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi Server AI: ${response.statusCode}'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể kết nối đến máy chủ AI: $e'), backgroundColor: Colors.red),
        );
      }
    }
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
                    const Icon(Icons.notifications_active, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Your appointment $statusVi!',
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
  // DRAWER UI (LEFT TOGGLE MENU)
  // =========================================================================
  Widget _buildDrawer(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final name = auth.mysqlUser?['fullName'] ?? auth.firebaseUser?.email ?? 'Customer';
    final email = auth.firebaseUser?.email ?? 'Email not updated';

    return Drawer(
      backgroundColor: AppColors.canvas,
      child: Column(
        children: [

          // ── Drawer header (brand gradient background) ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 60, bottom: 26, left: 24, right: 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFB923C), Color(0xFFF97316), Color(0xFFEA580C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(

                  width: 76, height: 76,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 14, offset: const Offset(0, 6))],
                  ),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'C',
                    style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.primaryHover),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  name,
                  style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  email,
                  style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.9), fontWeight: FontWeight.w500),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
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
                    Navigator.pop(context); // Close the drawer before navigating
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const BranchMapScreen()));
                  },
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.calendar_month,
                  title: 'My Appointments',
                  subtitle: 'Track maintenance progress',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerAppointmentScreen()));
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
                _buildDrawerItem(
                  context,
                  icon: Icons.smart_toy_rounded,
                  title: 'AI Tư vấn Bảo dưỡng',
                  subtitle: 'Hỏi đáp thông minh với AI',
                  iconColor: Colors.deepPurple,
                  onTap: () {
                    Navigator.pop(context);
                    AiAssistantBottomSheet.show(context);
                  },
                ),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8), child: Divider()),
              ],
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text('CareBike Version 1.0.0', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildDrawerItem(BuildContext context, {required IconData icon, required String title, String? subtitle, required VoidCallback onTap, Color? iconColor, Color? iconBg}) {
    return ListTile(
      leading: Container(
        width: 42, height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: iconBg ?? AppColors.primaryMuted,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor ?? AppColors.primaryHover, size: 22),
      ),
      title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: AppColors.ink, fontSize: 15)),
      subtitle: subtitle != null ? Text(subtitle, style: TextStyle(fontSize: 12, color: AppColors.inkMuted, fontWeight: FontWeight.w500)) : null,
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
      HomeTab(),
      VehiclesTab(),
      HistoryTab(),
      ProfileTab(),
    ];

    return Scaffold(
      drawer: _buildDrawer(context), // <--- Attach the drawer to the root Scaffold
      body: IndexedStack(
        index: _currentIndex,
        children: tabs,
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
              _buildNavItem(icon: Icons.motorcycle_rounded, label: 'My Vehicles', index: 1),
              const SizedBox(width: 48), // Center gap for the camera FAB
              _buildNavItem(icon: Icons.history_rounded, label: 'History', index: 2),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatScreen()));
        },
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        elevation: 4,
        child: const Icon(Icons.smart_toy),
      ),
    );
  }
}

// =========================================================================
// CLASS HỖ TRỢ VẼ KHUNG ĐỎ LÊN ẢNH (BẮT BUỘC ĐỂ BÊN NGOÀI CLASS MAIN)
// =========================================================================
class BoundingBoxPainter extends CustomPainter {
  final List<dynamic> detections;
  final double originalWidth;
  final double originalHeight;

  BoundingBoxPainter(this.detections, this.originalWidth, this.originalHeight);

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Tính toán tỷ lệ thu phóng (Vì ảnh trên màn hình đt nhỏ hơn ảnh gốc)
    final double scaleX = size.width / originalWidth;
    final double scaleY = size.height / originalHeight;

    // 2. Thiết lập nét bút vẽ khung
    final paint = Paint()
      ..color = Colors.redAccent
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    // 3. Quét từng lỗi và vẽ lên
    for (var d in detections) {
      final box = d['box'];

      // Tính tọa độ đã scale cho khớp với màn hình
      final rect = Rect.fromLTRB(
        box['x_min'] * scaleX,
        box['y_min'] * scaleY,
        box['x_max'] * scaleX,
        box['y_max'] * scaleY,
      );

      canvas.drawRect(rect, paint); // Vẽ khung chữ nhật

      // 4. Vẽ thêm cái nhãn tên lỗi (VD: tire 85%)
      final text = '${d['label']} ${(d['confidence'] * 100).toInt()}%';
      textPainter.text = TextSpan(
        text: text,
        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
      );
      textPainter.layout();

      // Vẽ nền đỏ cho chữ dễ đọc
      final bgRect = Rect.fromLTWH(rect.left, rect.top - 18, textPainter.width + 4, 18);
      final bgPaint = Paint()..color = Colors.redAccent..style = PaintingStyle.fill;
      canvas.drawRect(bgRect, bgPaint);

      textPainter.paint(canvas, Offset(rect.left + 2, rect.top - 17));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}