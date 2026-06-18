import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../providers/auth_provider.dart';
import '../../services/web_socket_service.dart';
import 'branch_rescue_screen.dart';
import 'create_maintenance_screen.dart';

/// Màn hình điều hướng chính của nhân viên Chi nhánh.
/// Tích hợp BottomNavigationBar, tính năng quét QR và các tab chức năng.
class BranchMobileDashboard extends StatefulWidget {
  const BranchMobileDashboard({super.key});

  @override
  State<BranchMobileDashboard> createState() => _BranchMobileDashboardState();
}

class _BranchMobileDashboardState extends State<BranchMobileDashboard> {
  int _currentIndex = 0;
  bool _isScanning = false;
  final MobileScannerController _scannerController = MobileScannerController();

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  /// Trích xuất định danh Chi nhánh từ dữ liệu người dùng được lưu trữ
  int? _getBranchId(AuthProvider auth) {
    final userMap = auth.mysqlUser;
    return userMap?['branchId'] ??
           userMap?['branch']?['id'] ??
           userMap?['user']?['branchId'] ??
           userMap?['user']?['branch']?['id'] ??
           userMap?['branch_id'];
  }

  /// Xử lý sự kiện nhận diện mã QR
  void _onDetect(BarcodeCapture capture) async {
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty && !_isScanning) {
      final String? code = barcodes.first.rawValue;
      if (code != null) {
        setState(() => _isScanning = true);
        _scannerController.stop();

        try {
          // Giải mã dữ liệu QR Khách hàng
          final Map<String, dynamic> qrData = jsonDecode(code);
          final int customerId = qrData['customerId'];
          final String customerName = qrData['fullName'] ?? 'Khách hàng';

          if (!mounted) return;

          // Điều hướng sang màn hình khởi tạo phiếu bảo dưỡng
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
              content: Text('Mã QR không hợp lệ. Vui lòng quét mã của ứng dụng CareBike.'),
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

  /// Khởi tạo giao diện BottomSheet quét mã QR
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
              title: const Text('Quét mã QR Khách hàng'),
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
    final auth = context.watch<AuthProvider>();
    final branchId = _getBranchId(auth);

    final List<Widget> pages = [
      _BranchHomeTab(auth: auth),
      branchId != null 
          ? BranchRescueScreen(branchId: branchId) 
          : const Center(child: Text('Đang tải dữ liệu chi nhánh...')),
      branchId != null
          ? _BranchAppointmentTab(branchId: branchId)
          : const Center(child: Text('Đang tải dữ liệu chi nhánh...')),
      const _BranchProfileTab(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        onPressed: _openQRScanner,
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.qr_code_scanner, size: 28),
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(icon: Icons.home_rounded, label: 'Trang chủ', index: 0),
              _buildNavItem(icon: Icons.engineering, label: 'Cứu hộ', index: 1),
              const SizedBox(width: 48), // Khoảng trống trung tâm cho FAB
              _buildNavItem(icon: Icons.calendar_month, label: 'Lịch hẹn', index: 2),
              _buildNavItem(icon: Icons.person, label: 'Cá nhân', index: 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({required IconData icon, required String label, required int index}) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? Theme.of(context).colorScheme.primary : Colors.grey;
    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      highlightColor: Colors.transparent,
      splashColor: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color, 
              fontSize: 12, 
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
            ),
          ),
        ],
      ),
    );
  }
}

/// Giao diện Trang chủ: Hiển thị lời chào và thống kê tổng quan
class _BranchHomeTab extends StatelessWidget {
  final AuthProvider auth;
  const _BranchHomeTab({required this.auth});

