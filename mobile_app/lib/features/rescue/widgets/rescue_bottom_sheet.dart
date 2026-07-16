import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/features/auth/providers/auth_provider.dart';

class RescueBottomSheet extends StatefulWidget {
  const RescueBottomSheet({super.key});

  // Static helper to open this BottomSheet anywhere in a single line
  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Let the sheet rise when the keyboard opens
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
    'Flat / punctured tire',
    'Dead battery',
    'Broken chain / belt',
    'Engine died for no clear reason',
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
    // Run both in parallel: GPS location and loading the vehicle list to save time
    await Future.wait([_getLocationSafe(), _loadMyVehicles()]);
  }

  // ── SUPER-SAFE GPS LOGIC (reused from the map) ──
  Future<void> _getLocationSafe() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('GPS off');

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied)
          throw Exception('Permission denied');
      }

      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
      _lat = pos.latitude;
      _lng = pos.longitude;
    } catch (e) {
      // If GPS fails, use the last known position or leave null (warned on submit)
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

  // ── LOAD THE CUSTOMER'S VEHICLE LIST ──
  Future<void> _loadMyVehicles() async {
    // 1. Get the user from the Provider
    final user = context.read<AuthProvider>().mysqlUser;

    // Try 'userId', fall back to 'id' (a common mistake here)
    final userId = user?['userId'] ?? user?['id'];

    if (userId == null) {
      if (kDebugMode)
        print('🚨 ERROR: Could not get the customer ID from AuthProvider');
      if (mounted) setState(() => _isLoadingVehicles = false);
      return;
    }

    if (kDebugMode) print('▶️ Loading vehicles for Customer ID: $userId');

    try {
      // 2. Call the API
      final res = await ApiClient.get('/vehicles/owner/$userId');

      if (kDebugMode)
        print(
          '✅ API returned: ${res.body}',
        ); // Print to console to inspect the real structure

      final data = ApiClient.parseResponse(res);

      if (mounted) {
        setState(() {
          // 3. Handle any JSON structure from the backend
          if (data is List) {
            _myVehicles = data; // If the backend returns a plain array
          } else if (data is Map) {
            // If the backend wraps it in an object (e.g. ApiResponse)
            if (data.containsKey('data')) {
              _myVehicles = data['data'] ?? [];
            } else if (data.containsKey('content')) {
              _myVehicles = data['content'] ?? [];
            }
          }

          // 4. Set a default value if there are vehicles
          if (_myVehicles.isNotEmpty) {
            _selectedVehicle = _myVehicles.first;
          }
        });
      }
    } catch (e) {
      if (kDebugMode)
        print(
          '🚨 ERROR CALLING VEHICLES API: $e',
        ); // Bright red console error if the API fails
    } finally {
      if (mounted) setState(() => _isLoadingVehicles = false);
    }
  }

  // ── SUBMIT THE RESCUE REQUEST ──
  Future<void> _submitRescue() async {
    if (_selectedVehicle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select the vehicle that broke down.'),
        ),
      );
      return;
    }
    if (_selectedIssue.isEmpty && _otherIssueCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please pick or enter the vehicle issue.'),
        ),
      );
      return;
    }
    if (_lat == null || _lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not get coordinates. Please enable GPS and try again.',
          ),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final userId = context.read<AuthProvider>().mysqlUser?['userId'];
    final finalIssue = _selectedIssue.isNotEmpty
        ? _selectedIssue
        : _otherIssueCtrl.text.trim();

    final messenger = ScaffoldMessenger.of(context);
    try {
      // POST the rescue request to the backend
      final res = await ApiClient.post('/rescues', {
        'customerId': userId,
        'vehicleId': _selectedVehicle['id'],
        'latitude': _lat,
        'longitude': _lng,
        'issueDescription': finalIssue,
      });

      final data = ApiClient.parseResponse(res);
      final rescueData = data is Map
          ? Map<String, dynamic>.from(data)
          : <String, dynamic>{};
      final branch = rescueData['branch'];
      final branchName = branch is Map ? branch['name']?.toString() ?? '' : '';
      final staffName = rescueData['assignedStaffName']?.toString() ?? '';
      final staffCode = rescueData['staffCode']?.toString() ?? '';
      final staffPhone = rescueData['assignedStaffPhone']?.toString() ?? '';

      final assignmentMessage = branchName.isNotEmpty && staffName.isNotEmpty
          ? 'Rescue request sent to $branchName. '
                '$staffName ($staffCode) will contact you in a few minutes'
                '${staffPhone.isNotEmpty ? ' at $staffPhone' : ''}.'
          : 'Your rescue request was sent successfully. A staff member will contact you in a few minutes.';

      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(assignmentMessage),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 8),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom:
            MediaQuery.of(context).viewInsets.bottom +
            20, // Rise when the keyboard opens
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
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Icon(Icons.support_agent, color: Colors.red.shade500, size: 28),
                const SizedBox(width: 8),
                const Text(
                  'Emergency Rescue 24/7',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 1. SELECT THE BROKEN-DOWN VEHICLE
            Text(
              'Which vehicle has a problem?',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            if (_isLoadingVehicles)
              const Center(child: CircularProgressIndicator())
            else if (_myVehicles.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'You have not added any vehicle yet. Please add one under "My Vehicles" first.',
                  style: TextStyle(color: Colors.red),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: scheme.outlineVariant),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<dynamic>(
                    value: _selectedVehicle,
                    isExpanded: true,
                    hint: const Text('Select a vehicle...'),
                    items: _myVehicles
                        .map(
                          (v) => DropdownMenuItem(
                            value: v,
                            child: Text(
                              '${v['brand']} ${v['vehicleName']} - Plate: ${v['licensePlate']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) => setState(() => _selectedVehicle = val),
                  ),
                ),
              ),
            const SizedBox(height: 20),

            // 2. ISSUE DETAILS
            Text(
              'Current vehicle condition:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _issues.map((issue) {
                final isSelected = _selectedIssue == issue;
                return ChoiceChip(
                  label: Text(issue),
                  selected: isSelected,
                  selectedColor: Colors.red.shade100,
                  side: BorderSide(
                    color: isSelected
                        ? Colors.red.shade300
                        : scheme.outlineVariant,
                  ),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.red.shade800 : scheme.onSurface,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                  onSelected: (selected) {
                    setState(() {
                      _selectedIssue = selected ? issue : '';
                      _otherIssueCtrl.clear();
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _otherIssueCtrl,
              decoration: InputDecoration(
                hintText: 'Enter another issue (if any)...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              onChanged: (val) {
                if (val.isNotEmpty) setState(() => _selectedIssue = '');
              },
            ),
            const SizedBox(height: 20),

            // 3. GPS STATUS
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    _isLocating
                        ? Icons.gps_not_fixed
                        : (_lat != null ? Icons.gps_fixed : Icons.location_off),
                    color: _lat != null ? Colors.blue : Colors.grey,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _isLocating
                        ? const Text(
                            'Locating your position...',
                            style: TextStyle(
                              color: Colors.grey,
                              fontStyle: FontStyle.italic,
                            ),
                          )
                        : (_lat != null
                              ? const Text(
                                  'Your coordinates were recorded for the rescue team.',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                )
                              : const Text(
                                  'GPS error! Please enable location.',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.w500,
                                  ),
                                )),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // CALL-RESCUE BUTTON
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: (_isSubmitting || _isLocating || _myVehicles.isEmpty)
                    ? null
                    : _submitRescue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'CALL RESCUE NOW',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
