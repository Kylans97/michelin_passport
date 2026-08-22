import '../../core/utils/event_time.dart' show compareCalendarDates;
import '../../models/event.dart';
import '../../models/event_discovery_filters.dart';
import '../../models/friendship.dart';
import 'friends_going_view_model.dart';

/// Events V2 Discovery Taxonomy Phase B — the pure, Supabase-free core of
/// filter application. Every function here operates on already-resolved
/// data (an [Event] list, a [Friendship] list, plain id-keyed maps) —
/// resolving THAT data from Supabase is [EventDiscoveryFilterService]'s
/// job (`event_discovery_filter_service.dart`), kept deliberately
/// separate so the actual inclusion/exclusion decision — the part with
/// real product rules and edge cases worth exhaustively testing — never
/// needs a live SupabaseClient to verify. Mirrors this codebase's own
/// established split between `event_discovery_ranking.dart` (pure) and
/// `event_discovery_service.dart` (thin Supabase orchestration).
///
/// Semantics (Phase B §3-§9, confirmed against the architecture audit):
/// AND across the five dimensions (Social, Type, Theme/Tags, Country,
/// Date); OR within each dimension's own selected values. Social filters
/// reuse Step 8A's own "friend going"/"friend interested"/"followed host"
/// definitions verbatim ([friendsGoingToEvent],
/// `EventHostFollowRepository`'s qualification rule) — never a second,
/// competing definition.

/// Calendar-date interval overlap — [event] qualifies if its own
/// [Event.startDate]/[Event.endDate] span intersects [from]/[to] (either
/// or both may be null/open). Mirrors [eventMatchesTrip]'s identical
/// overlap check (`event_trip_match.dart`) and reuses the same
/// zone-tag-agnostic [compareCalendarDates] — never a raw
/// [DateTime.isAfter]/[isBefore], which would leak whichever zone tag the
/// two [DateTime]s happen to carry into what must be a pure calendar-date
/// comparison. A `null` range (both sides open) always intersects.
bool eventIntersectsDateRange(Event event, DateTime? from, DateTime? to) {
  if (from != null && compareCalendarDates(event.endDate, from) < 0) {
    return false;
  }
  if (to != null && compareCalendarDates(event.startDate, to) > 0) {
    return false;
  }
  return true;
}

/// Narrows [events] to exactly the ones every active filter dimension in
/// [filters] admits. [tagMatchingEventIds]/[socialQualifyingEventIds] are
/// the already-resolved id sets for the Theme and Social dimensions
/// respectively (ignored entirely when the corresponding filter is
/// empty — an unused, possibly-stale set passed in by a caller that
/// simply didn't bother computing it costs nothing and changes nothing).
///
/// Signed-out + at least one active Social filter is a deterministic
/// empty result (Phase B §16) — a signed-out viewer has no "friends" or
/// "following" concept to qualify against, so no event can honestly
/// satisfy that dimension; this is checked once, up front, rather than
/// every event happening to fail the same check individually.
///
/// An [EventDiscoveryFilters.isEmpty] input returns [events] completely
/// unchanged (same list, same order) — the exact "empty filter behaves
/// identically to today" invariant Phase B §29/§35 requires, since every
/// per-dimension check below is a structural no-op when that dimension's
/// selection is empty.
///
/// Cancelled events are deliberately NOT specially excluded here beyond
/// whatever the caller's own base [events] list already contains — the
/// existing Events surface has always included cancelled events (marked,
/// not hidden; see `EventsRepository.loadEvents`'s own doc comment), and
/// changing that would violate the "empty filter = unchanged behavior"
/// invariant. A cancelled Event that matches every active filter
/// dimension is included exactly as it already is today with no filter
/// active — filtering narrows by type/theme/country/date/social, it does
/// not introduce a new lifecycle rule.
List<Event> applyDiscoveryFilters({
  required List<Event> events,
  required EventDiscoveryFilters filters,
  required bool userSignedIn,
  Set<String> tagMatchingEventIds = const {},
  Set<String> socialQualifyingEventIds = const {},
}) {
  if (filters.isEmpty) return events;
  if (filters.social.isNotEmpty && !userSignedIn) return const [];

  return events.where((event) {
    if (filters.eventTypes.isNotEmpty &&
        !filters.eventTypes.contains(event.eventType)) {
      return false;
    }
    if (filters.countryCodes.isNotEmpty &&
        !filters.countryCodes.contains(event.countryCode.toUpperCase())) {
      return false;
    }
    if (!filters.dateRange.isEmpty &&
        !eventIntersectsDateRange(
          event,
          filters.dateRange.from,
          filters.dateRange.to,
        )) {
      return false;
    }
    if (filters.tagSlugs.isNotEmpty &&
        !tagMatchingEventIds.contains(event.id)) {
      return false;
    }
    if (filters.social.isNotEmpty &&
        !socialQualifyingEventIds.contains(event.id)) {
      return false;
    }
    return true;
  }).toList();
}

/// Resolves which of [eventIds] satisfy at least one selected [social]
/// filter (OR within the Social dimension — Phase B §4) from already-
/// fetched, batched attendance/follow data. Reuses [friendsGoingToEvent]
/// for BOTH Friends Going and Friends Interested (exactly how
/// `EventDetailScreen` and `EventDiscoveryService` already call it twice
/// with different status-keyed id maps — never a second "is this a
/// friend" definition) and the presence of an id as a key in
/// [followedHostNamesByEvent] for Following (exactly what
/// `EventHostFollowRepository.getFollowedHostEventNames` already
/// guarantees: an id only appears there when a genuine `is_host = true`
/// relationship qualifies — see `eventHostFollowQualifies`).
///
/// Zero accepted friends or zero followed hosts naturally resolves to an
/// empty result for that sub-check (an empty [friends] list means
/// [friendsGoingToEvent] can never find a match; an empty
/// [followedHostNamesByEvent] means no id is ever a key) — no special-
/// cased "zero-friend" branch is needed, the same data-driven emptiness
/// Step 8A itself already relies on (Phase B §17).
Set<String> resolveSocialQualifyingEventIds({
  required Set<EventSocialFilter> social,
  required List<String> eventIds,
  required Map<String, List<String>> goingUserIdsByEvent,
  required Map<String, List<String>> interestedUserIdsByEvent,
  required List<Friendship> friends,
  required String selfUserId,
  required Map<String, String?> followedHostNamesByEvent,
}) {
  final qualifying = <String>{};
  for (final eventId in eventIds) {
    if (social.contains(EventSocialFilter.friendsGoing) &&
        friendsGoingToEvent(
          attendeeUserIds: goingUserIdsByEvent[eventId] ?? const [],
          friends: friends,
          selfUserId: selfUserId,
        ).isNotEmpty) {
      qualifying.add(eventId);
      continue;
    }
    if (social.contains(EventSocialFilter.friendsInterested) &&
        friendsGoingToEvent(
          attendeeUserIds: interestedUserIdsByEvent[eventId] ?? const [],
          friends: friends,
          selfUserId: selfUserId,
        ).isNotEmpty) {
      qualifying.add(eventId);
      continue;
    }
    if (social.contains(EventSocialFilter.following) &&
        followedHostNamesByEvent.containsKey(eventId)) {
      qualifying.add(eventId);
    }
  }
  return qualifying;
}