  @override
  Widget build(BuildContext context) {
    final fullName = auth.mysqlUser?['fullName'];
    final email = auth.firebaseUser?.email;
    final displayName = (fullName != null && fullName.toString().isNotEmpty) ? fullName : email;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Text(
              'Xin chào,\n$displayName',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Quản lý Chi nhánh',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    context, 
                    title: 'Lịch hẹn chờ', 
                    value: '0', 
                    icon: Icons.calendar_today, 
                    color: Colors.blue
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    context, 
                    title: 'Cứu hộ khẩn', 
                    value: '0', 
                    icon: Icons.support_agent, 
                    color: Colors.red
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, {required String title, required String value, required IconData icon, required MaterialColor color}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color.shade700),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

/// Giao diện Lịch hẹn: Truy xuất và hiển thị danh sách lịch hẹn chờ xác nhận
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
    
    // Khởi tạo kết nối WebSocket để lắng nghe các yêu cầu đặt lịch mới theo thời gian thực
    WebSocketService.connectBranchAppointments(widget.branchId, (newAppointment) {
      if (mounted) {
        setState(() {
          // Đẩy đơn đặt lịch mới lên đầu danh sách và làm mới giao diện không cần gọi lại API
          _appointments.insert(0, newAppointment);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🚨 Có đơn đặt lịch bảo dưỡng mới! Vui lòng kiểm tra.'),
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
    // Ngắt kết nối WebSocket để giải phóng tài nguyên khi Tab này bị hủy
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
      
      // Khởi tạo tác vụ tải danh sách từ Backend: Lấy cả đơn Chờ xử lý và Đã xác nhận
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
        
        // Gộp hai danh sách và sắp xếp theo ID (mới nhất lên đầu)
        final combined = [...pendingData, ...confirmedData];
        combined.sort((a, b) => b['id'].compareTo(a['id']));

        if (mounted) {
          setState(() {
            _appointments = combined;
            _isLoading = false;
          });
        }
      } else {
        throw Exception("Quá trình truy xuất dữ liệu thất bại");
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint("Lỗi truy xuất lịch hẹn: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Lịch hẹn'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _appointments.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text('Không có lịch hẹn đang chờ xử lý', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchAppointments,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _appointments.length,
                    itemBuilder: (context, index) {
                      final apt = _appointments[index];
                      final DateTime date = DateTime.parse(apt['appointmentDate']).toLocal();
                      final String formattedDate = DateFormat('HH:mm - dd/MM/yyyy').format(date);
                      final String customerName = apt['customer']?['fullName'] ?? apt['customerName'] ?? 'Khách hàng';
                      final String status = apt['status'];

                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _showAppointmentActionSheet(context, apt),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: CircleAvatar(
                              backgroundColor: status == 'CONFIRMED' ? Colors.green.shade50 : Colors.blue.shade50,
                              child: Icon(Icons.person, color: status == 'CONFIRMED' ? Colors.green.shade700 : Colors.blue.shade700),
                            ),
                            title: Text(customerName, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.access_time, size: 14, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(formattedDate, style: const TextStyle(color: Colors.grey)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                _buildStatusBadge(status),
                              ],
                            ),
                            trailing: const Icon(Icons.chevron_right),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  /// Khởi tạo nhãn hiển thị trạng thái của đơn đặt lịch
  Widget _buildStatusBadge(String status) {
    Color color;
    String text;
    switch (status) {
      case 'PENDING':
        color = Colors.orange;
        text = 'Chờ xác nhận';
        break;
      case 'CONFIRMED':
        color = Colors.green;
        text = 'Đã nhận xe';
        break;
      default:
        color = Colors.grey;
        text = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  /// Cập nhật trạng thái Lịch hẹn qua API Backend và làm mới giao diện cục bộ
  Future<void> _updateAppointmentStatus(BuildContext context, int appointmentId, String newStatus) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.firebaseUser;
      if (user == null) return;
      
      String? token = await user.getIdToken();
      
      // Gọi API cập nhật dữ liệu trên Server
      final response = await http.put(
        Uri.parse('http://10.0.2.2:8080/api/appointments/$appointmentId/status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'status': newStatus}),
      );

      if (response.statusCode == 200) {
        // Đóng BottomSheet
        if (mounted) Navigator.pop(context);

        // Cập nhật State cục bộ để UI thay đổi lập tức mà không cần gọi lại API GET
        setState(() {
          final index = _appointments.indexWhere((a) => a['id'] == appointmentId);
          if (index != -1) {
            // Nếu Hoàn thành hoặc Hủy, xóa khỏi danh sách Chờ/Xác nhận. Nếu không thì cập nhật nhãn.
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
              content: Text('✅ Đã cập nhật trạng thái đơn thành công!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception("Giao tiếp máy chủ thất bại.");
      }
    } catch (e) {
      debugPrint('Lỗi cập nhật trạng thái: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lỗi hệ thống: Không thể cập nhật trạng thái.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Giao diện BottomSheet cung cấp các nút thao tác nghiệp vụ
  void _showAppointmentActionSheet(BuildContext context, dynamic apt) {
    final status = apt['status'];
    final customerName = apt['customer']?['fullName'] ?? 'Khách hàng ẩn danh';
    final vehicle = apt['vehicle'] ?? {};
    final vehicleInfo = vehicle.isNotEmpty ? '${vehicle['brand']} ${vehicle['model']} - ${vehicle['licensePlate']}' : 'Chưa có dữ liệu xe';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Xử lý Lịch hẹn #${apt['id']}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Text('👤 Khách hàng: $customerName', style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 8),
              Text('🛵 Xe: $vehicleInfo', style: const TextStyle(fontSize: 16, color: Colors.grey)),
              const SizedBox(height: 8),
              Text('📝 Ghi chú: ${apt['note'] ?? 'Không có'}', style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic)),
              const SizedBox(height: 24),
              
              if (status == 'PENDING')
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _updateAppointmentStatus(context, apt['id'], 'CONFIRMED'),
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Xác nhận nhận xe'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              if (status == 'CONFIRMED')
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _updateAppointmentStatus(context, apt['id'], 'COMPLETED'),
                    icon: const Icon(Icons.done_all),
                    label: const Text('Hoàn thành bảo dưỡng'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () => _updateAppointmentStatus(context, apt['id'], 'CANCELLED'),
                  icon: const Icon(Icons.cancel),
                  label: const Text('Từ chối / Hủy lịch'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 12),
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

/// Giao diện Cá nhân: Thông tin tài khoản và điều khiển phiên làm việc
class _BranchProfileTab extends StatelessWidget {
  const _BranchProfileTab();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cá nhân'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Center(
            child: CircleAvatar(
              radius: 40,
              backgroundColor: Colors.teal,
              child: Icon(Icons.storefront, size: 40, color: Colors.white),
            ),
          ),
          const SizedBox(height: 32),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Đăng xuất', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              onTap: () {
                context.read<AuthProvider>().logout();
              },
            ),
          ),
        ],
      ),
    );
  }
}