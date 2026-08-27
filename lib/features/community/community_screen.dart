import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/analytics/analytics_properties.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/star_row.dart';
import '../../core/widgets/venue_thumbnail.dart';
import '../../data/repositories/event_social_repository.dart';
import '../../data/repositories/events_repository.dart';
import '../../data/repositories/friendship_repository.dart';
import '../../data/repositories/rankings_repository.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../../models/event.dart';
import '../../models/friendship.dart';
import '../../models/going_member_count.dart';
import '../../models/ranking_entry.dart';
import '../../models/restaurant.dart';
import '../events/event_detail_screen.dart';
import '../events/events_screen.dart';
import '../friends/add_friend_screen.dart';
import '../friends/friend_profile_screen.dart';
import '../friends/friends_screen.dart';
import '../restaurants/restaurant_detail_screen.dart';
import 'community_rankings_screen.dart';
import 'dining_together_screen.dart';
import 'widgets/community_events_preview.dart';
import 'widgets/community_local_tab_bar.dart';
import 'widgets/community_ranking_preview.dart';
import 'widgets/community_shared.dart';
import 'widgets/friends_circle_row.dart';

/// Community — Navigation & Information Architecture V2's fourth primary
/// destination. "What are other Mantelier members interested in?"
///
/// COMMUNITY & FRIENDS FOUNDATION V1: introduces two local top-level tabs
/// — COMMUNITY (discovery/activity across the wider Mantelier
/// community) and FRIENDS (personal activity from people the user
/// follows) — the same persistent-local-tab pattern Passport's own
/// PASSPORT/WISHLIST/RANKING/TRIPS subsections already established:
/// switching never pushes a route, never leaves this screen, and
/// Community stays the selected bottom-nav destination for both. This
/// does NOT rename or replace the existing standalone Friends feature
/// (`lib/features/friends/`, still reachable from Profile) — FRIENDS here
/// is a new, additional entry point built entirely on that same existing
/// `FriendshipRepository`/`Friendship` data, never a parallel source.
/// See `docs/Architecture/COMMUNITY_FRIENDS_UX.md` for that feature's own
/// prior architecture and its Step 1 decision to keep "Friends" (not
/// "Community") as the social feature's own label — this task's own
/// brief supersedes that naming note by design, folding both concepts
/// under one Community destination with an explicit internal split.
///
/// A bottom-tab body (no own `Scaffold`, matching `ExploreScreen`/
/// `PassportScreen`'s established convention).
class CommunityScreen extends StatefulWidget {
  final Future<List<CommunityRankingEntry>> Function()? loadCommunityRankings;
  final Future<Restaurant?> Function(String id)? getRestaurantById;
  final Future<List<Event>> Function()? loadUpcomingEvents;
  final Future<GoingMemberCount> Function(String eventId)? loadGoingMemberCount;
  final Future<List<Friendship>> Function()? loadFriends;

  const CommunityScreen({
    super.key,
    this.loadCommunityRankings,
    this.getRestaurantById,
    this.loadUpcomingEvents,
    this.loadGoingMemberCount,
    this.loadFriends,
  });

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  CommunityTopTab _tab = CommunityTopTab.community;

  // Lazily populated as each tab is first visited, then cached for the
  // lifetime of this screen — the same IndexedStack-caching pattern
  // PassportScreen's own four subsections already use, so switching
  // Community ↔ Friends never re-fetches or loses scroll position once
  // visited once.
  late final Map<CommunityTopTab, Widget> _bodies = {
    CommunityTopTab.community: _CommunityTabBody(
      loadCommunityRankings: widget.loadCommunityRankings,
      getRestaurantById: widget.getRestaurantById,
      loadUpcomingEvents: widget.loadUpcomingEvents,
      loadGoingMemberCount: widget.loadGoingMemberCount,
    ),
  };

