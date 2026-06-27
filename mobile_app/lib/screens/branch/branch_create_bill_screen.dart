import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/api_client.dart';
import '../../widgets/loading_button.dart';
import 'temporary_invoice_screen.dart';

class BranchCreateBillScreen extends StatefulWidget {
  final int rescueId;
  final String customerName;
  final Map<String, dynamic> rescueData; // Full rescue data

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
  // ── STEP 1: Scan customer QR ──
  bool _qrVerified = false;
  Map<String, dynamic>? _scannedCustomer;

  // ── STEP 2: Enter staff code ──
  final _staffCodeCtrl = TextEditingController();
  bool _staffVerified = false;
  Map<String, dynamic>? _staffInfo;

  // ── STEP 3: Select service ──
  bool _isLoadingParts = true;
  List<dynamic> _spareParts = [];
  String _searchQuery = '';
  final Map<int, Map<String, dynamic>> _cart = {};

  // Additional services
  final List<Map<String, dynamic>> _commonServices = [
    {'id': -1, 'name': 'Tire patch', 'price': 50000.0, 'imageUrl': null, 'isService': true},
    {'id': -2, 'name': 'Tubeless tire patch', 'price': 30000.0, 'imageUrl': null, 'isService': true},
    {'id': -3, 'name': 'Tire pump', 'price': 10000.0, 'imageUrl': null, 'isService': true},
    {'id': -4, 'name': 'Battery charge', 'price': 50000.0, 'imageUrl': null, 'isService': true},
    {'id': -5, 'name': 'Jump start battery', 'price': 80000.0, 'imageUrl': null, 'isService': true},
    {'id': -6, 'name': 'Oil change', 'price': 80000.0, 'imageUrl': null, 'isService': true},
  ];

  // Vehicle transport
  bool _needVehicleTransport = false;
  final double _transportPricePerKm = 15000; // 15,000 VNĐ / km

  // Staff travel
  bool _needStaffTravel = true;
  final double _staffTravelPricePerKm = 5000; // 5,000 VNĐ / km

  // Rescue labor cost
  final double _laborCost = 100000;

  @override
  void initState() {
    super.initState();
    _loadSpareParts();
  }

  @override
  void dispose() {
    _staffCodeCtrl.dispose();
    super.dispose();
  }

  // ─── Price multiplier based on dispatch hour ─────────────────────────────────────────
  double get _timeMultiplier {
    try {
      final createdAt = DateTime.parse(widget.rescueData['createdAt']).toLocal();
      final hour = createdAt.hour;
      // 10 PM - 6 AM: x2
      if (hour >= 22 || hour < 6) return 2.0;
    } catch (_) {}
    return 1.0;
  }

  // ─── Haversine distance (km) ──────────────────────────────────────────────
  double get _distanceKm {
    try {
      final customerLat = (widget.rescueData['latitude'] as num).toDouble();
      final customerLng = (widget.rescueData['longitude'] as num).toDouble();
      final branch = widget.rescueData['branch'];
      final branchLat = double.parse(branch['latitude'].toString());
      final branchLng = double.parse(branch['longitude'].toString());
      return _haversine(customerLat, customerLng, branchLat, branchLng);
    } catch (_) {
      return 5.0; // Default 5km if error
    }
  }

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0;
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _toRad(double deg) => deg * pi / 180;

