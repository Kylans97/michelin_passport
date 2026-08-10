// Maps a row from `public.planned_venues` (see
// supabase/migrations/20260810120000_create_planned_trips.sql — additive,
// not yet applied). Polymorphic like public.visits/public.wishlist:
// entity_type + entity_id address either a restaurant or a hotel, with no
// foreign key on entity_id (see DATABASE_ARCHITECTURE.md section 4).
//
// A PlannedVenue is NOT a Wishlist entry: wishlist means "I want to go here
// someday", a PlannedVenue means "I intend to visit/stay here around this
// date" — the two are independent and a venue can be in either, both, or
// neither.

/// The three permitted values of `planned_venues.status`.
enum PlannedVenueStatus {
  planned('planned'),
  completed('completed'),
  cancelled('cancelled');

  final String dbValue;
  const PlannedVenueStatus(this.dbValue);

  static PlannedVenueStatus fromDbValue(String? value) {
    for (final status in PlannedVenueStatus.values) {
      if (status.dbValue == value) return status;
    }
    // The DB CHECK constraint guarantees one of the three values; this is
    // only reached if the schema changes underneath us, never in practice.
    return PlannedVenueStatus.planned;
  }

  String get label => switch (this) {
    PlannedVenueStatus.planned => 'Planned',
    PlannedVenueStatus.completed => 'Completed',
    PlannedVenueStatus.cancelled => 'Cancelled',
  };
}

class PlannedVenue {
  final String id;
  final String userId;
  final String entityType; // 'restaurant' or 'hotel'
  final String entityId;
  final String? tripId;

  // Restaurant: the single planned visit date (endDate stays null). Hotel:
  // check-in (startDate) / check-out (endDate) — endDate may still be null
  // if the user hasn't decided check-out yet.
  final DateTime startDate;
  final DateTime? endDate;

  final String? notes;
  final PlannedVenueStatus status;
  final DateTime createdAt;

  const PlannedVenue({
    required this.id,
    required this.userId,
    required this.entityType,
    required this.entityId,
    this.tripId,
    required this.startDate,
    this.endDate,
    this.notes,
    required this.status,
    required this.createdAt,
  });

  bool get isRestaurant => entityType == 'restaurant';
  bool get isHotel => entityType == 'hotel';

  factory PlannedVenue.fromJson(Map<String, dynamic> json) => PlannedVenue(
    id: json['id'].toString(),
    userId: json['user_id'].toString(),
    entityType: (json['entity_type'] as String?) ?? '',
    entityId: json['entity_id'].toString(),
    tripId: json['trip_id'] as String?,
    startDate: DateTime.parse(json['start_date'] as String),
    endDate: json['end_date'] != null
        ? DateTime.parse(json['end_date'] as String)
        : null,
    notes: json['notes'] as String?,
    status: PlannedVenueStatus.fromDbValue(json['status'] as String?),
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}
