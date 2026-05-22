import 'package:flutter/material.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.light);

class AppTheme {
  AppTheme._();

  static bool get isDark => themeNotifier.value == ThemeMode.dark;

  // ─── Colors ────────────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF2563EB);
  static Color get primaryLight => isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF);
  static const Color primaryDark = Color(0xFF1D4ED8);
  static const Color accent = Color(0xFF3B82F6);
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  
  static Color get surface => isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFFFF);
  static Color get background => isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
  static Color get cardBg => isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFFFF);
  static Color get border => isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
  
  static Color get textPrimary => isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
  static Color get textSecondary => isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  static Color get textMuted => isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
  static Color get navBarBg => isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFFFF);

  // ─── Icon backgrounds ──────────────────────────────────────────────────────
  static Color get iconBg => isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF);

  // ─── Gradients ─────────────────────────────────────────────────────────────
  static LinearGradient get primaryGradient => const LinearGradient(
    colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get presetActiveGradient => const LinearGradient(
    colors: [Color(0xFF1D4ED8), Color(0xFF2563EB), Color(0xFF3B82F6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ─── Text Styles ───────────────────────────────────────────────────────────
  static TextStyle get headingLarge => TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: -0.5,
  );

  static TextStyle get headingMedium => TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  static TextStyle get bodyMedium => TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: textSecondary,
    height: 1.5,
  );

  static TextStyle get bodySmall => TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: textMuted,
  );

  static TextStyle get labelPrimary => TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: primary,
  );

  static TextStyle get labelSuccess => TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: success,
  );

  // ─── Card decoration ───────────────────────────────────────────────────────
  static BoxDecoration get cardDecoration => BoxDecoration(
    color: cardBg,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: border, width: 1),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  );

  static BoxDecoration get dashedBorderDecoration => BoxDecoration(
    color: primaryLight,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: const Color.fromRGBO(59, 130, 246, 0.4), width: 1.5),
  );

  // ─── MaterialApp ThemeData ─────────────────────────────────────────────────
  static ThemeData get themeData => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          brightness: isDark ? Brightness.dark : Brightness.light,
        ),
        scaffoldBackgroundColor: background,
        appBarTheme: AppBarTheme(
          backgroundColor: background,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: navBarBg,
          selectedItemColor: primary,
          unselectedItemColor: textMuted,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          unselectedLabelStyle: TextStyle(fontSize: 11),
          elevation: 8,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        cardTheme: CardThemeData(
          color: cardBg,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: border, width: 1),
          ),
        ),
      );
}