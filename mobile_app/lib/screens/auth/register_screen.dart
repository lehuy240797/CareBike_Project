import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/loading_button.dart';

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

    // FIX LỖI THIẾU THÔNG BÁO: Hiện thông báo bắt buộc đọc thay vì tự động pop() ngay
    if (success) {
      showDialog(
        context: context,
        barrierDismissible: false, // Bắt người dùng phải bấm nút để đóng
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.mark_email_unread_outlined, color: Colors.green, size: 28),
              SizedBox(width: 8),
              Text("Đăng ký thành công", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: const Text(
              "Tài khoản của bạn đã được tạo thành công.\n\nHệ thống vừa gửi một liên kết xác thực đến hòm thư của bạn. Vui lòng kiểm tra Email (bao gồm cả mục Thư rác/Spam) và xác nhận trước khi đăng nhập.",
              style: TextStyle(fontSize: 15, height: 1.4)
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx); // Đóng bảng thông báo
                Navigator.pop(context); // Trở về trang Đăng nhập
              },
              child: const Text("Đã hiểu", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('Tạo tài khoản'),
        centerTitle: true,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Thông tin cá nhân', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: scheme.onSurface)),
                const SizedBox(height: 4),
                AppTextField(
                  label: 'Họ và tên', controller: _fullNameCtrl,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập họ tên.' : null,
                ),
                const SizedBox(height: 14),
                AppTextField(
                  label: 'Số điện thoại', controller: _phoneCtrl, keyboardType: TextInputType.phone,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập số điện thoại.' : null,
                ),
                const SizedBox(height: 14),
                AppTextField(
                  label: 'Email', controller: _emailCtrl, keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Vui lòng nhập email.';
                    if (!v.contains('@')) return 'Email không hợp lệ.';
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                Divider(color: scheme.outlineVariant),
                const SizedBox(height: 16),

                Text('Thông tin bảo mật', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: scheme.onSurface)),
                const SizedBox(height: 16),

                AppTextField(
                  label: 'Mật khẩu', controller: _passwordCtrl, hint: 'Tối thiểu 6 ký tự', obscureText: _obscurePass,
                  validator: (v) {
                    if (v == null || v.length < 6) return 'Mật khẩu tối thiểu 6 ký tự.';
                    return null;
                  },
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                    onPressed: () => setState(() => _obscurePass = !_obscurePass),
                  ),
                ),
                const SizedBox(height: 28),
                LoadingButton(
                  label: 'Tạo tài khoản',
                  isLoading: auth.isLoading,
                  onPressed: _submit,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}