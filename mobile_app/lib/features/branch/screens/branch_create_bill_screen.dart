import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/theme/theme.dart';
import 'package:mobile_app/features/branch/screens/temporary_invoice_screen.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BranchCreateBillScreen extends StatefulWidget {
  final int rescueId;
  final String customerName;
  final Map<String, dynamic> rescueData;

  const BranchCreateBillScreen({
    super.key,
    required this.rescueId,
    required this.customerName,
    required this.rescueData,
  });

  @override
  State<BranchCreateBillScreen> createState() => _BranchCreateBillScreenState();
}

class _BranchCreateBillScreenState extends State<BranchCreateBillScreen> {
  final _staffCodeCtrl = TextEditingController();
  final Map<int, Map<String, dynamic>> _cart = {};

  bool _qrVerified = false;
  bool _staffVerified = false;
  bool _isLoadingParts = true;
  bool _needStaffTravel = true;
  bool _needVehicleTransport = false;
  String _searchQuery = '';
  int _selectedCategoryIndex = 0;
  List<String> _categories = ['All'];
  Map<String, dynamic>? _staffInfo;
  Map<String, dynamic>? _assignedStaffInfo;
  bool _isLoadingAssignedStaff = true;
  String? _assignedStaffError;
  List<dynamic> _spareParts = [];

  final double _laborCost = 100000;
  final double _staffTravelPricePerKm = 5000;
  final double _transportPricePerKm = 15000;

