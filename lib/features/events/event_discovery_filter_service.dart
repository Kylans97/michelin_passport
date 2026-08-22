import '../../data/repositories/event_attendance_repository.dart';
import '../../data/repositories/event_host_follow_repository.dart';
import '../../data/repositories/event_tag_repository.dart';
import '../../data/repositories/events_repository.dart';
import '../../data/repositories/friendship_repository.dart';
import '../../models/event_attendance.dart';
import '../../models/event_discovery_filters.dart';
import '../../models/event_discovery_item.dart';
import '../../models/friendship.dart';
import 'event_discovery_filtering.dart';
import 'event_discovery_service.dart';

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
  Future<List<EventDiscoveryItem>> loadFilteredDiscovery({
    required EventDiscoveryFilters filters,
    required String? userId,
    DateTime? from,
    DateTime? to,
    String query = '',
  }) async {
    final events = await eventsRepo.loadEvents(
      from: from,
      to: to,
      countryCodes: filters.countryCodes.isEmpty ? null : filters.countryCodes,
      eventTypes: filters.eventTypes.isEmpty ? null : filters.eventTypes,
      query: query,
    );

    if (filters.isEmpty || events.isEmpty) {
      return discoveryService.rankForDiscovery(events: events, userId: userId);
    }

    final tagMatchingIds = filters.tagSlugs.isEmpty
        ? const <String>{}
        : await tagRepo.loadEventIdsForTagSlugs(filters.tagSlugs);

    Set<String> socialQualifyingIds = const {};
    if (filters.social.isNotEmpty && userId != null) {
      socialQualifyingIds = await _resolveSocialQualifyingIds(
        social: filters.social,
        eventIds: [for (final event in events) event.id],
        userId: userId,
      );
    }

    final filtered = applyDiscoveryFilters(
      events: events,
      filters: filters,
      userSignedIn: userId != null,
      tagMatchingEventIds: tagMatchingIds,
      socialQualifyingEventIds: socialQualifyingIds,
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
