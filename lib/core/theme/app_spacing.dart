/// Shared spacing scale. New/redesigned screens should build from these
/// rather than ad-hoc magic numbers; existing screens keep their own
/// literal values for now (out of scope for this visual pass) but can
/// migrate onto this scale incrementally.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

/// Shared corner-radius scale, matching the brief's "soft rounded
/// cards/sheets" — nothing in the new design system uses a hard corner.
class AppRadii {
  AppRadii._();

  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 28;
  static const double pill = 999;
}
