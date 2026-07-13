import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../models/loyalty.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/loading_button.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  LoyaltyProfile? _loyalty;
  bool _loyaltyLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLoyalty();
  }

  Future<void> _loadLoyalty() async {
    final userId = context.read<AuthProvider>().mysqlUser?['userId'];
    if (userId == null) return;
    try {
      final response = await ApiClient.get('/customer-profiles/user/$userId');
      final data = ApiClient.parseResponse(response);
      setState(() {
        _loyalty = LoyaltyProfile.fromJson(data as Map<String, dynamic>);
        _loyaltyLoading = false;
      });
    } catch (_) {
      setState(() => _loyaltyLoading = false);
    }
  }

  void _openChangePassword() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ChangePasswordSheet(),
    );
  }

  void _openUpdateInfo() {
    final auth = context.read<AuthProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UpdateInfoSheet(
        mysqlUser: auth.mysqlUser,
      ),
    );
  }

  void _showMyQRCode() {
    final auth = context.read<AuthProvider>();

    final userId = auth.mysqlUser?['userId']?.toString() ?? '0';
    final name = auth.mysqlUser?['fullName']?.toString() ?? 'Customer';
    final email = auth.firebaseUser?.email?.toString() ?? '';

    final qrData = jsonEncode({
      'customerId': int.tryParse(userId) ?? 0,
      'fullName': name,
      'email': email
    });

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('CareBike Identity Code',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Show this code to branch staff to create a maintenance order quickly.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 24),

            Container(
              width: 220,
              height: 220,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))
                  ]
              ),
              child: Center(
                child: QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 180.0,
                  backgroundColor: Colors.white,
                  errorStateBuilder: (cxt, err) {
                    return const Center(
                      child: Text('Loading code...', textAlign: TextAlign.center, style: TextStyle(color: Colors.red)),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 16),
            Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            Text('ID: CB-$userId', style: const TextStyle(fontSize: 14, color: Colors.blueGrey, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          )
        ],
      ),
    );
  }

  void _comingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature is coming soon.'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  void _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out'),
        content: const Text('Are you sure you want to log out of CareBike?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<AuthProvider>().logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final auth   = context.watch<AuthProvider>();

    final name = auth.mysqlUser?['fullName'] ?? 'Customer';

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('My Account'),
        centerTitle: true,
        backgroundColor: AppColors.canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadLoyalty,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _LoyaltyCard(loyalty: _loyalty, isLoading: _loyaltyLoading, userName: name),
              const SizedBox(height: 24),

              _ActionTile(
                icon: Icons.qr_code_2_rounded,
                label: 'My QR Code',
                color: AppColors.primary,
                onTap: _showMyQRCode,
              ),
              const SizedBox(height: 8),

              _ActionTile(
                icon: Icons.manage_accounts_outlined,
                label: 'Update info',
                color: Colors.blue.shade700,
                onTap: _openUpdateInfo,
              ),
              const SizedBox(height: 8),

              _ActionTile(
                icon: Icons.lock_reset_outlined, label: 'Change password', color: scheme.primary,
                onTap: _openChangePassword,
              ),
              const SizedBox(height: 8),

              _ActionTile(
                icon: Icons.local_activity_rounded,
                label: 'Offers & Vouchers',
                color: AppColors.primary,
                onTap: () => _comingSoon('Offers & Vouchers'),
              ),
              const SizedBox(height: 8),

              _ActionTile(
                icon: Icons.headset_mic_rounded,
                label: 'Help Center',
                color: Colors.teal.shade700,
                onTap: () => _comingSoon('Help Center'),
              ),
              const SizedBox(height: 8),

              _ActionTile(
                icon: Icons.logout_rounded, label: 'Log out', color: scheme.error,
                onTap: _logout,
              ),
              const SizedBox(height: 40),

              Text('CareBike v1.0.0  ΓÇó  Smart motorbike care', style: TextStyle(color: scheme.outlineVariant, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}

// ΓöÇΓöÇ Loyalty card ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ

class _LoyaltyCard extends StatelessWidget {
  final LoyaltyProfile? loyalty;
  final bool isLoading;
  final String userName;

  const _LoyaltyCard({
    this.loyalty,
    required this.isLoading,
    required this.userName,
  });

  Color _tierColor(String tier, ColorScheme s) {
    switch (tier) {
      case 'SILVER':   return Colors.blueGrey;
      case 'GOLD':     return Colors.amber[700]!;
      case 'PLATINUM': return Colors.lightBlue[700]!;
      default:         return s.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (isLoading) return const Center(child: CircularProgressIndicator());

    if (loyalty == null) {
      return Card(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(children: [
            const Icon(Icons.account_circle, size: 48, color: Colors.grey),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(userName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('No membership data yet.', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
                ],
              ),
            ),
          ]),
        ),
      );
    }

    final color = _tierColor(loyalty!.memberTier, scheme);
    final tierName = const {'SILVER': 'Silver', 'GOLD': 'Gold', 'PLATINUM': 'Platinum'}[loyalty!.memberTier] ?? 'Standard';
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.82), color, Color.lerp(color, Colors.black, 0.22)!],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 34, offset: const Offset(0, 14))],
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(userName, style: GoogleFonts.poppins(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(Icons.workspace_premium_rounded, color: Colors.white.withValues(alpha: 0.9), size: 18),
                          const SizedBox(width: 5),
                          Text('$tierName member', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 48, height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.two_wheeler_rounded, color: Colors.white, size: 27),
                ),
              ]),
          const SizedBox(height: 20),
          Row(children: [
            _StatBox(label: 'Loyalty points', value: '${loyalty!.accumulatedPoints}'),
            const SizedBox(width: 16),
            _StatBox(label: 'Total spent', value: loyalty!.formattedSpent),
          ]),
          const SizedBox(height: 8),
          _TierProgress(loyalty: loyalty!),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  const _StatBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
      ]),
    ),
  );
}

