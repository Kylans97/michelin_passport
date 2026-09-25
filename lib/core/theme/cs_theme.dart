import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import 'cs_spacing.dart';
import 'cs_typography.dart';

/// A complete [ThemeData] built from the redesigned Mantelier tokens —
/// PREPARED, NOT APPLIED. `app.dart` still constructs `MaterialApp(theme:
/// AppTheme.mantelier)`; nothing here is wired in. Swapping it in is a
/// deliberate Step 2+ decision (see the Step 1 report's "proposed Step 2"),
/// made only once individual screens are actually ready to sit on a
/// deep-green canvas — flipping this globally today would restyle every
/// screen still built for [AppTheme.mantelier] in one shot, exactly the
/// "unintentional visual change" this foundation pass must avoid.
class CsTheme {
  CsTheme._();

  static ThemeData get value {
    final base = ThemeData.light(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.deepGreen,
      primaryColor: AppColors.deepGreen,
      // primary = deepGreen (the brief's actual primary identity color —
      // "dark forest green is the PRIMARY Mantelier canvas"), not
      // mutedBrass: Material widgets reach for `colorScheme.primary` by
      // default (FilledButton, active states, ...), and the brief is
      // explicit that buttons/large fills must never be brass ("Do not
      // use: gold buttons"). mutedBrass sits under `secondary`, its
      // accent role — onSecondary is deepGreen text, which is 4.16:1 on
      // mutedBrass (AA for large/bold text only, not normal-size body
      // text; see the Step 1 report's contrast audit).
      colorScheme: const ColorScheme.dark(
        primary: AppColors.deepGreen,
        onPrimary: AppColors.textOnDark,
        secondary: AppColors.mutedBrass,
        onSecondary: AppColors.deepGreen,
        surface: AppColors.ivory,
        onSurface: AppColors.charcoal,
        error: AppColors.error,
        onError: AppColors.textOnDark,
        surfaceContainerHighest: AppColors.warmWhite,
        outline: AppColors.subtleBorderLight,
      ),
      textTheme: _buildTextTheme(base.textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.deepGreen,
        foregroundColor: AppColors.textOnDark,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: CsTypography.screenTitle.copyWith(
          color: AppColors.textOnDark,
          fontSize: 20,
        ),
        iconTheme: const IconThemeData(color: AppColors.textOnDark),
      ),
      cardTheme: CardThemeData(
        color: AppColors.ivory,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CsRadius.card),
          side: const BorderSide(
            color: AppColors.subtleBorderLight,
            width: 0.5,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.ivory,
        hintStyle: CsTypography.body.copyWith(color: AppColors.taupe),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CsRadius.medium),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CsRadius.medium),
          borderSide: const BorderSide(
            color: AppColors.subtleBorderLight,
            width: 0.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CsRadius.medium),
          borderSide: const BorderSide(color: AppColors.mutedBrass, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: CsSpacing.base,
          vertical: CsSpacing.md,
        ),
        prefixIconColor: AppColors.taupe,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.subtleBorderLight,
        thickness: 0.5,
        space: 0,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.ivory,
        selectedColor: AppColors.deepGreen,
        side: const BorderSide(color: AppColors.subtleBorderLight, width: 0.5),
        labelStyle: CsTypography.smallLabel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CsRadius.pill),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: CsSpacing.md,
          vertical: CsSpacing.xs,
        ),
      ),
    );
  }

  static TextTheme _buildTextTheme(TextTheme base) {
    return base.copyWith(
      displayLarge: CsTypography.displayHero,
      displayMedium: CsTypography.screenTitle,
      headlineLarge: CsTypography.screenTitle,
      headlineMedium: CsTypography.sectionTitle,
      headlineSmall: CsTypography.placeTitle,
      titleLarge: CsTypography.placeTitle,
      titleMedium: CsTypography.bodyMedium,
      titleSmall: CsTypography.eyebrow,
      bodyLarge: CsTypography.body,
      bodyMedium: CsTypography.body,
      bodySmall: CsTypography.metadata,
      labelLarge: CsTypography.bodyMedium,
      labelMedium: CsTypography.navigation,
      labelSmall: CsTypography.smallLabel,
    );
  }
}

/// Bottom navigation tokens — kept in sync with whatever `FloatingNavBar`
/// (`lib/core/widgets/floating_nav_bar.dart`, wired in from app.dart)
/// actually implements; nothing in this file applies these automatically,
/// so treat this as a named reference to correct alongside that widget,
/// not an independent source of truth. Current as of the floating-pill
/// redesign: the bar is no longer Material's docked `NavigationBar` on a
/// deepGreen primary surface — it's a pill floating ON the deepGreen
/// canvas, so its own background is forestGreen (a panel token, see
/// app_colors.dart's own role documentation), not deepGreen.
class CsNavStyle {
  CsNavStyle._();

  static const double iconSize = 22;
  static const double labelFontSize = 12;

  /// No filled selection capsule — selection reads through icon/label
  /// TONE alone: [selectedColor] vs. [unselectedColor], never a filled
  /// background.
  static const Color selectedColor = AppColors.ivory;
  static const Color unselectedColor = AppColors.secondaryOnDark;
  static const Color background = AppColors.forestGreen;
}
