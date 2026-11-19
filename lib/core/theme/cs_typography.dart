import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'cs_fonts.dart';

/// Mantelier's type system — Spectral for editorial/display roles and
/// reading text, Hanken Grotesk for functional interface roles (the
/// "Salon" direction, chosen by the product owner on 2026-11-19; it
/// replaced Cormorant Garamond + Inter). Both families are bundled — see
/// [CsFonts].
///
/// Sizes are not the old ones carried over. Spectral is ~12% wider per
/// point than Cormorant Garamond but has a much larger x-height (45% of
/// the body vs. 38.6%), so serif roles sit ~9% smaller and still read
/// larger. Hanken Grotesk is ~6% narrower per point than Inter with a
/// smaller x-height (49% vs. 55%), so small interface roles sit half a
/// point larger and still take less width. Measured on the fonts' own
/// advance widths over the production catalogue's names, 2026-11-18.
///
/// Every role here defaults to [AppColors.charcoal] (readable on the warm
/// light surfaces) — call `.copyWith(color: AppColors.textOnDark)` (or
/// [AppColors.secondaryOnDark]) for the deep-green canvas, mirroring how
/// [AppTypography] itself defaults to `textPrimary` and expects the same
/// override for on-dark use.
///
/// Spectral's default figures are already lining (same height, aligned to
/// the capitals), so no role needs the `lnum` feature Cormorant did.
class CsTypography {
  CsTypography._();

  /// DISPLAY HERO — Spectral Light, 36 / 40.
  static TextStyle get displayHero => CsFonts.serif(
    color: AppColors.charcoal,
    fontSize: 36,
    fontWeight: FontWeight.w300,
    height: 40 / 36,
  );

  /// SCREEN TITLE — Spectral Light, 30 / 34.
  static TextStyle get screenTitle => CsFonts.serif(
    color: AppColors.charcoal,
    fontSize: 30,
    fontWeight: FontWeight.w300,
    height: 34 / 30,
  );

  /// SECTION TITLE — Spectral Regular, 26 / 30.
  static TextStyle get sectionTitle => CsFonts.serif(
    color: AppColors.charcoal,
    fontSize: 26,
    fontWeight: FontWeight.w400,
    height: 30 / 26,
  );

  /// PLACE TITLE — Spectral Regular, 20 / 26. A restaurant/hotel/event
  /// name at card or detail-hero scale.
  static TextStyle get placeTitle => CsFonts.serif(
    color: AppColors.charcoal,
    fontSize: 20,
    fontWeight: FontWeight.w400,
    height: 26 / 20,
  );

  /// LARGE METRIC — Spectral Light, 27 / 30. A serif numeral treatment for
  /// scores/ratings/counts — a distinct semantic role from [sectionTitle]
  /// (a metric, not a heading), matching [AppTypography.score]'s "numerals
  /// read as a considered detail" intent.
  static TextStyle get largeMetric => CsFonts.serif(
    color: AppColors.charcoal,
    fontSize: 27,
    fontWeight: FontWeight.w300,
    height: 30 / 27,
  );

  /// BODY — Hanken Grotesk, Regular, 16 / 24.
  static TextStyle get body => CsFonts.sans(
    color: AppColors.charcoal,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 24 / 16,
  );

  /// BODY MEDIUM — Hanken Grotesk, Medium, 16 / 24.
  static TextStyle get bodyMedium => CsFonts.sans(
    color: AppColors.charcoal,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 24 / 16,
  );

  /// READING — Spectral, Regular, 16.5 / 26. Running text someone reads
  /// rather than scans: a venue's about text, an event's description, a
  /// news article's body. Kept separate from [body], which stays the sans
  /// interface role.
  static TextStyle get reading => CsFonts.serif(
    color: AppColors.charcoal,
    fontSize: 16.5,
    fontWeight: FontWeight.w400,
    height: 26 / 16.5,
  );

  /// METADATA — Hanken Grotesk, Regular, 14.5 / 21. Dates, counts,
  /// city/country lines — the same job [AppTypography.metadata] does.
  static TextStyle get metadata => CsFonts.sans(
    color: AppColors.taupe,
    fontSize: 14.5,
    fontWeight: FontWeight.w400,
    height: 21 / 14.5,
  );

