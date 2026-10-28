import 'package:flutter/material.dart';
import '../../../core/widgets/star_row.dart';
import '../../../data/repositories/restaurant_repository.dart';
import '../../../models/restaurant.dart';
import 'venue_picker_sheet.dart';

/// Searchable single-restaurant picker for a trip, live against the
/// restaurant catalogue (RestaurantRepository.search()). Adding several
/// restaurants means opening this once per restaurant — the single-select
/// sheet pattern used everywhere else in this app; [excludeIds] hides
/// restaurants already on the trip so the same one can't be picked twice.
/// Used by both Create Trip and Trip Detail so a trip's restaurants are
/// always normalized references (planned_venues.entity_id ->
/// restaurants_full.id), never copied data.
///
/// Destination-scoped (2026-10-28): only restaurants in the trip's own
/// country are offered — filtered server-side on `country_code`, never on
/// a name, and never on `property_name`. [destinationLabel] is display
/// only.
Future<Restaurant?> showRestaurantPickerSheet(
  BuildContext context, {
  required RestaurantRepository repo,
  required String countryCode,
  required String destinationLabel,
  Set<String> excludeIds = const {},
}) {
  return showTripVenuePicker<Restaurant>(
    context,
    title: 'Add a restaurant',
    scopeLabel: 'Restaurants in $destinationLabel',
    hintText: 'Search restaurants, cities…',
    emptyMessage: 'No restaurants in $destinationLabel in the catalogue yet.',
    // Sorted A→Z here: the shared catalogue search orders by name without
    // `ascending: true`, which postgrest-dart treats as descending.
    search: (query) async => (await repo.search(
      query,
      countryCode: countryCode,
    ))..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())),
    exclude: (restaurant) => excludeIds.contains(restaurant.id),
    describe: (restaurant) => TripVenuePickerRow(
      title: restaurant.name,
      subtitle: restaurant.cityName,
      imageUrl: restaurant.cardImageUrl,
      framing: restaurant.cardFraming,
      awardRow: restaurant.hasMichelinStar
          ? StarRow(count: restaurant.michelinStars!, size: 12)
          : null,
    ),
  );
}
