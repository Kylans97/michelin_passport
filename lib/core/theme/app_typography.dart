import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'cs_fonts.dart';

/// Mantelier's older role set, still read by a handful of screens next to
/// [CsTypography]. Same two families as [CsTypography] (Spectral for venue
/// identity and premium moments, Hanken Grotesk for functional UI,
/// metadata and ratings — see [CsFonts]); it used Playfair Display + Inter
/// until 2026-11-19. Every style here defaults to [AppColors.textPrimary];
/// call `.copyWith(color: ...)` for [AppColors.textOnDark] hero contexts or
/// accent colors.
class AppTypography {
  AppTypography._();

  /// The largest role — a venue name on a hero image.
  static TextStyle get display => CsFonts.serif(
    color: AppColors.textPrimary,
    fontSize: 28,
    fontWeight: FontWeight.w300,
    height: 1.15,
  );

  /// A prominent serif heading with editorial warmth — screen headings,
  /// premium section intros (e.g. Award History's section titles).
  static TextStyle get editorialHeading => CsFonts.serif(
    color: AppColors.textPrimary,
    fontSize: 20,
    fontWeight: FontWeight.w500,
    height: 1.25,
  );

  /// A tight, functional sans-serif section label — small caps eyebrow
  /// text ("INFORMATION", "ACTIONS"). Compact, used where density matters
  /// more than editorial warmth.
  static TextStyle get sectionHeading => CsFonts.sans(
    color: AppColors.textSecondary,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 12 * 0.12,
  );

  /// Paragraph / notes text.
  static TextStyle get body => CsFonts.sans(
    color: AppColors.textPrimary,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.55,
  );

  /// Small, muted supporting text — dates, counts, city/country lines.
  static TextStyle get metadata => CsFonts.sans(
    color: AppColors.textSecondary,
    fontSize: 13.5,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  /// The smallest role — tags, badges, compact uppercase chips.
  static TextStyle get label => CsFonts.sans(
    color: AppColors.textSecondary,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.6,
  );

  /// A distinctive numeral treatment for scores/ratings (e.g. inside
  /// [CircularScoreBadge]) — serif numerals read as a considered, premium
  /// detail rather than a generic app statistic.
  static TextStyle get score => CsFonts.serif(
    color: AppColors.textPrimary,
    fontSize: 22,
    fontWeight: FontWeight.w400,
    height: 1.0,
  );
}
