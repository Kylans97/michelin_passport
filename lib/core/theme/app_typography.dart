import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

/// Chasing Stars' typography, expressed as roles rather than one-off,
/// screen-specific `GoogleFonts.xxx(...)` calls scattered across widgets.
/// Editorial serif (Playfair Display) carries venue identity and premium
/// moments; clean sans (Inter) carries functional UI, metadata and
/// ratings — per the brand brief. Every style here defaults to
/// [AppColors.textPrimary]; call `.copyWith(color: ...)` for
/// [AppColors.textOnDark] hero contexts or accent colors.
class AppTypography {
  AppTypography._();

  /// The largest role — a venue name on a hero image.
  static TextStyle get display => GoogleFonts.playfairDisplay(
    color: AppColors.textPrimary,
    fontSize: 30,
    fontWeight: FontWeight.w700,
    height: 1.15,
  );

  /// A prominent serif heading with editorial warmth — screen headings,
  /// premium section intros (e.g. Award History's section titles).
  static TextStyle get editorialHeading => GoogleFonts.playfairDisplay(
    color: AppColors.textPrimary,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  /// A tight, functional sans-serif section label — small caps eyebrow
  /// text ("INFORMATION", "ACTIONS"). Compact, used where density matters
  /// more than editorial warmth.
  static TextStyle get sectionHeading => GoogleFonts.inter(
    color: AppColors.textSecondary,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.5,
  );

  /// Paragraph / notes text.
  static TextStyle get body => GoogleFonts.inter(
    color: AppColors.textPrimary,
    fontSize: 14.5,
    fontWeight: FontWeight.w400,
    height: 1.55,
  );

  /// Small, muted supporting text — dates, counts, city/country lines.
  static TextStyle get metadata => GoogleFonts.inter(
    color: AppColors.textSecondary,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  /// The smallest role — tags, badges, compact uppercase chips.
  static TextStyle get label => GoogleFonts.inter(
    color: AppColors.textSecondary,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.6,
  );

  /// A distinctive numeral treatment for scores/ratings (e.g. inside
  /// [CircularScoreBadge]) — serif numerals read as a considered, premium
  /// detail rather than a generic app statistic.
  static TextStyle get score => GoogleFonts.playfairDisplay(
    color: AppColors.textPrimary,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    height: 1.0,
  );
}
