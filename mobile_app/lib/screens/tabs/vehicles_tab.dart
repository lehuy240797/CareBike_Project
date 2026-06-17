import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../models/vehicle.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/loading_button.dart';

class VehiclesTab extends StatefulWidget {
  const VehiclesTab({super.key});

  @override
  State<VehiclesTab> createState() => _VehiclesTabState();
}

class _VehiclesTabState extends State<VehiclesTab> {
  // THAY ĐỔI: Chuyển từ 1 xe sang 1 Danh sách xe
  List<Vehicle> _vehicles = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });

    try {
      final userId = context.read<AuthProvider>().mysqlUser?['userId'];
      if (userId == null) throw Exception('Không tìm thấy thông tin đăng nhập.');

      final response = await ApiClient.get('/vehicles/owner/$userId');
      final data = ApiClient.parseResponse(response);

      // Nhận 1 mảng dữ liệu xe từ Backend
      if (data is List) {
        _vehicles = data.map((v) => Vehicle.fromJson(v as Map<String, dynamic>)).toList();
      } else {
        _vehicles = [];
      }
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        _vehicles = [];
      } else {
        _error = e.message;
      }
    } catch (e) {
      _error = 'Lỗi hệ thống: $e';
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  void _openForm({Vehicle? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _VehicleForm(
        existing: existing,
        onSaved: () => _load(), // Cập nhật xong thì tải lại danh sách
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('Hồ sơ xe máy'),
        centerTitle: true,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(), // Bấm nút này là luôn mở form Thêm mới
        icon: const Icon(Icons.add),
        label: const Text('Thêm xe'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(child: Text(_error!, style: TextStyle(color: scheme.error)))
            : _vehicles.isEmpty
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.motorcycle_outlined, size: 72, color: scheme.outlineVariant),
              const SizedBox(height: 16),
              Text('Chưa có hồ sơ xe',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: scheme.onSurface)),
              const SizedBox(height: 8),
              Text('Nhấn nút bên dưới để thêm xe của bạn.',
                  style: TextStyle(color: scheme.onSurfaceVariant)),
            ],
          ),
        )
        // HIỂN THỊ DANH SÁCH NHIỀU XE
            : ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), // Cách đáy cho khỏi vướng nút Add
          itemCount: _vehicles.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final vehicle = _vehicles[index];
            return _VehicleCard(
              vehicle: vehicle,
              onEdit: () => _openForm(existing: vehicle), // Truyền xe cũ vào để sửa
            );
          },
        ),
      ),
    );
  }
}

// ── Vehicle display card ──────────────────────────────────────────────────────

class _VehicleCard extends StatelessWidget {
  final Vehicle vehicle;
  final VoidCallback onEdit; // Thêm hàm lắng nghe sự kiện sửa

  const _VehicleCard({required this.vehicle, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: scheme.primaryContainer.withValues(alpha: 0.5), // Giảm màu nền xíu cho dịu
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)), // Thêm viền mờ
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.motorcycle_rounded, size: 32, color: scheme.primary),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(vehicle.vehicleName,
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: scheme.onPrimaryContainer)),
                      const SizedBox(height: 4),
                      Row(children: [
                        _Chip(vehicle.brand),
                        const SizedBox(width: 6),
                        _Chip(vehicle.typeLabel),
                      ]),
                    ],
                  )),
                  // Nút chỉnh sửa nằm góc trên bên phải của Thẻ
                  IconButton(
                    icon: Icon(Icons.edit_note_rounded, color: scheme.primary),
                    onPressed: onEdit,
                    tooltip: 'Chỉnh sửa xe',
                  )
                ]
            ),
            const SizedBox(height: 20),
            _DetailRow(label: 'Hãng xe',     value: vehicle.brand),
            _DetailRow(label: 'Dòng xe',     value: vehicle.typeLabel),
            _DetailRow(label: 'Tên xe',      value: vehicle.vehicleName),
            _DetailRow(label: 'Biển số xe',  value: vehicle.licensePlate, mono: true),
            _DetailRow(label: 'Phân khối',   value: '${vehicle.engineCapacity ?? 0} cc'),
            _DetailRow(label: 'Số Km đã đi', value: '${vehicle.currentKm ?? 0} km'),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip(this.label);
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: scheme.primary, fontWeight: FontWeight.w600)),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool mono;
  const _DetailRow({required this.label, required this.value, this.mono = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 90, child: Text(label, style: TextStyle(color: scheme.onPrimaryContainer.withValues(alpha: 0.7), fontSize: 13))),
          Expanded(child: Text(value,
            style: TextStyle(
              color: scheme.onPrimaryContainer,
              fontWeight: FontWeight.w600,
              fontFamily: mono ? 'monospace' : null,
              fontSize: mono ? 16 : 14,
              letterSpacing: mono ? 1.5 : 0,
            ),
          )),
        ],
      ),
    );
  }
}

// ── Vehicle form bottom sheet ─────────────────────────────────────────────────