  final List<Map<String, dynamic>> _commonServices = [
    {
      'id': -1,
      'name': 'Tire patch',
      'price': 50000.0,
      'imageUrl': null,
      'isService': true,
    },
    {
      'id': -2,
      'name': 'Tubeless tire patch',
      'price': 30000.0,
      'imageUrl': null,
      'isService': true,
    },
    {
      'id': -3,
      'name': 'Tire pump',
      'price': 10000.0,
      'imageUrl': null,
      'isService': true,
    },
    {
      'id': -4,
      'name': 'Battery charge',
      'price': 50000.0,
      'imageUrl': null,
      'isService': true,
    },
    {
      'id': -5,
      'name': 'Jump start battery',
      'price': 80000.0,
      'imageUrl': null,
      'isService': true,
    },
    {
      'id': -6,
      'name': 'Oil change',
      'price': 80000.0,
      'imageUrl': null,
      'isService': true,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadSpareParts();
    _loadAssignedStaff();
  }

  Future<void> _loadAssignedStaff() async {
    if (mounted) {
      setState(() {
        _isLoadingAssignedStaff = true;
        _assignedStaffError = null;
      });
    }

    try {
      final response = await ApiClient.get(
        '/rescues/${widget.rescueId}/assigned-staff',
      );
      final parsed = ApiClient.parseResponse(response);
      final data = Map<String, dynamic>.from(parsed as Map);
      final code = data['staffCode']?.toString().trim().toUpperCase() ?? '';
      if (code.isEmpty) {
        throw StateError(
          'No staff member has been assigned to this rescue request.',
        );
      }
      if (!mounted) return;
      setState(() {
        _assignedStaffInfo = data;
        _isLoadingAssignedStaff = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _assignedStaffInfo = null;
        _assignedStaffError = e.toString().replaceAll('Exception: ', '');
        _isLoadingAssignedStaff = false;
      });
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

  @override
  void dispose() {
    _staffCodeCtrl.dispose();
    super.dispose();
  }

  double get _timeMultiplier {
    try {
      final createdAt = DateTime.parse(
        widget.rescueData['createdAt'].toString(),
      ).toLocal();
      final hour = createdAt.hour;
      if (hour >= 22 || hour < 6) return 2.0;
    } catch (_) {}
    return 1.0;
  }

  double get _distanceKm {
    try {
      final customerLat = (widget.rescueData['latitude'] as num).toDouble();
      final customerLng = (widget.rescueData['longitude'] as num).toDouble();
      final branch = widget.rescueData['branch'] as Map<String, dynamic>?;
      final branchLat = double.parse(branch?['latitude'].toString() ?? '0');
      final branchLng = double.parse(branch?['longitude'].toString() ?? '0');
      if (branchLat == 0 || branchLng == 0) return 5.0;
      return _haversine(customerLat, customerLng, branchLat, branchLng);
    } catch (_) {
      return 5.0;
    }
  }

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const radiusKm = 6371.0;
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    return radiusKm * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  double _toRad(double deg) => deg * pi / 180;

  double _calculateTotal() {
    double sum = _laborCost * _timeMultiplier;
    for (final item in _cart.values) {
      final price = (item['part']['price'] as num).toDouble();
      final qty = item['quantity'] as int;
      sum += price * qty * _timeMultiplier;
    }
    if (_needStaffTravel) sum += _distanceKm * 2 * _staffTravelPricePerKm;
    if (_needVehicleTransport) sum += _distanceKm * 2 * _transportPricePerKm;
    return sum;
  }

  Future<void> _loadSpareParts() async {
    setState(() => _isLoadingParts = true);
    try {
      final response = await ApiClient.get('/spare-parts?search=$_searchQuery');
      final data = ApiClient.parseResponse(response) as List;
      final filteredServices = _searchQuery.isEmpty
          ? _commonServices
          : _commonServices
                .where(
                  (s) => s['name'].toString().toLowerCase().contains(
                    _searchQuery.toLowerCase(),
                  ),
                )
                .toList();
      final category = _categories[_selectedCategoryIndex];
      List<dynamic> filteredData = data;
      if (category != 'All') {
        filteredData = data
            .where(
              (part) => (part['category'] ?? part['categoryName']) == category,
            )
            .toList();
      }

      if (!mounted) return;
      setState(() {
        _spareParts = [...filteredServices, ...filteredData];
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

  void _openQRScanner() {
    final scannerController = MobileScannerController();
    bool hasScanned = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.72,
        child: Column(
          children: [
            AppBar(
              title: const Text('Scan Customer QR'),
              leading: const CloseButton(),
              backgroundColor: AppColors.surface,
              foregroundColor: AppColors.ink,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
            ),
            Expanded(
              child: MobileScanner(
                controller: scannerController,
                onDetect: (capture) {
                  if (hasScanned) return;
                  final rawValue = capture.barcodes.isNotEmpty
                      ? capture.barcodes.first.rawValue
                      : null;
                  if (rawValue == null) return;
                  hasScanned = true;
                  scannerController.stop();
                  try {
                    final qrData = jsonDecode(rawValue);
                    final expectedId = widget.rescueData['customer']?['id'];
                    if (qrData['customerId'] == expectedId) {
                      setState(() => _qrVerified = true);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Customer verified successfully.'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } else {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'QR code does not match this rescue customer.',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  } catch (_) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Invalid QR code.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    ).whenComplete(scannerController.dispose);
  }

  Future<void> _verifyStaffCode() async {
    final code = _staffCodeCtrl.text.trim().toUpperCase();
    if (!RegExp(r'^CBS-\d{4}$').hasMatch(code)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Staff code must follow CBS-xxxx, e.g. CBS-0001.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_isLoadingAssignedStaff) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please wait while the assigned staff member is loaded.',
          ),
        ),
      );
      return;
    }

    final assignedCode =
        _assignedStaffInfo?['staffCode']?.toString().trim().toUpperCase() ?? '';
    if (assignedCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _assignedStaffError ??
                'The assigned staff member could not be loaded. Please try again.',
          ),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    if (code != assignedCode) {
      setState(() {
        _staffVerified = false;
        _staffInfo = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'This staff code does not match the staff member assigned to this rescue request.',
          ),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    try {
      final encodedCode = Uri.encodeQueryComponent(code);
      final response = await ApiClient.get(
        '/rescues/${widget.rescueId}/verify-staff?code=$encodedCode',
      );
      final parsed = ApiClient.parseResponse(response);
      final data = Map<String, dynamic>.from(parsed as Map);
      if (!mounted) return;
      setState(() {
        _staffVerified = true;
        _staffInfo = data;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Verified staff: ${data['fullName']}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _staffVerified = false;
        _staffInfo = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  void _createTemporaryInvoice() {
    final customer = widget.rescueData['customer'] as Map<String, dynamic>?;
    final vehicle = widget.rescueData['vehicle'] as Map<String, dynamic>?;
    final vehicleName =
        '${vehicle?['brand'] ?? ''} ${vehicle?['vehicleName'] ?? vehicle?['model'] ?? ''}'
            .trim();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TemporaryInvoiceScreen(
          rescueId: widget.rescueId,
          customerName: customer?['fullName'] ?? 'Customer',
          customerPhone: customer?['phone'] ?? '',
          vehicleName: vehicleName,
          vehiclePlate: vehicle?['licensePlate'] ?? '',
          staffCode:
              _staffInfo?['staffCode'] ??
              _staffCodeCtrl.text.trim().toUpperCase(),
          staffName: _staffInfo?['fullName'] ?? '',
          cart: Map.from(_cart),
          laborCost: _laborCost,
          timeMultiplier: _timeMultiplier,
          needStaffTravel: _needStaffTravel,
          staffTravelPricePerKm: _staffTravelPricePerKm,
          needVehicleTransport: _needVehicleTransport,
          distanceKm: _distanceKm,
          transportPricePerKm: _transportPricePerKm,
          totalAmount: _calculateTotal(),
        ),
      ),
    ).then((result) {
      if (result == true && mounted) Navigator.pop(context, true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: 'VND',
      decimalDigits: 0,
    );
    final customer = widget.rescueData['customer'] as Map<String, dynamic>?;
    final vehicle = widget.rescueData['vehicle'] as Map<String, dynamic>?;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: Text('Create bill - ${widget.customerName}'),
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
        backgroundColor: AppColors.danger,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(
              'STEP 1: Verify customer',
              Icons.qr_code_scanner_rounded,
            ),
            const SizedBox(height: 10),
            _qrVerified
                ? _verifiedTile(
                    icon: Icons.check_circle_rounded,
                    title: 'Customer verified',
                    subtitle:
                        '${customer?['fullName'] ?? ''}\n${vehicle?['brand'] ?? ''} ${vehicle?['vehicleName'] ?? vehicle?['model'] ?? ''} - ${vehicle?['licensePlate'] ?? ''}',
                  )
                : _fullButton(
                    icon: Icons.qr_code_scanner_rounded,
                    label: 'OPEN CAMERA TO SCAN QR',
                    color: AppColors.info,
                    onPressed: _openQRScanner,
                  ),
            const SizedBox(height: 24),
            _sectionTitle('STEP 2: Verify staff', Icons.badge_rounded),
            const SizedBox(height: 10),
            if (_isLoadingAssignedStaff)
              const LinearProgressIndicator()
            else if (_assignedStaffError != null)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _assignedStaffError!,
                      style: TextStyle(color: AppColors.danger),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _loadAssignedStaff,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                  ),
                ],
              )
            else
              _notice('Assigned staff: ${_assignedStaffInfo?['fullName']}'),
            const SizedBox(height: 10),
            _staffVerified
                ? _verifiedTile(
                    icon: Icons.verified_user_rounded,
                    title: 'Staff verified',
                    subtitle:
                        '${_staffInfo?['fullName']} (${_staffInfo?['staffCode']})',
                  )
                : Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _staffCodeCtrl,
                          enabled:
                              _qrVerified &&
                              !_isLoadingAssignedStaff &&
                              _assignedStaffInfo != null,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            hintText: 'CBS-0001',
                            prefixIcon: Icon(Icons.badge_rounded),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed:
                            _qrVerified &&
                                !_isLoadingAssignedStaff &&
                                _assignedStaffInfo != null
                            ? _verifyStaffCode
                            : null,
                        child: const Text('Confirm'),
                      ),
                    ],
                  ),
            if (_qrVerified && _staffVerified) ...[
              const SizedBox(height: 24),
              _sectionTitle(
                'STEP 3: Select services / spare parts',
                Icons.build_rounded,
              ),
              if (_timeMultiplier > 1) ...[
                const SizedBox(height: 10),
                _notice('Night shift rate is active: service prices x2.'),
              ],
              const SizedBox(height: 10),
              TextField(
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
                height: 220,
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
                          final price =
                              (part['price'] as num).toDouble() *
                              _timeMultiplier;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading:
                                  part['imageUrl'] != null &&
                                      part['imageUrl'].toString().isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        part['imageUrl'],
                                        width: 50,
                                        height: 50,
                                        fit: BoxFit.cover,
                                        errorBuilder: (ctx, _, __) => Icon(
                                          part['isService'] == true
                                              ? Icons.handyman_rounded
                                              : Icons.settings_rounded,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    )
                                  : Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryLight,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        part['isService'] == true
                                            ? Icons.handyman_rounded
                                            : Icons.settings_rounded,
                                        color: AppColors.primary,
                                      ),
                                    ),
                              title: Text(
                                part['name'],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
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
              const SizedBox(height: 10),
              CheckboxListTile(
                value: _needStaffTravel,
                onChanged: (value) =>
                    setState(() => _needStaffTravel = value ?? false),
                title: const Text(
                  'Staff travel fee',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${_distanceKm.toStringAsFixed(1)} km x round trip x ${formatter.format(_staffTravelPricePerKm)}/km',
                ),
              ),
              CheckboxListTile(
                value: _needVehicleTransport,
                onChanged: (value) =>
                    setState(() => _needVehicleTransport = value ?? false),
                title: const Text(
                  'Vehicle towing fee',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${_distanceKm.toStringAsFixed(1)} km x round trip x ${formatter.format(_transportPricePerKm)}/km',
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

  Widget _billSummary(NumberFormat formatter) {
    final total = _calculateTotal();
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
          const Divider(),
          _priceRow(
            'Rescue labor fee ${_timeMultiplier > 1 ? "(x2)" : "(x1)"}',
            _laborCost * _timeMultiplier,
            formatter,
          ),
          ..._cart.values.map((item) {
            final part = item['part'];
            final qty = item['quantity'] as int;
            final price = (part['price'] as num).toDouble() * _timeMultiplier;
            return _cartRow(
              part['id'] as int,
              '${part['name']} x$qty',
              price * qty,
              formatter,
            );
          }),
          if (_needStaffTravel)
            _priceRow(
              'Staff travel (${_distanceKm.toStringAsFixed(1)}km)',
              _distanceKm * 2 * _staffTravelPricePerKm,
              formatter,
            ),
          if (_needVehicleTransport)
            _priceRow(
              'Vehicle towing (${_distanceKm.toStringAsFixed(1)}km)',
              _distanceKm * 2 * _transportPricePerKm,
              formatter,
            ),
          const Divider(thickness: 1.5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TOTAL',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
              Text(
                formatter.format(total),
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  color: AppColors.danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _fullButton(
            icon: Icons.receipt_long_rounded,
            label: 'CREATE TEMPORARY BILL',
            color: AppColors.success,
            onPressed: _createTemporaryInvoice,
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
          Expanded(child: Text(label)),
          Text(
            formatter.format(amount),
            style: const TextStyle(fontWeight: FontWeight.w700),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label)),
          Text(
            formatter.format(amount),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.danger),
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

  Widget _verifiedTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
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
          Icon(icon, color: AppColors.success),
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

  Widget _notice(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.warningBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _fullButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
