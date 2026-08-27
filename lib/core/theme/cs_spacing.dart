/// Mantelier's redesigned 4pt spacing grid (Step 1 foundation) — a
/// complete, self-contained token set matching the brand brief exactly.
///
/// Deliberately a NEW class rather than an extension of [AppSpacing]:
/// [AppSpacing.lg] is already 16 and is actively read by [DetailCard]'s
/// padding today, while the brief's own "lg" is 20 — the two can't share
/// one identifier without either breaking [DetailCard]'s current layout or
/// giving the brief's token the wrong value. Every [AppSpacing]/[AppRadii]
/// constant stays exactly as it is; existing screens are unaffected.
/// Screens migrate onto [CsSpacing] deliberately, in a later pass.
class CsSpacing {
  CsSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double base = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double section = 40;
  static const double hero = 48;

  /// Primary page horizontal padding.
  static const double pageHorizontal = 20;

  /// Standard card padding (all sides).
  static const double cardPadding = 20;
}

/// Mantelier's redesigned corner-radius scale (Step 1 foundation) — see
/// [CsSpacing]'s own doc comment for why this is a new class rather than
/// an extension of the existing [AppRadii] (which is actively read by
/// [DetailCard]/[PrimaryButton]/[VenueThumbnail] today, at different
/// values than the brief specifies for the equivalent role). The brief is
/// explicit that the redesigned interface should feel editorial, not
/// bubbly — cards default to [card] (18), not something rounder; pills
/// are reserved for controls that genuinely behave like pills (filter
/// chips, tags), not applied everywhere by default.
class CsRadius {
  CsRadius._();

  static const double small = 8;
  static const double medium = 12;
  static const double card = 18;
  static const double large = 24;
  static const double pill = 999;
}
