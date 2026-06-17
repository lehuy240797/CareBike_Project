import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/loading_button.dart';
import '../../providers/auth_provider.dart';

class CreateMaintenanceScreen extends StatefulWidget {
  final int customerId;
  final String customerName;

  const CreateMaintenanceScreen({
    super.key,
    required this.customerId,
    required this.customerName
  });

  @override
  State<CreateMaintenanceScreen> createState() => _CreateMaintenanceScreenState();
}

class _CreateMaintenanceScreenState extends State<CreateMaintenanceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _serviceDetailsCtrl = TextEditingController();
  final _currentKmCtrl = TextEditingController();
  final _totalCostCtrl = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _serviceDetailsCtrl.dispose();
    _currentKmCtrl.dispose();
    _totalCostCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final auth = context.read<AuthProvider>();
      final myUserId = auth.mysqlUser?['userId'];

      final branchesRes = await ApiClient.get('/branches');
      final branchesData = ApiClient.parseResponse(branchesRes) as List;

      int? currentBranchId;
      for (var b in branchesData) {
        final manager = b['manager'] as Map<String, dynamic>?;
        if (manager != null && manager['id'] == myUserId) {
          currentBranchId = b['id'] as int;
          break;
        }
      }

      if (currentBranchId == null) {
        throw Exception('Không tìm thấy chi nhánh của bạn. Bạn có phải là quản lý chi nhánh không?');
      }

      // Đẩy phiếu bảo dưỡng lên Spring Boot
      await ApiClient.post('/maintenance', {
        'serviceDate': DateTime.now().toIso8601String().split('T')[0],
        'currentKm': int.tryParse(_currentKmCtrl.text) ?? 0,
        'serviceDetails': _serviceDetailsCtrl.text,
        'totalCost': double.tryParse(_totalCostCtrl.text.replaceAll('.', '')) ?? 0.0,
        'customerId': widget.customerId, // Lấy ID trực tiếp từ mã QR
        'branchId': currentBranchId,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tạo phiếu bảo dưỡng thành công!'), backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Có lỗi xảy ra: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tạo phiếu bảo dưỡng')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Đã đổi từ Hiển thị thông tin Xe sang thông tin Khách hàng
              Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.teal,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  title: Text(widget.customerName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('ID Hệ thống: CB-${widget.customerId}'),
                ),
              ),
              const SizedBox(height: 24),
              const Text('Chi tiết sửa chữa', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              AppTextField(
                label: 'Phụ tùng linh kiện đã thay', controller: _serviceDetailsCtrl, hint: 'VD: Thay nhớt, Thay lốp...',
                validator: (v) => v == null || v.isEmpty ? 'Vui lòng nhập chi tiết' : null,
              ),
              const SizedBox(height: 16),

              AppTextField(
                label: 'Số Km hiện tại', controller: _currentKmCtrl, keyboardType: TextInputType.number,
                validator: (v) => v == null || v.isEmpty ? 'Vui lòng nhập số km' : null,
              ),
              const SizedBox(height: 16),

              AppTextField(
                label: 'Tổng tiền (VNĐ)', controller: _totalCostCtrl, keyboardType: TextInputType.number,
                validator: (v) => v == null || v.isEmpty ? 'Vui lòng nhập tổng tiền' : null,
              ),

              const SizedBox(height: 32),
              LoadingButton(
                label: 'Lưu phiếu bảo dưỡng',
                isLoading: _isLoading,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}