import 'package:flutter/material.dart';

/// Theme source: https://www.figma.com/make/krbFqdZPOQqYmuGSE8a4nM/Mobile-App-Theme-Design
/// Matches Padam Heart Care Centre dashboard: blue accent, white header, light background.
class AppTheme {
  // Primary (welcome banner, active nav, CTAs, logo accent)
  static const Color brandPrimary = Color(0xFF00B0EC);
  // Header/nav text and icons (inactive)
  static const Color brandCharcoal = Color(0xFF2F3137);
  // Page background
  static const Color brandSurface = Color(0xFFF8F6F4);
  // Semantic: positive metrics, success (e.g. "+2" badge)
  static const Color metricPositive = Color(0xFF2E7D32);
  // Semantic: negative metrics (e.g. "-3" badge)
  static const Color metricNegative = Color(0xFF00838F);
  // Quick action: Chat
  static const Color accentGreen = Color(0xFF43A047);
  // Quick action: Reports
  static const Color accentOrange = Color(0xFFFB8C00);

  static ThemeData get light {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: brandPrimary,
      onPrimary: Colors.white,
      secondary: brandCharcoal,
      onSecondary: Colors.white,
      error: Color(0xFFB3261E),
      onError: Colors.white,
      surface: Colors.white,
      onSurface: Color(0xFF1E1E1E),
      surfaceContainerHighest: Color(0xFFF5F5F5),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: brandCharcoal,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFEEEEEE)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDEDBD8)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDEDBD8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: brandPrimary, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: brandPrimary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: brandPrimary),
      ),
      // Outlined/white CTA on red (e.g. "View Progress")
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: brandCharcoal,
          side: const BorderSide(color: Colors.white),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        elevation: 0,
        indicatorColor: brandPrimary.withOpacity(0.15),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: brandPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 11,
              height: 1.0,
            );
          }
          return const TextStyle(
            color: brandCharcoal,
            fontWeight: FontWeight.w500,
            fontSize: 11,
            height: 1.0,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: brandPrimary, size: 24);
          }
          return const IconThemeData(color: brandCharcoal, size: 24);
        }),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: brandPrimary,
        unselectedItemColor: brandCharcoal,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }
}
