import '../../data/repositories/event_attendance_repository.dart';
import '../../data/repositories/event_host_follow_repository.dart';
import '../../data/repositories/event_tag_repository.dart';
import '../../data/repositories/events_repository.dart';
import '../../data/repositories/friendship_repository.dart';
import '../../models/event_attendance.dart';
import '../../models/event_discovery_filters.dart';
import '../../models/event_discovery_item.dart';
import '../../models/event_near_me_location.dart';
import '../../models/friendship.dart';
import 'event_discovery_filtering.dart';
import 'event_discovery_service.dart';

/// Events V2 Discovery Taxonomy Phase C §19 — thrown by
/// [EventDiscoveryFilterService.loadFilteredDiscovery] when resolving an
/// ACTIVE Theme or Social dimension fails (a taxonomy/attendance/friend/
/// follow query throws). Deliberately distinct from a base
/// `EventsRepository.loadEvents` failure (which still propagates as
/// whatever exception it naturally throws, unwrapped — the screen's
/// existing generic "could not load" handling already covers that): the
/// whole point of this type is to let the UI tell "the base feed itself
/// failed" apart from "the feed loaded fine but we can no longer honestly
/// claim your Theme/Social filter was actually applied" — the latter must
/// never be silently swallowed into an unfiltered-but-unlabeled result, or
/// a user who chose "Friends Going" could end up looking at Events with no
/// relation to their friends while believing the filter still worked
/// (Phase C §19's own explicit product requirement). Carries no raw
/// backend error text — [message] is a fixed, friendly, already-safe-to-
/// display string.
class EventFilterResolutionException implements Exception {
  const EventFilterResolutionException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Events V2 Discovery Taxonomy Phase B — the single orchestration path
/// for filtered Event discovery: **filter first, then apply the existing
/// Step 8A ranking to the filtered result set** (the non-negotiable
/// product rule this whole phase exists to implement correctly — see
/// this class's own [loadFilteredDiscovery] doc comment for the exact
/// sequencing). [EventDiscoveryService] (`event_discovery_service.dart`)
/// and [rankEventsForDiscovery]/`primaryReasonFor`
/// (`event_discovery_ranking.dart`) are used entirely unmodified — this
/// class composes them, it does not re-implement or duplicate any part
/// of the ranking hierarchy.
///
/// Query strategy (Phase B §11-§13): Type/Country/Date are pushed down to
/// `EventsRepository.loadEvents` as server-side predicates (never fetch-
/// everything-then-filter-in-Dart); Theme/Tag resolves via
/// [EventTagRepository] (2 bounded queries, independent of catalogue
/// size); Social resolves via the exact same batched, per-signal-
/// independent-failure repository calls [EventDiscoveryService] itself
/// already uses for ranking (`getVisibleUserIdsForEvents`, `getFriends`,
/// `getFollowedHostEventNames`) — never a second "friend going"/
/// "followed host" definition.
class EventDiscoveryFilterService {
  EventDiscoveryFilterService({
    required this.eventsRepo,
    required this.tagRepo,
    required this.attendanceRepo,
    required this.friendshipRepo,
    required this.hostFollowRepo,
    required this.discoveryService,
  });

  final EventsRepository eventsRepo;
  final EventTagRepository tagRepo;
  final EventAttendanceRepository attendanceRepo;
  final FriendshipRepository friendshipRepo;
  final EventHostFollowRepository hostFollowRepo;
  final EventDiscoveryService discoveryService;

