import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/theme/theme.dart';

class BranchCustomerIntakeScreen extends StatefulWidget {
  final int branchId;
  final int customerId;
  final String customerName;

  const BranchCustomerIntakeScreen({
    super.key,
    required this.branchId,
    required this.customerId,
    required this.customerName,
  });

  @override
  State<BranchCustomerIntakeScreen> createState() =>
      _BranchCustomerIntakeScreenState();
}

class _BranchCustomerIntakeScreenState
    extends State<BranchCustomerIntakeScreen> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _appointments = [];

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final pending = await _loadByStatus('PENDING');
      final confirmed = await _loadByStatus('CONFIRMED');
      final combined =
          [...pending, ...confirmed].where(_belongsToScannedCustomer).toList()
            ..sort((a, b) => (b['id'] as int).compareTo(a['id'] as int));

      if (!mounted) return;
      setState(() {
        _appointments = combined;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _loadByStatus(String status) async {
    final response = await ApiClient.get(
      '/appointments/branch/${widget.branchId}?status=$status',
    );
    final data = ApiClient.parseResponse(response) as List;
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  bool _belongsToScannedCustomer(Map<String, dynamic> appointment) {
    final customer = appointment['customer'];
    if (customer is Map && customer['id'] == widget.customerId) return true;
    if (appointment['customerId'] == widget.customerId) return true;

    final name = (appointment['customerName'] ?? '').toString().trim();
    return name.isNotEmpty && name == widget.customerName;
  }

  Future<void> _openRepairFlow({Map<String, dynamic>? appointment}) async {
    final completed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => BranchMaintenanceBillScreen(
          branchId: widget.branchId,
          customerId: widget.customerId,
          customerName: widget.customerName,
          appointment: appointment,
        ),
      ),
    );
    if (completed == true && mounted) {
      await _loadAppointments();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('Customer Intake'),
        centerTitle: true,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.ink,
        surfaceTintColor: Colors.transparent,
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _loadAppointments,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            _customerHeader(),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () => _openRepairFlow(),
              icon: const Icon(Icons.add_circle_outline_rounded),
              label: const Text('CREATE NEW REPAIR ORDER'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Existing bookings',
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 10),
            if (_isLoading)
              Padding(
                padding: const EdgeInsets.only(top: 48),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            else if (_error != null)
              _emptyState(Icons.cloud_off_rounded, _error!)
            else if (_appointments.isEmpty)
              _emptyState(
                Icons.event_busy_rounded,
                'No active booking for this customer.',
              )
            else
              ..._appointments.map(_appointmentCard),
          ],
        ),
      ),
    );
  }

  Widget _customerHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppStyles.card(radius: 18),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: AppStyles.brandGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.person_rounded, color: Colors.white),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.customerName,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Customer ID: CB-${widget.customerId}',
                  style: TextStyle(color: AppColors.inkMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _appointmentCard(Map<String, dynamic> appointment) {
    final date = DateTime.tryParse(
      appointment['appointmentDate']?.toString() ?? '',
    )?.toLocal();
    final dateText = date == null
        ? 'No appointment date'
        : DateFormat('HH:mm - dd/MM/yyyy').format(date);
    final status = appointment['status']?.toString() ?? 'PENDING';
    final isPending = status == 'PENDING';
    final color = isPending ? AppColors.primary : AppColors.info;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppStyles.card(radius: 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openRepairFlow(appointment: appointment),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Appointment #${appointment['id']}',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: AppColors.inkMuted),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 16,
                    color: AppColors.faint,
                  ),
                  const SizedBox(width: 6),
                  Text(dateText, style: TextStyle(color: AppColors.inkMuted)),
                ],
              ),
              if ((appointment['note'] ?? '').toString().trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.fieldFill,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.edge),
                  ),
                  child: Text(
                    appointment['note'].toString(),
                    style: TextStyle(color: AppColors.ink),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 34),
      decoration: AppStyles.card(radius: 16),
      child: Column(
        children: [
          Icon(icon, color: AppColors.faint, size: 44),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.inkMuted),
          ),
        ],
      ),
    );
  }
}

class BranchMaintenanceBillScreen extends StatefulWidget {
  final int branchId;
  final int customerId;
  final String customerName;
  final Map<String, dynamic>? appointment;

  const BranchMaintenanceBillScreen({
    super.key,
    required this.branchId,
    required this.customerId,
    required this.customerName,
    this.appointment,
  });

  @override
  State<BranchMaintenanceBillScreen> createState() =>
      _BranchMaintenanceBillScreenState();
}

