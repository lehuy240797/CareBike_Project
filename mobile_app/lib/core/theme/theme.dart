import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/theme/theme_controller.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// CareBike design tokens — mirrors the web app's "Energize" orange theme.
/// Tokens resolve to a light or dark value based on [ThemeController]. Purely
/// presentational — no business logic here.
/// ─────────────────────────────────────────────────────────────────────────

/// A complete set of resolved color values for one brightness.
class _Pal {
  final Color primary, primaryHover, primaryDeep, primaryBright, primaryLight, primaryMuted;
  final Color ink, inkMuted, surface, canvas, edge, edgeSoft;
  final Color fieldFill, faint, hairline;
  final Color success, successBg, danger, dangerBg, warning, warningBg, info;
  const _Pal({
    required this.primary,
    required this.primaryHover,
    required this.primaryDeep,
    required this.primaryBright,
    required this.primaryLight,
    required this.primaryMuted,
    required this.ink,
    required this.inkMuted,
    required this.surface,
    required this.canvas,
    required this.edge,
    required this.edgeSoft,
    required this.fieldFill,
    required this.faint,
    required this.hairline,
    required this.success,
    required this.successBg,
    required this.danger,
    required this.dangerBg,
    required this.warning,
    required this.warningBg,
    required this.info,
  });
}

const _light = _Pal(
  primary: Color(0xFFF97316),
  primaryHover: Color(0xFFEA580C),
  primaryDeep: Color(0xFFC2410C),
  primaryBright: Color(0xFFFB923C),
  primaryLight: Color(0xFFFFF7ED),
  primaryMuted: Color(0xFFFFEDD5),
  ink: Color(0xFF1C1917),
  inkMuted: Color(0xFF78716C),
  surface: Color(0xFFFFFFFF),
  canvas: Color(0xFFFDF9F5),
  edge: Color(0xFFF0E9E1),
  edgeSoft: Color(0xFFF7F1EA),
  fieldFill: Color(0xFFFDFAF6),
  faint: Color(0xFFA8A29E),
  hairline: Color(0xFFD6CCC2),
  success: Color(0xFF16A34A),
  successBg: Color(0xFFF0FDF4),
  danger: Color(0xFFDC2626),
  dangerBg: Color(0xFFFEF2F2),
  warning: Color(0xFFB45309),
  warningBg: Color(0xFFFFFBEB),
  info: Color(0xFF2563EB),
);

const _dark = _Pal(
  // Accents brighten on dark so icons/eyebrows stay legible (matches mockup).
  primary: Color(0xFFFB923C),
  primaryHover: Color(0xFFFB923C),
  primaryDeep: Color(0xFFFDBA74), // light orange — used as text on muted pills
  primaryBright: Color(0xFFFB923C),
  primaryLight: Color(0x1FF97316), // ~12% orange tile over dark
  primaryMuted: Color(0x29F97316), // ~16% orange pill over dark
  ink: Color(0xFFF2ECE6),
  inkMuted: Color(0xFF8B817A),
  surface: Color(0xFF211C18),
  canvas: Color(0xFF16120F),
  edge: Color(0xFF2E2823),
  edgeSoft: Color(0xFF241F1B),
  fieldFill: Color(0xFF1C1814),
  faint: Color(0xFF6B635C),
  hairline: Color(0xFF3A332E),
  success: Color(0xFF4ADE80),
  successBg: Color(0x2622C55E),
  danger: Color(0xFFF87171),
  dangerBg: Color(0x26DC2626),
  warning: Color(0xFFFBBF24),
  warningBg: Color(0x26B45309),
  info: Color(0xFF60A5FA),
);

_Pal get _p => ThemeController.instance.isDark ? _dark : _light;

class AppColors {
  // Brand — bright energetic orange
  static Color get primary => _p.primary;
  static Color get primaryHover => _p.primaryHover;
  static Color get primaryDeep => _p.primaryDeep;
  static Color get primaryBright => _p.primaryBright;
  static Color get primaryLight => _p.primaryLight;
  static Color get primaryMuted => _p.primaryMuted;

  // Warm neutrals
  static Color get ink => _p.ink;
  static Color get inkMuted => _p.inkMuted;
  static Color get surface => _p.surface;
  static Color get canvas => _p.canvas;
  static Color get edge => _p.edge;
  static Color get edgeSoft => _p.edgeSoft;

  // Extra surface tokens (cream input fills, faint text, hairline dividers)
  static Color get fieldFill => _p.fieldFill;
  static Color get faint => _p.faint;
  static Color get hairline => _p.hairline;

  // Feedback
  static Color get success => _p.success;
  static Color get successBg => _p.successBg;
  static Color get danger => _p.danger;
  static Color get dangerBg => _p.dangerBg;
  static Color get warning => _p.warning;
  static Color get warningBg => _p.warningBg;
  static Color get info => _p.info;
}

/// Shared, reusable visual helpers used across screens.
class AppStyles {
  AppStyles._();