  /// NAVIGATION — Hanken Grotesk, Medium, 12.5 / 16. Bottom-nav labels and
  /// similar compact wayfinding text.
  static TextStyle get navigation => CsFonts.sans(
    color: AppColors.charcoal,
    fontSize: 12.5,
    fontWeight: FontWeight.w500,
    height: 16 / 12.5,
  );

  /// EYEBROW — Hanken Grotesk, SemiBold, 12, uppercase, letter-spacing
  /// 0.12em. Callers pass already-uppercased text (matching how
  /// [AppTypography.sectionHeading]'s call sites — 'INFORMATION',
  /// 'ACTIONS' — already work): [TextStyle] has no built-in
  /// text-transform, so this is a styling contract, not automatic casing.
  static TextStyle get eyebrow => CsFonts.sans(
    color: AppColors.taupe,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 12 * 0.12,
  );

  /// SMALL LABEL — Hanken Grotesk, Medium, 12.5 / 16. Tags, badges,
  /// compact chips — the same job [AppTypography.label] does.
  static TextStyle get smallLabel => CsFonts.sans(
    color: AppColors.charcoal,
    fontSize: 12.5,
    fontWeight: FontWeight.w500,
    height: 16 / 12.5,
  );

  /// STAMP STAT VALUE — Spectral Light, 28, no fixed line height (the
  /// Passport stamp-page stats row's own three big serif numerals —
  /// Places/Countries/Stars).
  static TextStyle get stampStatValue => CsFonts.serif(
    color: AppColors.charcoal,
    fontSize: 28,
    fontWeight: FontWeight.w300,
  );

  // ── Editorial roles ─────────────────────────────────────────────────
  // Factory methods (a size parameter with a sensible default), not fixed
  // getters like every role above, so one call site can ask for "a display
  // line, but at this screen's own size" instead of every screen needing
  // its own bespoke TextStyle. Defaults to [AppColors.charcoal]/ink, same
  // as every role above — override with `.copyWith(color: ...)` for
  // text-on-green exactly like the rest of this class.

  /// EDITORIAL DISPLAY — Spectral, Light (or Italic), 42–51, line-height
  /// 1.0. Screen titles ("Tonight", "Events", "Passport", "Community").
  static TextStyle editorialDisplay({double size = 44, bool italic = true}) =>
      CsFonts.serif(
        color: AppColors.charcoal,
        fontSize: size,
        fontWeight: FontWeight.w300,
        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
        height: 1.0,
      );

  /// EDITORIAL TITLE — Spectral, Regular (or Italic), 20–38. Event/venue
  /// names at whatever scale the surrounding layout calls for (a list
  /// row vs. an InvitationCard's own large title).
  static TextStyle editorialTitle({double size = 26, bool italic = false}) =>
      CsFonts.serif(
        color: AppColors.charcoal,
        fontSize: size,
        fontWeight: FontWeight.w400,
        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
        height: 1.2,
      );

  /// EDITORIAL LEAD — Spectral, Italic, 15–21. A quote-like lead line or
  /// tagline ("Culinary happenings worth planning a trip around.").
  static TextStyle editorialLead({double size = 17}) => CsFonts.serif(
    color: AppColors.taupe,
    fontSize: size,
    fontStyle: FontStyle.italic,
    fontWeight: FontWeight.w400,
    height: 1.45,
  );

  /// EDITORIAL BODY — Hanken Grotesk, Regular, 14.5 / 1.5. The compact
  /// body copy size of the editorial screens — distinct from [body]
  /// (16/1.5).
  static TextStyle get editorialBody => CsFonts.sans(
    color: AppColors.charcoal,
    fontSize: 14.5,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  /// EDITORIAL LABEL — Hanken Grotesk, Medium, 11.5, uppercase,
  /// letter-spacing ~0.12em (computed per [size]). Callers pass
  /// already-uppercased text, same contract as [eyebrow].
  static TextStyle editorialLabel({double size = 11.5, double em = 0.12}) =>
      CsFonts.sans(
        color: AppColors.taupe,
        fontSize: size,
        fontWeight: FontWeight.w500,
        letterSpacing: size * em,
      );
}
