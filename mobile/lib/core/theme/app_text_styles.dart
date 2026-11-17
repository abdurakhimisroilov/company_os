import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  static TextStyle get _base => GoogleFonts.inter(
        color: AppColors.textPrimary,
        fontFeatures: [const FontFeature.tabularFigures()],
      );

  // ─── Display ───────────────────────────────────────────────────────────────
  /// 48sp ExtraBold — huge hero numbers
  static TextStyle get displayLarge => _base.copyWith(
        fontSize: 48,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.5,
        height: 1.1,
      );

  /// 40sp Bold — large hero numbers
  static TextStyle get displayMedium => _base.copyWith(
        fontSize: 40,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.0,
        height: 1.2,
      );

  /// 34sp Bold
  static TextStyle get displaySmall => _base.copyWith(
        fontSize: 34,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        height: 1.2,
      );

  // ─── Headline ──────────────────────────────────────────────────────────────
  /// 28sp Bold
  static TextStyle get headlineLarge => _base.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        height: 1.3,
      );

  /// 24sp SemiBold
  static TextStyle get headlineMedium => _base.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        height: 1.3,
      );

  /// 20sp SemiBold
  static TextStyle get headlineSmall => _base.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        height: 1.4,
      );

  // Convenient Aliases
  static TextStyle get h1 => headlineLarge;
  static TextStyle get h2 => headlineMedium;
  static TextStyle get h3 => headlineSmall;

  // ─── Title ─────────────────────────────────────────────────────────────────
  /// 18sp SemiBold
  static TextStyle get titleLarge => _base.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        height: 1.4,
      );

  /// 16sp SemiBold
  static TextStyle get titleMedium => _base.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        height: 1.5,
      );

  /// 14sp Medium
  static TextStyle get titleSmall => _base.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        height: 1.5,
      );

  // ─── Body ──────────────────────────────────────────────────────────────────
  /// 16sp Regular
  static TextStyle get bodyLarge => _base.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.15,
        height: 1.6,
      );

  /// 14sp Regular
  static TextStyle get bodyMedium => _base.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.25,
        height: 1.6,
      );

  /// 12sp Regular
  static TextStyle get bodySmall => _base.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.4,
        height: 1.6,
      );

  // ─── Label ─────────────────────────────────────────────────────────────────
  /// 14sp Medium — button text
  static TextStyle get labelLarge => _base.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        height: 1.4,
      );

  /// 12sp Medium
  static TextStyle get labelMedium => _base.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        height: 1.4,
      );

  /// 11sp Medium
  static TextStyle get labelSmall => _base.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        height: 1.4,
      );

  // ─── Caption ───────────────────────────────────────────────────────────────
  /// 11sp Regular — timestamps, hints
  static TextStyle get caption => _base.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.4,
        height: 1.4,
        color: AppColors.textSecondary,
      );

  /// 10sp Regular
  static TextStyle get captionSmall => _base.copyWith(
        fontSize: 10,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.4,
        height: 1.4,
        color: AppColors.textTertiary,
      );

  // ─── Monetary ──────────────────────────────────────────────────────────────
  /// Large money amount: 32sp ExtraBold
  static TextStyle get moneyLarge => _base.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        height: 1.2,
        color: AppColors.textWhite,
      );

  /// Medium money: 22sp Bold
  static TextStyle get moneyMedium => _base.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        height: 1.2,
      );

  /// Small money: 16sp SemiBold
  static TextStyle get moneySmall => _base.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        height: 1.3,
      );

  // ─── Percentage change ─────────────────────────────────────────────────────
  static TextStyle get percentagePositive => _base.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.success,
        letterSpacing: 0,
      );

  static TextStyle get percentageNegative => _base.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.error,
        letterSpacing: 0,
      );

  // ─── White variants (for cards with gradient bg) ───────────────────────────
  static TextStyle get displayLargeWhite =>
      displayLarge.copyWith(color: AppColors.textWhite);
  static TextStyle get headlineLargeWhite =>
      headlineLarge.copyWith(color: AppColors.textWhite);
  static TextStyle get titleMediumWhite =>
      titleMedium.copyWith(color: AppColors.textWhite70);
  static TextStyle get bodyLargeWhite =>
      bodyLarge.copyWith(color: AppColors.textWhite70);
  static TextStyle get labelMediumWhite =>
      labelMedium.copyWith(color: AppColors.textWhite70);
}