  static const double radiusSm = 12;
  static const double radiusMd = 16;
  static const double radiusLg = 20;
  static const double radiusXl = 24; // rounded-3xl equivalent

  /// Warm-tinted card shadow (matches the web's --shadow-card).
  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: AppColors.primaryDeep.withValues(alpha: 0.08),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];

  /// Orange glow used on primary surfaces on hover/press in the web app.
  static List<BoxShadow> get glow => [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.30),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];

  /// rounded-3xl white card with warm border — the web's signature card.
  static BoxDecoration card({double radius = radiusXl, bool shadow = true}) =>
      BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.edge),
        boxShadow: shadow ? softShadow : null,
      );

  /// The brand gradient (orange-400 → orange-500 → orange-600).
  /// Fixed across themes — the orange identity stays the same in dark mode.
  static const LinearGradient brandGradient = LinearGradient(
    colors: [Color(0xFFFB923C), Color(0xFFF97316), Color(0xFFEA580C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Typography helpers ──────────────────────────────────────────────────

  /// Racing Sans One brand wordmark (uppercase, tracked) — like the web logo.
  static TextStyle brand({double size = 26, Color? color}) =>
      GoogleFonts.racingSansOne(
        fontSize: size,
        color: color ?? AppColors.primary,
        letterSpacing: 3,
      );

  /// Orbitron uppercase eyebrow label above headings.
  static TextStyle eyebrow({Color? color}) => GoogleFonts.orbitron(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 2.5,
        color: color ?? AppColors.primary,
      );

  /// Big Poppins black heading (the web's dashTitle).
  static TextStyle heading({double size = 26, Color? color}) =>
      GoogleFonts.poppins(
        fontSize: size,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        color: color ?? AppColors.ink,
      );

  static TextStyle section({double size = 17, Color? color}) =>
      GoogleFonts.poppins(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color ?? AppColors.ink,
      );
}

class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(_light, Brightness.light);
  static ThemeData get dark => _build(_dark, Brightness.dark);

  static ThemeData _build(_Pal p, Brightness brightness) {
    final base = ColorScheme.fromSeed(
      seedColor: p.primary,
      brightness: brightness,
    );

    final scheme = base.copyWith(
      primary: p.primary,
      onPrimary: Colors.white,
      primaryContainer: p.primaryMuted,
      onPrimaryContainer: p.primaryDeep,
      secondary: p.primaryHover,
      onSecondary: Colors.white,
      secondaryContainer: p.primaryLight,
      onSecondaryContainer: p.primaryDeep,
      tertiary: p.primaryBright,
      onTertiary: Colors.white,
      surface: p.surface,
      onSurface: p.ink,
      onSurfaceVariant: p.inkMuted,
      surfaceContainerLowest: p.surface,
      surfaceContainerLow: p.primaryLight,
      surfaceContainer: p.canvas,
      surfaceContainerHigh: p.primaryLight,
      surfaceContainerHighest: p.edgeSoft,
      outline: p.edge,
      outlineVariant: p.edge,
      error: p.danger,
    );

    final textTheme = GoogleFonts.interTextTheme(
      brightness == Brightness.dark ? ThemeData.dark().textTheme : null,
    ).copyWith(
      displayLarge: GoogleFonts.poppins(fontWeight: FontWeight.w800, color: p.ink),
      displayMedium: GoogleFonts.poppins(fontWeight: FontWeight.w800, color: p.ink),
      displaySmall: GoogleFonts.poppins(fontWeight: FontWeight.w800, color: p.ink),
      headlineLarge: GoogleFonts.poppins(fontWeight: FontWeight.w800, color: p.ink),
      headlineMedium: GoogleFonts.poppins(fontWeight: FontWeight.w800, color: p.ink),
      headlineSmall: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: p.ink),
      titleLarge: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: p.ink),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.canvas,
      textTheme: textTheme,
      splashFactory: InkRipple.splashFactory,

      appBarTheme: AppBarTheme(
        backgroundColor: p.surface,
        foregroundColor: p.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 19,
          fontWeight: FontWeight.w800,
          color: p.ink,
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        height: 66,
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: p.primaryMuted,
        elevation: 3,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.inter(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? p.primaryDeep : p.inkMuted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? p.primaryDeep : p.inkMuted,
          );
        }),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.primary,
          side: BorderSide(color: p.edge),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: p.primary),
      ),

      cardTheme: CardThemeData(
        color: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppStyles.radiusXl),
          side: BorderSide(color: p.edge),
        ),
        margin: EdgeInsets.zero,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: p.primaryLight,
        side: BorderSide.none,
        labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, color: p.primaryDeep),
        shape: const StadiumBorder(),
      ),

      dividerTheme: DividerThemeData(color: p.edge, thickness: 1),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.fieldFill,
        labelStyle: TextStyle(color: p.inkMuted),
        hintStyle: TextStyle(color: p.inkMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.edge),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.edge),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.danger, width: 1.5),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: p.ink,
        ),
        contentTextStyle: TextStyle(fontSize: 14.5, height: 1.4, color: p.inkMuted),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}