class _TierProgress extends StatelessWidget {
  final LoyaltyProfile loyalty;
  const _TierProgress({required this.loyalty});

  @override
  Widget build(BuildContext context) {
    double progress;
    String nextTier;
    double target;

    final spent = loyalty.totalSpent;
    if (spent < 5000000) {
      progress = spent / 5000000;
      nextTier = '≡ƒÑê Silver';
      target = 5000000;
    } else if (spent < 15000000) {
      progress = (spent - 5000000) / 10000000;
      nextTier = '≡ƒÑç Gold';
      target = 15000000;
    } else if (spent < 30000000) {
      progress = (spent - 15000000) / 15000000;
      nextTier = '≡ƒÆÄ Platinum';
      target = 30000000;
    } else {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: const Text('Γ£¿ You have reached the top tier!',
            style: TextStyle(color: Colors.white70, fontSize: 12)),
      );
    }

    final remaining = (target - spent).clamp(0, target);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 8),
      Text('${remaining.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.')} VND left to reach $nextTier',
          style: const TextStyle(color: Colors.white70, fontSize: 11)),
      const SizedBox(height: 4),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: progress.clamp(0.0, 1.0),
          backgroundColor: Colors.white24,
          valueColor: const AlwaysStoppedAnimation(Colors.white),
          minHeight: 6,
        ),
      ),
    ]);
  }
}

// ΓöÇΓöÇ Action tile ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionTile({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppStyles.radiusMd),
        side: BorderSide(color: AppColors.edge),
      ),
      tileColor: AppColors.surface,
      leading: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      trailing: Icon(Icons.chevron_right, color: color.withValues(alpha: 0.5)),
    );
  }
}

// ΓöÇΓöÇ Update Info bottom sheet ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
class _UpdateInfoSheet extends StatefulWidget {
  final Map<String, dynamic>? mysqlUser;

  const _UpdateInfoSheet({this.mysqlUser});

  @override
  State<_UpdateInfoSheet> createState() => _UpdateInfoSheetState();
}

