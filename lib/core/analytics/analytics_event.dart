/// Events V2 Step 2 — the one canonical analytics event vocabulary for this
/// app. See `docs/Architecture/EVENTS_V2_ANALYTICS_CONTRACT.md` for the full
/// contract (when to fire each event, which properties are required/
/// optional/prohibited, attribution, privacy). This file exists so no
/// feature ever hand-types an event name as a raw string — every call site
/// picks a value from this enum, and [wireName] is the single place that
/// name is spelled out.
///
/// Adding a new value here never requires a [analyticsSchemaVersion] bump.
/// Changing what an existing value *means* always does — see that
/// constant's own doc comment.
enum AnalyticsEvent {
  // ── Discovery ──────────────────────────────────────────────────────────
  /// Fired once when a user explicitly navigates to and lands on Event
  /// Detail — never on card render, prefetch, or route construction. See
  /// the contract doc's "Event open" section for the precise boundary.
  eventOpened,
  eventSearchPerformed,
  eventFilterApplied,

  // ── Host / place ───────────────────────────────────────────────────────
  hostProfileOpened,
  followAdded,
  followRemoved,

  // ── Event intent (Interested / Going) ─────────────────────────────────
  /// Fired only after the corresponding `event_attendance` write succeeds
  /// — never as the write itself, never on failure. See the contract doc's
  /// "Successful-write rule".
  eventInterestedAdded,
  eventInterestedRemoved,
  eventGoingAdded,
  eventGoingRemoved,

  // ── Ticketing ──────────────────────────────────────────────────────────
  /// Means only "the user opened the external ticket/booking destination
  /// from Mantelier." Never implies purchase, booking, or revenue. Scoped
  /// to Events only — an Event's own ticket/booking link, never a
  /// Restaurant/Hotel's own website or booking_url. See
  /// [venueBookingLinkOpened] for the Venue-scoped sibling.
  ticketLinkOpened,

  /// The narrow venue-link-click-tracking path (see
  /// docs/Architecture/EVENTS_V2_ANALYTICS_CONTRACT.md's "Venue link
  /// clicks" section) — fired after a Restaurant/Hotel's own website or
  /// `booking_url` link is opened from that venue's own Detail screen.
  /// Deliberately a separate event from [ticketLinkOpened], which stays
  /// scoped to Events only. Carries [AnalyticsProperties.entityType]/
  /// [AnalyticsProperties.entityId] (the venue), [AnalyticsProperties.
  /// linkDestination] (website vs. booking) and [AnalyticsProperties.
  /// sourceScreen] — all three REQUIRED; see `SupabaseAnalyticsService`.
  venueBookingLinkOpened,

  // ── Attendance ─────────────────────────────────────────────────────────
  eventAttendancePrompted,
  eventAttendanceConfirmed,
  eventAttendanceDenied,

  // ── Content (on confirmed attendance) ─────────────────────────────────
  eventRatingAdded,
  eventPhotoAdded,
  eventCommentAdded,

  /// Events V2 Step 4.1. Fired on every save that results in a definite
  /// Yes/No `would_recommend` value — first answer AND changing an
  /// existing answer both fire this one event, mirroring
  /// [eventRatingAdded]'s own "no separate updated event" convention.
  /// Never fired for a save that leaves the value at null — see
  /// [eventRecommendationRemoved] for the distinct "cleared an existing
  /// answer" case.
  eventRecommendationAdded,

  /// Events V2 Step 4.1. Fired only when a save changes `would_recommend`
  /// from a definite Yes/No back to null — i.e. an existing answer was
  /// deliberately cleared. Never fired when the value was already null
  /// (nothing to remove) — see EVENTS_V2_ANALYTICS_CONTRACT.md's Content
  /// section for the full decision not to silently report a null update
  /// as "added".
  eventRecommendationRemoved,

  // ── Trips ──────────────────────────────────────────────────────────────
  tripEventAdded,
  tripRestaurantAdded,
  tripHotelAdded,
  tripReviewOpened,
  tripItemConfirmed,
  tripItemRejected,

  // ── Passport ───────────────────────────────────────────────────────────
  passportItemCreated,
  passportItemRemoved,

  // ── Friends ────────────────────────────────────────────────────────────
  friendsSignalOpened,