class _BranchMaintenanceBillScreenState
    extends State<BranchMaintenanceBillScreen> {
  final _staffCodeCtrl = TextEditingController();
  final _currentKmCtrl = TextEditingController();
  final _customerPhoneCtrl = TextEditingController();
  final _vehicleNameCtrl = TextEditingController();
  final _vehiclePlateCtrl = TextEditingController();
  final _engineCapacityCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  final Map<int, Map<String, dynamic>> _cart = {};

  int _selectedCategoryIndex = 0;
  List<String> _categories = ['All'];
  bool _staffVerified = false;
  bool _kmVerified = false;
  bool _isLoadingParts = true;
  String _searchQuery = '';
  Map<String, dynamic>? _staffInfo;
  List<dynamic> _spareParts = [];

  List<Map<String, dynamic>> _customerVehicles = [];
  Map<String, dynamic>? _selectedVehicle;
  bool _isOtherVehicle = false;
  bool _isLoadingVehicles = false;

  final double _laborCost = 100000;

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
    _prefillCustomerVehicleInfo();
    _loadCategories();
    _loadSpareParts();
    if (widget.appointment == null) {
      _loadCustomerVehicles();
      _loadCustomerPhone();
    }
  }

  Future<void> _loadCategories() async {
    try {
      final response = await ApiClient.get('/categories');
      final data = ApiClient.parseResponse(response) as List;
      final cats = data.map((e) => e['name'].toString()).toList();
      if (!mounted) return;
      setState(() {
        _categories = ['All', ...cats];
      });
    } catch (_) {}
  }

  Future<void> _loadCustomerPhone() async {
    try {
      final response = await ApiClient.get('/users/${widget.customerId}');
      final data = ApiClient.parseResponse(response);
      if (mounted &&
          data is Map &&
          data['phone'] != null &&
          _customerPhoneCtrl.text.isEmpty) {
        setState(() {
          _customerPhoneCtrl.text = data['phone'].toString();
        });
      }
    } catch (e) {
      debugPrint("Could not fetch user phone: $e");
    }
  }

  Future<void> _loadCustomerVehicles() async {
    setState(() => _isLoadingVehicles = true);
    try {
      final response = await ApiClient.get(
        '/vehicles/owner/${widget.customerId}',
      );
      final data = ApiClient.parseResponse(response) as List;
      if (!mounted) return;
      setState(() {
        _customerVehicles = List<Map<String, dynamic>>.from(data);
        _isLoadingVehicles = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingVehicles = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not load vehicles: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  void dispose() {
    _staffCodeCtrl.dispose();
    _currentKmCtrl.dispose();
    _customerPhoneCtrl.dispose();
    _vehicleNameCtrl.dispose();
    _vehiclePlateCtrl.dispose();
    _engineCapacityCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _prefillCustomerVehicleInfo() {
    final appointment = widget.appointment;
    _customerPhoneCtrl.text = appointment?['customerPhone']?.toString() ?? '';

    if (appointment != null) {
      final vName = appointment['vehicleName']?.toString() ?? '';
      final vBrand = appointment['vehicleBrand']?.toString() ?? '';
      final engineCap = appointment['engineCapacity']?.toString() ?? '';

      _vehicleNameCtrl.text = '$vBrand $vName'.trim();
      _vehiclePlateCtrl.text = appointment['vehiclePlate']?.toString() ?? '';
      _engineCapacityCtrl.text = engineCap;
    } else {
      // Walk-in default to manual entry until they select a vehicle
      _isOtherVehicle = true;
    }
  }

  void _onVehicleSelected(Map<String, dynamic>? vehicle) {
    setState(() {
      _selectedVehicle = vehicle;
      if (vehicle != null) {
        _isOtherVehicle = false;
        final vName = vehicle['vehicleName']?.toString() ?? '';
        final vBrand = vehicle['brand']?.toString() ?? '';
        _vehicleNameCtrl.text = '$vBrand $vName'.trim();
        _vehiclePlateCtrl.text = vehicle['licensePlate']?.toString() ?? '';
        _engineCapacityCtrl.text = vehicle['engineCapacity']?.toString() ?? '';
      } else {
        _isOtherVehicle = true;
        _vehicleNameCtrl.clear();
        _vehiclePlateCtrl.clear();
        _engineCapacityCtrl.clear();
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
        try {
          final errorData = jsonDecode(utf8.decode(response.bodyBytes));
          if (errorData['message'] != null) {
            throw Exception(errorData['message']);
          }
        } catch (_) {}
        throw Exception('Staff with this code was not found or not on shift.');
      }
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      
      // Immediately set staff status to BUSY
      final staffId = data['id'];
      if (staffId != null) {
        try {
          await ApiClient.put('/staff/$staffId/status', {'status': 'BUSY'});
        } catch (e) {
          debugPrint('Could not update staff status: $e');
        }
      }
      
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
          content: Text('${e.toString().replaceAll('Exception: ', '')}'),
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

  void _openTemporaryBill() {
    if (_customerPhoneCtrl.text.trim().isEmpty ||
        _vehicleNameCtrl.text.trim().isEmpty ||
        _vehiclePlateCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter phone, vehicle, and plate.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    if (_currentKmCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter the current odometer reading.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _MaintenanceTemporaryBillScreen(
          branchId: widget.branchId,
          customerId: widget.customerId,
          customerName: widget.customerName,
          appointment: widget.appointment,
          selectedVehicleId: _selectedVehicle?['id'],
          currentKm: int.tryParse(_currentKmCtrl.text.trim()) ?? 0,
          customerPhone: _customerPhoneCtrl.text.trim(),
          vehicleName: _vehicleNameCtrl.text.trim(),
          vehiclePlate: _vehiclePlateCtrl.text.trim(),
          staffCode:
              _staffInfo?['staffCode'] ??
              _staffCodeCtrl.text.trim().toUpperCase(),
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
        title: Text(
          widget.appointment == null ? 'New Repair Order' : 'Process Booking',
        ),
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
            _sectionTitle('STEP 2: Repair details', Icons.speed_rounded),
            const SizedBox(height: 10),
            if (widget.appointment == null) ...[
              if (_isLoadingVehicles)
                const Center(child: CircularProgressIndicator())
              else
                DropdownButtonFormField<Map<String, dynamic>?>(
                  value: _selectedVehicle,
                  decoration: const InputDecoration(
                    labelText: 'Select Vehicle',
                    prefixIcon: Icon(Icons.two_wheeler_rounded),
                  ),
                  items: [
                    ..._customerVehicles.map(
                      (v) => DropdownMenuItem(
                        value: v,
                        child: Text(
                          '${v['brand']} ${v['vehicleName']} - ${v['licensePlate']}',
                        ),
                      ),
                    ),
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Other (Manual entry)'),
                    ),
                  ],
                  onChanged: _onVehicleSelected,
                ),
              const SizedBox(height: 10),
            ],
            TextField(
              controller: _customerPhoneCtrl,
              keyboardType: TextInputType.phone,
              enabled: widget.appointment == null,
              decoration: const InputDecoration(
                hintText: 'Customer phone',
                prefixIcon: Icon(Icons.phone_rounded),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _vehicleNameCtrl,
              textCapitalization: TextCapitalization.words,
              enabled: widget.appointment == null && _isOtherVehicle,
              decoration: const InputDecoration(
                hintText: 'Vehicle name (e.g. Honda Vision)',
                prefixIcon: Icon(Icons.two_wheeler_rounded),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _vehiclePlateCtrl,
              textCapitalization: TextCapitalization.characters,
              enabled: widget.appointment == null && _isOtherVehicle,
              decoration: const InputDecoration(
                hintText: 'License plate',
                prefixIcon: Icon(Icons.pin_rounded),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _engineCapacityCtrl,
              enabled: widget.appointment == null && _isOtherVehicle,
              decoration: const InputDecoration(
                hintText: 'Engine capacity (cc)',
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
                      hintText: 'Current km (required)',
                      prefixIcon: Icon(Icons.speed_rounded),
                    ),
                    onChanged: (v) {
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
                          content: const Text('Please enter current KM first.'),
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
                        setState(() {
                          _selectedCategoryIndex = i;
                        });
                        _loadSpareParts();
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
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
                        alignment: Alignment.center,
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
                              leading: part['isService'] == true
                                  ? Icon(
                                      Icons.handyman_rounded,
                                      color: AppColors.primary,
                                      size: 32,
                                    )
                                  : (part['imageUrl'] != null
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            child: Image.network(
                                              part['imageUrl'].toString(),
                                              width: 36,
                                              height: 36,
                                              fit: BoxFit.cover,
                                            ),
                                          )
                                        : Icon(
                                            Icons.settings_rounded,
                                            color: AppColors.primary,
                                            size: 32,
                                          )),
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
    final note = widget.appointment?['note']?.toString();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppStyles.card(radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.customerName,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.appointment == null
                ? 'Walk-in repair order'
                : 'Appointment #${widget.appointment?['id']}',
            style: TextStyle(color: AppColors.inkMuted),
          ),
          if (note != null && note.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(note, style: TextStyle(color: AppColors.ink)),
          ],
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

class _MaintenanceTemporaryBillScreen extends StatefulWidget {
  final int branchId;
  final int customerId;
  final String customerName;
  final Map<String, dynamic>? appointment;
  final int? selectedVehicleId;
  final int currentKm;
  final String customerPhone;
  final String vehicleName;
  final String vehiclePlate;
  final String staffCode;
  final String staffName;
  final Map<int, Map<String, dynamic>> cart;
  final double laborCost;
  final double totalAmount;

  const _MaintenanceTemporaryBillScreen({
    required this.branchId,
    required this.customerId,
    required this.customerName,
    required this.appointment,
    this.selectedVehicleId,
    required this.currentKm,
    required this.customerPhone,
    required this.vehicleName,
    required this.vehiclePlate,
    required this.staffCode,
    required this.staffName,
    required this.cart,
    required this.laborCost,
    required this.totalAmount,
  });

  @override
  State<_MaintenanceTemporaryBillScreen> createState() =>
      _MaintenanceTemporaryBillScreenState();
}

class _MaintenanceTemporaryBillScreenState
    extends State<_MaintenanceTemporaryBillScreen> {
  bool _isSubmitting = false;

  Future<void> _completeMaintenance() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      final appointmentId = _appointmentId();
      final invoice = _invoiceData(appointmentId: appointmentId);
      final response = await _runStep(
        'send temporary bill',
        () => ApiClient.post('/appointments/invoice', {
          'appointmentId': appointmentId,
          'customerId': widget.customerId,
          'branchId': widget.branchId,
          'vehicleId':
              widget.selectedVehicleId ?? widget.appointment?['vehicleId'],
          'currentKm': widget.currentKm,
          'invoiceDetails': jsonEncode(invoice),
          'totalCost': widget.totalAmount,
        }),
      );
      ApiClient.parseResponse(response);

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Bill Sent', textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.send_rounded, color: AppColors.primary, size: 60),
              const SizedBox(height: 14),
              const Text(
                'The temporary bill has been sent to the customer.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Please ask the customer to open their app to review and pay.',
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
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<T> _runStep<T>(String label, Future<T> Function() action) async {
    try {
      return await action();
    } catch (e) {
      throw Exception('Could not $label: $e');
    }
  }

  int? _appointmentId() {
    final id = widget.appointment?['id'];
    return id is int ? id : int.tryParse(id?.toString() ?? '');
  }

  Map<String, dynamic> _invoiceData({int? appointmentId}) {
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
      'sourceType': 'APPOINTMENT',
      'appointmentId': appointmentId ?? _appointmentId(),
      'customerName': widget.customerName,
      'customerPhone': widget.customerPhone,
      'vehicleName': widget.vehicleName,
      'vehiclePlate': widget.vehiclePlate,
      'staffCode': widget.staffCode,
      'staffName': widget.staffName,
      'date': DateFormat('HH:mm - dd/MM/yyyy').format(DateTime.now()),
      'laborCost': widget.laborCost,
      'transportFee': 0,
      'distanceKm': 0,
      'timeMultiplier': 1,
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
    final invoice = _invoiceData();
    final items = invoice['items'] as List;

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
                'Date: ${invoice['date']}',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.inkMuted, fontSize: 12),
              ),
              Divider(height: 28, color: AppColors.edge),
              _infoSection('CUSTOMER INFORMATION', [
                _infoRow('Name', widget.customerName),
                _infoRow('Phone', invoice['customerPhone'].toString()),
                _infoRow('Vehicle', invoice['vehicleName'].toString()),
                _infoRow('Plate', invoice['vehiclePlate'].toString()),
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
              Divider(color: AppColors.edge),
              _billRow(
                'Maintenance labor fee',
                formatter.format(widget.laborCost),
              ),
              ...items.map((itemDynamic) {
                final item = itemDynamic as Map<String, dynamic>;
                final qty = item['quantity'] as int;
                final price = (item['price'] as num).toDouble();
                return _billRow(
                  '${item['name']} x$qty',
                  formatter.format(price * qty),
                );
              }),
              Divider(thickness: 1.5, height: 28, color: AppColors.ink),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'TOTAL',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      color: AppColors.ink,
                    ),
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
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: _isSubmitting ? null : _completeMaintenance,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(
                    _isSubmitting ? 'SENDING...' : 'SEND BILL TO CUSTOMER',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoSection(String title, List<Widget> children) {
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
        Divider(color: AppColors.edge),
        ...children,
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: TextStyle(color: AppColors.inkMuted, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? 'N/A' : value,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label, style: TextStyle(color: AppColors.ink)),
          ),
          Text(
            amount,
            style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink),
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
    TextStyle style(Color color) => GoogleFonts.montserrat(
      fontSize: size,
      fontWeight: FontWeight.w800,
      fontStyle: FontStyle.italic,
      color: color,
      letterSpacing: -0.8,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('CARE', style: style(AppColors.primary)),
        Text('BIKE', style: style(AppColors.ink)),
      ],
    );
  }
}