class _UpdateInfoSheetState extends State<_UpdateInfoSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _dobCtrl;

  DateTime? _selectedDob;
  String? _selectedGender;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.mysqlUser?['fullName'] ?? '');
    _phoneCtrl = TextEditingController(text: widget.mysqlUser?['phone'] ?? '');
    _dobCtrl = TextEditingController();

    // Load gender
    final String? existingGender = widget.mysqlUser?['gender'];
    if (existingGender == 'Nam' || existingGender == 'Nß╗»' || existingGender == 'Kh├íc') {
      _selectedGender = existingGender;
    }

    // Load date of birth
    final String? existingDob = widget.mysqlUser?['dob'];
    if (existingDob != null && existingDob.isNotEmpty) {
      try {
        _selectedDob = DateTime.parse(existingDob);
        _dobCtrl.text = "${_selectedDob!.day.toString().padLeft(2, '0')}/${_selectedDob!.month.toString().padLeft(2, '0')}/${_selectedDob!.year}";
      } catch (_) {
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _dobCtrl.dispose();
    super.dispose();
  }

// Open the calendar
  Future<void> _selectDate(BuildContext context) async {
    final DateTime today = DateTime.now();
    // Max date of birth (today minus exactly 18 years)
    final DateTime maxDate = DateTime(today.year - 18, today.month, today.day);

    // Use the existing DOB if valid, otherwise jump to maxDate
    final DateTime initial = (_selectedDob != null && !_selectedDob!.isAfter(maxDate))
        ? _selectedDob!
        : maxDate;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: maxDate,
      helpText: 'Pick your date of birth (must be 18+)',
      cancelText: 'Cancel',
      confirmText: 'Done',
    );

    if (picked != null && picked != _selectedDob) {
      setState(() {
        _selectedDob = picked;
        _dobCtrl.text = "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}";
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final userId = widget.mysqlUser?['userId'];
      if (userId == null) throw Exception('User ID not found.');

      String? dobIsoString;
      if (_selectedDob != null) {
        dobIsoString = _selectedDob!.toIso8601String().split('T')[0];
      }

      await ApiClient.put('/users/$userId', {
        'fullName': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'dob': dobIsoString,
        'gender': _selectedGender, // Include gender
      });

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Info updated successfully! Please sign in again to refresh.'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(color: scheme.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: scheme.outlineVariant, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text('Update info', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: scheme.onSurface)),
            const SizedBox(height: 20),

            AppTextField(
              label: 'Full name', controller: _nameCtrl,
              validator: (v) => (v == null || v.isEmpty) ? 'Please enter your full name.' : null,
            ),
            const SizedBox(height: 14),

            // VALIDATE PHONE NUMBER FORMAT
            AppTextField(
              label: 'Phone number', controller: _phoneCtrl, keyboardType: TextInputType.phone,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Please enter your phone number.';
                if (!RegExp(r'^[0-9]{10,}$').hasMatch(v)) {
                  return 'Phone must be digits and at least 10 characters.';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),

            // GENDER DROPDOWN
            DropdownButtonFormField<String>(
              value: _selectedGender,
              decoration: InputDecoration(
                labelText: 'Gender',
                filled: true,
                fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: scheme.outline)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: scheme.outlineVariant)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: scheme.primary, width: 2)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              items: const {'Nam': 'Male', 'Nß╗»': 'Female', 'Kh├íc': 'Other'}.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
              onChanged: (v) => setState(() => _selectedGender = v),
              validator: (v) => v == null ? 'Please select your gender.' : null,
            ),
            const SizedBox(height: 14),

            GestureDetector(
              onTap: () => _selectDate(context),
              child: AbsorbPointer(
                child: AppTextField(
                  label: 'Date of birth (18+)',
                  controller: _dobCtrl,
                  suffixIcon: const Icon(Icons.calendar_month_rounded, color: Colors.grey),
                  validator: (v) => (v == null || v.isEmpty) ? 'Please pick your date of birth.' : null,
                ),
              ),
            ),
            const SizedBox(height: 24),

            LoadingButton(label: 'Save changes', isLoading: _isLoading, onPressed: _submit),
          ],
        ),
      ),
    );
  }
}

// ΓöÇΓöÇ Change password bottom sheet ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet();

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _oldCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscureOld = true;
  bool _obscureNew = true;

  @override
  void dispose() { _oldCtrl.dispose(); _newCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context);
    await context.read<AuthProvider>().changePassword(context, _oldCtrl.text, _newCtrl.text);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(color: scheme.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: scheme.outlineVariant, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text('Change password', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: scheme.onSurface)),
            const SizedBox(height: 20),
            AppTextField(
              label: 'Current password', controller: _oldCtrl, obscureText: _obscureOld,
              validator: (v) => (v == null || v.isEmpty) ? 'Enter your current password.' : null,
              suffixIcon: IconButton(
                icon: Icon(_obscureOld ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                onPressed: () => setState(() => _obscureOld = !_obscureOld),
              ),
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'New password', controller: _newCtrl, obscureText: _obscureNew,
              validator: (v) {
                if (v == null || v.length < 6) return 'New password must be at least 6 characters.';
                return null;
              },
              suffixIcon: IconButton(
                icon: Icon(_obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                onPressed: () => setState(() => _obscureNew = !_obscureNew),
              ),
            ),
            const SizedBox(height: 20),
            LoadingButton(label: 'Confirm password change', isLoading: false, onPressed: _submit),
          ],
        ),
      ),
    );
  }
}
