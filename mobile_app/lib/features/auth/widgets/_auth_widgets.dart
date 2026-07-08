import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/theme/theme.dart';

/// Orange gradient hero with the CAREBIKE wordmark — shared by the auth screens.
class AuthHero extends StatelessWidget {
  const AuthHero({super.key});

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery
        .of(context)
        .padding
        .top;
    return Container(
      height: 300 + topInset,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFDBA74), Color(0xFFF97316), Color(0xFFEA580C)],
          begin: Alignment(0.4, -1), end: Alignment(-0.4, 1),
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(46)),
      ),
      child: Stack(
        children: [
          _circle(top: -70 + topInset,
              right: -50,
              size: 220,
              color: Colors.white.withValues(alpha: 0.12)),
          _ring(top: 30 + topInset, left: -60, size: 160),
          _circle(bottom: -40,
              left: 40,
              size: 120,
              color: Colors.white.withValues(alpha: 0.08)),
          _dot(top: 90 + topInset, left: 42, size: 9),
          _dot(top: 130 + topInset, right: 54, size: 6),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('CARE', style: GoogleFonts.montserrat(fontSize: 46,
                        fontWeight: FontWeight.w800,
                        fontStyle: FontStyle.italic,
                        color: Colors.white,
                        letterSpacing: -1)),
                    Text('BIKE', style: GoogleFonts.montserrat(fontSize: 46,
                        fontWeight: FontWeight.w800,
                        fontStyle: FontStyle.italic,
                        color: const Color(0xFF7C2D12),
                        letterSpacing: -1)),
                  ],
                ),
                const SizedBox(height: 10),
                Text('Smart motorbike care',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _circle(
      {double? top, double? bottom, double? left, double? right, required double size, required Color color}) {
    return Positioned(top: top,
        bottom: bottom,
        left: left,
        right: right,
        child: Container(width: size,
            height: size,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color)));
  }

  Widget _ring({double? top, double? left, required double size}) {
    return Positioned(top: top, left: left,
        child: Container(width: size,
            height: size,
            decoration: BoxDecoration(shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.22), width: 2))));
  }

  Widget _dot(
      {double? top, double? left, double? right, required double size}) {
    return Positioned(top: top, left: left, right: right,
        child: Container(width: size,
            height: size,
            decoration: BoxDecoration(shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.6))));
  }
}

/// Orbitron pill badge (e.g. "Welcome back").
class AuthBadge extends StatelessWidget {
  final IconData icon;
  final String text;

  const AuthBadge({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(color: AppColors.primaryMuted,
          borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primaryDeep),
          const SizedBox(width: 6),
          Text(text.toUpperCase(),
              style: GoogleFonts.orbitron(fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: AppColors.primaryDeep)),
        ],
      ),
    );
  }
}

/// Field label, optionally with the small orange dot.
class AuthLabel extends StatelessWidget {
  final String text;
  final bool dot;

  const AuthLabel(this.text, {super.key, this.dot = true});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          if (dot) ...[
            Container(width: 5,
                height: 5,
                decoration: BoxDecoration(
                    shape: BoxShape.circle, color: AppColors.primary)),
            const SizedBox(width: 6),
          ],
          Text(text, style: TextStyle(fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.inkMuted)),
        ],
      ),
    );
  }
}

/// Styled text field matching the mockup (leading icon, warm fill, orange focus).
class AuthField extends StatelessWidget {
  final TextEditingController controller;
  final IconData icon;
  final String? hint;
  final bool obscure;
  final VoidCallback? onToggleObscure;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;

  const AuthField({
    super.key,
    required this.controller,
    required this.icon,
    this.hint,
    this.obscure = false,
    this.onToggleObscure,
    this.keyboardType = TextInputType.text,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: AppColors.fieldFill,
        hintText: hint,
        hintStyle: TextStyle(fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.faint),
        prefixIcon: Icon(icon, size: 20, color: AppColors.faint),
        suffixIcon: onToggleObscure == null
            ? null
            : IconButton(
          icon: Icon(
              obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
              size: 20, color: AppColors.faint),
          onPressed: onToggleObscure,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 4),
        border: _border(AppColors.edge),
        enabledBorder: _border(AppColors.edge),
        focusedBorder: _border(AppColors.primary),
        errorBorder: _border(AppColors.danger),
        focusedErrorBorder: _border(AppColors.danger),
      ),
    );
  }

  OutlineInputBorder _border(Color c) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: c, width: 1.5),
      );
}

/// Full-width gradient action button with optional trailing icon + loading state.
class AuthGradientButton extends StatelessWidget {
  final String label;
  final IconData? trailingIcon;
  final bool isLoading;
  final VoidCallback onTap;

  const AuthGradientButton(
      {super.key, required this.label, this.trailingIcon, required this.isLoading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        width: double.infinity,
        height: 53,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(colors: [
            Color(0xFFFB923C),
            Color(0xFFF97316),
            Color(0xFFEA580C)
          ]),
          boxShadow: [
            BoxShadow(color: AppColors.primary.withValues(alpha: 0.6),
                blurRadius: 26,
                offset: const Offset(0, 14))
          ],
        ),
        child: isLoading
            ? const SizedBox(width: 22,
            height: 22,
            child: CircularProgressIndicator(
                strokeWidth: 2.4, color: Colors.white))
            : Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: const TextStyle(color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700)),
            if (trailingIcon != null) ...[
              const SizedBox(width: 8),
              Icon(trailingIcon, size: 20, color: Colors.white),
            ],
          ],
        ),
      ),
    );
  }
}

/// "─── or ───" divider.
class AuthOrDivider extends StatelessWidget {
  const AuthOrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: AppColors.edge, thickness: 1)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text('or', style: TextStyle(fontSize: 11.5,
              color: Color(0xFFB8AC9F),
              fontWeight: FontWeight.w600)),
        ),
        Expanded(child: Divider(color: AppColors.edge, thickness: 1)),
      ],
    );
  }
}