  // ─── Load spare parts list ──────────────────────────────────────────────────
  Future<void> _loadSpareParts() async {
    setState(() => _isLoadingParts = true);
    try {
      final response = await ApiClient.get('/spare-parts?search=$_searchQuery');
      final data = ApiClient.parseResponse(response) as List;
      if (mounted) {
        setState(() {
          final List<dynamic> combined = [];
          final filteredServices = _searchQuery.isEmpty
              ? _commonServices
              : _commonServices.where((s) => s['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase())).toList();
          combined.addAll(filteredServices);
          combined.addAll(data);
          _spareParts = combined;
          _isLoadingParts = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingParts = false);
    }
  }

  void _addToCart(dynamic part) {
    setState(() {
      final int id = part['id'];
      if (_cart.containsKey(id)) {
        _cart[id]!['quantity'] = (_cart[id]!['quantity'] as int) + 1;
      } else {
        _cart[id] = {'part': part, 'quantity': 1};
      }
    });
  }

  void _removeFromCart(int id) {
    setState(() {
      if (_cart.containsKey(id)) {
        final currentQty = _cart[id]!['quantity'] as int;
        if (currentQty > 1) {
          _cart[id]!['quantity'] = currentQty - 1;
        } else {
          _cart.remove(id);
        }
      }
    });
  }

  double _calculateTotal() {
    double sum = _laborCost * _timeMultiplier;
    _cart.forEach((key, item) {
      final price = (item['part']['price'] as num).toDouble();
      final qty = item['quantity'] as int;
      sum += (price * qty * _timeMultiplier);
    });
    if (_needStaffTravel) {
      sum += _distanceKm * 2 * _staffTravelPricePerKm; // Round trip
    }
    if (_needVehicleTransport) {
      sum += _distanceKm * 2 * _transportPricePerKm; // Round trip
    }
    return sum;
  }

  // ─── Scan Customer QR ──────────────────────────────────────────────────────
  void _openQRScanner() {
    final scannerController = MobileScannerController();
    bool hasScanned = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.7,
        child: Column(
          children: [
            AppBar(
              title: const Text('Scan Customer QR'),
              leading: const CloseButton(),
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            ),
            Expanded(
              child: MobileScanner(
                controller: scannerController,
                onDetect: (capture) {
                  if (hasScanned) return;
                  final barcodes = capture.barcodes;
                  if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                    hasScanned = true;
                    scannerController.stop();
                    try {
                      final qrData = jsonDecode(barcodes.first.rawValue!);
                      final expectedId = widget.rescueData['customer']?['id'];

                      if (qrData['customerId'] == expectedId) {
                        setState(() {
                          _qrVerified = true;
                          _scannedCustomer = qrData;
                        });
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('✅ Customer verified successfully!'), backgroundColor: Colors.green),
                        );
                      } else {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('❌ QR code does not match the customer who requested rescue!'), backgroundColor: Colors.red),
                        );
                      }
                    } catch (e) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Invalid QR code'), backgroundColor: Colors.red),
                      );
                    }
                  }
                },
              ),
            ),
          ],
        ),
      ),
    ).whenComplete(() => scannerController.dispose());
  }

  // ─── Verify Staff Code ───────────────────────────────────────────────────
  Future<void> _verifyStaffCode() async {
    final code = _staffCodeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter staff code'), backgroundColor: Colors.orange),
      );
      return;
    }
    // Validate format CBS-xxxx
    if (!RegExp(r'^CBS-\d{4}$').hasMatch(code)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Staff code must follow the format CBS-xxxx (E.g: CBS-0001)'), backgroundColor: Colors.red),
      );
      return;
    }

    try {
      final res = await ApiClient.get('/staff/lookup?code=$code');
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        setState(() {
          _staffVerified = true;
          _staffInfo = data;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✅ Verified staff: ${data['fullName']}'), backgroundColor: Colors.green),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('❌ Staff with this code not found!'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ─── Create temporary invoice ────────────────────────────────────────────────────────────
  void _createTemporaryInvoice() {
    final customer = widget.rescueData['customer'];
    final vehicle = widget.rescueData['vehicle'];

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TemporaryInvoiceScreen(
          rescueId: widget.rescueId,
          rescueData: widget.rescueData,
          customerName: customer?['fullName'] ?? 'Customer',
          customerPhone: customer?['phone'] ?? '',
          vehicleName: '${vehicle?['brand'] ?? ''} ${vehicle?['vehicleName'] ?? ''}',
          vehiclePlate: vehicle?['licensePlate'] ?? '',
          staffCode: _staffInfo?['staffCode'] ?? _staffCodeCtrl.text.trim(),
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
      if (result == true && mounted) {
        Navigator.pop(context, true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'VND', decimalDigits: 0);
    final total = _calculateTotal();

    return Scaffold(
      appBar: AppBar(
        title: Text('Repair - ${widget.customerName}'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ═══════ STEP 1: SCAN CUSTOMER QR ═══════
            _buildSectionTitle('STEP 1: Verify Customer', Icons.qr_code_scanner),
            const SizedBox(height: 8),
            if (!_qrVerified)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _openQRScanner,
                  icon: const Icon(Icons.qr_code_scanner, size: 28),
                  label: const Text('OPEN CAMERA TO SCAN QR', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: 8),
                      const Text('Customer Verified', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                    ]),
                    const Divider(),
                    Text('👤 Name: ${widget.rescueData['customer']?['fullName'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text('🚙 Vehicle: ${widget.rescueData['vehicle']?['brand'] ?? ''} ${widget.rescueData['vehicle']?['vehicleName'] ?? ''}'),
                    Text('🏷️ License Plate: ${widget.rescueData['vehicle']?['licensePlate'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                  ],
                ),
              ),
            const SizedBox(height: 24),

            // ═══════ STEP 2: ENTER STAFF CODE ═══════
            _buildSectionTitle('STEP 2: Verify Staff', Icons.badge),
            const SizedBox(height: 8),
            if (!_staffVerified)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _staffCodeCtrl,
                      enabled: _qrVerified,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        hintText: 'Enter staff code (E.g: CBS-0001)',
                        prefixIcon: const Icon(Icons.badge),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: _qrVerified ? Colors.white : Colors.grey.shade200,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _qrVerified ? _verifyStaffCode : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                    ),
                    child: const Text('Confirm'),
                  ),
                ],
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.teal.shade300),
                ),
                child: Row(children: [
                  const Icon(Icons.verified_user, color: Colors.teal),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Staff: ${_staffInfo?['fullName']} (${_staffInfo?['staffCode']})', style: const TextStyle(fontWeight: FontWeight.bold))),
                ]),
              ),
            const SizedBox(height: 24),

            // ═══════ STEP 3: SELECT SERVICE ═══════
            if (_qrVerified && _staffVerified) ...[
              _buildSectionTitle('STEP 3: Select service / spare parts', Icons.build),
              // Price multiplier
              if (_timeMultiplier > 1)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(children: [
                    const Icon(Icons.nightlight_round, color: Colors.orange),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('⚠️ Night shift (10 PM - 6 AM): Service price x2', style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold))),
                  ]),
                ),
              const SizedBox(height: 8),
              // Search bar
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search spare parts / services...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.white,
                ),
                onChanged: (val) {
                  _searchQuery = val;
                  _loadSpareParts();
                },
              ),
              const SizedBox(height: 8),
              // Service list
              SizedBox(
                height: 200,
                child: _isLoadingParts
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        itemCount: _spareParts.length,
                        itemBuilder: (context, index) {
                          final part = _spareParts[index];
                          final price = (part['price'] as num).toDouble() * _timeMultiplier;
                          return Card(
                            child: ListTile(
                              leading: Container(
                                width: 50, height: 50,
                                decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: part['imageUrl'] != null
                                      ? Image.network(
                                          part['imageUrl'],
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.grey, size: 20),
                                        )
                                      : (part['isService'] == true
                                          ? const Icon(Icons.handyman, color: Colors.green, size: 24)
                                          : const Icon(Icons.build, size: 24)),
                                ),
                              ),
                              title: Text(part['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text(formatter.format(price), style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w600, fontSize: 12)),
                              trailing: IconButton(icon: const Icon(Icons.add_circle, color: Colors.blue, size: 26), onPressed: () => _addToCart(part)),
                              dense: true,
                            ),
                          );
                        },
                      ),
              ),

              // Transport checkboxes
              const SizedBox(height: 12),
              CheckboxListTile(
                value: _needStaffTravel,
                onChanged: (v) => setState(() => _needStaffTravel = v ?? false),
                title: const Text('🏃‍♂️ Staff travel fee', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Distance: ${_distanceKm.toStringAsFixed(1)} km × Round trip × ${formatter.format(_staffTravelPricePerKm)}/km'),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                tileColor: _needStaffTravel ? Colors.blue.shade50 : Colors.grey.shade50,
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: _needVehicleTransport,
                onChanged: (v) => setState(() => _needVehicleTransport = v ?? false),
                title: const Text('🚛 Vehicle towing fee (To center)', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Distance: ${_distanceKm.toStringAsFixed(1)} km × Round trip × ${formatter.format(_transportPricePerKm)}/km'),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                tileColor: _needVehicleTransport ? Colors.blue.shade50 : Colors.grey.shade50,
              ),

              // ═══════ TEMPORARY BILL ═══════
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('📋 Bill Summary:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const Divider(),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('Rescue labor fee ${_timeMultiplier > 1 ? "(x2)" : "(x1)"}'),
                      Text(formatter.format(_laborCost * _timeMultiplier)),
                    ]),
                    ..._cart.values.map((item) {
                      final p = item['part'];
                      final qty = item['quantity'];
                      final price = (p['price'] as num).toDouble() * _timeMultiplier;
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          children: [
                            Expanded(child: Text('${p['name']} (x$qty)')),
                            Text(formatter.format(price * qty)),
                            const SizedBox(width: 4),
                            InkWell(onTap: () => _removeFromCart(p['id']), child: const Icon(Icons.remove_circle, color: Colors.red, size: 18)),
                          ],
                        ),
                      );
                    }),
                    if (_needStaffTravel)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text('Staff Travel (${_distanceKm.toStringAsFixed(1)}km × Round trip)'),
                          Text(formatter.format(_distanceKm * 2 * _staffTravelPricePerKm)),
                        ]),
                      ),
                    if (_needVehicleTransport)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text('Vehicle Towing (${_distanceKm.toStringAsFixed(1)}km × Round trip)'),
                          Text(formatter.format(_distanceKm * 2 * _transportPricePerKm)),
                        ]),
                      ),
                    const Divider(thickness: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('TOTAL:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        Text(formatter.format(total), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.red.shade700)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _createTemporaryInvoice,
                        icon: const Icon(Icons.receipt_long),
                        label: const Text('CREATE TEMPORARY BILL', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.red.shade700, size: 22),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.red.shade800)),
      ],
    );
  }
}