  // ── News V1 ────────────────────────────────────────────────────────────
  /// Fired once when a user opens a News article's detail screen — not
  /// on card render/prefetch, and not on the article's own optional
  /// outbound link (that's a separate, unmeasured action; News V1 only
  /// measures opens, not read time or scroll depth). Carries
  /// [AnalyticsProperties.entityType] (`newsArticle`) and
  /// [AnalyticsProperties.entityId] (the article id), both REQUIRED —
  /// see `SupabaseAnalyticsService`, which writes this to
  /// `news_article_opens`
  /// (20260918140000_add_news_v1.sql).
  newsArticleOpened,

  // ── Venue invites ("suggest going together") ───────────────────────────
  /// Fired only after `send_venue_invite` succeeds. Carries
  /// [AnalyticsProperties.inviteId], [AnalyticsProperties.entityType]
  /// (`restaurant`/`hotel`) and [AnalyticsProperties.entityId] (the
  /// venue) — all three REQUIRED. See `SupabaseAnalyticsService`, which
  /// writes this to `venue_invite_events`
  /// (20260925150000_add_venue_invite_event_tracking.sql).
  venueInviteSent,

  /// Fired only after `accept_venue_invite` succeeds — the recipient's
  /// own action, same required properties as [venueInviteSent].
  venueInviteAccepted,

  /// Fired only after `decline_venue_invite` succeeds — same required
  /// properties as [venueInviteSent].
  venueInviteDeclined;

  /// The canonical `snake_case` wire name — the only place any of these
  /// strings is spelled out. A future provider adapter (or the debug
  /// implementation) reads this, never `.name` (Dart's own camelCase
  /// enum-member name), so a Dart-side rename never silently changes what
  /// ships on the wire.
  String get wireName => switch (this) {
    AnalyticsEvent.eventOpened => 'event_opened',
    AnalyticsEvent.eventSearchPerformed => 'event_search_performed',
    AnalyticsEvent.eventFilterApplied => 'event_filter_applied',
    AnalyticsEvent.hostProfileOpened => 'host_profile_opened',
    AnalyticsEvent.followAdded => 'follow_added',
    AnalyticsEvent.followRemoved => 'follow_removed',
    AnalyticsEvent.eventInterestedAdded => 'event_interested_added',
    AnalyticsEvent.eventInterestedRemoved => 'event_interested_removed',
    AnalyticsEvent.eventGoingAdded => 'event_going_added',
    AnalyticsEvent.eventGoingRemoved => 'event_going_removed',
    AnalyticsEvent.ticketLinkOpened => 'ticket_link_opened',
    AnalyticsEvent.venueBookingLinkOpened => 'venue_booking_link_opened',
    AnalyticsEvent.eventAttendancePrompted => 'event_attendance_prompted',
    AnalyticsEvent.eventAttendanceConfirmed => 'event_attendance_confirmed',
    AnalyticsEvent.eventAttendanceDenied => 'event_attendance_denied',
    AnalyticsEvent.eventRatingAdded => 'event_rating_added',
    AnalyticsEvent.eventPhotoAdded => 'event_photo_added',
    AnalyticsEvent.eventCommentAdded => 'event_comment_added',
    AnalyticsEvent.eventRecommendationAdded => 'event_recommendation_added',
    AnalyticsEvent.eventRecommendationRemoved => 'event_recommendation_removed',
    AnalyticsEvent.tripEventAdded => 'trip_event_added',
    AnalyticsEvent.tripRestaurantAdded => 'trip_restaurant_added',
    AnalyticsEvent.tripHotelAdded => 'trip_hotel_added',
    AnalyticsEvent.tripReviewOpened => 'trip_review_opened',
    AnalyticsEvent.tripItemConfirmed => 'trip_item_confirmed',
    AnalyticsEvent.tripItemRejected => 'trip_item_rejected',
    AnalyticsEvent.passportItemCreated => 'passport_item_created',
    AnalyticsEvent.passportItemRemoved => 'passport_item_removed',
    AnalyticsEvent.friendsSignalOpened => 'friends_signal_opened',
    AnalyticsEvent.newsArticleOpened => 'news_article_opened',
    AnalyticsEvent.venueInviteSent => 'venue_invite_sent',
    AnalyticsEvent.venueInviteAccepted => 'venue_invite_accepted',
    AnalyticsEvent.venueInviteDeclined => 'venue_invite_declined',
  };
}

/// Bumped only when an *existing* event or property's meaning changes
/// materially — never when a new event/property is merely added. The old
/// meaning is retired under a new name wherever feasible instead of being
/// silently reinterpreted under the same name at a new version.
const int analyticsSchemaVersion = 1;
