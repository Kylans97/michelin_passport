// Maps a row from `public.events` (see
// supabase/migrations/20260810160000_create_events.sql — additive, not yet
// applied). An event is never required to belong to one restaurant or one
// hotel — see EventRepository for how event_restaurants/event_hotels are
// resolved separately, the same "join table, not a required FK column"
// shape as hotel_restaurants.

import '../core/utils/event_time.dart';
import 'event_local_time.dart';

/// The permitted values of `events.event_type`. Stores the exact
/// database strings via [dbValue] — do not rename these without a
/// migration.
///
/// Events V2 Discovery Taxonomy Phase A: `lunch`/`gala`/`brunch`/`party`
/// were added to the CHECK constraint (widened, additive-only) to cover
/// the seven approved V1 Event Types. `market`/`experience`/`other`
/// remain fully supported for backward compatibility — no existing row
/// or legacy value is invalidated by this change.
enum EventType {
  festival('festival'),
  dinner('dinner'),
  lunch('lunch'),
  tasting('tasting'),
  gala('gala'),
  brunch('brunch'),
  party('party'),
  market('market'),
  experience('experience'),
  other('other');

  final String dbValue;
  const EventType(this.dbValue);

  static EventType fromDbValue(String? value) {
    for (final type in EventType.values) {
      if (type.dbValue == value) return type;
    }
    // The DB CHECK constraint guarantees one of the permitted values;
    // this is only reached if the schema changes underneath us.
    return EventType.other;
  }

