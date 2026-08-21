/// Events V2 Step 2 — the controlled vocabularies and the one typed
/// property bag every [AnalyticsEvent] call site fills in from. No feature
/// code ever passes a raw `Map<String, dynamic>` or an arbitrary string for
/// any of these — see `docs/Architecture/EVENTS_V2_ANALYTICS_CONTRACT.md`
/// for the full REQUIRED/OPTIONAL/DO-NOT-TRACK contract each field belongs
/// to.
library;

/// Where the user was, or what they did, immediately before the tracked
/// action — session-scoped, last-touch attribution only (never multi-touch,
/// never "first ever discovery"). Matches
/// `EVENTS_V2_ARCHITECTURE.md` §31.4 exactly.
enum AnalyticsSourceSurface {
  eventsFeed,
  eventSearch,
  discover,
  hostProfile,
  friendActivity,
  tripRecommendation,
  passport,
  map,
  pushNotification,
  deepLink,
  externalShare;

  String get wireName => switch (this) {
    AnalyticsSourceSurface.eventsFeed => 'events_feed',
    AnalyticsSourceSurface.eventSearch => 'event_search',
    AnalyticsSourceSurface.discover => 'discover',
    AnalyticsSourceSurface.hostProfile => 'host_profile',
    AnalyticsSourceSurface.friendActivity => 'friend_activity',
    AnalyticsSourceSurface.tripRecommendation => 'trip_recommendation',
    AnalyticsSourceSurface.passport => 'passport',
    AnalyticsSourceSurface.map => 'map',
    AnalyticsSourceSurface.pushNotification => 'push_notification',
    AnalyticsSourceSurface.deepLink => 'deep_link',
    AnalyticsSourceSurface.externalShare => 'external_share',
  };
}

/// A more specific reason than [AnalyticsSourceSurface] alone, only when
/// one is actually known — optional on every event that carries it.
enum AnalyticsSourceContext {
  featured,
  followedHost,
  nearby,
  tripDestination,
  friendSignal,
  searchResult;

  String get wireName => switch (this) {
    AnalyticsSourceContext.featured => 'featured',
    AnalyticsSourceContext.followedHost => 'followed_host',
    AnalyticsSourceContext.nearby => 'nearby',
    AnalyticsSourceContext.tripDestination => 'trip_destination',
    AnalyticsSourceContext.friendSignal => 'friend_signal',
    AnalyticsSourceContext.searchResult => 'search_result',
  };
}

/// *What kind* of friend signal preceded an action — never *which* friend.
/// Pairs with [AnalyticsSourceContext.friendSignal]; a friend's identity
/// (user id, name, email) must never appear in any analytics payload.
enum FriendSignalType {
  interested,
  going,
  attended;

  String get wireName => switch (this) {
    FriendSignalType.interested => 'interested',
    FriendSignalType.going => 'going',
    FriendSignalType.attended => 'attended',
  };
}

/// Mirrors `event_confirmed_attendance.source`'s own CHECK constraint
/// exactly (Events V2 Step 1) — never a different vocabulary from the
/// database's.
enum AttendanceSource {
  manual,
  postEventPrompt,
  tripCompletion;

  String get wireName => switch (this) {
    AttendanceSource.manual => 'manual',
    AttendanceSource.postEventPrompt => 'post_event_prompt',
    AttendanceSource.tripCompletion => 'trip_completion',
  };
}

/// MVP entity types only — matches the Step 1 Chef MVP hosting boundary
/// (`EVENTS_V2_ARCHITECTURE.md` §6.1a) exactly. `restaurant`/`hotel`/
/// `privateChef` are the only entity types Follow supports today; `event`
/// is included because Trip/Passport events reference an event as their
/// entity, not because Follow does. Winery/Bar/a broader Chef entity are
/// deliberately not added — do not extend this enum ahead of those
/// entities actually existing.
enum AnalyticsEntityType {
  restaurant,
  hotel,
  privateChef,
  event;

  String get wireName => switch (this) {
    AnalyticsEntityType.restaurant => 'restaurant',
    AnalyticsEntityType.hotel => 'hotel',
    AnalyticsEntityType.privateChef => 'private_chef',
    AnalyticsEntityType.event => 'event',
  };
}

/// A coarse price bucket — the exact `price_amount` (if that field is ever
/// added to `events`) must never be sent; this is a deliberate coarsening,
/// not a placeholder for the real value.
enum PriceBucket {
  free,
  under100,
  between100And250,
  over250;

  String get wireName => switch (this) {
    PriceBucket.free => 'free',
    PriceBucket.under100 => 'under_100',
    PriceBucket.between100And250 => '100_250',
    PriceBucket.over250 => 'over_250',
  };
}

