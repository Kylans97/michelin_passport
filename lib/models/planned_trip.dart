// Maps a row from `public.planned_trips` (see
// supabase/migrations/20260810120000_create_planned_trips.sql — additive,
// not yet applied). A trip is a higher-level grouping a planned venue may
// optionally belong to; see PlannedVenue.
class PlannedTrip {
  final String id;
  final String userId;
  final String title;
  final DateTime startDate;
  final DateTime endDate;
  final String countryCode;

  // Free text, not a catalogue city — a trip destination isn't restricted
  // to cities that happen to have Michelin-catalogued venues.
  final String? city;
  final String? notes;
  final DateTime createdAt;

  const PlannedTrip({
    required this.id,
    required this.userId,
    required this.title,
    required this.startDate,
    required this.endDate,
    required this.countryCode,
    this.city,
    this.notes,
    required this.createdAt,
  });

  factory PlannedTrip.fromJson(Map<String, dynamic> json) => PlannedTrip(
    id: json['id'].toString(),
    userId: json['user_id'].toString(),
    title: (json['title'] as String?) ?? '',
    startDate: DateTime.parse(json['start_date'] as String),
    endDate: DateTime.parse(json['end_date'] as String),
    countryCode: (json['country_code'] as String?) ?? '',
    city: json['city'] as String?,
    notes: json['notes'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}
