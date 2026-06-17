import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/loading_button.dart';
import 'register_screen.dart';

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

    // AuthProvider sẽ tự lo việc hiện Loading và báo lỗi
    await context.read<AuthProvider>().signInWithEmailForm(
      context,
      _emailCtrl.text.trim(),
      _passwordCtrl.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),

                // ── Brand mark ──
                Center(
                  child: Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [scheme.primary, scheme.tertiary],
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: scheme.primary.withValues(alpha: 0.35),
                          blurRadius: 20, offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(Icons.motorcycle_rounded, size: 44, color: scheme.onPrimary),
                  ),
                ),
                const SizedBox(height: 28),
                Center(
                  child: Text('CareBike',
                    style: TextStyle(
                      fontSize: 28, fontWeight: FontWeight.w800,
                      color: scheme.primary, letterSpacing: -0.5,
                    ),
                  ),
                ),
                Center(
                  child: Text('Chăm sóc xe máy thông minh', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14)),
                ),
                const SizedBox(height: 40),

                // ── Form ──
                Text('Đăng nhập', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: scheme.onSurface)),
                const SizedBox(height: 6),
                Text('Chào mừng trở lại!', style: TextStyle(color: scheme.onSurfaceVariant)),
                const SizedBox(height: 24),

                AppTextField(
                  label: 'Email',
                  controller: _emailCtrl,
                  hint: 'example@gmail.com',
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập tên đăng nhập.' : null,
                ),
                const SizedBox(height: 16),

                AppTextField(
                  label: 'Mật khẩu',
                  controller: _passwordCtrl,
                  hint: 'Nhập mật khẩu',
                  obscureText: _obscurePass,
                  validator: (v) => (v == null || v.isEmpty) ? 'Vui lòng nhập mật khẩu.' : null,
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                    onPressed: () => setState(() => _obscurePass = !_obscurePass),
                  ),
                ),

                // Nút Quên mật khẩu
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      if (_emailCtrl.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập email phía trên trước khi lấy lại mật khẩu')));
                        return;
                      }
                      context.read<AuthProvider>().sendForgotPasswordEmail(context, _emailCtrl.text);
                    },
                    child: Text('Quên mật khẩu?', style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 16),

                LoadingButton(
                  label: 'Đăng nhập',
                  isLoading: auth.isLoading, // Đồng bộ trạng thái Loading từ Provider
                  onPressed: _submit,
                ),
                const SizedBox(height: 16),

                // Nút Đăng nhập bằng Google
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.g_mobiledata, size: 32, color: Colors.red),
                    label: const Text('Đăng nhập bằng Google', style: TextStyle(fontSize: 16, color: Colors.black87)),
                    onPressed: auth.isLoading ? null : () {
                      context.read<AuthProvider>().signInWithGoogle(context);
                    },
                  ),
                ),
                const SizedBox(height: 20),

                // ── Register link ──
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                    child: RichText(
                      text: TextSpan(
                        text: 'Chưa có tài khoản? ',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                        children: [
                          TextSpan(text: 'Đăng ký ngay', style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}