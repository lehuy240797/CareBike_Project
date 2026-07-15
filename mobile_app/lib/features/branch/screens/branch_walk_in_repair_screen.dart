import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/theme/theme.dart';

class BranchWalkInRepairScreen extends StatefulWidget {
  final int branchId;

  const BranchWalkInRepairScreen({super.key, required this.branchId});

  @override
  State<BranchWalkInRepairScreen> createState() =>
      _BranchWalkInRepairScreenState();
}

class _BranchWalkInRepairScreenState extends State<BranchWalkInRepairScreen> {
  final _staffCodeCtrl = TextEditingController();
  final _customerNameCtrl = TextEditingController();
  final _customerPhoneCtrl = TextEditingController();
  final _vehicleNameCtrl = TextEditingController();
  final _vehiclePlateCtrl = TextEditingController();
  final _engineCapacityCtrl = TextEditingController();
  final _currentKmCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();

  final Map<int, Map<String, dynamic>> _cart = {};
  final double _laborCost = 100000;

  int _selectedCategoryIndex = 0;
  List<String> _categories = ['All'];
  List<dynamic> _spareParts = [];
  String _searchQuery = '';
  bool _staffVerified = false;
  bool _kmVerified = false;
  bool _isLoadingParts = true;
  Map<String, dynamic>? _staffInfo;

