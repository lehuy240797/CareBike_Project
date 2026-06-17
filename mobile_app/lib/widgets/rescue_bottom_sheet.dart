import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../core/api_client.dart';
import '../providers/auth_provider.dart';


class RescueBottomSheet extends StatefulWidget {
  const RescueBottomSheet({super.key});

  // Hàm tĩnh giúp gọi BottomSheet này ở bất kỳ đâu chỉ với 1 dòng code
  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Cho phép BottomSheet trượt cao lên khi mở bàn phím
      backgroundColor: Colors.transparent,
      builder: (_) => const RescueBottomSheet(),
    );
  }

  @override
  State<RescueBottomSheet> createState() => _RescueBottomSheetState();
}

class _RescueBottomSheetState extends State<RescueBottomSheet> {
  bool _isLoadingVehicles = true;
  bool _isLocating = true;
  bool _isSubmitting = false;

  List<dynamic> _myVehicles = [];
  dynamic _selectedVehicle;

  double? _lat;
  double? _lng;

  final List<String> _issues = [
    'Thủng lốp / Xịt lốp',
    'Hết ắc quy',
    'Đứt xích / Curoa',
    'Chết máy không rõ nguyên nhân'
  ];
  String _selectedIssue = '';
  final _otherIssueCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  @override
  void dispose() {
    _otherIssueCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchInitialData() async {
    // Chạy song song 2 luồng: Định vị GPS và Tải danh sách xe để tiết kiệm thời gian
    await Future.wait([
      _getLocationSafe(),
      _loadMyVehicles(),
    ]);
  }

  // ── LOGIC LẤY GPS SIÊU AN TOÀN (KẾT THỪA TỪ MAP) ──
  Future<void> _getLocationSafe() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('GPS tắt');

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw Exception('Từ chối quyền');
      }