  void _selectTab(CommunityTopTab tab) {
    setState(() {
      _tab = tab;
      _bodies.putIfAbsent(
        tab,
        () => tab == CommunityTopTab.friends
            ? _FriendsTabBody(loadFriends: widget.loadFriends)
            : _CommunityTabBody(
                loadCommunityRankings: widget.loadCommunityRankings,
                getRestaurantById: widget.getRestaurantById,
                loadUpcomingEvents: widget.loadUpcomingEvents,
                loadGoingMemberCount: widget.loadGoingMemberCount,
              ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.deepGreen,
    child: Column(
      // Header Alignment Fix (unchanged reasoning): stretch forces every
      // direct child to the full tight width, so the header/tab-bar
      // Columns/Rows left-align against real bounds instead of shrinking
      // to their own widest line.
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              CsSpacing.pageHorizontal,
              CsSpacing.lg,
              CsSpacing.pageHorizontal,
              CsSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Community',
                  style: CsTypography.screenTitle.copyWith(
                    color: AppColors.ivory,
                  ),
                ),
                const SizedBox(height: CsSpacing.xs),
                Text(
                  'Connect, follow and explore together.',
                  style: CsTypography.body.copyWith(
                    color: AppColors.secondaryOnDark,
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            CsSpacing.pageHorizontal,
            0,
            CsSpacing.pageHorizontal,
            0,
          ),
          child: CommunityLocalTabBar(selected: _tab, onSelect: _selectTab),
        ),
        Expanded(
          child: IndexedStack(
            index: _tab.index,
            children: [
              for (final tab in CommunityTopTab.values)
                _bodies[tab] ?? const SizedBox.shrink(),
            ],
          ),
        ),
      ],
    ),
  );
}

// ── COMMUNITY tab ───────────────────────────────────────────────────────

/// Bundles a fetched Upcoming Events preview with the real, anonymous
/// Going count for each — fetched together so the combined result can be
/// memoized behind one `late final Future`, never re-fetched on rebuild.
class _EventsWithGoingCounts {
  final List<Event> events;
  final Map<String, GoingMemberCount> goingCounts;
  const _EventsWithGoingCounts(this.events, this.goingCounts);
}

class _CommunityTabBody extends StatefulWidget {
  final Future<List<CommunityRankingEntry>> Function()? loadCommunityRankings;
  final Future<Restaurant?> Function(String id)? getRestaurantById;
  final Future<List<Event>> Function()? loadUpcomingEvents;
  final Future<GoingMemberCount> Function(String eventId)? loadGoingMemberCount;

  const _CommunityTabBody({
    this.loadCommunityRankings,
    this.getRestaurantById,
    this.loadUpcomingEvents,
    this.loadGoingMemberCount,
  });

  @override
  State<_CommunityTabBody> createState() => _CommunityTabBodyState();
}

class _CommunityTabBodyState extends State<_CommunityTabBody> {
  // Hottest Places and the new Community Ranking preview both read the
  // exact same already-sorted (community_rating DESC) source — one fetch,
  // never two competing queries against the same view.
  late final Future<List<CommunityRankingEntry>> _rankingsFuture =
      _loadRankings();
  late final Future<_EventsWithGoingCounts> _eventsFuture =
      _loadEventsWithGoing();

  Future<List<CommunityRankingEntry>> _loadRankings() async {
    try {
      final load =
          widget.loadCommunityRankings ??
          RankingsRepository(Supabase.instance.client).getCommunityRankings;
      return await load();
    } catch (_) {
      // Graceful omission, never a raw error surfaced on these sections —
      // matches this screen's own established Hottest Places behavior.
      return const [];
    }
  }

  Future<_EventsWithGoingCounts> _loadEventsWithGoing() async {
    List<Event> events;
    try {
      final load =
          widget.loadUpcomingEvents ??
          () => EventsRepository(
            Supabase.instance.client,
          ).loadEvents(from: DateTime.now());
      events = await load();
    } catch (_) {
      return const _EventsWithGoingCounts([], {});
    }
    if (events.isEmpty) return _EventsWithGoingCounts(events, const {});

    // The events LIST itself must never depend on the Going-count signal
    // resolving — everything below (including constructing the fallback
    // repository) is scoped to its own try/catch so a failure here only
    // ever costs the "N going" line on affected cards, never the events
    // themselves.
    final preview = events.take(3).toList();
    Map<String, GoingMemberCount> goingCounts = const {};
    try {
      final loadGoing =
          widget.loadGoingMemberCount ??
          EventSocialRepository(Supabase.instance.client).getGoingMemberCount;
      final results = await Future.wait(
        preview.map((event) async {
          try {
            return MapEntry(event.id, await loadGoing(event.id));
          } catch (_) {
            // A single event's Going count failing to load never blocks
            // the rest of the preview — that event's line simply omits it.
            return null;
          }
        }),
      );
      goingCounts = {
        for (final r in results)
          if (r != null) r.key: r.value,
      };
    } catch (_) {
      // loadGoing itself failed to construct (e.g. no live Supabase
      // session) — every card just omits its Going line.
    }
    return _EventsWithGoingCounts(events, goingCounts);
  }

  Future<void> _openRestaurant(String restaurantId) async {
    final getById =
        widget.getRestaurantById ??
        RestaurantRepository(Supabase.instance.client).getById;
    final restaurant = await getById(restaurantId);
    if (!mounted || restaurant == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RestaurantDetailScreen(restaurant: restaurant),
      ),
    );
  }

  void _openCommunityRankings() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const CommunityRankingsScreen()),
  );

  void _openDiningTogether() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const DiningTogetherScreen()),
  );

  void _openEvent(Event event) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => EventDetailScreen(
        eventId: event.id,
        sourceSurface: AnalyticsSourceSurface.discover,
      ),
    ),
  );

  void _openEventsScreen() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const EventsScreen()),
  );

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(
      CsSpacing.pageHorizontal,
      CsSpacing.lg,
      CsSpacing.pageHorizontal,
      CsSpacing.section,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FutureBuilder<List<CommunityRankingEntry>>(
          future: _rankingsFuture,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done ||
                (snap.data ?? const []).isEmpty) {
              // Loading or genuinely empty — omit the whole section
              // rather than show a heading over nothing.
              return const SizedBox.shrink();
            }
            final hottest = snap.data!.first;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CommunitySectionTitle('Hottest Places'),
                const SizedBox(height: CsSpacing.sm),
                _HottestPlacesRestaurantCard(
                  entry: hottest,
                  onTap: () => _openRestaurant(hottest.restaurantId),
                ),
                const SizedBox(height: CsSpacing.section),
              ],
            );
          },
        ),
        CommunitySectionTitle('Community Ranking'),
        const SizedBox(height: CsSpacing.sm),
        FutureBuilder<List<CommunityRankingEntry>>(
          future: _rankingsFuture,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const _SectionLoading();
            }
            return CommunityRankingPreview(
              entries: snap.data ?? const [],
              onTapEntry: (entry) => _openRestaurant(entry.restaurantId),
              onSeeFullRanking: _openCommunityRankings,
            );
          },
        ),
        const SizedBox(height: CsSpacing.section),
        // Trending Now — COMMUNITY V1 UI REFINEMENT explicitly hides this
        // section entirely rather than showing a placeholder/"coming
        // soon" state: no canonical trending source exists yet, and a
        // fabricated empty feature reads as unfinished. The extension
        // point is ready — reinsert a `CommunitySectionTitle('Trending
        // Now')` + real content block here once a genuine trending
        // signal exists; do not resurrect the old placeholder text.
        CommunitySectionTitle('Upcoming Events'),
        const SizedBox(height: CsSpacing.sm),
        FutureBuilder<_EventsWithGoingCounts>(
          future: _eventsFuture,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const _SectionLoading();
            }
            final data = snap.data ?? const _EventsWithGoingCounts([], {});
            return CommunityEventsPreview(
              events: data.events,
              goingCounts: data.goingCounts,
              onTapEvent: _openEvent,
              onSeeAll: data.events.isEmpty ? null : _openEventsScreen,
            );
          },
        ),
        const SizedBox(height: CsSpacing.section),
        // Recently Discovered — same reasoning as Trending Now above: no
        // canonical "recently discovered" source exists yet, so this
        // section is hidden entirely rather than shown empty. Reinsert a
        // `CommunitySectionTitle('Recently Discovered')` + real content
        // block once a genuine source exists.
        //
        // "Meet the Community" is deliberately absent — no genuine
        // editorial/user-story content exists yet (unchanged from before
        // this pass).
        CommunitySectionTitle('Dining Together'),
        const SizedBox(height: CsSpacing.xs),
        Text(
          'Great tables are better shared.',
          style: CsTypography.body.copyWith(color: AppColors.secondaryOnDark),
        ),
        const SizedBox(height: CsSpacing.sm),
        CommunityActionLink(
          label: 'Discover the concept',
          onTap: _openDiningTogether,
        ),
      ],
    ),
  );
}