  /// Loads, filters, and ranks Events for discovery. [from]/[to] are the
  /// SAME base browse-window parameters `EventsScreen` already resolves
  /// via `EventDateFilter` — [filters] is layered ON TOP of that window,
  /// never a replacement for it (a Theme/Type/Social filter narrows
  /// within "Upcoming" or "This Month", it doesn't change what "Upcoming"
  /// means).
  ///
  /// Sequencing, exactly per Phase B's own core principle:
  /// 1. `EventsRepository.loadEvents` — base query, with [filters]'s
  ///    Type/Country pushed down as server-side predicates alongside the
  ///    existing date-window/search/country-code parameters.
  /// 2. If [EventDiscoveryFilters.tagSlugs] is non-empty: resolve the
  ///    matching event-id set via [EventTagRepository], once.
  /// 3. If [EventDiscoveryFilters.social] is non-empty and [userId] is
  ///    non-null: resolve the qualifying event-id set via the exact same
  ///    batched calls [EventDiscoveryService.rankForDiscovery] itself
  ///    uses for its own Friend Going/Interested/Followed Host signals.
  /// 4. [applyDiscoveryFilters] — the single authoritative, pure
  ///    predicate (`event_discovery_filtering.dart`) — narrows the
  ///    candidate list using the id sets resolved above.
  /// 5. The filtered list — and ONLY the filtered list — is handed to
  ///    [EventDiscoveryService.rankForDiscovery], completely unmodified.
  ///    A filtered-out Event never reaches ranking; a filtered-IN Event's
  ///    [EventDiscoveryItem.primaryReason] is computed exactly as it
  ///    would be with no filter active at all — filtering never invents,
  ///    suppresses, or overrides a relevance reason (Phase B §15).
  ///
  /// Failure isolation (Phase C §19 — mandatory now that this method has a
  /// live UI caller, unlike Phase B where it did not): step 1's base
  /// `eventsRepo.loadEvents` failure propagates unwrapped — an empty
  /// [filters] never reaches step 2/3 at all, so a taxonomy/social outage
  /// can never break the base feed when no such filter is even active
  /// (§19's "EMPTY FILTER" rule, true by construction — the calls below
  /// are simply never made). Steps 2/3 (Theme/Social resolution), ONLY
  /// reached when that dimension is genuinely active, are wrapped in
  /// try/catch that rethrows as [EventFilterResolutionException] rather
  /// than either propagating a raw backend error or silently degrading to
  /// an empty matching set (which would either crash the UI with an
  /// unrecognized exception type, or — worse — read as "zero results
  /// match," indistinguishable from an honest zero-result filter outcome,
  /// exactly the false impression §19 forbids).
  Future<List<EventDiscoveryItem>> loadFilteredDiscovery({
    required EventDiscoveryFilters filters,
    required String? userId,
    DateTime? from,
    DateTime? to,
    String query = '',
    // Events V2 Near Me Phase N2.3 — the already-resolved Near-me location
    // (EventsScreen's own `_location.nearMe`, never computed here: this
    // service never requests permission, calls a location provider, or
    // performs its own distance math — it simply forwards whatever it was
    // given straight into `applyDiscoveryFilters`'s already-existing
    // `nearMeLocation` parameter, exactly like `filters` itself is already
    // forwarded unchanged).
    EventNearMeLocation? nearMeLocation,
  }) async {
    final events = await eventsRepo.loadEvents(
      from: from,
      to: to,
      countryCodes: filters.countryCodes.isEmpty ? null : filters.countryCodes,
      eventTypes: filters.eventTypes.isEmpty ? null : filters.eventTypes,
      query: query,
    );

    if ((filters.isEmpty && nearMeLocation == null) || events.isEmpty) {
      return discoveryService.rankForDiscovery(events: events, userId: userId);
    }

    Set<String> tagMatchingIds = const {};
    if (filters.tagSlugs.isNotEmpty) {
      try {
        tagMatchingIds = await tagRepo.loadEventIdsForTagSlugs(
          filters.tagSlugs,
        );
      } catch (_) {
        throw const EventFilterResolutionException(
          'Could not apply your theme filter right now.',
        );
      }
    }

    Set<String> socialQualifyingIds = const {};
    if (filters.social.isNotEmpty && userId != null) {
      try {
        socialQualifyingIds = await _resolveSocialQualifyingIds(
          social: filters.social,
          eventIds: [for (final event in events) event.id],
          userId: userId,
        );
      } catch (_) {
        throw const EventFilterResolutionException(
          'Could not apply your social filter right now.',
        );
      }
    }

    final filtered = applyDiscoveryFilters(
      events: events,
      filters: filters,
      userSignedIn: userId != null,
      tagMatchingEventIds: tagMatchingIds,
      socialQualifyingEventIds: socialQualifyingIds,
      nearMeLocation: nearMeLocation,
    );

    return discoveryService.rankForDiscovery(events: filtered, userId: userId);
  }

  // Bounded, batched, per-source-independent — the same shape
  // EventDiscoveryService.rankForDiscovery already uses for its own
  // signal resolution, reused here rather than re-implemented. Friends
  // are fetched once and reused for both Going and Interested (never
  // twice), matching resolveSocialQualifyingEventIds's own single-
  // friends-list contract.
  Future<Set<String>> _resolveSocialQualifyingIds({
    required Set<EventSocialFilter> social,
    required List<String> eventIds,
    required String userId,
  }) async {
    final needsGoing = social.contains(EventSocialFilter.friendsGoing);
    final needsInterested = social.contains(
      EventSocialFilter.friendsInterested,
    );
    final needsFollowing = social.contains(EventSocialFilter.following);

    final goingFuture = needsGoing
        ? attendanceRepo.getVisibleUserIdsForEvents(
            eventIds: eventIds,
            status: EventIntentStatus.going,
          )
        : Future.value(const <String, List<String>>{});
    final interestedFuture = needsInterested
        ? attendanceRepo.getVisibleUserIdsForEvents(
            eventIds: eventIds,
            status: EventIntentStatus.interested,
          )
        : Future.value(const <String, List<String>>{});
    final friendsFuture = (needsGoing || needsInterested)
        ? friendshipRepo.getFriends()
        : Future.value(const <Friendship>[]);
    final followedHostFuture = needsFollowing
        ? hostFollowRepo.getFollowedHostEventNames(
            userId: userId,
            eventIds: eventIds,
          )
        : Future.value(const <String, String?>{});

    final going = await goingFuture;
    final interested = await interestedFuture;
    final friends = await friendsFuture;
    final followedHostNames = await followedHostFuture;

    return resolveSocialQualifyingEventIds(
      social: social,
      eventIds: eventIds,
      goingUserIdsByEvent: going,
      interestedUserIdsByEvent: interested,
      friends: friends,
      selfUserId: userId,
      followedHostNamesByEvent: followedHostNames,
    );
  }
}
