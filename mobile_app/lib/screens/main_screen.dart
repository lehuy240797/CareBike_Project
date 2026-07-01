import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../providers/auth_provider.dart';
import '../services/web_socket_service.dart';

import '../widgets/rescue_bottom_sheet.dart';
import '../widgets/ai_assistant_bottom_sheet.dart';
import 'tabs/home_tab.dart';
import 'tabs/vehicles_tab.dart';
import 'tabs/history_tab.dart';
import 'tabs/profile_tab.dart';
import './branch/branch_map_screen.dart';
import './customer_appointment_screen.dart';

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
      label: 'Trang chủ',
    ),
    NavigationDestination(
      icon: Icon(Icons.motorcycle_outlined),
      selectedIcon: Icon(Icons.motorcycle_rounded),
      label: 'Xe của tôi',
    ),
    // Dummy Destination tạo khoảng trống giữa thanh NavigationBar
    NavigationDestination(
      icon: SizedBox(height: 24),
      label: '',
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
          Uri.parse('http://192.168.100.78:8000/api/vision/analyze') // Giữ nguyên IP máy ảo
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
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
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
                    Navigator.pop(context);
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
      drawer: _buildDrawer(context),
      body: IndexedStack(
        index: _currentIndex,
        children: _tabs,
      ),

      // =======================================================================
      // NÚT QUÉT AI NỔI BẬT NẰM Ở CHÍNH GIỮA (FLOATING CENTER BUTTON)
      // =======================================================================
      floatingActionButton: Container(
        height: 64,
        width: 64,
        margin: const EdgeInsets.only(top: 30), // Căn chỉnh độ lún của nút xuống thanh NavigationBar
        child: FloatingActionButton(
          onPressed: _isLoading ? null : _analyzeTire,
          backgroundColor: Theme.of(context).colorScheme.primary,
          shape: const CircleBorder(),
          elevation: 6,
          child: _isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : const Icon(Icons.document_scanner_rounded, size: 30, color: Colors.white),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      // =======================================================================
      // THANH ĐIỀU HƯỚNG
      // =======================================================================
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) {
          if (i == 2) return; // Vô hiệu hóa việc bấm vào cái tab "tàng hình" bên dưới nút AI
          setState(() => _currentIndex = i);
        },
        destinations: _destinations,
        elevation: 3,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        animationDuration: const Duration(milliseconds: 300),
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