class _SectionLoading extends StatelessWidget {
  const _SectionLoading();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: CsSpacing.md),
    child: Center(
      child: CircularProgressIndicator(
        color: AppColors.secondaryOnDark,
        strokeWidth: 1.5,
      ),
    ),
  );
}

/// Community's editorial hero — the community's highest-rated restaurant,
/// via the same real `restaurant_rankings` view `CommunityRankingsTab`
/// already reads. Deliberately not styled as a generic Material dashboard
/// card: dark-canvas editorial treatment (VenueThumbnail, serif name,
/// StarRow — gold there is correct, it's the Michelin-star signal —
/// everything else ivory/secondaryOnDark, never gold on the rating
/// numeral itself).
class _HottestPlacesRestaurantCard extends StatelessWidget {
  final CommunityRankingEntry entry;
  final VoidCallback onTap;

  const _HottestPlacesRestaurantCard({
    required this.entry,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label:
        '${entry.name}, ${entry.city}. Highest rated by the community, '
        '${entry.communityRating.toStringAsFixed(1)}.',
    excludeSemantics: true,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CsRadius.medium),
        child: Container(
          padding: const EdgeInsets.all(CsSpacing.base),
          decoration: BoxDecoration(
            color: AppColors.brandGreenLight,
            borderRadius: BorderRadius.circular(CsRadius.medium),
            border: Border.all(color: AppColors.subtleBorderDark),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const VenueThumbnail(imageUrl: null, size: 64),
              const SizedBox(width: CsSpacing.base),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RESTAURANT',
                      style: CsTypography.eyebrow.copyWith(
                        color: AppColors.secondaryOnDark,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CsTypography.placeTitle.copyWith(
                        color: AppColors.textOnDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (entry.michelinStars > 0) ...[
                          StarRow(count: entry.michelinStars, size: 12),
                          const SizedBox(width: CsSpacing.xs),
                        ],
                        Flexible(
                          child: Text(
                            '${entry.countryFlag} ${entry.city}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: CsTypography.metadata.copyWith(
                              color: AppColors.secondaryOnDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: CsSpacing.xs),
                    Text(
                      'Highest rated by the community',
                      style: CsTypography.metadata.copyWith(
                        color: AppColors.secondaryOnDark,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: CsSpacing.sm),
              Text(
                entry.communityRating.toStringAsFixed(1),
                style: CsTypography.largeMetric.copyWith(
                  color: AppColors.ivory,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// ── FRIENDS tab ─────────────────────────────────────────────────────────

class _FriendsTabBody extends StatefulWidget {
  final Future<List<Friendship>> Function()? loadFriends;
  const _FriendsTabBody({this.loadFriends});

  @override
  State<_FriendsTabBody> createState() => _FriendsTabBodyState();
}

class _FriendsTabBodyState extends State<_FriendsTabBody> {
  late final Future<List<Friendship>> _friendsFuture = _load();

  Future<List<Friendship>> _load() async {
    try {
      final load =
          widget.loadFriends ??
          FriendshipRepository(Supabase.instance.client).getFriends;
      return await load();
    } catch (_) {
      return const [];
    }
  }

  void _openFriendProfile(Friendship friend) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => FriendProfileScreen(userId: friend.friendId),
    ),
  );

  void _openFriendsScreen() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const FriendsScreen()),
  );

  void _openAddFriend() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const AddFriendScreen()),
  );

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(
      CsSpacing.pageHorizontal,
      CsSpacing.lg,
      CsSpacing.pageHorizontal,
      CsSpacing.section,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CommunitySectionTitle('Your Circle'),
        const SizedBox(height: CsSpacing.sm),
        FutureBuilder<List<Friendship>>(
          future: _friendsFuture,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const _SectionLoading();
            }
            return FriendsCircleRow(
              friends: snap.data ?? const [],
              onTapFriend: _openFriendProfile,
              onSeeAll: _openFriendsScreen,
              onFindPeople: _openAddFriend,
            );
          },
        ),
        const SizedBox(height: CsSpacing.section),
        CommunitySectionTitle("Friends' Activity"),
        const SizedBox(height: CsSpacing.sm),
        // Cross-friend activity aggregation is a genuinely new capability
        // — every existing repository (VisitedRepository/WishlistRepository/
        // EventAttendanceRepository) answers "one friend's own activity,"
        // never "everyone I follow, merged and sorted." Building that is
        // explicitly out of this pass's scope (Foundation V1 §10) — a
        // restrained foundation empty state, never fabricated activity.
        const CommunityEmptyNote(
          message: 'Activity from your friends will appear here.',
        ),
        const SizedBox(height: CsSpacing.section),
        CommunitySectionTitle("Friends' Top Visited"),
        const SizedBox(height: CsSpacing.sm),
        // Same reasoning as Friends' Activity — deriving "places popular
        // with your friends" needs a new cross-friend aggregation this
        // pass deliberately doesn't build.
        const CommunityEmptyNote(
          message: 'Places popular with your friends will appear here.',
        ),
      ],
    ),
  );
}
