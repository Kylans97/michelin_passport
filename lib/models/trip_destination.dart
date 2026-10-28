// Maps a row from `public.planned_trip_destinations` (see
// supabase/migrations/20261021120000_add_trip_destinations_and_members.sql).
// One leg of a trip: a catalogue country, optionally narrowed to one
// catalogue city — always codes/ids the catalogue knows, never a free-text
// place, so the stay/restaurant pickers can key on them.

class TripDestination {
  final String countryCode;

  /// `cities.id`, or null for a whole-country destination.
  final String? cityId;

  /// The catalogue city's display name (joined from `cities`) — for
  /// display only, never used to match anything.
  final String? cityName;

  /// This leg's dates. Both null on a single-destination trip, whose one
  /// leg is the whole trip; both set on every leg of a multi-destination
  /// trip (save_trip_destinations enforces this).
  final DateTime? startDate;
  final DateTime? endDate;

  const TripDestination({
    required this.countryCode,
    this.cityId,
    this.cityName,
    this.startDate,
    this.endDate,
  });

  bool get hasDates => startDate != null && endDate != null;

  factory TripDestination.fromJson(Map<String, dynamic> json) {
    final city = json['cities'];
    return TripDestination(
      countryCode: ((json['country_code'] as String?) ?? '').trim(),
      cityId: json['city_id'] as String?,
      cityName: city is Map<String, dynamic> ? city['name'] as String? : null,
      startDate: json['start_date'] == null
          ? null
          : DateTime.parse(json['start_date'] as String),
      endDate: json['end_date'] == null
          ? null
          : DateTime.parse(json['end_date'] as String),
    );
  }

  /// The shape save_trip_destinations takes for one leg.
  Map<String, dynamic> toRpcJson() => {
    'country_code': countryCode,
    'city_id': cityId,
    'start_date': startDate == null ? null : _dateOnly(startDate!),
    'end_date': endDate == null ? null : _dateOnly(endDate!),
  };

  TripDestination withDates(DateTime? start, DateTime? end) => TripDestination(
    countryCode: countryCode,
    cityId: cityId,
    cityName: cityName,
    startDate: start,
    endDate: end,
  );
}

String _dateOnly(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
