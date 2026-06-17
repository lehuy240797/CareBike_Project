import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'branch_rescue_screen.dart';
import 'create_maintenance_screen.dart';

class BranchMobileDashboard extends StatefulWidget {
  const BranchMobileDashboard({super.key});

  @override
  State<BranchMobileDashboard> createState() => _BranchMobileDashboardState();
}

class _BranchMobileDashboardState extends State<BranchMobileDashboard> {
  bool _isScanning = false;
  final MobileScannerController _scannerController = MobileScannerController();

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty && !_isScanning) {
      final String? code = barcodes.first.rawValue;
      if (code != null) {
        setState(() => _isScanning = true);
        _scannerController.stop();

        try {
          // =========================================================
          // GIẢI MÃ CHUỖI JSON TỪ MÃ QR CỦA KHÁCH HÀNG
          // =========================================================
          final Map<String, dynamic> qrData = jsonDecode(code);
          final int customerId = qrData['customerId'];
          final String customerName = qrData['fullName'] ?? 'Khách hàng';

          if (!mounted) return;

          // Chuyển sang màn hình tạo phiếu và truyền thẳng thông tin Khách Hàng
          await Navigator.push(
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
            const SnackBar(content: Text('Mã QR không hợp lệ hoặc không đúng định dạng của CareBike.'), backgroundColor: Colors.red),
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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    final fullName = auth.mysqlUser?['fullName'];
    final email = auth.firebaseUser?.email;
    final displayName = (fullName != null && fullName.toString().isNotEmpty) ? fullName : email;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Chi nhánh'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthProvider>().logout(),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Xin chào, $displayName',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('Nhân viên chi nhánh', style: TextStyle(fontSize: 16, color: Colors.grey)),
              const SizedBox(height: 24),

              // 👉 NÚT BẤM VÀO TRANG CỨU HỘ
              SizedBox(
                width: double.infinity,
                height: 70,
                child: ElevatedButton.icon(
                  onPressed: () {
                    debugPrint('🚨 DỮ LIỆU USER TỪ BACKEND: ${auth.mysqlUser}');
                    final userMap = auth.mysqlUser;
                    final branchId = userMap?['branchId']
                        ?? userMap?['branch']?['id']
                        ?? userMap?['user']?['branchId']
                        ?? userMap?['user']?['branch']?['id']
                        ?? userMap?['branch_id'];
                    if (branchId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Lỗi: Không tìm thấy dữ liệu Chi nhánh trong tài khoản này.'),
                            backgroundColor: Colors.red,
                          )
                      );
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => BranchRescueScreen(branchId: branchId)),
                    );
                  },
                  icon: const Icon(Icons.support_agent, size: 30),
                  label: const Text('QUẢN LÝ CỨU HỘ 24/7', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 5,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              if (_isScanning)
                const CircularProgressIndicator()
              else ...[
                const Icon(Icons.qr_code_scanner, size: 80, color: Colors.teal),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: FilledButton.icon(
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        builder: (context) => SizedBox(
                          height: MediaQuery.of(context).size.height * 0.7,
                          child: Column(
                            children: [
                              AppBar(title: const Text('Quét mã QR Khách hàng'), leading: const CloseButton()),
                              Expanded(
                                child: MobileScanner(
                                  controller: _scannerController,
                                  onDetect: _onDetect,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Quét QR Khách hàng', style: TextStyle(fontSize: 18)),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Sử dụng camera để quét mã QR trên ứng dụng của khách hàng để tạo phiếu bảo dưỡng.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}