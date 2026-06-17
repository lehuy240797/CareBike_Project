import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Thêm Provider
import '../../core/api_client.dart';
import '../../models/maintenance.dart';
import '../../providers/auth_provider.dart'; // Lấy ID trực tiếp từ Auth

class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  List<MaintenanceRecord> _records = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    // Bật vòng xoay ngay lập tức khi bắt đầu
    setState(() { _isLoading = true; _error = null; });

    try {
      // Lấy trực tiếp từ Provider để không bị lỗi mất Context/Delay
      final userId = context.read<AuthProvider>().mysqlUser?['userId'];
      if (userId == null) throw Exception('Chưa đăng nhập.');

      final response = await ApiClient.get('/maintenance/customer/$userId');
      final data = ApiClient.parseResponse(response);

      if (data is List) {
        _records = data.map((e) => MaintenanceRecord.fromJson(e as Map<String, dynamic>)).toList();
      } else {
        _records = [];
      }
    } on ApiException catch (e) {
      // Bắt chính xác lỗi 404 (Không tìm thấy lịch sử -> Khách mới)
      if (e.statusCode == 404) {
        _records = []; // Trả về mảng rỗng để hiện UI "Chưa có lịch sử"
      } else {
        _error = e.message;
      }
    } catch (e) {
      _error = 'Không thể tải lịch sử: $e';
    } finally {
      // Dù thành công hay thất bại (có hoặc không có lịch sử) đều PHẢI tắt vòng xoay
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('Lịch sử sửa chữa'),
        centerTitle: true,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_outlined, size: 52, color: scheme.outlineVariant),
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            TextButton(onPressed: _load, child: const Text('Thử lại')),
          ],
        ))
            : _records.isEmpty
            ? ListView(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.build_circle_outlined, size: 72, color: scheme.outlineVariant),
                    const SizedBox(height: 16),
                    Text('Chưa có lịch sử bảo dưỡng',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: scheme.onSurface)),
                  ],
                ),
              ),
            ),
          ],
        )
            : ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(), // Đảm bảo luôn kéo vuốt Refresh được
          padding: const EdgeInsets.all(16),
          itemCount: _records.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) => _RecordCard(record: _records[index], index: index),
        ),
      ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  final MaintenanceRecord record;
  final int index;
  const _RecordCard({required this.record, required this.index});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // ── Timeline indicator ───────────────────────────────────────
            Container(
              width: 48,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.12),
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.build_rounded, size: 20, color: scheme.primary),
                  const SizedBox(height: 4),
                  Text('#${index + 1}',
                      style: TextStyle(fontSize: 10, color: scheme.primary, fontWeight: FontWeight.w600)),
                ],
              ),
            ),

            // ── Details ──────────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(record.formattedDate,
                            style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurface)),
                        Text(record.formattedCost,
                            style: TextStyle(fontWeight: FontWeight.w700, color: scheme.primary, fontSize: 15)),
                      ],
                    ),
                    if (record.branchName != null) ...[
                      const SizedBox(height: 4),
                      Row(children: [
                        Icon(Icons.location_on_outlined, size: 13, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 3),
                        Text(record.branchName!, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
                      ]),
                    ],
                    if (record.currentKm != null) ...[
                      const SizedBox(height: 4),
                      Row(children: [
                        Icon(Icons.speed_outlined, size: 13, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 3),
                        Text('${record.currentKm} km',
                            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
                      ]),
                    ],
                    if (record.serviceDetails != null && record.serviceDetails!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(record.serviceDetails!,
                          style: TextStyle(fontSize: 12, color: scheme.onSurface),
                          maxLines: 3, overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}