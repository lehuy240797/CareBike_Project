import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api_client.dart';
import '../../services/web_socket_service.dart';

class BranchRescueScreen extends StatefulWidget {
  final int branchId;
  const BranchRescueScreen({super.key, required this.branchId});

  @override
  State<BranchRescueScreen> createState() => _BranchRescueScreenState();
}

class _BranchRescueScreenState extends State<BranchRescueScreen> {
  List<dynamic> _pendingRescues = [];
  List<dynamic> _acceptedRescues = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRescues();
    _setupWebSocket();
  }

  @override
  void dispose() {
    WebSocketService.disconnect();
    super.dispose();
  }

  // 1. LẤY DỮ LIỆU TỪ BACKEND VÀ CHIA VÀO 2 TAB
  Future<void> _fetchRescues() async {
    try {
      final res = await ApiClient.get('/rescues/branch/${widget.branchId}');
      final data = ApiClient.parseResponse(res) as List;

      if (mounted) {
        setState(() {
          _pendingRescues = data.where((r) => r['status'] == 'PENDING').toList();
          _acceptedRescues = data.where((r) => r['status'] == 'ACCEPTED').toList();
        });
      }
    } catch (e) {
      debugPrint("Lỗi tải danh sách cứu hộ: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 2. RADAR LẮNG NGHE CA MỚI (Real-time)
  void _setupWebSocket() {
    WebSocketService.connectBranch(widget.branchId, (newRescue) {
      if (mounted) {
        setState(() {
          // Bỏ vào danh sách Chờ tiếp nhận
          _pendingRescues.insert(0, newRescue);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🚨 CÓ CA CỨU HỘ MỚI! VUI LÒNG KIỂM TRA NGAY!'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    });
  }

  // 3. GỌI ĐIỆN (Chỉ hoạt động trên máy thật)
  Future<void> _callCustomer(String phone) async {
    final Uri uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không thể gọi điện trên thiết bị ảo.')));
    }
  }

  // 4. FIX LỖI BẢN ĐỒ: Mở đường dẫn Google Maps chuẩn để vạch đường
  Future<void> _openGoogleMaps(double destLat, double destLng) async {
    final String googleMapsUrl = 'https://www.google.com/maps/dir/?api=1&destination=$destLat,$destLng';
    final Uri uri = Uri.parse(googleMapsUrl);

    try {
      // LaunchMode.externalApplication đảm bảo nó mở bằng App Google Maps chứ không mở trình duyệt ẩn
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không tìm thấy ứng dụng bản đồ trên máy.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi: Không thể khởi chạy bản đồ.')));
    }
  }

  // 5. CHUYỂN CA TỪ "CHỜ TIẾP NHẬN" SANG "ĐANG XỬ LÝ"
  Future<void> _acceptRescue(int rescueId) async {
    try {
      // Gọi API xuống Spring Boot để cập nhật DB
      await ApiClient.put('/rescues/$rescueId/accept', {});

      // Xử lý UI: Đẩy ca từ mảng Pending sang Accepted
      setState(() {
        final itemIndex = _pendingRescues.indexWhere((r) => r['id'] == rescueId);
        if (itemIndex != -1) {
          final item = _pendingRescues.removeAt(itemIndex);
          item['status'] = 'ACCEPTED';
          _acceptedRescues.insert(0, item);
        }
      });

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã nhận ca! Hãy sang tab "Đang xử lý" để xem.'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Có lỗi xảy ra khi gọi API nhận ca.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    // SỬ DỤNG DEFAULT TAB CONTROLLER ĐỂ TẠO 2 TAB
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          title: const Text('Điều Phối Cứu Hộ', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.red.shade700,
          foregroundColor: Colors.white,
          actions: [
            IconButton(icon: const Icon(Icons.refresh), onPressed: () { setState(() => _isLoading = true); _fetchRescues(); })
          ],
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            indicatorWeight: 4,
            tabs: [
              Tab(text: 'CHỜ TIẾP NHẬN'),
              Tab(text: 'ĐANG XỬ LÝ'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.red))
            : TabBarView(
          children: [
            _buildList(_pendingRescues, isPending: true),
            _buildList(_acceptedRescues, isPending: false),
          ],
        ),
      ),
    );
  }

  // HÀM TẠO DANH SÁCH CHUNG CHO CẢ 2 TAB
  Widget _buildList(List<dynamic> list, {required bool isPending}) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 80, color: Colors.green.shade300),
            const SizedBox(height: 16),
            Text(isPending ? 'Không có yêu cầu cứu hộ nào mới.' : 'Chưa có ca nào đang xử lý.', style: const TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        return _buildRescueCard(list[index], isPending: isPending);
      },
    );
  }

  // THẺ HIỂN THỊ THÔNG TIN
  Widget _buildRescueCard(dynamic r, {required bool isPending}) {
    final customer = r['customer'];
    final vehicle = r['vehicle'];

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: isPending ? Colors.red.shade600 : Colors.blue.shade600, width: 6)),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Yêu cầu #${r['id']}', style: TextStyle(fontWeight: FontWeight.bold, color: isPending ? Colors.red.shade800 : Colors.blue.shade800, fontSize: 16)),
                Icon(isPending ? Icons.warning_amber_rounded : Icons.engineering, color: isPending ? Colors.orange : Colors.blue),
              ],
            ),
            const Divider(),
            Text('Khách hàng: ${customer['fullName'] ?? 'Ẩn danh'}', style: const TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade100)),
              child: Text('⚠️ Sự cố: ${r['issueDescription']}', style: TextStyle(color: Colors.red.shade800, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('🚙 Xe: ${vehicle['brand']} ${vehicle['model']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('🏷️ Biển số: ${vehicle['licensePlate']}'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // NÚT GỌI ĐIỆN VÀ BẢN ĐỒ LUÔN HIỆN ĐỂ NHÂN VIÊN SỬ DỤNG
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _callCustomer(customer['phone']),
                    icon: const Icon(Icons.phone, size: 18),
                    label: const Text('Gọi KH'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _openGoogleMaps(r['latitude'], r['longitude']),
                    icon: const Icon(Icons.map, size: 18),
                    label: const Text('Bản đồ'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                  ),
                ),
              ],
            ),

            // NẾU LÀ TAB CHỜ TIẾP NHẬN -> HIỆN NÚT NHẬN CA
            if (isPending) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _acceptRescue(r['id']),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('TIẾP NHẬN CA NÀY', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}