  String get label => switch (this) {
    EventType.festival => 'Festival',
    EventType.dinner => 'Dinner',
    EventType.lunch => 'Lunch',
    EventType.tasting => 'Tasting',
    EventType.gala => 'Gala',
    EventType.brunch => 'Brunch',
    EventType.party => 'Party',
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

  // ── Time precision (Events V2 Time Precision Phase B) ──────────────────
  //
  // Three tiers of precision, each meaningful independently — see
  // docs/Architecture/Events/EVENT_TIME_PRECISION_ARCHITECTURE_AUDIT.md:
  //
  // CALENDAR (always known): [startDate]/[endDate] — the event's own local
  // calendar dates, canonical for sorting, lifecycle, and Trip matching.
  // [endDate] uses "last active local calendar date" semantics, not "the
  // date containing the raw end instant" — see the derivation helper's own
  // doc comment for the midnight-boundary rule this encodes.
  //
  // LOCAL CLOCK (known only when the source actually published a time):
  // [startTime]/[endTime] — a wall-clock reading with no date/timezone of
  // its own attached (see [EventLocalTime]). Null means genuinely unknown,
  // never midnight-as-placeholder.
  //
  // EXACT INSTANT (known only when BOTH the calendar date AND the clock
  // time for that side are known): [startAt]/[endAt] — an absolute
  // timestamptz, the one representation every pre-Phase-B consumer in this
  // codebase still assumes exists. Nullable now — never derived merely
  // because [startDate]/[startTime] both exist without a source-confirmed
  // instant backing them (see the architecture audit's own "do not derive
  // fake exact instants" rule). Production today (Phase A only) still
  // populates these for every row — Phase C is what will ever actually let
  // this be null in a real database row.
  final DateTime startDate;
  final DateTime endDate;
  final EventLocalTime? startTime;
  final EventLocalTime? endTime;
  final DateTime? startAt;
  final DateTime? endAt;

  // IANA identifier (e.g. "Europe/Amsterdam") — see
  // supabase/migrations/20260820120000_events_v2_timezone_hardening.sql.
  // Nullable: pre-hardening rows (and any row read before the NOT NULL
  // follow-up migration lands) may not have this backfilled yet. Every
  // Event-local render must go through
  // lib/features/events/event_date_format.dart, which already treats a
  // null/invalid value as "fall back to UTC" — never the device's zone.
  // Also required for the calendar/lifecycle helpers above — a date-only
  // Event needs its own timezone just as much as a full-precision one
  // does, to know when its local day actually ends.
  final String? timezone;
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

  // Deliberately NOT `const` — [startDate]/[endDate]/[startTime]/[endTime]
  // may need to be derived at construction time (see below), which reads
  // the timezone database via [eventLocalDateTime] and can't run in a
  // const context. No call site in this codebase ever constructs a const
  // `Event` (confirmed by direct search) — every instance already comes
  // from dynamic JSON or a test's own runtime `DateTime` values.
  //
  // [startDate]/[endDate] are the one truly required precision input —
  // every Event has a calendar date, full stop. Callers may supply them
  // directly (the only path `Event.fromJson` uses, matching Phase A's own
  // already-backfilled columns) OR omit them and supply [startAt]/[endAt]
  // instead, in which case they're derived automatically via the exact
  // same [eventLocalDateTime] + midnight-boundary rule Phase A's own
  // migration backfill used — this is what keeps every pre-Phase-B test
  // fixture in this codebase compiling and behaving identically without
  // being touched: a fixture that only ever knew `startAt`/`endAt` gets
  // the same calendar dates (and the same [startTime]/[endTime], see
  // below) it would have if those fields had always existed. Supplying
  // NEITHER `startDate` nor `startAt` (and the `end` equivalents) is a
  // genuine construction error — [ArgumentError] is thrown immediately,
  // never silently defaulted.
  //
  // [startTime]/[endTime] follow the identical pattern: supplied directly
  // when known (Phase A's own backfilled columns, or a Phase-C-shaped
  // test fixture deliberately testing an unknown-time case), or derived
  // from [startAt]/[endAt] when the caller only provided the legacy exact
  // instant — never the other direction: this constructor NEVER derives
  // [startAt]/[endAt] from [startDate]/[startTime], even when both are
  // given, because a date+time pair without a source-confirmed instant is
  // exactly the "date-only"/"start-known" shape this whole model exists to
  // represent honestly — see the architecture audit's own "do not derive
  // fake exact instants" rule.
  Event({
    required this.id,
    required this.name,
    this.description,
    this.startAt,
    this.endAt,
    DateTime? startDate,
    DateTime? endDate,
    EventLocalTime? startTime,
    EventLocalTime? endTime,
    this.timezone,
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
  }) : startDate =
           startDate ??
           _deriveDateOnly(
             startAt,
             timezone,
             isEnd: false,
             fieldName: 'startDate',
           ),
       endDate =
           endDate ??
           _deriveDateOnly(endAt, timezone, isEnd: true, fieldName: 'endDate'),
       startTime = startTime ?? _deriveClockTime(startAt, timezone),
       endTime = endTime ?? _deriveClockTime(endAt, timezone);

  static DateTime _deriveDateOnly(
    DateTime? instant,
    String? timezone, {
    required bool isEnd,
    required String fieldName,
  }) {
    if (instant == null) {
      throw ArgumentError(
        'Event requires either "$fieldName" or the corresponding exact '
        'instant to determine its calendar date — neither was provided.',
      );
    }
    final local = eventLocalDateTime(instant, timezone);
    // The midnight-boundary rule (architecture audit + Phase A migration):
    // an END side landing exactly on local 00:00:00 belongs to the
    // PRECEDING calendar day — the instant has technically rolled into the
    // next day, but the Event itself is understood to run through the day
    // before. Never applied to the start side, where a genuine midnight
    // start is exactly what it says.
    if (isEnd && local.hour == 0 && local.minute == 0 && local.second == 0) {
      return DateTime.utc(
        local.year,
        local.month,
        local.day,
      ).subtract(const Duration(days: 1));
    }
    return DateTime.utc(local.year, local.month, local.day);
  }

  static EventLocalTime? _deriveClockTime(DateTime? instant, String? timezone) {
    if (instant == null) return null;
    final local = eventLocalDateTime(instant, timezone);
    return EventLocalTime(
      hour: local.hour,
      minute: local.minute,
      second: local.second,
    );
  }

  bool get isCancelled => status == EventStatus.cancelled;

  // "mixed" is free general admission with a separately-ticketed add-on
  // (e.g. 't Preuvenemint) — attending the event itself costs nothing, so
  // it counts as free entry same as EventAdmissionType.free. Single
  // canonical definition (EventCard and EventDetailScreen both read this)
  // rather than each re-deriving the same two-value check.
  bool get isFreeEntry =>
      admissionType == EventAdmissionType.free ||
      admissionType == EventAdmissionType.mixed;

  // ── Precision helpers (Events V2 Time Precision Phase B) ───────────────
  // Pure semantic queries over the three tiers above — every call site
  // that used to assume `startAt`/`endAt` always exist reads one of these
  // instead of a scattered null check, so the "what does this Event
  // actually know" question is answered in exactly one place.

  bool get hasStartTime => startTime != null;
  bool get hasEndTime => endTime != null;
  bool get hasExactStart => startAt != null;
  bool get hasExactEnd => endAt != null;

  /// No time known on either side at all — the purest "date only" case
  /// (architecture audit Case A/D).
  bool get isDateOnly => startTime == null && endTime == null;

  /// Both sides have a known clock time — Case C/E, what every one of
  /// today's 4 production Events already is.
  bool get hasFullTimePrecision => startTime != null && endTime != null;

  factory Event.fromJson(Map<String, dynamic> json) => Event(
    id: json['id'].toString(),
    name: (json['name'] as String?) ?? '',
    description: json['description'] as String?,
    // No .toLocal() here, deliberately: start_at/end_at must stay tagged
    // as the absolute instant Postgres sent (UTC). Event-local display is
    // derived later, on demand, from this instant + [timezone] — see
    // lib/features/events/event_date_format.dart. Tagging as device-local
    // here would silently discard the information needed to render the
    // event's OWN local time for a viewer in a different zone. Nullable
    // parse: production still always sends a value today (Phase A only),
    // but the model itself must not assume that forever — Phase C's whole
    // point is a row where these are genuinely absent.
    startAt: json['start_at'] == null
        ? null
        : DateTime.parse(json['start_at'] as String),
    endAt: json['end_at'] == null
        ? null
        : DateTime.parse(json['end_at'] as String),
    // Required calendar dates — an unconditional cast+parse, exactly like
    // every other required field on this model: a missing/malformed value
    // fails loudly here rather than silently falling back to something
    // invented. Parsed via a plain three-int split, never a bare
    // `DateTime.parse` — Dart resolves a date-only ISO string (no "Z", no
    // offset) to the DEVICE's local zone by default, which would corrupt
    // exactly the "no accidental timezone semantics" guarantee this field
    // exists to provide. `start_date`/`end_date` are pure `YYYY-MM-DD` —
    // PostgREST's own `date` serialization, confirmed against a live row.
    startDate: _parseCalendarDate(json['start_date'] as String),
    endDate: _parseCalendarDate(json['end_date'] as String),
    // Optional clock times — PostgREST's own `time` serialization,
    // confirmed against a live row as plain "HH:MM:SS", no date, no
    // offset. Absent (null) is a deliberate, meaningful value — never
    // defaulted to a placeholder.
    startTime: json['start_time'] == null
        ? null
        : EventLocalTime.parse(json['start_time'] as String),
    endTime: json['end_time'] == null
        ? null
        : EventLocalTime.parse(json['end_time'] as String),
    timezone: json['timezone'] as String?,
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

/// Parses a bare `"YYYY-MM-DD"` string (PostgREST's `date` serialization)
/// into a UTC-tagged, midnight-zeroed [DateTime] — deliberately not a bare
/// `DateTime.parse`, which resolves a date-only ISO string with no "Z"/
/// offset to the DEVICE's local zone by Dart's own documented default,
/// exactly the "accidental timezone semantics" this whole precision model
/// exists to avoid. Throws on a malformed value — a required calendar
/// date fails loudly, matching every other required field on [Event].
DateTime _parseCalendarDate(String value) {
  final parts = value.split('-');
  if (parts.length != 3) {
    throw FormatException('Not a valid YYYY-MM-DD date string: "$value"');
  }
  return DateTime.utc(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}
