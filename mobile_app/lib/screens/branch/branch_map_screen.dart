import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/api_client.dart';
import '../../models/branch.dart';
import 'package:url_launcher/url_launcher.dart';

class BranchMapScreen extends StatefulWidget {
  const BranchMapScreen({super.key});

  @override
  State<BranchMapScreen> createState() => _BranchMapScreenState();
}

class _BranchMapScreenState extends State<BranchMapScreen> {
  final MapController _mapController = MapController();

  List<Branch> _branches = [];
  LatLng? _userLocation;
  Branch? _selectedBranch;
  double? _distanceToSelected;

  bool _isLoading = true;
  String _statusMsg = "Đang tìm vị trí của bạn...";

  @override
  void initState() {
    super.initState();
    _initMapData();
  }

  Future<void> _initMapData() async {
    try {
      // 1. Thử lấy vị trí người dùng (An toàn)
      Position? position = await _determinePosition();

      if (position != null) {
        _userLocation = LatLng(position.latitude, position.longitude);
      } else {
        // NẾU GPS LỖI HOẶC TỪ CHỐI: Lấy trung tâm TP.HCM (Chợ Bến Thành) làm mặc định
        _userLocation = const LatLng(10.7725, 106.6981);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Không thể lấy GPS. Đang hiển thị bản đồ mặc định.'))
          );
        }
      }

      setState(() => _statusMsg = "Đang tải các chi nhánh...");

      // 2. Gọi API lấy danh sách chi nhánh
      final response = await ApiClient.get('/branches');
      final data = ApiClient.parseResponse(response);

      if (data is List) {
        _branches = data.map((e) => Branch.fromJson(e)).where((b) => b.latitude != null && b.longitude != null).toList();
      }

      // 3. Tìm chi nhánh gần nhất làm mặc định
      _findNearestBranch();

    } catch (e) {
      setState(() => _statusMsg = "Đã xảy ra lỗi: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _findNearestBranch() {
    if (_userLocation == null || _branches.isEmpty) return;

    final distanceCalc = const Distance();
    double minDistance = double.infinity;
    Branch? nearest;

    for (var branch in _branches) {
      final branchLoc = LatLng(branch.latitude!, branch.longitude!);
      final meter = distanceCalc.as(LengthUnit.Meter, _userLocation!, branchLoc);
      if (meter < minDistance) {
        minDistance = meter;
        nearest = branch;
      }
    }

    if (nearest != null) {
      _selectBranch(nearest);
      _mapController.move(LatLng(nearest.latitude!, nearest.longitude!), 14.0);
    }
  }

  void _selectBranch(Branch branch) {
    if (_userLocation == null) return;
    final distanceCalc = const Distance();
    final meter = distanceCalc.as(LengthUnit.Meter, _userLocation!, LatLng(branch.latitude!, branch.longitude!));

    setState(() {
      _selectedBranch = branch;
      _distanceToSelected = meter;
    });
  }

  // ── LOGIC MỞ GOOGLE MAPS ĐỂ CHỈ ĐƯỜNG ──
  Future<void> _openGoogleMaps(double destLat, double destLng) async {
    // Đây là Cú pháp Universal URL chính thức của Google Maps
    final String googleUrl = 'https://www.google.com/maps/dir/?api=1&destination=$destLat,$destLng';
    final Uri uri = Uri.parse(googleUrl);

    try {
      // Dùng LaunchMode.externalApplication để ép mở bằng App Google Maps (hoặc Trình duyệt web)
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không thể mở bản đồ trên thiết bị này.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: Không thể mở liên kết bản đồ!')),
        );
      }
    }
  }

  // ── LOGIC LẤY GPS SIÊU AN TOÀN (CHỐNG TREO APP) ──
  Future<Position?> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null; // GPS đang tắt

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null; // Từ chối cấp quyền
    }

    if (permission == LocationPermission.deniedForever) return null;

    try {
      // FIX LỖI TREO: Giới hạn thời gian chờ máy ảo phản hồi đúng 5 giây!
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 5),
      );
    } catch (e) {
      // Hết 5 giây mà không có phản hồi, thử lấy vị trí cũ nhất còn lưu trong bộ nhớ
      return await Geolocator.getLastKnownPosition();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: scheme.surface,
        appBar: AppBar(title: const Text('Bản đồ Chi nhánh')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(_statusMsg, style: TextStyle(color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hệ thống CareBike'),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _userLocation!,
              initialZoom: 13.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.carebike.app',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _userLocation!,
                    width: 60,
                    height: 60,
                    child: const Icon(Icons.my_location_rounded, color: Colors.blue, size: 30),
                  ),
                  ..._branches.map((b) {
                    final isSelected = _selectedBranch?.id == b.id;
                    return Marker(
                      point: LatLng(b.latitude!, b.longitude!),
                      width: 50,
                      height: 50,
                      child: GestureDetector(
                        onTap: () => _selectBranch(b),
                        child: Icon(
                          Icons.location_on,
                          color: isSelected ? Colors.red : scheme.primary,
                          size: isSelected ? 45 : 35,
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),

          Positioned(
            right: 16,
            bottom: _selectedBranch != null ? 180 : 20,
            child: FloatingActionButton(
              backgroundColor: scheme.surface,
              onPressed: () {
                _mapController.move(_userLocation!, 15.0);
              },
              child: Icon(Icons.my_location, color: scheme.primary),
            ),
          ),

          if (_selectedBranch != null)
            Positioned(
              left: 16, right: 16, bottom: 20,
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _selectedBranch!.name,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(8)),
                            child: Text(
                              _distanceToSelected != null
                                  ? '${(_distanceToSelected! / 1000).toStringAsFixed(1)} km'
                                  : '',
                              style: TextStyle(color: scheme.onPrimaryContainer, fontWeight: FontWeight.bold),
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(child: Text(_selectedBranch!.address, style: const TextStyle(color: Colors.black87))),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.phone_outlined, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(_selectedBranch!.phone, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500)),
                        ],
                      ),
                      // ── 2 NÚT BẤM CHUYÊN NGHIỆP ──
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                // Tạm thời bấm quay lại trang chủ.
                                // Sau này có thể truyền ID chi nhánh về HomeTab để tự động điền form.
                                Navigator.pop(context);
                              },
                              icon: const Icon(Icons.calendar_month, size: 18),
                              label: const Text('Đặt lịch'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                // GỌI HÀM MỞ GOOGLE MAPS TẠI ĐÂY
                                _openGoogleMaps(
                                    _selectedBranch!.latitude!,
                                    _selectedBranch!.longitude!
                                );
                              },
                              icon: const Icon(Icons.directions, size: 18),
                              label: const Text('Chỉ đường'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: scheme.primary,
                                foregroundColor: scheme.onPrimary,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ),
            )
        ],
      ),
    );
  }
}