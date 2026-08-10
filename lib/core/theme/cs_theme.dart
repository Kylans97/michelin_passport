import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import 'cs_spacing.dart';
import 'cs_typography.dart';

/// A complete [ThemeData] built from the redesigned Chasing Stars tokens —
/// PREPARED, NOT APPLIED. `app.dart` still constructs `MaterialApp(theme:
/// AppTheme.chasingStars)`; nothing here is wired in. Swapping it in is a
/// deliberate Step 2+ decision (see the Step 1 report's "proposed Step 2"),
/// made only once individual screens are actually ready to sit on a
/// deep-green canvas — flipping this globally today would restyle every
/// screen still built for [AppTheme.chasingStars] in one shot, exactly the
/// "unintentional visual change" this foundation pass must avoid.
class CsTheme {
  CsTheme._();

  static ThemeData get value {
    final base = ThemeData.light(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.deepGreen,
      primaryColor: AppColors.deepGreen,
      // primary = deepGreen (the brief's actual primary identity color —
      // "dark forest green is the PRIMARY Chasing Stars canvas"), not
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

/// Documented future direction for bottom navigation styling — TOKENS
/// ONLY, not an applied [NavigationBarThemeData]. The brief is explicit
/// that the actual navigation implementation (`_MainNavigation` in
/// app.dart) must not be touched in this step; these values exist so Step
/// 2+ (once navigation architecture itself is revisited alongside a future
/// Home) has the intended look already agreed rather than re-derived.
class CsNavStyle {
  CsNavStyle._();

  static const double iconSize = 24;
  static const double labelFontSize = 12;

  /// No filled/beige selection capsule — the brief's explicit "understated,
  /// no heavy background" direction. Selected vs. unselected reads through
  /// icon/label TONE alone: [selectedColor] vs. [unselectedColor].
  static const Color selectedColor = AppColors.mutedBrass;
  static const Color unselectedColor = AppColors.secondaryOnDark;
  static const Color background = AppColors.deepGreen;
}
