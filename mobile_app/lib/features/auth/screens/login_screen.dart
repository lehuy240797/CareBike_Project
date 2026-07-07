import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/theme/theme.dart';
import 'package:mobile_app/core/theme/theme_controller.dart';
import 'package:mobile_app/features/auth/providers/auth_provider.dart';
import 'package:mobile_app/features/auth/widgets/_auth_widgets.dart';
import 'package:mobile_app/features/auth/screens/register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey        = GlobalKey<FormState>();
  final _emailCtrl      = TextEditingController();
  final _passwordCtrl   = TextEditingController();
  bool  _obscurePass    = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // AuthProvider handles showing the loading state and errors
    await context.read<AuthProvider>().signInWithEmailForm(
      context,
      _emailCtrl.text.trim(),
      _passwordCtrl.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    context.watch<ThemeController>(); // repaint tokens when the theme flips

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                const AuthHero(),
                Transform.translate(
                  offset: const Offset(0, -44),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _card(auth),
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -22),
                  child: _signupLink(),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
          // Dark-mode toggle floating over the hero.
          Positioned(
            top: 0, right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: _themeToggle(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _themeToggle() {
    final isDark = ThemeController.instance.isDark;
    return Material(
      color: Colors.white.withValues(alpha: 0.2),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => ThemeController.instance.toggle(),
        child: Container(
          width: 42, height: 42,
          alignment: Alignment.center,
          child: Icon(
            isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            color: Colors.white, size: 22,
          ),
        ),
      ),
    );
  }

  Widget _card(AuthProvider auth) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.edge),
        boxShadow: [BoxShadow(color: AppColors.primaryDeep.withValues(alpha: 0.16), blurRadius: 50, offset: const Offset(0, 22))],
      ),
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AuthBadge(icon: Icons.waving_hand_rounded, text: 'Welcome back'),
            const SizedBox(height: 13),
            Text('Sign in', style: GoogleFonts.poppins(fontSize: 25, fontWeight: FontWeight.w800, color: AppColors.ink, letterSpacing: -0.4)),
            const SizedBox(height: 3),
            Text('Log in to keep your bike in top shape',
                style: TextStyle(color: AppColors.faint, fontSize: 13.5, fontWeight: FontWeight.w500)),
            const SizedBox(height: 20),

            const AuthLabel('Email'),
            AuthField(
              controller: _emailCtrl,
              icon: Icons.mail_rounded,
              hint: 'example@gmail.com',
              keyboardType: TextInputType.emailAddress,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter your username.' : null,
            ),
            const SizedBox(height: 15),

            const AuthLabel('Password'),
            AuthField(
              controller: _passwordCtrl,
              icon: Icons.lock_rounded,
              hint: 'Enter your password',
              obscure: _obscurePass,
              onToggleObscure: () => setState(() => _obscurePass = !_obscurePass),
              validator: (v) => (v == null || v.isEmpty) ? 'Please enter your password.' : null,
            ),
            const SizedBox(height: 10),

            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () {
                  if (_emailCtrl.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter your email above before resetting your password')));
                    return;
                  }
                  context.read<AuthProvider>().sendForgotPasswordEmail(context, _emailCtrl.text);
                },
                child: Text('Forgot password?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
              ),
            ),
            const SizedBox(height: 12),

            AuthGradientButton(
              label: 'Sign in',
              trailingIcon: Icons.arrow_forward_rounded,
              isLoading: auth.isLoading,
              onTap: _submit,
            ),
            const SizedBox(height: 14),

            const AuthOrDivider(),
            const SizedBox(height: 14),

            // Sign in with Google
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  backgroundColor: AppColors.surface,
                  side: BorderSide(color: AppColors.edge, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: auth.isLoading ? null : () => context.read<AuthProvider>().signInWithGoogle(context),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('G', style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 18, color: const Color(0xFF4285F4))),
                    const SizedBox(width: 10),
                    Text('Sign in with Google', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.ink)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _signupLink() {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
      child: RichText(
        text: TextSpan(
          text: "Don't have an account?  ",
          style: TextStyle(color: AppColors.faint, fontSize: 13.5, fontWeight: FontWeight.w500),
          children: [
            TextSpan(text: 'Sign up', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
