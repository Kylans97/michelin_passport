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
/// Destination-scoped (2026-10-28): only hotels in the trip's destinations
/// are offered — catalogue city ids for city legs, country codes for
/// whole-country legs, filtered server-side, never on a name. [destinationLabel] is
/// display only ("🇫🇷 France"). [excludeIds] hides hotels already on the
/// trip.
Future<Hotel?> showHotelPickerSheet(
  BuildContext context, {
  required HotelRepository repo,
  required List<String> countryCodes,
  List<String> cityIds = const [],
  required String destinationLabel,
  Set<String> excludeIds = const {},
}) {
  return showTripVenuePicker<Hotel>(
    context,
    title: 'Add a stay',
    scopeLabel: 'Hotels in $destinationLabel',
    hintText: 'Search hotels, cities…',
    emptyMessage: 'No hotels in $destinationLabel in the catalogue yet.',
    search: (query) => repo.searchInPlaces(
      query,
      countryCodes: countryCodes,
      cityIds: cityIds,
    ),
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