class _VehicleForm extends StatefulWidget {
  final Vehicle? existing;
  final VoidCallback onSaved;
  const _VehicleForm({this.existing, required this.onSaved});

  @override
  State<_VehicleForm> createState() => _VehicleFormState();
}

class _VehicleFormState extends State<_VehicleForm> {
  final _formKey            = GlobalKey<FormState>();
  final _nameCtrl           = TextEditingController();
  final _licensePlateCtrl   = TextEditingController();
  final _engineCapacityCtrl = TextEditingController();
  final _currentKmCtrl      = TextEditingController();

  String _brand       = 'Honda';
  String _vehicleType = 'XE_TAY_GA';
  bool   _isSaving    = false;
  String? _error;

  static const _brands = ['Honda', 'Yamaha', 'Suzuki', 'SYM', 'Piaggio', 'Khác'];
  static const _types  = [
    {'value': 'XE_SO',     'label': 'Xe số'},
    {'value': 'XE_TAY_GA', 'label': 'Xe tay ga'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final v = widget.existing!;
      _nameCtrl.text           = v.vehicleName;
      _licensePlateCtrl.text   = v.licensePlate;
      _engineCapacityCtrl.text = v.engineCapacity?.toString() ?? '';
      _currentKmCtrl.text      = v.currentKm?.toString() ?? '';
      _brand                   = v.brand;
      _vehicleType             = v.vehicleType;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _licensePlateCtrl.dispose();
    _engineCapacityCtrl.dispose();
    _currentKmCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isSaving = true; _error = null; });

    try {
      final userId = context.read<AuthProvider>().mysqlUser?['userId'];
      final body = {
        'id':             widget.existing?.id, // Gửi kèm ID nếu là đang sửa
        'brand':          _brand,
        'vehicleType':    _vehicleType,
        'vehicleName':    _nameCtrl.text.trim(),
        'licensePlate':   _licensePlateCtrl.text.trim().toUpperCase(),
        'engineCapacity': int.tryParse(_engineCapacityCtrl.text.trim()) ?? 0,
        'currentKm':      int.tryParse(_currentKmCtrl.text.trim()) ?? 0,
      };

      await ApiClient.put('/vehicles/owner/$userId', body);

      widget.onSaved(); // Báo cho danh sách load lại
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      // IN RA CONSOLE CỦA FLUTTER
      print('=== LỖI TỪ BACKEND TRẢ VỀ: ${e.message} ===');
      setState(() { _error = e.message; });
    } catch (e) {
      // IN RA CONSOLE CỦA FLUTTER
      print('=== LỖI FLUTTER NỘI BỘ: $e ===');
      setState(() { _error = 'Lưu thất bại: $e'; });
    } finally {
      if (mounted) setState(() { _isSaving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(color: scheme.outlineVariant, borderRadius: BorderRadius.circular(2)),
              )),
              const SizedBox(height: 16),
              Text(widget.existing == null ? 'Thêm xe máy' : 'Chỉnh sửa xe',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: scheme.onSurface)),
              const SizedBox(height: 16),

              Row(children: [
                Expanded(child: _DropdownField(
                  label: 'Hãng xe',
                  value: _brand,
                  items: _brands.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                  onChanged: (v) => setState(() => _brand = v!),
                )),
                const SizedBox(width: 12),
                Expanded(child: _DropdownField(
                  label: 'Dòng xe',
                  value: _vehicleType,
                  items: _types.map((t) => DropdownMenuItem(value: t['value'], child: Text(t['label']!))).toList(),
                  onChanged: (v) => setState(() => _vehicleType = v!),
                )),
              ]),
              const SizedBox(height: 12),

              AppTextField(
                label: 'Tên xe', controller: _nameCtrl, hint: 'VD: Airblade, Exciter...',
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập tên xe.' : null,
              ),
              const SizedBox(height: 12),

              AppTextField(
                label: 'Biển số xe', controller: _licensePlateCtrl, hint: 'VD: 59X1-123.45',
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập biển số xe.' : null,
              ),
              const SizedBox(height: 12),

              Row(children: [
                Expanded(child: AppTextField(
                  label: 'Phân khối', controller: _engineCapacityCtrl, keyboardType: TextInputType.number, hint: 'VD: 150',
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Bắt buộc';
                    if (int.tryParse(v) == null) return 'Phải là số';
                    return null;
                  },
                )),
                const SizedBox(width: 12),
                Expanded(child: AppTextField(
                  label: 'Số Km đi', controller: _currentKmCtrl, keyboardType: TextInputType.number, hint: 'VD: 15000',
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Bắt buộc';
                    if (int.tryParse(v) == null) return 'Phải là số';
                    return null;
                  },
                )),
              ]),

              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: TextStyle(color: scheme.error, fontSize: 13)),
              ],
              const SizedBox(height: 20),

              LoadingButton(label: 'Lưu hồ sơ xe', isLoading: _isSaving, onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final void Function(T?) onChanged;
  const _DropdownField({required this.label, required this.value, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<T>(
    value: value,
    decoration: InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    isExpanded: true,
    items: items,
    onChanged: onChanged,
  );
}