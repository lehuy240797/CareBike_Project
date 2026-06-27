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
    final auth = context.watch<AuthProvider>();
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
                color: AppColors.primary,
                onTap: _openUpdateInfo,
              ),
              const SizedBox(height: 8),
              _ActionTile(
                icon: Icons.lock_reset_outlined, 
                label: 'Change password', 
                color: scheme.primary,
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
                icon: Icons.logout_rounded, 
                label: 'Log out', 
                color: scheme.error,
                onTap: _logout,
              ),
              const SizedBox(height: 40),
              Text('CareBike v1.0.0 • Smart Motorcycle Care', style: TextStyle(color: scheme.outlineVariant, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}
