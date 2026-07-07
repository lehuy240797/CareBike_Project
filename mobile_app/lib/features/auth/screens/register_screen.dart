import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/theme/theme.dart';
import 'package:mobile_app/features/auth/providers/auth_provider.dart';
import 'package:mobile_app/features/auth/widgets/_auth_widgets.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey      = GlobalKey<FormState>();
  final _passwordCtrl = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _fullNameCtrl = TextEditingController();
  final _phoneCtrl    = TextEditingController();
  bool  _obscurePass  = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _fullNameCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await context.read<AuthProvider>().registerWithEmailForm(
      context,
      email:    _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
      fullName: _fullNameCtrl.text.trim(),
      phone:    _phoneCtrl.text.trim(),
    );

    if (!mounted) return;

    // Show a must-read dialog instead of popping automatically
    if (success) {
      showDialog(
        context: context,
        barrierDismissible: false, // Force the user to tap the button to close
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.mark_email_unread_outlined, color: Colors.green, size: 28),
              SizedBox(width: 8),
              Text("Registration successful", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: const Text(
              "Your account has been created successfully.\n\nWe just sent a verification link to your inbox. Please check your email (including the Spam folder) and confirm before signing in.",
              style: TextStyle(fontSize: 15, height: 1.4)
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx); // Close the dialog
                Navigator.pop(context); // Back to the sign-in screen
              },
              child: const Text("Got it", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            // Header bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(11),
                    child: Container(
                      width: 38, height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(color: AppColors.edge),
                      ),
                      child: Icon(Icons.arrow_back_rounded, size: 22, color: AppColors.ink),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 38),
                      child: Text('Create account',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.ink)),
                    ),
                  ),
                ],
              ),
            ),

            // Form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 14, 28, 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle(Icons.person_rounded, 'Personal information'),
                      const SizedBox(height: 14),

                      const AuthLabel('Full name', dot: false),
                      AuthField(
                        controller: _fullNameCtrl,
                        icon: Icons.badge_rounded,
                        hint: 'e.g. Minh Nguyen',
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter your full name.' : null,
                      ),
                      const SizedBox(height: 14),

                      const AuthLabel('Phone number', dot: false),
                      AuthField(
                        controller: _phoneCtrl,
                        icon: Icons.call_rounded,
                        hint: '090 123 4567',
                        keyboardType: TextInputType.phone,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter your phone number.' : null,
                      ),
                      const SizedBox(height: 14),

                      const AuthLabel('Email', dot: false),
                      AuthField(
                        controller: _emailCtrl,
                        icon: Icons.mail_rounded,
                        hint: 'example@gmail.com',
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Please enter your email.';
                          if (!v.contains('@')) return 'Invalid email.';
                          return null;
                        },
                      ),

                      const SizedBox(height: 22),
                      Container(height: 1, color: AppColors.edge),
                      const SizedBox(height: 22),

                      _sectionTitle(Icons.shield_rounded, 'Security information'),
                      const SizedBox(height: 14),

                      const AuthLabel('Password', dot: false),
                      AuthField(
                        controller: _passwordCtrl,
                        icon: Icons.lock_rounded,
                        hint: 'At least 6 characters',
                        obscure: _obscurePass,
                        onToggleObscure: () => setState(() => _obscurePass = !_obscurePass),
                        validator: (v) {
                          if (v == null || v.length < 6) return 'Password must be at least 6 characters.';
                          return null;
                        },
                      ),

                      const SizedBox(height: 28),
                      AuthGradientButton(
                        label: 'Create account',
                        isLoading: auth.isLoading,
                        onTap: _submit,
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(text, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink)),
      ],
    );
  }
}