  final List<Map<String, dynamic>> _commonServices = [
    {'id': -1, 'name': 'Oil change labor', 'price': 80000.0, 'isService': true},
    {'id': -2, 'name': 'Brake inspection', 'price': 50000.0, 'isService': true},
    {'id': -3, 'name': 'Chain adjustment', 'price': 40000.0, 'isService': true},
    {'id': -4, 'name': 'Tire patch', 'price': 50000.0, 'isService': true},
    {'id': -5, 'name': 'Battery charge', 'price': 50000.0, 'isService': true},
  ];

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadSpareParts();
  }

  @override
  void dispose() {
    _staffCodeCtrl.dispose();
    _customerNameCtrl.dispose();
    _customerPhoneCtrl.dispose();
    _vehicleNameCtrl.dispose();
    _vehiclePlateCtrl.dispose();
    _engineCapacityCtrl.dispose();
    _currentKmCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final response = await ApiClient.get('/categories');
      final data = ApiClient.parseResponse(response) as List;
      final cats = data.map((e) => e['name'].toString()).toList();
      if (!mounted) return;
      setState(() => _categories = ['All', ...cats]);
    } catch (_) {}
  }

  Future<void> _loadSpareParts() async {
    setState(() => _isLoadingParts = true);
    try {
      final response = await ApiClient.get('/spare-parts?search=$_searchQuery');
      final data = ApiClient.parseResponse(response) as List;
      final category = _categories[_selectedCategoryIndex];
      List<dynamic> parts = data;

      if (category != 'All') {
        parts = data
            .where(
              (part) => (part['category'] ?? part['categoryName']) == category,
            )
            .toList();
      }

      final filteredServices = category == 'All'
          ? (_searchQuery.isEmpty
                ? _commonServices
                : _commonServices
                      .where(
                        (s) => s['name'].toString().toLowerCase().contains(
                          _searchQuery.toLowerCase(),
                        ),
                      )
                      .toList())
          : [];

      if (!mounted) return;
      setState(() {
        _spareParts = [...filteredServices, ...parts];
        _isLoadingParts = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingParts = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not load spare parts: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _verifyStaffCode() async {
    final code = _staffCodeCtrl.text.trim().toUpperCase();
    if (!RegExp(r'^CBS-\d{4}$').hasMatch(code)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Staff code must follow CBS-xxxx.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    try {
      final response = await ApiClient.get('/staff/verify-shift?code=$code');
      if (response.statusCode != 200) {
        throw Exception('Staff with this code was not found or not on shift.');
      }

      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _staffVerified = true;
        _staffInfo = data;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Verified staff: ${data['fullName']}'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  void _addToCart(dynamic part) {
    setState(() {
      final id = part['id'] as int;
      if (_cart.containsKey(id)) {
        _cart[id]!['quantity'] = (_cart[id]!['quantity'] as int) + 1;
      } else {
        _cart[id] = {'part': part, 'quantity': 1};
      }
    });
  }

  void _removeFromCart(int id) {
    setState(() {
      final item = _cart[id];
      if (item == null) return;
      final qty = item['quantity'] as int;
      if (qty > 1) {
        item['quantity'] = qty - 1;
      } else {
        _cart.remove(id);
      }
    });
  }

  double _calculateTotal() {
    double sum = _laborCost;
    for (final item in _cart.values) {
      final price = (item['part']['price'] as num).toDouble();
      final qty = item['quantity'] as int;
      sum += price * qty;
    }
    return sum;
  }

  void _openTemporaryBill() {
    if (_customerNameCtrl.text.trim().isEmpty ||
        _customerPhoneCtrl.text.trim().isEmpty ||
        _vehicleNameCtrl.text.trim().isEmpty ||
        _vehiclePlateCtrl.text.trim().isEmpty ||
        _engineCapacityCtrl.text.trim().isEmpty ||
        _currentKmCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please fill all customer and vehicle fields.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _WalkInTemporaryBillScreen(
          branchId: widget.branchId,
          customerName: _customerNameCtrl.text.trim(),
          customerPhone: _customerPhoneCtrl.text.trim(),
          vehicleName: _vehicleNameCtrl.text.trim(),
          vehiclePlate: _vehiclePlateCtrl.text.trim(),
          engineCapacity: _engineCapacityCtrl.text.trim(),
          currentKm: int.tryParse(_currentKmCtrl.text.trim()) ?? 0,
          staffCode: _staffInfo?['staffCode'] ?? _staffCodeCtrl.text.trim(),
          staffName: _staffInfo?['fullName'] ?? '',
          cart: Map.from(_cart),
          laborCost: _laborCost,
          totalAmount: _calculateTotal(),
        ),
      ),
    ).then((done) {
      if (done == true && mounted) Navigator.pop(context, true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: 'VND',
      decimalDigits: 0,
    );

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('Walk-in Repair Order'),
        centerTitle: true,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.ink,
        surfaceTintColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _contextCard(),
            const SizedBox(height: 20),
            _sectionTitle('STEP 1: Verify staff', Icons.badge_rounded),
            const SizedBox(height: 10),
            _staffVerified
                ? _verifiedTile(
                    title: 'Staff verified',
                    subtitle:
                        '${_staffInfo?['fullName']} (${_staffInfo?['staffCode']})',
                  )
                : Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _staffCodeCtrl,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            hintText: 'CBS-xxxx',
                            prefixIcon: Icon(Icons.badge_rounded),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _verifyStaffCode,
                        child: const Text('Confirm'),
                      ),
                    ],
                  ),
            const SizedBox(height: 20),
            _sectionTitle(
              'STEP 2: Customer & repair details',
              Icons.speed_rounded,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _customerNameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: 'Customer name',
                prefixIcon: Icon(Icons.person_rounded),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _customerPhoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                hintText: 'Customer phone',
                prefixIcon: Icon(Icons.phone_rounded),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _vehicleNameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: 'Vehicle name',
                prefixIcon: Icon(Icons.two_wheeler_rounded),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _vehiclePlateCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                hintText: 'License plate',
                prefixIcon: Icon(Icons.pin_rounded),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _engineCapacityCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: 'Engine capacity',
                prefixIcon: Icon(Icons.speed_rounded),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _currentKmCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'Current km',
                      prefixIcon: Icon(Icons.speed_rounded),
                    ),
                    onChanged: (_) {
                      if (_kmVerified) setState(() => _kmVerified = false);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    if (_currentKmCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Please enter current km first.'),
                          backgroundColor: AppColors.danger,
                        ),
                      );
                      return;
                    }
                    setState(() => _kmVerified = true);
                  },
                  child: const Text('Confirm'),
                ),
              ],
            ),
            if (_staffVerified && _kmVerified) ...[
              const SizedBox(height: 20),
              _sectionTitle(
                'STEP 3: Select services / spare parts',
                Icons.build_rounded,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _searchCtrl,
                decoration: const InputDecoration(
                  hintText: 'Search spare parts / services...',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: (value) {
                  _searchQuery = value;
                  _loadSpareParts();
                },
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  itemBuilder: (ctx, i) {
                    final isSelected = i == _selectedCategoryIndex;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedCategoryIndex = i);
                        _loadSpareParts();
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.edge,
                          ),
                        ),
                        child: Text(
                          _categories[i],
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : AppColors.inkMuted,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 230,
                child: _isLoadingParts
                    ? Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      )
                    : ListView.builder(
                        itemCount: _spareParts.length,
                        itemBuilder: (context, index) {
                          final part = _spareParts[index];
                          final price = (part['price'] as num).toDouble();
                          return Card(
                            color: AppColors.surface,
                            surfaceTintColor: Colors.transparent,
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: Icon(
                                part['isService'] == true
                                    ? Icons.handyman_rounded
                                    : Icons.settings_rounded,
                                color: AppColors.primary,
                                size: 32,
                              ),
                              title: Text(
                                part['name'].toString(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.ink,
                                ),
                              ),
                              subtitle: Text(
                                formatter.format(price),
                                style: TextStyle(
                                  color: AppColors.danger,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              trailing: IconButton(
                                icon: Icon(
                                  Icons.add_circle_rounded,
                                  color: AppColors.info,
                                ),
                                onPressed: () => _addToCart(part),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 14),
              _billSummary(formatter),
            ],
          ],
        ),
      ),
    );
  }

  Widget _contextCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppStyles.card(radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No-account customer',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Create a repair order for a walk-in customer without app account.',
            style: TextStyle(color: AppColors.inkMuted),
          ),
        ],
      ),
    );
  }

  Widget _billSummary(NumberFormat formatter) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppStyles.card(radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bill Summary',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          Divider(color: AppColors.edge),
          _priceRow('Maintenance labor fee', _laborCost, formatter),
          ..._cart.values.map((item) {
            final part = item['part'];
            final qty = item['quantity'] as int;
            final price = (part['price'] as num).toDouble();
            return _cartRow(
              part['id'] as int,
              '${part['name']} x$qty',
              price * qty,
              formatter,
            );
          }),
          Divider(color: AppColors.edge, thickness: 1.5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TOTAL',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: AppColors.ink,
                ),
              ),
              Text(
                formatter.format(_calculateTotal()),
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  color: AppColors.danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              onPressed: _openTemporaryBill,
              icon: const Icon(Icons.receipt_long_rounded),
              label: const Text(
                'CREATE TEMPORARY BILL',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cartRow(int id, String label, double amount, NumberFormat formatter) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(color: AppColors.ink)),
          ),
          Text(
            formatter.format(amount),
            style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink),
          ),
          IconButton(
            icon: Icon(Icons.remove_circle_rounded, color: AppColors.danger),
            onPressed: () => _removeFromCart(id),
          ),
        ],
      ),
    );
  }

  Widget _priceRow(String label, double amount, NumberFormat formatter) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(color: AppColors.ink)),
          ),
          Text(
            formatter.format(amount),
            style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
        ),
      ],
    );
  }

  Widget _verifiedTile({required String title, required String subtitle}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.successBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.verified_user_rounded, color: AppColors.success),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(subtitle, style: TextStyle(color: AppColors.ink)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WalkInTemporaryBillScreen extends StatefulWidget {
  final int branchId;
  final String customerName;
  final String customerPhone;
  final String vehicleName;
  final String vehiclePlate;
  final String engineCapacity;
  final int currentKm;
  final String staffCode;
  final String staffName;
  final Map<int, Map<String, dynamic>> cart;
  final double laborCost;
  final double totalAmount;

  const _WalkInTemporaryBillScreen({
    required this.branchId,
    required this.customerName,
    required this.customerPhone,
    required this.vehicleName,
    required this.vehiclePlate,
    required this.engineCapacity,
    required this.currentKm,
    required this.staffCode,
    required this.staffName,
    required this.cart,
    required this.laborCost,
    required this.totalAmount,
  });

  @override
  State<_WalkInTemporaryBillScreen> createState() =>
      _WalkInTemporaryBillScreenState();
}

class _WalkInTemporaryBillScreenState
    extends State<_WalkInTemporaryBillScreen> {
  bool _isSubmitting = false;

  Future<void> _sendToProcessing() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      final invoice = _invoiceData();
      final response = await ApiClient.post('/walk-in-repairs', {
        'branchId': widget.branchId,
        'customerName': widget.customerName,
        'customerPhone': widget.customerPhone,
        'vehicleName': widget.vehicleName,
        'vehiclePlate': widget.vehiclePlate,
        'engineCapacity': widget.engineCapacity,
        'currentKm': widget.currentKm,
        'staffCode': widget.staffCode,
        'staffName': widget.staffName,
        'invoiceDetails': jsonEncode(invoice),
        'totalCost': widget.totalAmount,
      });
      ApiClient.parseResponse(response);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger),
      );
      return;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Bill Created', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_rounded,
              color: AppColors.primary,
              size: 60,
            ),
            const SizedBox(height: 14),
            const Text(
              'The temporary bill has been created.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'The walk-in bill is now in Manage Appointments > Processing.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.inkMuted, fontSize: 13),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context, true);
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
              ),
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );

    if (mounted) setState(() => _isSubmitting = false);
  }

  Map<String, dynamic> _invoiceData() {
    final items = widget.cart.values.map((item) {
      final part = item['part'] as Map<String, dynamic>;
      return {
        'sparePartId': (part['id'] as int) < 0 ? null : part['id'],
        'name': part['name'],
        'quantity': item['quantity'],
        'price': part['price'],
      };
    }).toList();

    return {
      'sourceType': 'WALK_IN',
      'customerName': widget.customerName,
      'customerPhone': widget.customerPhone,
      'vehicleName': widget.vehicleName,
      'vehiclePlate': widget.vehiclePlate,
      'engineCapacity': widget.engineCapacity,
      'currentKm': widget.currentKm,
      'staffCode': widget.staffCode,
      'staffName': widget.staffName,
      'date': DateFormat('HH:mm - dd/MM/yyyy').format(DateTime.now()),
      'laborCost': widget.laborCost,
      'items': items,
      'totalAmount': widget.totalAmount,
    };
  }

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: 'VND',
      decimalDigits: 0,
    );
    final dateStr = DateFormat('HH:mm - dd/MM/yyyy').format(DateTime.now());

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('Temporary Bill'),
        centerTitle: true,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.ink,
        surfaceTintColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: AppStyles.card(radius: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _CareBikeBillLogo(size: 28),
              Text(
                'Maintenance Service',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.inkMuted, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                'Date: $dateStr',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.inkMuted, fontSize: 12),
              ),
              const Divider(height: 28),
              _infoSection('CUSTOMER INFORMATION', [
                _infoRow('Name', widget.customerName),
                _infoRow('Phone', widget.customerPhone),
                _infoRow('Vehicle', widget.vehicleName),
                _infoRow('Plate', widget.vehiclePlate),
                _infoRow('Engine', widget.engineCapacity),
                _infoRow('Current KM', '${widget.currentKm} km'),
              ]),
              const SizedBox(height: 14),
              _infoSection('STAFF INFORMATION', [
                _infoRow('Staff Code', widget.staffCode),
                _infoRow('Name', widget.staffName),
              ]),
              const SizedBox(height: 14),
              Text(
                'SERVICES USED',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w800,
                  color: AppColors.inkMuted,
                  fontSize: 13,
                ),
              ),
              const Divider(),
              _billRow(
                'Maintenance labor fee',
                formatter.format(widget.laborCost),
              ),
              ...widget.cart.values.map((item) {
                final part = item['part'] as Map<String, dynamic>;
                final qty = item['quantity'] as int;
                final price = (part['price'] as num).toDouble();
                return _billRow(
                  '${part['name']} x$qty',
                  formatter.format(price * qty),
                );
              }),
              const Divider(thickness: 1.5, height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'TOTAL',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
                  ),
                  Text(
                    formatter.format(widget.totalAmount),
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                      color: AppColors.danger,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: _isSubmitting ? null : _sendToProcessing,
                icon: const Icon(Icons.receipt_long_rounded),
                label: Text(
                  _isSubmitting ? 'Creating...' : 'SEND TO PROCESSING',
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoSection(String title, List<Widget> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w800,
            color: AppColors.inkMuted,
            fontSize: 13,
          ),
        ),
        const Divider(),
        ...rows,
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: TextStyle(color: AppColors.inkMuted)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _billRow(String label, String amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(color: AppColors.ink)),
          ),
          Text(
            amount,
            style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink),
          ),
        ],
      ),
    );
  }
}

class _CareBikeBillLogo extends StatelessWidget {
  final double size;
  const _CareBikeBillLogo({required this.size});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: 'CARE',
              style: GoogleFonts.montserrat(
                fontSize: size,
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
                color: AppColors.primary,
              ),
            ),
            TextSpan(
              text: 'BIKE',
              style: GoogleFonts.montserrat(
                fontSize: size,
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
                color: AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
