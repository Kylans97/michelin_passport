import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

/// Chasing Stars' redesigned type system (Step 1 foundation) — Cormorant
/// Garamond for editorial/display roles, Inter for functional interface
/// roles, per the brand brief. Purely additive: [AppTypography] (Playfair
/// Display + Inter) is untouched and keeps serving every current screen —
/// this is a SEPARATE, not-yet-adopted role set for screens to migrate
/// onto deliberately, one at a time. Kept as its own class rather than
/// changing [AppTypography] in place because the two use materially
/// different serif families under overlapping role names ("display",
/// "heading") — reusing the same names with a swapped font would silently
/// reskin every screen currently reading [AppTypography] the moment this
/// file's roles line up with those names, which is exactly the
/// unintentional-visual-change this foundation pass must avoid.
///
/// Every role here defaults to [AppColors.charcoal] (readable on the warm
/// light surfaces) — call `.copyWith(color: AppColors.textOnDark)` (or
/// [AppColors.secondaryOnDark]) for the deep-green canvas, mirroring how
/// [AppTypography] itself defaults to `textPrimary` and expects the same
/// override for on-dark use.
///
/// `google_fonts` (already a dependency, ^6.2.1) bundles Cormorant
/// Garamond — no new package, no local font files.
class CsTypography {
  CsTypography._();

  /// DISPLAY HERO — Cormorant Garamond, Semibold, 40 / 42.
  static TextStyle get displayHero => GoogleFonts.cormorantGaramond(
    color: AppColors.charcoal,
    fontSize: 40,
    fontWeight: FontWeight.w600,
    height: 42 / 40,
  );

  /// SCREEN TITLE — Cormorant Garamond, Semibold, 32 / 36.
  static TextStyle get screenTitle => GoogleFonts.cormorantGaramond(
    color: AppColors.charcoal,
    fontSize: 32,
    fontWeight: FontWeight.w600,
    height: 36 / 32,
  );

  /// SECTION TITLE — Cormorant Garamond, Semibold, 28 / 32.
  static TextStyle get sectionTitle => GoogleFonts.cormorantGaramond(
    color: AppColors.charcoal,
    fontSize: 28,
    fontWeight: FontWeight.w600,
    height: 32 / 28,
  );

  /// PLACE TITLE — Cormorant Garamond, Semibold, 22 / 26. A restaurant/
  /// hotel/event name at card or detail-hero scale.
  static TextStyle get placeTitle => GoogleFonts.cormorantGaramond(
    color: AppColors.charcoal,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    height: 26 / 22,
  );

  /// LARGE METRIC — Cormorant Garamond, Semibold, 28 / 32. A serif numeral
  /// treatment for scores/ratings/counts — same size as [sectionTitle] but
  /// a distinct semantic role (a metric, not a heading), matching
  /// [AppTypography.score]'s existing "numerals read as a considered
  /// detail" intent.
  static TextStyle get largeMetric => GoogleFonts.cormorantGaramond(
    color: AppColors.charcoal,
    fontSize: 28,
    fontWeight: FontWeight.w600,
    height: 32 / 28,
  );

  /// BODY — Inter, Regular, 16 / 24.
  static TextStyle get body => GoogleFonts.inter(
    color: AppColors.charcoal,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 24 / 16,
  );

  /// BODY MEDIUM — Inter, Medium, 16 / 24.
  static TextStyle get bodyMedium => GoogleFonts.inter(
    color: AppColors.charcoal,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 24 / 16,
  );

  /// METADATA — Inter, Regular, 14 / 20. Dates, counts, city/country
  /// lines — the same job [AppTypography.metadata] does today.
  static TextStyle get metadata => GoogleFonts.inter(
    color: AppColors.taupe,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 20 / 14,
  );

  /// NAVIGATION — Inter, Medium, 12 / 16. Bottom-nav labels (see the
  /// brief's future nav direction) and similar compact wayfinding text.
  static TextStyle get navigation => GoogleFonts.inter(
    color: AppColors.charcoal,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 16 / 12,
  );

  /// EYEBROW — Inter, Medium, 12, uppercase, letter-spacing ~1.8. Callers
  /// pass already-uppercased text (matching how [AppTypography.
  /// sectionHeading]'s call sites — 'INFORMATION', 'ACTIONS' — already
  /// work): [TextStyle] has no built-in text-transform, so this is a
  /// styling contract, not automatic casing.
  static TextStyle get eyebrow => GoogleFonts.inter(
    color: AppColors.taupe,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.8,
  );

  /// SMALL LABEL — Inter, Medium, 12 / 16. Tags, badges, compact chips —
  /// the same job [AppTypography.label] does today.
  static TextStyle get smallLabel => GoogleFonts.inter(
    color: AppColors.charcoal,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 16 / 12,
  );
}
