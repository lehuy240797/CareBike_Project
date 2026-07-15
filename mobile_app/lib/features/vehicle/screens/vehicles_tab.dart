import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/theme/theme.dart';
import 'package:mobile_app/features/vehicle/models/vehicle.dart';
import 'package:mobile_app/features/auth/providers/auth_provider.dart';
import 'package:mobile_app/shared/widgets/app_text_field.dart';
import 'package:mobile_app/shared/widgets/loading_button.dart';

class VehiclesTab extends StatefulWidget {
  const VehiclesTab({super.key});

  @override
  State<VehiclesTab> createState() => _VehiclesTabState();
}

class _VehiclesTabState extends State<VehiclesTab> {
  // CHANGE: from a single vehicle to a list of vehicles
  List<Vehicle> _vehicles = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userId = context.read<AuthProvider>().mysqlUser?['userId'];
      if (userId == null) throw Exception('Login info not found.');

      final response = await ApiClient.get('/vehicles/owner/$userId');
      final data = ApiClient.parseResponse(response);

      // Receive an array of vehicles from the backend
      if (data is List) {
        _vehicles = data
            .map((v) => Vehicle.fromJson(v as Map<String, dynamic>))
            .toList();
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
      _error = 'System error: $e';
    } finally {
      if (mounted)
        setState(() {
          _isLoading = false;
        });
    }
  }

  void _openForm({Vehicle? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _VehicleForm(
        existing: existing,
        onSaved: () => _load(), // Reload the list after saving
      ),
    );
  }

  String _fmt(int n) => n.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (m) => '${m[1]},',
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('Vehicle profile'),
        centerTitle: true,
        backgroundColor: AppColors.canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      floatingActionButton: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFFFB923C), Color(0xFFF97316), Color(0xFFEA580C)],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryHover.withValues(alpha: 0.45),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: () => _openForm(),
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          highlightElevation: 0,
          icon: const Icon(Icons.add_rounded),
          label: const Text(
            'Add vehicle',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _load,
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _error != null
            ? Center(
                child: Text(_error!, style: TextStyle(color: AppColors.danger)),
              )
            : _vehicles.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 140),
                  Icon(
                    Icons.two_wheeler_rounded,
                    size: 72,
                    color: AppColors.edge,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No vehicle profile yet',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap the button below to add your vehicle.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.inkMuted),
                  ),
                ],
              )
            // SHOW THE LIST OF VEHICLES
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  20,
                  8,
                  20,
                  110,
                ), // Bottom gap to clear the Add button
                itemCount: _vehicles.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final vehicle = _vehicles[index];
                  return _VehicleCard(
                    vehicle: vehicle,
                    kmText: '${_fmt(vehicle.currentKm ?? 0)} km',
                    onEdit: () => _openForm(
                      existing: vehicle,
                    ), // Pass the existing vehicle to edit
                  );
                },
              ),
      ),
    );
  }
}

// ── Vehicle display card (mockup) ─────────────────────────────────────────────

class _VehicleCard extends StatelessWidget {
  final Vehicle vehicle;
  final String kmText;
  final VoidCallback onEdit;

