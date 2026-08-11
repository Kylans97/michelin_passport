import '../../models/venue_country.dart';

/// Whether [current] (the previously selected country) is still one of
/// [availableForNewYear] (the newly-fetched year's country options) — and,
/// if not, the clean reset FiftyBestRestaurantGuideScreen's/
/// FiftyBestHotelGuideScreen's year-change handler should apply instead of
/// leaving a stale selection that would silently produce a confusing
/// zero-result state (see the Guides Step 2C
/// brief's explicit "do not allow stale filters to create confusing
/// zero-result states when a clean reset is more appropriate").
///
/// Pure and testable without Supabase — mirrors guide_view_model.dart's
/// own reasoning (Step 2B): the screen that calls this on a year change
/// can't itself be widget-tested, but the reset-or-preserve decision it
/// makes can be.
VenueCountry? preserveCountrySelection(
  VenueCountry? current,
  List<VenueCountry> availableForNewYear,
) {
  if (current == null) return null;
  final stillValid = availableForNewYear.any(
    (country) => country.code == current.code,
  );
  return stillValid ? current : null;
}
