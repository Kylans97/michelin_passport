import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import 'app_typography.dart';
import 'cs_typography.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get mantelier {
    final base = ThemeData.light(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      primaryColor: AppColors.gold,
      colorScheme: const ColorScheme.light(
        primary: AppColors.gold,
        onPrimary: AppColors.textOnDark,
        secondary: AppColors.goldLight,
        onSecondary: AppColors.textOnDark,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        error: AppColors.error,
        onError: AppColors.textOnDark,
        surfaceContainerHighest: AppColors.surfaceElevated,
        outline: AppColors.cardBorder,
      ),
      textTheme: _buildTextTheme(base.textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: AppTypography.editorialHeading,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      // Bottom Navigation UI Consistency Step 1A: dark-green surface,
      // ivory selected / secondaryOnDark unselected — physical-device
      // direction change from Step 1's ivory surface (see app.dart's own
      // comment for the full reasoning). Never gold (gold stays reserved
      // for Michelin stars/Keys). No Material indicator pill —
      // indicatorColor: transparent means selection reads through icon/
      // label tone alone, not a filled background. app.dart's own
      // NavigationBar construction fully specifies these same properties
      // inline (it always has, for backgroundColor/height), so this theme
      // block is a consistent fallback/single source of truth rather than
      // the "live" styling path — NavigationBar is used nowhere else in
      // this app, so correcting it here carries no risk to other screens.
      //
      // Green Token Consistency Migration: AppColors.deepGreen, the app's
      // canonical primary brand dark surface — not forestGreen, which is
      // reserved for secondary elevated panels (see app_colors.dart's own
      // role documentation).
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.deepGreen,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return CsTypography.navigation.copyWith(
            color: selected ? AppColors.ivory : AppColors.secondaryOnDark,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? AppColors.ivory : AppColors.secondaryOnDark,
            size: 22,
          );
        }),
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.cardBorder, width: 0.5),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        hintStyle: GoogleFonts.inter(
          color: AppColors.textSecondary,
          fontSize: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.cardBorder, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        prefixIconColor: AppColors.textSecondary,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 0.5,
        space: 0,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.goldMuted,
        side: const BorderSide(color: AppColors.cardBorder, width: 0.5),
        labelStyle: GoogleFonts.inter(
          color: AppColors.textSecondary,
          fontSize: 13,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
    );
  }

  static TextTheme _buildTextTheme(TextTheme base) {
    return base.copyWith(
      displayLarge: AppTypography.display.copyWith(fontSize: 48),
      displayMedium: AppTypography.display.copyWith(fontSize: 36),
      headlineLarge: AppTypography.display,
      headlineMedium: AppTypography.editorialHeading.copyWith(fontSize: 24),
      headlineSmall: AppTypography.editorialHeading,
      titleLarge: GoogleFonts.inter(
        color: AppColors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
      titleMedium: GoogleFonts.inter(
        color: AppColors.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      titleSmall: AppTypography.sectionHeading,
      bodyLarge: AppTypography.body.copyWith(fontSize: 16, height: 1.6),
      bodyMedium: AppTypography.body,
      bodySmall: AppTypography.metadata,
      labelLarge: GoogleFonts.inter(
        color: AppColors.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
      labelMedium: AppTypography.label,
      labelSmall: AppTypography.label.copyWith(fontSize: 10.5),
    );
  }
}
