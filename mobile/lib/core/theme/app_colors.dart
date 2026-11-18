import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  /// Current theme brightness. Set by the app root (see `main.dart`) from
  /// [ThemeController] before the tree is rebuilt. Theme-dependent tokens
  /// below are getters that resolve against this flag.
  static bool isDark = false;

  // Primary Blue
  static const Color primaryBlue = Color(0xFF6B8EF5);
  static const Color primaryBlueDark = Color(0xFF7B9FF8);

  // Secondary Lavender
  static const Color secondaryLavender = Color(0xFFA78BFA);
  static const Color secondaryLavenderLight = Color(0xFFC4B5FD);

  // Background
  static Color get background =>
      isDark ? backgroundDark : const Color(0xFFF0F2FF);
  static const Color backgroundDark = Color(0xFF0F1130);
  static const Color surfaceDark = Color(0xFF1A1D3A);

  // Card
  static Color get cardBackground =>
      isDark ? surfaceDark : const Color(0xFFFFFFFF);
  static Color get cardBackgroundTranslucent =>
      isDark ? const Color(0xD91A1D3A) : const Color(0xD9FFFFFF); // 85% white
  static Color get cardBorder =>
      isDark ? const Color(0x337B9FF8) : const Color(0x1A6B8EF5); // subtle blue border

  // Gradient
  static const Color gradientStart = Color(0xFF7B9FF8);
  static const Color gradientEnd = Color(0xFFA78BFA);
  static const Color gradientStartDark = Color(0xFF5B7EE5);
  static const Color gradientEndDark = Color(0xFF8B6BE8);

  // Text
  static Color get textPrimary =>
      isDark ? const Color(0xFFF1F3FF) : const Color(0xFF1A1D3A);
  static Color get textSecondary =>
      isDark ? const Color(0xFFA9B0CC) : const Color(0xFF6B7280);
  static Color get textTertiary =>
      isDark ? const Color(0xFF7780A3) : const Color(0xFF9CA3AF);
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textWhite70 = Color(0xB3FFFFFF);

  /// Snackbar surface (white text on top). Light value equals textPrimary.
  static Color get snackBarBackground =>
      isDark ? const Color(0xFF2C3058) : const Color(0xFF1A1D3A);

  // Status
  static const Color success = Color(0xFF10B981);
  static Color get successLight =>
      isDark ? const Color(0xFF123A36) : const Color(0xFFD1FAE5);
  static const Color warning = Color(0xFFF59E0B);
  static Color get warningLight =>
      isDark ? const Color(0xFF3D3018) : const Color(0xFFFEF3C7);
  static const Color error = Color(0xFFEF4444);
  static Color get errorLight =>
      isDark ? const Color(0xFF45212F) : const Color(0xFFFEE2E2);
  static const Color info = Color(0xFF3B82F6);
  static Color get infoLight =>
      isDark ? const Color(0xFF1A2B57) : const Color(0xFFEFF6FF);

  // Icon backgrounds (for nav menu items)
  static Color get iconBgBlue =>
      isDark ? const Color(0xFF242B58) : const Color(0xFFEEF2FF);
  static Color get iconBgPurple =>
      isDark ? const Color(0xFF2D2759) : const Color(0xFFF5F3FF);
  static Color get iconBgGreen =>
      isDark ? const Color(0xFF153A3B) : const Color(0xFFECFDF5);
  static Color get iconBgOrange =>
      isDark ? const Color(0xFF3D2D26) : const Color(0xFFFFF7ED);
  static Color get iconBgRed =>
      isDark ? const Color(0xFF41222F) : const Color(0xFFFEF2F2);
  static Color get iconBgTeal =>
      isDark ? const Color(0xFF143B42) : const Color(0xFFF0FDFA);

  // Bottom nav
  static Color get navSelected =>
      isDark ? primaryBlueDark : const Color(0xFF6B8EF5);
  static Color get navUnselected =>
      isDark ? const Color(0xFF7780A3) : const Color(0xFF9CA3AF);
  static Color get navBackground =>
      isDark ? surfaceDark : const Color(0xFFFFFFFF);

  // Divider & border
  static Color get divider =>
      isDark ? const Color(0xFF2C3058) : const Color(0xFFE5E7EB);
  static Color get border =>
      isDark ? const Color(0xFF2C3058) : const Color(0xFFE5E7EB);
  static Color get borderFocused =>
      isDark ? primaryBlueDark : const Color(0xFF6B8EF5);

  // Neutral greys (light values equal Material `Colors.grey` shades, so the
  // light theme is unchanged; dark values follow the navy palette).
  static Color get neutral50 =>
      isDark ? const Color(0xFF1F2244) : const Color(0xFFFAFAFA);
  static Color get neutral100 =>
      isDark ? const Color(0xFF242850) : const Color(0xFFF5F5F5);
  static Color get neutral200 =>
      isDark ? const Color(0xFF2C3058) : const Color(0xFFEEEEEE);
  static Color get neutral300 =>
      isDark ? const Color(0xFF3A3F6B) : const Color(0xFFE0E0E0);
  static Color get neutral400 =>
      isDark ? const Color(0xFF5A6088) : const Color(0xFFBDBDBD);
  static Color get neutral700 =>
      isDark ? const Color(0xFFA9B0CC) : const Color(0xFF616161);

  // Shimmer
  static Color get shimmerBase =>
      isDark ? const Color(0xFF1E2246) : const Color(0xFFE8ECFF);
  static Color get shimmerHighlight =>
      isDark ? const Color(0xFF2D3262) : const Color(0xFFF8F9FF);

  // Shadow
  static Color get shadowBlue =>
      isDark ? const Color(0x33000000) : const Color(0x1A6B8EF5);
  static Color get shadowNeutral =>
      isDark ? const Color(0x40000000) : const Color(0x0D000000);

  // Gradient LinearGradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [gradientStart, gradientEnd],
  );

  static const LinearGradient primaryGradientDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [gradientStartDark, gradientEndDark],
  );

  static const LinearGradient _backgroundGradientLight = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFEEF2FF), Color(0xFFF5F3FF), Color(0xFFF0F2FF)],
    stops: [0.0, 0.5, 1.0],
  );

  static const LinearGradient _backgroundGradientDark = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF171A40), Color(0xFF141637), backgroundDark],
    stops: [0.0, 0.5, 1.0],
  );

  static LinearGradient get backgroundGradient =>
      isDark ? _backgroundGradientDark : _backgroundGradientLight;

  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF10B981), Color(0xFF059669)],
  );

  static const LinearGradient warningGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
  );

  static const LinearGradient errorGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
  );
}