  const _VehicleCard({
    required this.vehicle,
    required this.kmText,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.edge),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDeep.withValues(alpha: 0.07),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primaryLight, AppColors.primaryMuted],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: AppColors.primaryMuted),
                ),
                child: Icon(
                  Icons.two_wheeler_rounded,
                  size: 30,
                  color: AppColors.primaryHover,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vehicle.vehicleName,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _Chip(vehicle.brand),
                        const SizedBox(width: 6),
                        _Chip(vehicle.typeLabel),
                      ],
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: onEdit,
                borderRadius: BorderRadius.circular(11),
                child: Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.fieldFill,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: AppColors.edge),
                  ),
                  child: Icon(
                    Icons.edit_rounded,
                    size: 19,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: AppColors.edge),
          const SizedBox(height: 16),
          _DetailRow(
            label: 'License plate',
            value: vehicle.licensePlate,
            mono: true,
          ),
          const SizedBox(height: 11),
          _DetailRow(
            label: 'Engine',
            value: '${vehicle.engineCapacity ?? 0} cc',
          ),
          const SizedBox(height: 11),
          _DetailRow(label: 'Odometer', value: kmText),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip(this.label);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primaryMuted,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          color: AppColors.primaryDeep,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool mono;
  const _DetailRow({
    required this.label,
    required this.value,
    this.mono = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.faint,
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        mono
            ? Text(
                value,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                  letterSpacing: 1,
                ),
              )
            : Text(
                value,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF44403C),
                ),
              ),
      ],
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
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _licensePlateCtrl = TextEditingController();
  final _engineCapacityCtrl = TextEditingController();
  final _currentKmCtrl = TextEditingController();

  String _brand = 'Honda';
  String _vehicleType = 'XE_TAY_GA';
  bool _isSaving = false;
  String? _error;

  static const _brands = [
    'Honda',
    'Yamaha',
    'Suzuki',
    'SYM',
    'Piaggio',
    'Other',
  ];
  static const _types = [
    {'value': 'XE_SO', 'label': 'Manual'},
    {'value': 'XE_TAY_GA', 'label': 'Scooter'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final v = widget.existing!;
      _nameCtrl.text = v.vehicleName;
      _licensePlateCtrl.text = v.licensePlate;
      _engineCapacityCtrl.text = v.engineCapacity?.toString() ?? '';
      _currentKmCtrl.text = v.currentKm?.toString() ?? '';
      _brand = v.brand;
      _vehicleType = v.vehicleType;
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
    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final userId = context.read<AuthProvider>().mysqlUser?['userId'];
      final body = {
        'id': widget.existing?.id, // Include the ID when editing
        'brand': _brand,
        'vehicleType': _vehicleType,
        'vehicleName': _nameCtrl.text.trim(),
        'licensePlate': _licensePlateCtrl.text.trim().toUpperCase(),
        'engineCapacity': int.tryParse(_engineCapacityCtrl.text.trim()) ?? 0,
        'currentKm': int.tryParse(_currentKmCtrl.text.trim()) ?? 0,
      };

      await ApiClient.put('/vehicles/owner/$userId', body);

      widget.onSaved(); // Tell the list to reload
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      // PRINT TO THE FLUTTER CONSOLE
      print('=== ERROR RETURNED FROM BACKEND: ${e.message} ===');
      setState(() {
        _error = e.message;
      });
    } catch (e) {
      // PRINT TO THE FLUTTER CONSOLE
      print('=== INTERNAL FLUTTER ERROR: $e ===');
      setState(() {
        _error = 'Save failed: $e';
      });
    } finally {
      if (mounted)
        setState(() {
          _isSaving = false;
        });
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
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.existing == null ? 'Add vehicle' : 'Edit vehicle',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: _DropdownField(
                      label: 'Brand',
                      value: _brand,
                      items: _brands
                          .map(
                            (b) => DropdownMenuItem(value: b, child: Text(b)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _brand = v!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DropdownField(
                      label: 'Type',
                      value: _vehicleType,
                      items: _types
                          .map(
                            (t) => DropdownMenuItem(
                              value: t['value'],
                              child: Text(t['label']!),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _vehicleType = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              AppTextField(
                label: 'Model name',
                controller: _nameCtrl,
                hint: 'e.g. Airblade, Exciter...',
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Please enter the model name.'
                    : null,
              ),
              const SizedBox(height: 12),

              AppTextField(
                label: 'License plate',
                controller: _licensePlateCtrl,
                hint: 'e.g. 59X1-123.45',
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Please enter the license plate.'
                    : null,
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      label: 'Engine (cc)',
                      controller: _engineCapacityCtrl,
                      keyboardType: TextInputType.number,
                      hint: 'e.g. 150',
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        if (int.tryParse(v) == null) return 'Must be a number';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppTextField(
                      label: 'Odometer (km)',
                      controller: _currentKmCtrl,
                      keyboardType: TextInputType.number,
                      hint: 'e.g. 15000',
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        if (int.tryParse(v) == null) return 'Must be a number';
                        return null;
                      },
                    ),
                  ),
                ],
              ),

              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: TextStyle(color: scheme.error, fontSize: 13),
                ),
              ],
              const SizedBox(height: 20),

              LoadingButton(
                label: 'Save vehicle',
                isLoading: _isSaving,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final void Function(T?) onChanged;

  const _DropdownField({
    required this.label,
    this.value,
    required this.items,
    required this.onChanged,
  });

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
    validator: (value) => value == null ? 'Please select $label' : null,
  );
}
