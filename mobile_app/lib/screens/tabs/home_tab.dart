import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../providers/auth_provider.dart';
import '../../models/branch.dart';
import '../../widgets/loading_button.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  List<Branch> _branches = [];
  bool _branchesLoading = true;

  Branch?        _selectedBranch;
  DateTime?      _selectedDate;
  TimeOfDay?     _selectedTime;
  final _noteCtrl = TextEditingController();
  bool _isBooking = false;
  String? _bookingError;
  String? _bookingSuccess;

  @override
  void initState() {
    super.initState();
    _loadBranches();
  }

  @override
  void dispose() { _noteCtrl.dispose(); super.dispose(); }

  Future<void> _loadBranches() async {
    setState(() => _branchesLoading = true);
    try {
      final response = await ApiClient.get('/branches');
      final data = ApiClient.parseResponse(response) as List;
      setState(() {
        _branches = data.map((e) => Branch.fromJson(e as Map<String, dynamic>)).toList();
        _branchesLoading = false;
      });
    } catch (_) {
      setState(() => _branchesLoading = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _submitBooking() async {
    if (_selectedBranch == null) {
      setState(() => _bookingError = 'Vui lòng chọn chi nhánh.');
      return;
    }
    if (_selectedDate == null || _selectedTime == null) {
      setState(() => _bookingError = 'Vui lòng chọn ngày và giờ hẹn.');
      return;
    }

    setState(() { _isBooking = true; _bookingError = null; _bookingSuccess = null; });

    final userId = context.read<AuthProvider>().mysqlUser?['userId'];
    final dt = DateTime(
      _selectedDate!.year, _selectedDate!.month, _selectedDate!.day,
      _selectedTime!.hour, _selectedTime!.minute,
    );

    try {
      final response = await ApiClient.post('/appointments', {
        'customerId':       userId,
        'branchId':         _selectedBranch!.id,
        'appointmentDate':  dt.toIso8601String(),
        'note':             _noteCtrl.text.trim(),
      });
      ApiClient.parseResponse(response);
      setState(() {
        _bookingSuccess = 'Đặt lịch thành công! Chi nhánh sẽ xác nhận sớm.';
        _isBooking = false;
        _selectedBranch = null; _selectedDate = null; _selectedTime = null;
        _noteCtrl.clear();
      });
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) { // Kiểm tra xem người dùng còn ở màn hình này không
          setState(() {
            _bookingSuccess = null;
          });
        }
      });
    } on ApiException catch (e) {
      setState(() { _bookingError = e.message; _isBooking = false; });
    } catch (_) {
      setState(() { _bookingError = 'Có lỗi xảy ra. Vui lòng thử lại.'; _isBooking = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final auth   = context.watch<AuthProvider>();

    final name = auth.mysqlUser?['fullName'] ?? auth.firebaseUser?.email ?? 'Khách';
    final role = auth.mysqlUser?['role'] == 'CUSTOMER' ? 'Khách hàng' : '';

    return Scaffold(
      backgroundColor: scheme.surface,
      body: RefreshIndicator(
        onRefresh: () async { await _loadBranches(); },
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 140,
              floating: true,
              snap: true,
              backgroundColor: scheme.primaryContainer,
              surfaceTintColor: Colors.transparent,

              leading: Builder(
                builder: (BuildContext context) {
                  return IconButton(
                    icon: Icon(Icons.menu_rounded, size: 28, color: scheme.onPrimaryContainer),
                    onPressed: () {
                      context.findRootAncestorStateOfType<ScaffoldState>()?.openDrawer();
                    },
                    tooltip: 'Mở Menu',
                  );
                },
              ),

              flexibleSpace: FlexibleSpaceBar(
                background: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text('Xin chào, $role $name 👋',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: scheme.onPrimaryContainer),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text('Đặt lịch bảo dưỡng xe máy nhanh chóng',
                        style: TextStyle(color: scheme.onPrimaryContainer.withValues(alpha: 0.75), fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionCard(
                      title: 'Đặt lịch bảo dưỡng', icon: Icons.event_available_rounded,
                      child: Column(
                        children: [
                          if (_branchesLoading)
                            const Center(child: CircularProgressIndicator())
                          else
                            DropdownButtonFormField<Branch>(
                              value: _selectedBranch, hint: const Text('Chọn chi nhánh'), isExpanded: true,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                              items: _branches.map((b) => DropdownMenuItem(value: b, child: Text(b.name, overflow: TextOverflow.ellipsis))).toList(),
                              onChanged: (v) => setState(() => _selectedBranch = v),
                            ),
                          const SizedBox(height: 12),

                          Row(
                            children: [
                              Expanded(
                                child: _PickerTile(
                                  icon: Icons.calendar_today_outlined,
                                  label: _selectedDate == null ? 'Chọn ngày' : '${_selectedDate!.day.toString().padLeft(2,'0')}/${_selectedDate!.month.toString().padLeft(2,'0')}/${_selectedDate!.year}',
                                  onTap: _pickDate,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _PickerTile(
                                  icon: Icons.access_time_rounded,
                                  label: _selectedTime == null ? 'Chọn giờ' : _selectedTime!.format(context),
                                  onTap: _pickTime,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          TextFormField(
                            controller: _noteCtrl, maxLines: 2,
                            decoration: InputDecoration(
                              hintText: 'Ghi chú (VD: xe bị rò dầu, thay nhớt...)',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),
                          const SizedBox(height: 6),

                          if (_bookingError != null) _Banner(text: _bookingError!, isError: true),
                          if (_bookingSuccess != null) _Banner(text: _bookingSuccess!, isError: false),
                          const SizedBox(height: 12),

                          LoadingButton(label: 'Đặt lịch ngay', isLoading: _isBooking, onPressed: _submitBooking),
                        ],
                      ),
                    ),
                    const SizedBox(height: 80),
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

// ── Các Helper widgets ────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _SectionCard({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurface)),
            ]),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _PickerTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outline),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          Icon(icon, size: 16, color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: scheme.onSurface), overflow: TextOverflow.ellipsis)),
        ]),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final String text;
  final bool isError;
  const _Banner({required this.text, required this.isError});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isError ? scheme.errorContainer : const Color(0xFFD1FAE5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        Icon(isError ? Icons.error_outline : Icons.check_circle_outline,
            size: 16, color: isError ? scheme.onErrorContainer : Colors.green[800]),
        const SizedBox(width: 8),
        Expanded(child: Text(text,
          style: TextStyle(
            fontSize: 13,
            color: isError ? scheme.onErrorContainer : Colors.green[900],
          ),
        )),
      ]),
    );
  }
}