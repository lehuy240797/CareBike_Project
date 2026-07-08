import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/theme/theme.dart';
import 'package:mobile_app/shared/widgets/app_text_field.dart';
import 'package:mobile_app/shared/widgets/loading_button.dart';
import 'package:mobile_app/features/auth/providers/auth_provider.dart';

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
        throw Exception('Your branch was not found. Are you a branch manager?');
      }

      // Push the maintenance record to Spring Boot
      await ApiClient.post('/maintenance', {
        'serviceDate': DateTime.now().toIso8601String().split('T')[0],
        'currentKm': int.tryParse(_currentKmCtrl.text) ?? 0,
        'serviceDetails': _serviceDetailsCtrl.text,
        'totalCost': double.tryParse(_totalCostCtrl.text.replaceAll('.', '')) ?? 0.0,
        'customerId': widget.customerId, // Get the ID directly from the QR code
        'branchId': currentBranchId,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maintenance record created successfully!'), backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('Create maintenance record'),
        titleTextStyle: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink),
        centerTitle: true,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Switched from showing vehicle info to customer info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.edge),
                  boxShadow: [BoxShadow(color: AppColors.primaryDeep.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 8))],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 50, height: 50,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: AppStyles.brandGradient,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(Icons.person_rounded, color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.customerName, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink)),
                          const SizedBox(height: 2),
                          Text('System ID: CB-${widget.customerId}', style: TextStyle(fontSize: 13, color: AppColors.inkMuted, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              Text('Repair details', style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink)),
              const SizedBox(height: 16),

              AppTextField(
                label: 'Parts replaced', controller: _serviceDetailsCtrl, hint: 'e.g. Oil change, tire replacement...',
                validator: (v) => v == null || v.isEmpty ? 'Please enter the details' : null,
              ),
              const SizedBox(height: 16),

              AppTextField(
                label: 'Current km', controller: _currentKmCtrl, keyboardType: TextInputType.number,
                validator: (v) => v == null || v.isEmpty ? 'Please enter the km' : null,
              ),
              const SizedBox(height: 16),

              AppTextField(
                label: 'Total (VND)', controller: _totalCostCtrl, keyboardType: TextInputType.number,
                validator: (v) => v == null || v.isEmpty ? 'Please enter the total' : null,
              ),

              const SizedBox(height: 32),
              LoadingButton(
                label: 'Save maintenance record',
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