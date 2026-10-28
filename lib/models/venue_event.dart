import 'event.dart';
import 'event_local_time.dart';

/// Where a venue's own event stands, from its manager's point of view.
/// Mirrors events.moderation_status plus cancelled_at (20261018130000).
enum VenueEventStatus {
  awaitingReview,
  notApproved,
  live,
  cancelled;

  static VenueEventStatus from(String moderationStatus, DateTime? cancelledAt) {
    if (cancelledAt != null) return VenueEventStatus.cancelled;
    return switch (moderationStatus) {
      'published' => VenueEventStatus.live,
      'rejected' => VenueEventStatus.notApproved,
      _ => VenueEventStatus.awaitingReview,
    };
  }

  String get label => switch (this) {
    VenueEventStatus.awaitingReview => 'Awaiting review',
    VenueEventStatus.notApproved => 'Not approved',
    VenueEventStatus.live => 'Live',
    VenueEventStatus.cancelled => 'Cancelled',
  };
}

/// One event a venue hosts, as get_venue_events() returns it: the event
/// itself, its review state and its tags. Only the venue's own managers
/// ever see this shape.
class VenueEvent {
  final Event event;
  final VenueEventStatus status;
  final String? reviewNote;
  final List<String> tagSlugs;

  const VenueEvent({
    required this.event,
    required this.status,
    this.reviewNote,
    this.tagSlugs = const [],
  });

  factory VenueEvent.fromJson(
    Map<String, dynamic> json, {
    List<String> tagSlugs = const [],
  }) {
    final event = Event.fromJson(json);
    return VenueEvent(
      event: event,
      status: VenueEventStatus.from(
        (json['moderation_status'] as String?) ?? 'submitted',
        event.cancelledAt,
      ),
      reviewNote: json['review_note'] as String?,
      tagSlugs: tagSlugs,
    );
  }

  /// A cancelled event stays as it is; everything else can be edited.
  bool get canEdit => status != VenueEventStatus.cancelled;
}

/// The seven types a venue may choose (CLAUDE.md "V1 types"). The other
/// EventType values stay valid for curated events only.
const venueEventTypes = [
  EventType.dinner,
  EventType.lunch,
  EventType.festival,
  EventType.gala,
  EventType.tasting,
  EventType.brunch,
  EventType.party,
];

/// What the event form sends to submit_venue_event / update_venue_event.
/// Times are null when the venue didn't give them — never filled in.
class VenueEventDraft {
  final String name;
  final String description;
  final EventType eventType;
  final List<String> tagSlugs;
  final DateTime startDate;
  final DateTime? endDate;
  final EventLocalTime? startTime;
  final EventLocalTime? endTime;
  final String timezone;

  /// Held at the venue itself: the server copies the venue's own verified
  /// location and ignores the fields below.
  final bool atVenue;
  final String? venueName;
  final String? address;
  final String? city;
  final String? countryCode;
  final double? latitude;
  final double? longitude;

  final String? ticketUrl;
  final EventAdmissionType admissionType;
  final String? admissionNote;

  const VenueEventDraft({
    required this.name,
    required this.description,
    required this.eventType,
    this.tagSlugs = const [],
    required this.startDate,
    this.endDate,
    this.startTime,
    this.endTime,
    required this.timezone,
    required this.atVenue,
    this.venueName,
    this.address,
    this.city,
    this.countryCode,
    this.latitude,
    this.longitude,
    this.ticketUrl,
    this.admissionType = EventAdmissionType.unknown,
    this.admissionNote,
  });

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static String? _time(EventLocalTime? t) => t == null ? null : '${t.format()}:00';

  static String? _blankToNull(String? s) =>
      (s == null || s.trim().isEmpty) ? null : s.trim();

  /// The RPC's named parameters, shared by submit and update.
  Map<String, dynamic> toParams() => {
    'p_name': name.trim(),
    'p_description': description.trim(),
    'p_event_type': eventType.dbValue,
    'p_start_date': _date(startDate),
    'p_timezone': timezone,
    'p_at_venue': atVenue,
    'p_end_date': endDate == null ? null : _date(endDate!),
    'p_start_time': _time(startTime),
    'p_end_time': startTime == null ? null : _time(endTime),
    'p_tag_slugs': tagSlugs,
    'p_venue_name': atVenue ? null : _blankToNull(venueName),
    'p_address': atVenue ? null : _blankToNull(address),
    'p_city': atVenue ? null : _blankToNull(city),
    'p_country_code': atVenue ? null : countryCode,
    'p_latitude': atVenue ? null : latitude,
    'p_longitude': atVenue ? null : longitude,
    'p_ticket_url': _blankToNull(ticketUrl),
    'p_admission_type': admissionType.dbValue,
    'p_admission_note': _blankToNull(admissionNote),
  };
}

/// A country with every IANA zone it has (countries.timezones,
/// 20261018120000). One zone: the form uses it. Several: the form asks.
class EventCountry {
  final String code;
  final String name;
  final String flag;
  final List<String> timezones;

  const EventCountry({
    required this.code,
    required this.name,
    required this.flag,
    required this.timezones,
  });

  factory EventCountry.fromJson(Map<String, dynamic> json) => EventCountry(
    code: ((json['country_code'] as String?) ?? '').trim(),
    name: (json['name'] as String?) ?? '',
    flag: (json['flag_emoji'] as String?) ?? '',
    timezones: [
      for (final z in (json['timezones'] as List?) ?? const []) z as String,
    ],
  );

  /// The zone to use without asking, or null when there are several.
  String? get onlyTimezone => timezones.length == 1 ? timezones.single : null;
}
