import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary Blue
  static const Color primaryBlue = Color(0xFF6B8EF5);
  static const Color primaryBlueDark = Color(0xFF7B9FF8);

  // Secondary Lavender
  static const Color secondaryLavender = Color(0xFFA78BFA);
  static const Color secondaryLavenderLight = Color(0xFFC4B5FD);

  // Background
  static const Color background = Color(0xFFF0F2FF);
  static const Color backgroundDark = Color(0xFF0F1130);
  static const Color surfaceDark = Color(0xFF1A1D3A);

  // Card
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color cardBackgroundTranslucent = Color(0xD9FFFFFF); // 85% white
  static const Color cardBorder = Color(0x1A6B8EF5); // subtle blue border

  // Gradient
  static const Color gradientStart = Color(0xFF7B9FF8);
  static const Color gradientEnd = Color(0xFFA78BFA);
  static const Color gradientStartDark = Color(0xFF5B7EE5);
  static const Color gradientEndDark = Color(0xFF8B6BE8);

  // Text
  static const Color textPrimary = Color(0xFF1A1D3A);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textWhite70 = Color(0xB3FFFFFF);

  // Status
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFFD1FAE5);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFFEFF6FF);

  // Icon backgrounds (for nav menu items)
  static const Color iconBgBlue = Color(0xFFEEF2FF);
  static const Color iconBgPurple = Color(0xFFF5F3FF);
  static const Color iconBgGreen = Color(0xFFECFDF5);
  static const Color iconBgOrange = Color(0xFFFFF7ED);
  static const Color iconBgRed = Color(0xFFFEF2F2);
  static const Color iconBgTeal = Color(0xFFF0FDFA);

  // Bottom nav
  static const Color navSelected = Color(0xFF6B8EF5);
  static const Color navUnselected = Color(0xFF9CA3AF);
  static const Color navBackground = Color(0xFFFFFFFF);

  // Divider & border
  static const Color divider = Color(0xFFE5E7EB);
  static const Color border = Color(0xFFE5E7EB);
  static const Color borderFocused = Color(0xFF6B8EF5);

  // Shimmer
  static const Color shimmerBase = Color(0xFFE8ECFF);
  static const Color shimmerHighlight = Color(0xFFF8F9FF);

  // Shadow
  static const Color shadowBlue = Color(0x1A6B8EF5);
  static const Color shadowNeutral = Color(0x0D000000);

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

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFEEF2FF), Color(0xFFF5F3FF), background],
    stops: [0.0, 0.5, 1.0],
  );

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
