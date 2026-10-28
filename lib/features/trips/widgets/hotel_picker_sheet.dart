import 'package:flutter/material.dart';
import '../../../core/widgets/key_row.dart';
import '../../../data/repositories/hotel_repository.dart';
import '../../../models/hotel.dart';
import 'venue_picker_sheet.dart';

/// Searchable single-hotel picker for a trip, live against the hotel
/// catalogue (HotelRepository.search()) — used by both Create Trip and
/// Trip Detail so a trip's hotel is always a normalized reference
/// (planned_venues.entity_id -> hotels_full.id), never a copy of hotel
/// data.
///
/// Destination-scoped (2026-10-28): only hotels in the trip's own country
/// are offered — filtered server-side on `country_code`, the catalogue's
/// stable code, never on a city or country name. [destinationLabel] is
/// display only ("🇫🇷 France"). [excludeIds] hides hotels already on the
/// trip.
Future<Hotel?> showHotelPickerSheet(
  BuildContext context, {
  required HotelRepository repo,
  required String countryCode,
  required String destinationLabel,
  Set<String> excludeIds = const {},
}) {
  return showTripVenuePicker<Hotel>(
    context,
    title: 'Add a stay',
    scopeLabel: 'Hotels in $destinationLabel',
    hintText: 'Search hotels, cities…',
    emptyMessage: 'No hotels in $destinationLabel in the catalogue yet.',
    // Sorted A→Z here: the shared catalogue search orders by name without
    // `ascending: true`, which postgrest-dart treats as descending.
    search: (query) async => (await repo.search(
      query,
      countryCode: countryCode,
    ))..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())),
    exclude: (hotel) => excludeIds.contains(hotel.id),
    describe: (hotel) => TripVenuePickerRow(
      title: hotel.name,
      subtitle: hotel.cityName,
      imageUrl: hotel.cardImageUrl,
      framing: hotel.cardFraming,
      awardRow: hotel.hasMichelinKeys
          ? KeyRow(count: hotel.michelinKeys!, size: 12)
          : null,
    ),
  );
}
