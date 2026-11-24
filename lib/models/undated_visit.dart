import 'passport_venue.dart';
import 'visit.dart' show VisitVisibility;

/// One `undated_visits` row: a restaurant or hotel the member has been to
/// without knowing when (20261101700000_add_undated_visits.sql). Never a
/// Passport stamp: it lights a country on My Map and shows as a dashed pin
/// until the date is added, which moves it into `visits`.
class UndatedVisit {
  final String id;
  final String userId;

  /// 'restaurant' or 'hotel', as on `visits`.
  final String entityType;
  final String entityId;
  final VisitVisibility visibility;

  /// The venue's award on the day this was logged, frozen by the database.
  final int? starsAtVisit;
  final int? keysAtVisit;
  final DateTime createdAt;

  const UndatedVisit({
    required this.id,
    required this.userId,
    required this.entityType,
    required this.entityId,
    required this.visibility,
    required this.starsAtVisit,
    required this.keysAtVisit,
    required this.createdAt,
  });

  bool get isHotel => entityType == 'hotel';

  factory UndatedVisit.fromJson(Map<String, dynamic> json) => UndatedVisit(
    id: json['id'] as String,
    userId: json['user_id'] as String,
    entityType: json['entity_type'] as String,
    entityId: json['entity_id'] as String,
    visibility: VisitVisibility.fromDbValue(json['visibility'] as String?),
    starsAtVisit: (json['stars_at_visit'] as num?)?.toInt(),
    keysAtVisit: (json['keys_at_visit'] as num?)?.toInt(),
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}

/// An [UndatedVisit] with the venue it points at, resolved.
class UndatedVenue {
  final UndatedVisit visit;
  final PassportVenue venue;

  const UndatedVenue({required this.visit, required this.venue});
}
