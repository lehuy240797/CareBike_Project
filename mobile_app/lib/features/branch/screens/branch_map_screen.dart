import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/theme/theme.dart';
import 'package:mobile_app/features/branch/models/branch.dart';
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
  String _statusMsg = "Finding your location...";

  @override
  void initState() {
    super.initState();
    _initMapData();
  }

  Future<void> _initMapData() async {
    try {
      // 1. Try to get the user's location (safely)
      Position? position = await _determinePosition();

      if (position != null) {
        _userLocation = LatLng(position.latitude, position.longitude);
      } else {
        // IF GPS FAILS OR IS DENIED: default to central HCMC (Ben Thanh Market)
        _userLocation = const LatLng(10.7725, 106.6981);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not get GPS. Showing the default map.'))
          );
        }
      }

      setState(() => _statusMsg = "Loading branches...");

      // 2. Call the API to get the branch list
      final response = await ApiClient.get('/branches');
      final data = ApiClient.parseResponse(response);

      if (data is List) {
        _branches = data.map((e) => Branch.fromJson(e)).where((b) => b.latitude != null && b.longitude != null).toList();
      }

      // 3. Pick the nearest branch as default
      _findNearestBranch();

    } catch (e) {
      setState(() => _statusMsg = "An error occurred: $e");
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

  // ── OPEN GOOGLE MAPS FOR DIRECTIONS ──
  Future<void> _openGoogleMaps(double destLat, double destLng) async {
    // Official Google Maps universal URL syntax
    final String googleUrl = 'https://www.google.com/maps/dir/?api=1&destination=$destLat,$destLng';
    final Uri uri = Uri.parse(googleUrl);

    try {
      // Use LaunchMode.externalApplication to force the Google Maps app (or web browser)
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open the map on this device.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: could not open the map link!')),
        );
      }
    }
  }

  // ── SUPER-SAFE GPS LOGIC (prevents app freeze) ──
  Future<Position?> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null; // GPS is off

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null; // Permission denied
    }

    if (permission == LocationPermission.deniedForever) return null;

    try {
      // Anti-freeze: cap the emulator wait at exactly 5 seconds!
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 5),
      );
    } catch (e) {
      // After 5s with no response, fall back to the last known position
      return await Geolocator.getLastKnownPosition();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.canvas,
        appBar: AppBar(
          title: const Text('Branch Map'),
          titleTextStyle: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.ink,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: 16),
              Text(_statusMsg, style: TextStyle(color: AppColors.inkMuted, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('CareBike System'),
        titleTextStyle: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
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
            bottom: _selectedBranch != null ? 200 : 20,
            child: FloatingActionButton(
              backgroundColor: AppColors.surface,
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              onPressed: () {
                _mapController.move(_userLocation!, 15.0);
              },
              child: Icon(Icons.my_location_rounded, color: AppColors.primary),
            ),
          ),

          if (_selectedBranch != null)
            Positioned(
              left: 16, right: 16, bottom: 20,
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.edge),
                  boxShadow: [BoxShadow(color: AppColors.primaryDeep.withValues(alpha: 0.12), blurRadius: 28, offset: const Offset(0, 12))],
                ),
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
                            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(color: AppColors.primaryMuted, borderRadius: BorderRadius.circular(20)),
                          child: Text(
                            _distanceToSelected != null
                                ? '${(_distanceToSelected! / 1000).toStringAsFixed(1)} km'
                                : '',
                            style: TextStyle(color: AppColors.primaryDeep, fontWeight: FontWeight.w700, fontSize: 12.5),
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.location_on_outlined, size: 17, color: AppColors.inkMuted),
                        const SizedBox(width: 6),
                        Expanded(child: Text(_selectedBranch!.address, style: TextStyle(color: AppColors.ink, height: 1.3))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.phone_outlined, size: 17, color: AppColors.inkMuted),
                        const SizedBox(width: 6),
                        Text(_selectedBranch!.phone, style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    // ── TWO PROFESSIONAL BUTTONS ──
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                // Temporarily go back to home.
                                // Later we can pass the branch ID to HomeTab to auto-fill the form.
                                Navigator.pop(context);
                              },
                              icon: const Icon(Icons.calendar_month_rounded, size: 18),
                              label: const Text('Book'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primaryDeep,
                                side: BorderSide(color: AppColors.primary, width: 1.5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                textStyle: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: AppStyles.brandGradient,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [BoxShadow(color: AppColors.primaryHover.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 7))],
                            ),
                            child: ElevatedButton.icon(
                              onPressed: () {
                                // CALL THE OPEN-GOOGLE-MAPS FUNCTION HERE
                                _openGoogleMaps(
                                    _selectedBranch!.latitude!,
                                    _selectedBranch!.longitude!
                                );
                              },
                              icon: const Icon(Icons.directions_rounded, size: 18),
                              label: const Text('Directions'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                textStyle: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            )
        ],
      ),
    );
  }
}