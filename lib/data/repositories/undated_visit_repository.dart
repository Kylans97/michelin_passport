import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/hotel.dart';
import '../../models/passport_venue.dart';
import '../../models/restaurant.dart';
import '../../models/undated_visit.dart';
import '../../models/venue_country.dart';
import '../../models/visit.dart';
import 'fetch_all_rows.dart';
import 'hotel_repository.dart';
import 'restaurant_repository.dart';

const _undatedColumns =
    'id, user_id, entity_type, entity_id, visibility, stars_at_visit, '
    'keys_at_visit, created_at';

/// A restaurant or hotel offered in "Where in {country} have you been?":
/// only what the tick list shows, not a full catalogue row.
class CountryVenueChoice {
  final String id;
  final bool isHotel;
  final String name;
  final String city;
  final int? stars;
  final int? keys;

  const CountryVenueChoice({
    required this.id,
    required this.isHotel,
    required this.name,
    required this.city,
    required this.stars,
    required this.keys,
  });

  String get entityType => isHotel ? 'hotel' : 'restaurant';
}

/// Visits without a date (20261101700000_add_undated_visits.sql): adding
/// them from My Map, reading them back as dashed pins, and turning one into
/// a dated visit, which is when its Passport stamp is earned.
///
/// Every read goes through RLS like `visits`: the member's own rows, and a
/// friend's rows marked `friends`.
class UndatedVisitRepository {
  UndatedVisitRepository(this._client);

  final SupabaseClient _client;

  /// [userId]'s undated visits with their venues, newest first. Throws
  /// when the table isn't there yet (before the migration), so the caller
  /// can leave the feature out rather than show an empty map.
  Future<List<UndatedVenue>> loadUndatedVenues(String userId) async {
    final rows = await _client
        .from('undated_visits')
        .select(_undatedColumns)
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    final visits = [
      for (final row in (rows as List).cast<Map<String, dynamic>>())
        UndatedVisit.fromJson(row),
    ];
    if (visits.isEmpty) return [];

    final restaurantIds = {
      for (final v in visits)
        if (!v.isHotel) v.entityId,
    };
    final hotelIds = {
      for (final v in visits)
        if (v.isHotel) v.entityId,
    };
    final restaurantsFuture = restaurantIds.isEmpty
        ? Future.value(const <dynamic>[])
        : _client
              .from('restaurants_full')
              .select(restaurantFullColumns)
              .inFilter('id', restaurantIds.toList());
    final hotelsFuture = hotelIds.isEmpty
        ? Future.value(const <dynamic>[])
        : _client
              .from('hotels_full')
              .select(hotelFullColumns)
              .inFilter('id', hotelIds.toList());
    final restaurants = {
      for (final row in await restaurantsFuture)
        (row['id'] as String): Restaurant.fromJson(row as Map<String, dynamic>),
    };
    final hotels = {
      for (final row in await hotelsFuture)
        (row['id'] as String): Hotel.fromJson(row as Map<String, dynamic>),
    };

    // A venue no longer in the catalogue drops out, as on the Passport.
    final out = <UndatedVenue>[];
    for (final v in visits) {
      final PassportVenue? venue = v.isHotel
          ? switch (hotels[v.entityId]) {
              final hotel? => HotelVenue(hotel),
              null => null,
            }
          : switch (restaurants[v.entityId]) {
              final restaurant? => RestaurantVenue(restaurant),
              null => null,
            };
      if (venue != null) out.add(UndatedVenue(visit: v, venue: venue));
    }
    return out;
  }

  /// Adds every one of [choices] as an undated visit. One that is already
  /// there is left as it is (the table holds one per member and venue).
  Future<void> addMany({
    required String userId,
    required List<CountryVenueChoice> choices,
    required VisitVisibility visibility,
  }) async {
    if (choices.isEmpty) return;
    await _client
        .from('undated_visits')
        .upsert(
          [
            for (final c in choices)
              {
                'user_id': userId,
                'entity_type': c.entityType,
                'entity_id': c.id,
                'visibility': visibility.dbValue,
              },
          ],
          onConflict: 'user_id,entity_type,entity_id',
          ignoreDuplicates: true,
        );
  }

  Future<void> remove(String undatedVisitId) async {
    await _client.from('undated_visits').delete().eq('id', undatedVisitId);
  }

  /// Turns an undated visit into a dated one, in one transaction on the
  /// server (date_undated_visit). Returns the new `visits` row: the stamp.
  Future<Visit> addDate(String undatedVisitId, DateTime visitedOn) async {
    final row = await _client.rpc(
      'date_undated_visit',
      params: {
        'p_undated_visit_id': undatedVisitId,
        'p_visited_on': visitedOn.toIso8601String().substring(0, 10),
      },
    );
    return Visit.fromJson(row as Map<String, dynamic>);
  }

  /// Every restaurant and hotel in [countryCode], starred and Keyed first,
  /// then by city and name. Paged, since one country can pass the row cap.
  Future<List<CountryVenueChoice>> loadCountryChoices(
    String countryCode,
  ) async {
    final restaurantRows = fetchAllRows(
      () => _client
          .from('restaurants_full')
          .select('id, name, city_name, michelin_stars')
          .eq('country_code', countryCode)
          .order('id', ascending: true),
    );
    final hotelRows = fetchAllRows(
      () => _client
          .from('hotels_full')
          .select('id, name, city_name, michelin_keys')
          .eq('country_code', countryCode)
          .order('id', ascending: true),
    );
    final choices = [
      for (final row in await restaurantRows)
        CountryVenueChoice(
          id: row['id'] as String,
          isHotel: false,
          name: (row['name'] as String?) ?? '',
          city: (row['city_name'] as String?) ?? '',
          stars: (row['michelin_stars'] as num?)?.toInt(),
          keys: null,
        ),
      for (final row in await hotelRows)
        CountryVenueChoice(
          id: row['id'] as String,
          isHotel: true,
          name: (row['name'] as String?) ?? '',
          city: (row['city_name'] as String?) ?? '',
          stars: null,
          keys: (row['michelin_keys'] as num?)?.toInt(),
        ),
    ];
    choices.sort(compareCountryChoices);
    return choices;
  }

  /// Every country with at least one restaurant or hotel in the catalogue.
  Future<List<VenueCountry>> loadCatalogueCountries() async {
    final lists = await Future.wait([
      RestaurantRepository(_client).getCountries(),
      HotelRepository(_client).getCountries(),
    ]);
    final byCode = <String, VenueCountry>{
      for (final list in lists)
        for (final c in list) c.code: c,
    };
    return byCode.values.toList()..sort((a, b) => a.name.compareTo(b.name));
  }
}

/// Three stars before two before one, Keys likewise, then everything else;
/// within that, by city and then name.
int compareCountryChoices(CountryVenueChoice a, CountryVenueChoice b) {
  int weight(CountryVenueChoice c) =>
      c.isHotel ? (c.keys ?? 0) : (c.stars ?? 0);
  final byAward = weight(b).compareTo(weight(a));
  if (byAward != 0) return byAward;
  final byCity = a.city.compareTo(b.city);
  if (byCity != 0) return byCity;
  return a.name.compareTo(b.name);
}