/// The one typed property bag for every [AnalyticsEvent]. Every field is
/// nullable and optional at the type level — which fields are actually
/// REQUIRED for a given event is a documented convention
/// (`EVENTS_V2_ANALYTICS_CONTRACT.md`), not something the Dart type system
/// enforces here. A single class, not one per event: this app's event
/// taxonomy shares a small, well-defined property vocabulary (source,
/// entity, host, trip, friend-signal context) — a per-event class hierarchy
/// would be exactly the "large analytics framework" this step was told not
/// to build, for no correctness benefit a documented convention doesn't
/// already provide.
///
/// Deliberately absent from this class: `event_name`, `timestamp`,
/// `session_id`, `schema_version`, `user_internal_id` — every one of those
/// is envelope data [AnalyticsService.track] itself stamps on every call,
/// never something a call site passes by hand (see that class's own doc
/// comment).
class AnalyticsProperties {
  const AnalyticsProperties({
    this.entityType,
    this.entityId,
    this.sourceSurface,
    this.sourceContext,
    this.hostType,
    this.hostId,
    this.hostCount,
    this.city,
    this.countryCode,
    this.eventCategory,
    this.admissionType,
    this.priceBucket,
    this.tripId,
    this.followedHost,
    this.positionInFeed,
    this.friendSignalType,
    this.attendanceSource,
    this.resultsCount,
    this.wouldRecommend,
  });

  /// The catalogue entity type this action concerns (Follow's target,
  /// a Trip item's type, a Passport item's type). See [AnalyticsEntityType].
  final AnalyticsEntityType? entityType;

  /// The catalogue row id paired with [entityType] — a restaurant/hotel/
  /// private-chef/event id, never a user id.
  final String? entityId;

  final AnalyticsSourceSurface? sourceSurface;
  final AnalyticsSourceContext? sourceContext;

  /// Populate [hostType]/[hostId] **only** when the event has exactly one
  /// canonical host (`is_host = true` on exactly one row across
  /// `event_restaurants`/`event_hotels`/`event_chefs`, Step 1 §6.3). Leave
  /// both null for zero-host and multi-host events — never pick an
  /// arbitrary one of several hosts merely to have a value here, which
  /// would misattribute engagement to the wrong host. See
  /// `EVENTS_V2_ANALYTICS_CONTRACT.md`'s Host Attribution section.
  final AnalyticsEntityType? hostType;
  final String? hostId;

  /// The number of canonical (`is_host = true`) rows linked to this event,
  /// regardless of whether [hostId] is populated. Always safe to include
  /// when known — this is what lets a future multi-host event still be
  /// aggregated server-side without ever implying a false single host.
  final int? hostCount;

  /// The **event's/venue's** city/country — never the user's location.
  final String? city;
  final String? countryCode;

  /// `events.event_type` verbatim (`festival`/`dinner`/`tasting`/...).
  final String? eventCategory;

  /// `events.admission_type` verbatim (`free`/`paid`/`mixed`/`unknown`).
  final String? admissionType;

  /// Coarse only — see [PriceBucket]'s own doc comment.
  final PriceBucket? priceBucket;

  /// Only on Trip-funnel events.
  final String? tripId;

  /// True when the discovered/opened entity is one the user follows —
  /// only on discovery events where this is relevant.
  final bool? followedHost;

  /// Only where genuine impression/feed-position tracking is actually
  /// built (currently deferred — see the contract doc's Impressions
  /// section).
  final int? positionInFeed;

  /// *What kind* of friend signal preceded this action — never *which*
  /// friend. See [FriendSignalType]'s own doc comment.
  final FriendSignalType? friendSignalType;

  /// Mirrors `event_confirmed_attendance.source` for
  /// [AnalyticsEvent.eventAttendanceConfirmed]/`Denied`. See
  /// [AttendanceSource]'s own doc comment.
  final AttendanceSource? attendanceSource;

  /// [AnalyticsEvent.eventSearchPerformed] only — the count of results a
  /// search produced. Never the search query text itself, which is
  /// DO-NOT-TRACK in full (see the contract doc's Search Analytics
  /// section) — a plain count carries no personal information the way raw
  /// free text can.
  final int? resultsCount;

  /// Events V2 Step 4.1. The Yes/No value being reported by
  /// [AnalyticsEvent.eventRecommendationAdded] only — the controlled
  /// nullable boolean mirroring `event_confirmed_attendance.would_recommend`
  /// exactly (see that column's own comment: NULL is never sent as a
  /// property value, since there is nothing to report once cleared).
  /// Deliberately left null (omitted from the wire payload) on
  /// [AnalyticsEvent.eventRecommendationRemoved] — that event's entire
  /// meaning is "the answer no longer exists," so attaching a stale true/
  /// false here would misrepresent it as a fresh Yes/No.
  final bool? wouldRecommend;

  /// Serializes to wire-safe key/value pairs — every enum becomes its
  /// [wireName], every null field is omitted entirely rather than sent as
  /// an explicit null. Used by [DebugPrintAnalyticsService] today, and is
  /// the shape any future real provider adapter would consume.
  Map<String, Object> toMap() {
    final map = <String, Object>{};
    void put(String key, Object? value) {
      if (value != null) map[key] = value;
    }

    put('entity_type', entityType?.wireName);
    put('entity_id', entityId);
    put('source_surface', sourceSurface?.wireName);
    put('source_context', sourceContext?.wireName);
    put('host_type', hostType?.wireName);
    put('host_id', hostId);
    put('host_count', hostCount);
    put('city', city);
    put('country_code', countryCode);
    put('event_category', eventCategory);
    put('admission_type', admissionType);
    put('price_bucket', priceBucket?.wireName);
    put('trip_id', tripId);
    put('followed_host', followedHost);
    put('position_in_feed', positionInFeed);
    put('friend_signal_type', friendSignalType?.wireName);
    put('attendance_source', attendanceSource?.wireName);
    put('results_count', resultsCount);
    put('would_recommend', wouldRecommend);
    return map;
  }
}
