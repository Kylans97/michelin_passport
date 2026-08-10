// Maps a row from `public.events` (see
// supabase/migrations/20260810160000_create_events.sql — additive, not yet
// applied). An event is never required to belong to one restaurant or one
// hotel — see EventRepository for how event_restaurants/event_hotels are
// resolved separately, the same "join table, not a required FK column"
// shape as hotel_restaurants.

/// The six permitted values of `events.event_type`. Stores the exact
/// database strings via [dbValue] — do not rename these without a
/// migration.
enum EventType {
  festival('festival'),
  dinner('dinner'),
  tasting('tasting'),
  market('market'),
  experience('experience'),
  other('other');

  final String dbValue;
  const EventType(this.dbValue);

  static EventType fromDbValue(String? value) {
    for (final type in EventType.values) {
      if (type.dbValue == value) return type;
    }
    // The DB CHECK constraint guarantees one of the six values; this is
    // only reached if the schema changes underneath us.
    return EventType.other;
  }

  String get label => switch (this) {
    EventType.festival => 'Festival',
    EventType.dinner => 'Dinner',
    EventType.tasting => 'Tasting',
    EventType.market => 'Market',
    EventType.experience => 'Experience',
    EventType.other => 'Event',
  };
}

/// The three permitted values of `events.status`.
enum EventStatus {
  upcoming('upcoming'),
  cancelled('cancelled'),
  completed('completed');

  final String dbValue;
  const EventStatus(this.dbValue);

  static EventStatus fromDbValue(String? value) {
    for (final status in EventStatus.values) {
      if (status.dbValue == value) return status;
    }
    return EventStatus.upcoming;
  }
}

/// The four permitted values of `events.admission_type` (see
/// supabase/migrations/20260810180000_add_event_admission.sql). An event's
/// `ticket_url` alone never says whether the event ITSELF requires payment
/// — 't Preuvenemint is free to attend but still carries a ticket_url for
/// a separate, optional paid add-on, which is exactly what [mixed] exists
/// to represent.
enum EventAdmissionType {
  free('free'),
  paid('paid'),
  mixed('mixed'),
  unknown('unknown');

  final String dbValue;
  const EventAdmissionType(this.dbValue);

  static EventAdmissionType fromDbValue(String? value) {
    for (final type in EventAdmissionType.values) {
      if (type.dbValue == value) return type;
    }
    return EventAdmissionType.unknown;
  }

  String get label => switch (this) {
    EventAdmissionType.free => 'Free entry',
    EventAdmissionType.paid => 'Ticketed',
    EventAdmissionType.mixed => 'Free entry, optional ticket',
    EventAdmissionType.unknown => 'Admission not confirmed',
  };
}

class Event {
  final String id;
  final String name;
  final String? description;
  final DateTime startAt;
  final DateTime endAt;
  final String countryCode;
  final String? city;
  final String? venueName;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? officialUrl;
  final String? ticketUrl;
  final String? imageUrl;
  final EventType eventType;
  final EventStatus status;
  final EventAdmissionType admissionType;
  final String? admissionNote;
  final DateTime createdAt;

  const Event({
    required this.id,
    required this.name,
    this.description,
    required this.startAt,
    required this.endAt,
    required this.countryCode,
    this.city,
    this.venueName,
    this.address,
    this.latitude,
    this.longitude,
    this.officialUrl,
    this.ticketUrl,
    this.imageUrl,
    required this.eventType,
    required this.status,
    this.admissionType = EventAdmissionType.unknown,
    this.admissionNote,
    required this.createdAt,
  });

  bool get isCancelled => status == EventStatus.cancelled;

  // "mixed" is free general admission with a separately-ticketed add-on
  // (e.g. 't Preuvenemint) — attending the event itself costs nothing, so
  // it counts as free entry same as EventAdmissionType.free. Single
  // canonical definition (EventCard and EventDetailScreen both read this)
  // rather than each re-deriving the same two-value check.
  bool get isFreeEntry =>
      admissionType == EventAdmissionType.free ||
      admissionType == EventAdmissionType.mixed;

  factory Event.fromJson(Map<String, dynamic> json) => Event(
    id: json['id'].toString(),
    name: (json['name'] as String?) ?? '',
    description: json['description'] as String?,
    startAt: DateTime.parse(json['start_at'] as String).toLocal(),
    endAt: DateTime.parse(json['end_at'] as String).toLocal(),
    countryCode: (json['country_code'] as String?) ?? '',
    city: json['city'] as String?,
    venueName: json['venue_name'] as String?,
    address: json['address'] as String?,
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
    officialUrl: json['official_url'] as String?,
    ticketUrl: json['ticket_url'] as String?,
    imageUrl: json['image_url'] as String?,
    eventType: EventType.fromDbValue(json['event_type'] as String?),
    status: EventStatus.fromDbValue(json['status'] as String?),
    admissionType: EventAdmissionType.fromDbValue(
      json['admission_type'] as String?,
    ),
    admissionNote: json['admission_note'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
  );
}
