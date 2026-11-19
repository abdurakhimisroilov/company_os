import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

class AppTheme {
  AppTheme._();

  /// System bars for the light theme (same values the app always used).
  static const SystemUiOverlayStyle lightOverlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark, // Android
    statusBarBrightness: Brightness.light, // iOS: dark icons, whatever the phone's own appearance
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  );

  /// System bars for the dark theme.
  static const SystemUiOverlayStyle darkOverlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: AppColors.surfaceDark,
    systemNavigationBarIconBrightness: Brightness.light,
  );

  /// Light theme. Only valid while `AppColors.isDark == false`.
  static ThemeData get light => _build(false);

  /// Dark theme. Only valid while `AppColors.isDark == true`.
  static ThemeData get dark => _build(true);

  // Both themes share one definition: every colour comes from the AppColors
  // tokens (which resolve against AppColors.isDark). Anything that exists
  // only for dark mode is passed as `null` in light mode so the light theme
  // stays exactly as it was.
  static ThemeData _build(bool dark) => ThemeData(
        useMaterial3: true,
        brightness: dark ? Brightness.dark : Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryBlue,
          brightness: dark ? Brightness.dark : Brightness.light,
          primary: dark ? AppColors.primaryBlueDark : AppColors.primaryBlue,
          onSurfaceVariant: dark ? AppColors.textSecondary : null,
          outline: dark ? AppColors.border : null,
          outlineVariant: dark ? AppColors.divider : null,
          surfaceTint: dark ? Colors.transparent : null,
          surfaceContainerLowest: dark ? AppColors.backgroundDark : null,
          surfaceContainerLow: dark ? AppColors.surfaceDark : null,
          surfaceContainer: dark ? const Color(0xFF1F2244) : null,
          surfaceContainerHigh: dark ? const Color(0xFF242850) : null,
          surfaceContainerHighest: dark ? const Color(0xFF2C3058) : null,
          secondary: AppColors.secondaryLavender,
          background: AppColors.background,
          surface: AppColors.cardBackground,
          error: AppColors.error,
          onPrimary: AppColors.textWhite,
          onSecondary: AppColors.textWhite,
          onBackground: AppColors.textPrimary,
          onSurface: AppColors.textPrimary,
          onError: AppColors.textWhite,
        ),
        textTheme: GoogleFonts.interTextTheme(
          dark ? ThemeData.dark().textTheme : null,
        ).copyWith(
          displayLarge: AppTextStyles.displayLarge,
          displayMedium: AppTextStyles.displayMedium,
          displaySmall: AppTextStyles.displaySmall,
          headlineLarge: AppTextStyles.headlineLarge,
          headlineMedium: AppTextStyles.headlineMedium,
          headlineSmall: AppTextStyles.headlineSmall,
          titleLarge: AppTextStyles.titleLarge,
          titleMedium: AppTextStyles.titleMedium,
          titleSmall: AppTextStyles.titleSmall,
          bodyLarge: AppTextStyles.bodyLarge,
          bodyMedium: AppTextStyles.bodyMedium,
          bodySmall: AppTextStyles.bodySmall,
          labelLarge: AppTextStyles.labelLarge,
          labelMedium: AppTextStyles.labelMedium,
          labelSmall: AppTextStyles.labelSmall,
        ),
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: AppTextStyles.titleLarge,
          iconTheme: IconThemeData(color: AppColors.textPrimary),
          surfaceTintColor: Colors.transparent,
          systemOverlayStyle: dark ? darkOverlayStyle : lightOverlayStyle,
        ),
        cardTheme: CardThemeData(
          color: AppColors.cardBackgroundTranslucent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: AppColors.cardBorder, width: 1),
          ),
          clipBehavior: Clip.antiAlias,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.cardBackground,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: AppColors.border, width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: AppColors.border, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide:
                BorderSide(color: AppColors.borderFocused, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.error, width: 1),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.error, width: 1.5),
          ),
          labelStyle: AppTextStyles.bodyMedium
              .copyWith(color: AppColors.textSecondary),
          hintStyle: AppTextStyles.bodyMedium
              .copyWith(color: AppColors.textTertiary),
          errorStyle:
              AppTextStyles.caption.copyWith(color: AppColors.error),
          prefixIconColor: AppColors.textSecondary,
          suffixIconColor: AppColors.textSecondary,
          floatingLabelBehavior: FloatingLabelBehavior.auto,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryBlue,
            foregroundColor: AppColors.textWhite,
            elevation: 0,
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: AppTextStyles.labelLarge
                .copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primaryBlue,
            side: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: AppTextStyles.labelLarge
                .copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primaryBlue,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: AppTextStyles.labelLarge
                .copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: AppColors.secondaryLavender,
          foregroundColor: AppColors.textWhite,
          elevation: 4,
          shape: StadiumBorder(),
        ),
        tabBarTheme: const TabBarThemeData(
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          // Default 16 px per side truncates labels such as «Созданные мной» on 3–4 tab bars.
          labelPadding: EdgeInsets.symmetric(horizontal: 4),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: AppColors.navBackground,
          selectedItemColor: AppColors.navSelected,
          unselectedItemColor: AppColors.navUnselected,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          showSelectedLabels: true,
          showUnselectedLabels: true,
        ),
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.background,
          selectedColor: AppColors.primaryBlue.withOpacity(0.1),
          labelStyle: AppTextStyles.labelMedium,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: AppColors.border),
          ),
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        ),
        dividerTheme: DividerThemeData(
          color: AppColors.divider,
          thickness: 1,
          space: 1,
        ),
        listTileTheme: ListTileThemeData(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        ),
        iconTheme: dark ? IconThemeData(color: AppColors.textPrimary) : null,
        bottomSheetTheme: dark
            ? BottomSheetThemeData(
                backgroundColor: AppColors.cardBackground,
                modalBackgroundColor: AppColors.cardBackground,
                surfaceTintColor: Colors.transparent,
              )
            : null,
        popupMenuTheme: dark
            ? PopupMenuThemeData(
                color: AppColors.cardBackground,
                surfaceTintColor: Colors.transparent,
                textStyle: AppTextStyles.bodyMedium,
              )
            : null,
        datePickerTheme: dark
            ? DatePickerThemeData(
                backgroundColor: AppColors.cardBackground,
                surfaceTintColor: Colors.transparent,
                headerBackgroundColor: AppColors.cardBackground,
                headerForegroundColor: AppColors.textPrimary,
                dividerColor: AppColors.divider,
              )
            : null,
        timePickerTheme: dark
            ? TimePickerThemeData(
                backgroundColor: AppColors.cardBackground,
              )
            : null,
        dialogTheme: DialogThemeData(
          backgroundColor: AppColors.cardBackground,
          surfaceTintColor: dark ? Colors.transparent : null,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 0,
          titleTextStyle: AppTextStyles.headlineSmall,
          contentTextStyle: AppTextStyles.bodyMedium,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: AppColors.snackBarBackground,
          contentTextStyle:
              AppTextStyles.bodyMedium.copyWith(color: AppColors.textWhite),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          behavior: SnackBarBehavior.floating,
        ),
        progressIndicatorTheme: ProgressIndicatorThemeData(
          color: AppColors.primaryBlue,
          linearTrackColor: AppColors.shimmerBase,
        ),
        switchTheme: SwitchThemeData(
          thumbColor: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.selected)) {
              return AppColors.primaryBlue;
            }
            return AppColors.textTertiary;
          }),
          trackColor: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.selected)) {
              return AppColors.primaryBlue.withOpacity(0.3);
            }
            return AppColors.border;
          }),
        ),
        extensions: const [],
      );
}