      late LocationSettings locationSettings;
      if (defaultTargetPlatform == TargetPlatform.android) {
        locationSettings = AndroidSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 5),
          forceLocationManager: true, // Ép lấy GPS vượt rào máy ảo
        );
      } else {
        locationSettings = const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 5),
        );
      }

      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high, // Độ chính xác cao
        timeLimit: const Duration(seconds: 5), // Timeout 5s
      );
      _lat = pos.latitude;
      _lng = pos.longitude;
    } catch (e) {
      // Nếu không lấy được GPS, lấy vị trí cũ hoặc để null (sẽ cảnh báo lúc gửi)
      try {
        Position? lastPos = await Geolocator.getLastKnownPosition();
        if (lastPos != null) {
          _lat = lastPos.latitude;
          _lng = lastPos.longitude;
        }
      } catch (_) {}
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  // ── LOGIC TẢI DANH SÁCH XE CỦA KHÁCH ──
  Future<void> _loadMyVehicles() async {
    // 1. Lấy user từ Provider
    final user = context.read<AuthProvider>().mysqlUser;

    // Thử lấy 'userId', nếu không có thì thử lấy 'id' (Rất hay sai ở chỗ này)
    final userId = user?['userId'] ?? user?['id'];

    if (userId == null) {
      if (kDebugMode) print('🚨 LỖI: Không lấy được ID khách hàng từ AuthProvider');
      if (mounted) setState(() => _isLoadingVehicles = false);
      return;
    }

    if (kDebugMode) print('▶️ Đang tải danh sách xe cho Customer ID: $userId');

    try {
      // 2. Gọi API
      final res = await ApiClient.get('/vehicles/owner/$userId');

      if (kDebugMode) print('✅ API Trả về: ${res.body}'); // In ra màn hình console để xem cấu trúc thật

      final data = ApiClient.parseResponse(res);

      if (mounted) {
        setState(() {
          // 3. Xử lý linh hoạt mọi cấu trúc JSON từ Backend
          if (data is List) {
            _myVehicles = data; // Nếu backend trả về thẳng mảng
          } else if (data is Map) {
            // Nếu backend bọc trong object (Ví dụ: ApiResponse)
            if (data.containsKey('data')) {
              _myVehicles = data['data'] ?? [];
            } else if (data.containsKey('content')) {
              _myVehicles = data['content'] ?? [];
            }
          }

          // 4. Set giá trị mặc định nếu có xe
          if (_myVehicles.isNotEmpty) {
            _selectedVehicle = _myVehicles.first;
          }
        });
      }
    } catch (e) {
      if (kDebugMode) print('🚨 LỖI KHI GỌI API XE: $e'); // Báo lỗi đỏ chót ra console nếu sai API
    } finally {
      if (mounted) setState(() => _isLoadingVehicles = false);
    }
  }

  // ── LOGIC GỬI YÊU CẦU CỨU HỘ ──
  Future<void> _submitRescue() async {
    if (_selectedVehicle == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chọn chiếc xe đang hỏng.')));
      return;
    }
    if (_selectedIssue.isEmpty && _otherIssueCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chọn hoặc nhập tình trạng xe.')));
      return;
    }
    if (_lat == null || _lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không thể lấy tọa độ. Vui lòng bật GPS và thử lại.')));
      return;
    }

    setState(() => _isSubmitting = true);

    final userId = context.read<AuthProvider>().mysqlUser?['userId'];
    final finalIssue = _selectedIssue.isNotEmpty ? _selectedIssue : _otherIssueCtrl.text.trim();

    try {
      // Gọi API POST yêu cầu cứu hộ xuống Backend
      await ApiClient.post('/rescues', {
        'customerId': userId,
        'vehicleId': _selectedVehicle['id'],
        'latitude': _lat,
        'longitude': _lng,
        'issueDescription': finalIssue,
      });

      if (!mounted) return;
      Navigator.pop(context); // Đóng form

      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Đã gửi yêu cầu! Hệ thống đang tìm chi nhánh gần nhất...'),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 4),
          )
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi gửi yêu cầu. Vui lòng thử lại.')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20, // Tự đẩy lên khi bật bàn phím
      ),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thanh gạt (Drag handle)
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Icon(Icons.support_agent, color: Colors.red.shade500, size: 28),
                const SizedBox(width: 8),
                const Text('Cứu hộ khẩn cấp 24/7', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 20),

            // 1. CHỌN XE ĐANG HỎNG
            Text('Xe nào đang gặp sự cố?', style: TextStyle(fontWeight: FontWeight.w600, color: scheme.onSurface)),
            const SizedBox(height: 8),
            if (_isLoadingVehicles)
              const Center(child: CircularProgressIndicator())
            else if (_myVehicles.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                child: const Text('Bạn chưa thêm xe nào vào hệ thống. Vui lòng thêm xe ở mục "Xe của tôi" trước.', style: TextStyle(color: Colors.red)),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(border: Border.all(color: scheme.outlineVariant), borderRadius: BorderRadius.circular(10)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<dynamic>(
                    value: _selectedVehicle,
                    isExpanded: true,
                    hint: const Text('Chọn xe...'),
                    items: _myVehicles.map((v) => DropdownMenuItem(
                      value: v,
                      child: Text('${v['brand']} ${v['model']} - Biển số: ${v['licensePlate']}', style: const TextStyle(fontWeight: FontWeight.w500)),
                    )).toList(),
                    onChanged: (val) => setState(() => _selectedVehicle = val),
                  ),
                ),
              ),
            const SizedBox(height: 20),

            // 2. TÌNH TRẠNG SỰ CỐ
            Text('Tình trạng xe hiện tại:', style: TextStyle(fontWeight: FontWeight.w600, color: scheme.onSurface)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _issues.map((issue) {
                final isSelected = _selectedIssue == issue;
                return ChoiceChip(
                  label: Text(issue),
                  selected: isSelected,
                  selectedColor: Colors.red.shade100,
                  side: BorderSide(color: isSelected ? Colors.red.shade300 : scheme.outlineVariant),
                  labelStyle: TextStyle(color: isSelected ? Colors.red.shade800 : scheme.onSurface, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                  onSelected: (selected) {
                    setState(() { _selectedIssue = selected ? issue : ''; _otherIssueCtrl.clear(); });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _otherIssueCtrl,
              decoration: InputDecoration(
                hintText: 'Nhập vấn đề khác (nếu có)...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onChanged: (val) {
                if (val.isNotEmpty) setState(() => _selectedIssue = '');
              },
            ),
            const SizedBox(height: 20),

            // 3. TRẠNG THÁI GPS
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: scheme.surfaceContainerLow, borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  Icon(
                      _isLocating ? Icons.gps_not_fixed : (_lat != null ? Icons.gps_fixed : Icons.location_off),
                      color: _lat != null ? Colors.blue : Colors.grey,
                      size: 20
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _isLocating
                        ? const Text('Đang định vị vị trí của bạn...', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))
                        : (_lat != null
                        ? const Text('Đã ghi nhận tọa độ của bạn để đội cứu hộ tìm kiếm.', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13))
                        : const Text('Lỗi GPS! Vui lòng bật vị trí.', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500))),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // NÚT GỌI CỨU HỘ
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: (_isSubmitting || _isLocating || _myVehicles.isEmpty) ? null : _submitRescue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                child: _isSubmitting
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('GỌI CỨU HỘ NGAY', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}