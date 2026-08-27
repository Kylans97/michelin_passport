// COMMUNITY & FRIENDS FOUNDATION V1, refined by COMMUNITY V1 UI
// REFINEMENT: covers the COMMUNITY/FRIENDS local tab split inside
// CommunityScreen, the Friends tab's zero-friends foundation state (now
// an ivory onboarding card for Your Circle), Community's Community
// Ranking feature card / Upcoming Events preview (with its "See all"
// link to the existing EventsScreen), the deliberate absence of Trending
// Now/Recently Discovered (no canonical data source exists yet), and
// canonical navigation for every populated section.
// CommunityScreen injects loadCommunityRankings/getRestaurantById/
// loadUpcomingEvents/loadGoingMemberCount/loadFriends — the REAL widget is
// pumped directly with hand-rolled fakes, no mirrored copy of its build()
// method, matching this file's own established DI-seam convention (see
// community_screen_shell_test.dart's own note on why a mirror can't catch
// production defects a real-widget test can).
//
// Several destinations here (RestaurantDetailScreen/EventDetailScreen/
// FriendProfileScreen/FriendsScreen/AddFriendScreen) are Supabase-eager in
// their own initState, so a real push that lets Flutter mount them would
// crash under test with no live session — the same established limitation
// documented throughout this app's test suite. `_CapturingObserver`
// (mirrors event_friends_going_section_test.dart's own identical pattern)
// captures the pushed route the moment Navigator.push registers it
// (synchronous, before any frame is drawn) so the route's own builder can
// be called directly to inspect the widget it would produce, without ever
// mounting it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/features/community/community_screen.dart';
import 'package:michelin_passport/features/community/community_rankings_screen.dart';
import 'package:michelin_passport/features/events/event_detail_screen.dart';
import 'package:michelin_passport/features/events/events_screen.dart';
import 'package:michelin_passport/features/friends/add_friend_screen.dart';
import 'package:michelin_passport/features/friends/friend_profile_screen.dart';
import 'package:michelin_passport/features/friends/friends_screen.dart';
import 'package:michelin_passport/features/restaurants/restaurant_detail_screen.dart';
import 'package:michelin_passport/models/event.dart';
import 'package:michelin_passport/models/friendship.dart';
import 'package:michelin_passport/models/going_member_count.dart';
import 'package:michelin_passport/models/ranking_entry.dart';
import 'package:michelin_passport/models/restaurant.dart';

class _CapturingObserver extends NavigatorObserver {
  Route<dynamic>? pushed;
  int pushCount = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushCount++;
    pushed = route;
  }
}

CommunityRankingEntry _rankingEntry({
  String id = 'r1',
  String name = 'Maison Verte',
  double rating = 4.8,
  int stars = 2,
}) => CommunityRankingEntry(
  restaurantId: id,
  name: name,
  city: 'Paris',
  countryFlag: '🇫🇷',
  michelinStars: stars,
  communityRating: rating,
  totalVisits: 42,
);

Restaurant _restaurant({String id = 'r1', String name = 'Maison Verte'}) =>
    Restaurant(
      id: id,
      restaurantCode: id,
      name: name,
      michelinStars: null,
      inclusionReason: 'michelin_star',
      cityName: 'Paris',
      countryCode: 'FR',
      countryName: 'France',
      flagEmoji: '🇫🇷',
      address: '1 Rue de Test',
    );

Event _event({
  String id = 'e1',
  String name = "'t Preuvenemint",
  DateTime? startDate,
  DateTime? endDate,
}) => Event(
  id: id,
  name: name,
  startDate: startDate ?? DateTime.utc(2026, 8, 27),
  endDate: endDate ?? DateTime.utc(2026, 8, 31),
  countryCode: 'NL',
  city: 'Maastricht',
  eventType: EventType.festival,
  status: EventStatus.upcoming,
  createdAt: DateTime(2026, 1, 1),
);

Friendship _friendship({
  String friendshipId = 'f1',
  String friendId = 'u2',
  String displayName = 'Ada Boone',
}) => Friendship(
  friendshipId: friendshipId,
  friendId: friendId,
  displayName: displayName,
  username: 'adaboone',
);

Widget _wrap({
  Future<List<CommunityRankingEntry>> Function()? loadCommunityRankings,
  Future<Restaurant?> Function(String id)? getRestaurantById,
  Future<List<Event>> Function()? loadUpcomingEvents,
  Future<GoingMemberCount> Function(String eventId)? loadGoingMemberCount,
  Future<List<Friendship>> Function()? loadFriends,
  NavigatorObserver? observer,
}) => MaterialApp(
  navigatorObservers: [?observer],
  home: CommunityScreen(
    loadCommunityRankings: loadCommunityRankings ?? () async => [],
    getRestaurantById: getRestaurantById,
    loadUpcomingEvents: loadUpcomingEvents ?? () async => [],
    loadGoingMemberCount: loadGoingMemberCount,
    loadFriends: loadFriends ?? () async => [],
  ),
);

void main() {
  group('COMMUNITY / FRIENDS tabs', () {
    testWidgets('Community tab renders by default', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('Community Ranking'), findsOneWidget);
      expect(find.text('Upcoming Events'), findsOneWidget);
      // Trending Now / Recently Discovered have no canonical data source
      // yet — COMMUNITY V1 UI REFINEMENT hides them entirely rather than
      // showing a placeholder.
      expect(find.text('Trending Now'), findsNothing);
      expect(find.text('Recently Discovered'), findsNothing);
      expect(find.byType(IndexedStack), findsOneWidget);
      expect(
        tester.widget<IndexedStack>(find.byType(IndexedStack)).index,
        0,
      );
    });

    testWidgets('Friends tab renders once selected', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      await tester.tap(find.text('FRIENDS'));
      await tester.pumpAndSettle();
      expect(find.text('Your Circle'), findsOneWidget);
      expect(find.text("Friends' Activity"), findsOneWidget);
      expect(find.text("Friends' Top Visited"), findsOneWidget);
      expect(
        tester.widget<IndexedStack>(find.byType(IndexedStack)).index,
        1,
      );
    });

    testWidgets('tab switching swaps content back and forth, never pushes '
        'a route (Community remains the selected bottom-nav destination)', (
      tester,
    ) async {
      final observer = _CapturingObserver();
      await tester.pumpWidget(_wrap(observer: observer));
      await tester.pumpAndSettle();

      await tester.tap(find.text('FRIENDS'));
      await tester.pumpAndSettle();
      expect(find.text('Your Circle'), findsOneWidget);

      await tester.tap(find.text('COMMUNITY'));
      await tester.pumpAndSettle();
      expect(find.text('Community Ranking'), findsOneWidget);

      // Only the implicit initial MaterialApp route — switching tabs
      // never registers an additional push.
      expect(observer.pushCount, 1);
    });
  });

  group('FRIENDS tab — zero friends', () {
    testWidgets('all three sections remain visible with zero friends — '
        'never hidden just because they are empty', (tester) async {
      await tester.pumpWidget(_wrap(loadFriends: () async => []));
      await tester.pumpAndSettle();
      await tester.tap(find.text('FRIENDS'));
      await tester.pumpAndSettle();

      expect(find.text('Your Circle'), findsOneWidget);
      expect(find.text('Your circle is still empty.'), findsOneWidget);
      expect(
        find.text(
          "Connect with other members to see what they're discovering.",
        ),
        findsOneWidget,
      );
      expect(find.text('Find friends'), findsOneWidget);

      expect(find.text("Friends' Activity"), findsOneWidget);
      expect(
        find.text('Activity from your friends will appear here.'),
        findsOneWidget,
      );

      expect(find.text("Friends' Top Visited"), findsOneWidget);
      expect(
        find.text('Places popular with your friends will appear here.'),
        findsOneWidget,
      );
    });

    testWidgets('zero-friends state contains no fake/hardcoded people', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(loadFriends: () async => []));
      await tester.pumpAndSettle();
      await tester.tap(find.text('FRIENDS'));
      await tester.pumpAndSettle();

      for (final fakeName in ['Ward', 'Max', 'Ruud']) {
        expect(find.textContaining(fakeName), findsNothing);
      }
    });

    testWidgets('"Find friends" opens the existing AddFriendScreen', (
      tester,
    ) async {
      final observer = _CapturingObserver();
      await tester.pumpWidget(
        _wrap(loadFriends: () async => [], observer: observer),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('FRIENDS'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Find friends'));
      await tester.pump();
      final route = observer.pushed! as MaterialPageRoute<dynamic>;
      final widget = route.builder(tester.element(find.byType(MaterialApp)));
      expect(widget, isA<AddFriendScreen>());
    });
  });

  group('FRIENDS tab — populated circle, canonical navigation', () {
    testWidgets('a real friend renders in Your Circle and opens the '
        'canonical FriendProfileScreen for that exact friend', (
      tester,
    ) async {
      final observer = _CapturingObserver();
      await tester.pumpWidget(
        _wrap(
          loadFriends: () async => [_friendship()],
          observer: observer,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('FRIENDS'));
      await tester.pumpAndSettle();

      expect(find.text('Your circle is still empty.'), findsNothing);
      expect(find.text('Ada'), findsOneWidget); // first-name tile label
      expect(find.text('See all'), findsOneWidget);

      // Deliberately no pump() between tap and reading observer.pushed —
      // Navigator.push registers its route (and fires didPush)
      // synchronously as part of the tap's own gesture dispatch;
      // pumping any further would let the framework actually build/mount
      // FriendProfileScreen, which is Supabase-eager in initState and
      // would crash with no live session.
      await tester.tap(find.text('Ada'));
      final route = observer.pushed! as MaterialPageRoute<dynamic>;
      final widget =
          route.builder(tester.element(find.byType(MaterialApp)))
              as FriendProfileScreen;
      expect(widget.userId, 'u2');
    });

    testWidgets('"See all" opens the existing FriendsScreen', (tester) async {
      final observer = _CapturingObserver();
      await tester.pumpWidget(
        _wrap(
          loadFriends: () async => [_friendship()],
          observer: observer,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('FRIENDS'));
      await tester.pumpAndSettle();

      // No pump() — see the matching note on the FriendProfileScreen test
      // above; FriendsScreen is equally Supabase-eager.
      await tester.tap(find.text('See all'));
      final route = observer.pushed! as MaterialPageRoute<dynamic>;
      final widget = route.builder(tester.element(find.byType(MaterialApp)));
      expect(widget, isA<FriendsScreen>());
    });
  });

  group('Community Ranking preview', () {
    testWidgets('renders the real ordered entries from the existing '
        'Community Ranking source — never recomputed here', (tester) async {
      await tester.pumpWidget(
        _wrap(
          loadCommunityRankings: () async => [
            _rankingEntry(id: 'r1', name: 'First Place', rating: 4.9),
            _rankingEntry(id: 'r2', name: 'Second Place', rating: 4.7),
            _rankingEntry(id: 'r3', name: 'Third Place', rating: 4.5),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1'), findsOneWidget);
      expect(find.text('First Place'), findsWidgets); // hero + preview
      expect(find.text('2'), findsOneWidget);
      expect(find.text('Second Place'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('Third Place'), findsOneWidget);
      expect(find.text('See full ranking'), findsOneWidget);
    });

    testWidgets('a 4th+ entry never renders in the compact preview', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          loadCommunityRankings: () async => [
            _rankingEntry(id: 'r1', name: 'First Place'),
            _rankingEntry(id: 'r2', name: 'Second Place'),
            _rankingEntry(id: 'r3', name: 'Third Place'),
            _rankingEntry(id: 'r4', name: 'Fourth Place'),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Fourth Place'), findsNothing);
    });

    testWidgets('zero qualifying restaurants shows a restrained empty '
        'state, never fake ranking rows', (tester) async {
      await tester.pumpWidget(_wrap(loadCommunityRankings: () async => []));
      await tester.pumpAndSettle();
      expect(
        find.text('No restaurants have qualified yet.'),
        findsOneWidget,
      );
      expect(find.text('See full ranking'), findsOneWidget);
    });

    testWidgets('tapping a preview row looks up the exact tapped '
        'restaurant and opens the canonical RestaurantDetailScreen', (
      tester,
    ) async {
      final observer = _CapturingObserver();
      var lookedUpId = '';
      await tester.pumpWidget(
        _wrap(
          loadCommunityRankings: () async => [_rankingEntry()],
          getRestaurantById: (id) async {
            lookedUpId = id;
            return _restaurant();
          },
          observer: observer,
        ),
      );
      await tester.pumpAndSettle();

      // _openRestaurant awaits getRestaurantById before pushing — no
      // pump() here (only the microtask-flushing tap() itself already
      // performs): a real pump would let the framework actually build
      // RestaurantDetailScreen, which is Supabase-eager and would crash
      // with no live session. Inspecting observer.pushed/route.builder()
      // directly never mounts anything.
      await tester.tap(find.text('Maison Verte').first);

      expect(lookedUpId, 'r1');
      final route = observer.pushed! as MaterialPageRoute<dynamic>;
      final widget = route.builder(tester.element(find.byType(MaterialApp)));
      expect(widget, isA<RestaurantDetailScreen>());
    });

    testWidgets('"See full ranking" opens the existing '
        'CommunityRankingsScreen', (tester) async {
      final observer = _CapturingObserver();
      await tester.pumpWidget(
        _wrap(loadCommunityRankings: () async => [], observer: observer),
      );
      await tester.pumpAndSettle();

      // No pump() — CommunityRankingsScreen embeds the Supabase-eager
      // CommunityRankingsTab.
      await tester.tap(find.text('See full ranking'));
      final route = observer.pushed! as MaterialPageRoute<dynamic>;
      final widget = route.builder(tester.element(find.byType(MaterialApp)));
      expect(widget, isA<CommunityRankingsScreen>());
    });
  });

  group('Upcoming Events preview', () {
    testWidgets('no events scheduled shows a restrained empty state, '
        'never fake events, and no "See all" link with nothing to see', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(loadUpcomingEvents: () async => []));
      await tester.pumpAndSettle();
      expect(find.text('No upcoming events to show yet.'), findsOneWidget);
      expect(find.text('See all'), findsNothing);
    });

    testWidgets('a real event renders with its real Going count when the '
        'social signal is available', (tester) async {
      await tester.pumpWidget(
        _wrap(
          loadUpcomingEvents: () async => [_event()],
          loadGoingMemberCount: (id) async => const GoingMemberCount(12),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text("'t Preuvenemint"), findsOneWidget);
      expect(find.text('12 Mantelier members going'), findsOneWidget);
    });

    testWidgets('the Going-count RPC failing never crashes the section, '
        'and never fabricates a count', (tester) async {
      await tester.pumpWidget(
        _wrap(
          loadUpcomingEvents: () async => [_event()],
          loadGoingMemberCount: (id) async => throw Exception('rpc failed'),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text("'t Preuvenemint"), findsOneWidget);
      expect(find.textContaining('going'), findsNothing);
    });

    testWidgets('no fabricated "interested" count ever appears — no '
        'anonymous aggregate exists for it', (tester) async {
      await tester.pumpWidget(
        _wrap(
          loadUpcomingEvents: () async => [_event()],
          loadGoingMemberCount: (id) async => const GoingMemberCount(12),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('interested'), findsNothing);
      expect(find.textContaining('Interested'), findsNothing);
    });

    testWidgets('tapping an event opens the canonical EventDetailScreen '
        'for that exact event', (tester) async {
      final observer = _CapturingObserver();
      await tester.pumpWidget(
        _wrap(
          loadUpcomingEvents: () async => [_event(id: 'e42')],
          loadGoingMemberCount: (id) async => const GoingMemberCount(0),
          observer: observer,
        ),
      );
      await tester.pumpAndSettle();

      // No pump() after tap — EventDetailScreen is Supabase-eager.
      await tester.tap(find.text("'t Preuvenemint"));
      final route = observer.pushed! as MaterialPageRoute<dynamic>;
      final widget =
          route.builder(tester.element(find.byType(MaterialApp)))
              as EventDetailScreen;
      expect(widget.eventId, 'e42');
    });

    testWidgets('"See all" opens the existing EventsScreen when there are '
        'events to preview', (tester) async {
      final observer = _CapturingObserver();
      await tester.pumpWidget(
        _wrap(
          loadUpcomingEvents: () async => [_event()],
          loadGoingMemberCount: (id) async => const GoingMemberCount(0),
          observer: observer,
        ),
      );
      await tester.pumpAndSettle();

      // No pump() — EventsScreen is Supabase-eager in its own initState.
      await tester.tap(find.text('See all'));
      final route = observer.pushed! as MaterialPageRoute<dynamic>;
      final widget = route.builder(tester.element(find.byType(MaterialApp)));
      expect(widget, isA<EventsScreen>());
    });
  });

  group('visual regressions', () {
    testWidgets('deep-green remains the primary page background on both '
        'tabs', (tester) async {
      await tester.pumpWidget(
        _wrap(
          loadCommunityRankings: () async => [_rankingEntry()],
          loadFriends: () async => [_friendship()],
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (w) => w is ColoredBox && w.color == AppColors.deepGreen,
        ),
        findsWidgets,
      );

      await tester.tap(find.text('FRIENDS'));
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (w) => w is ColoredBox && w.color == AppColors.deepGreen,
        ),
        findsWidgets,
      );
    });

    testWidgets('no gold anywhere on either tab, fully populated', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          loadCommunityRankings: () async => [_rankingEntry()],
          loadUpcomingEvents: () async => [_event()],
          loadGoingMemberCount: (id) async => const GoingMemberCount(5),
        ),
      );
      await tester.pumpAndSettle();
      for (final text in tester.widgetList<Text>(find.byType(Text))) {
        expect(text.style?.color, isNot(AppColors.gold));
      }

      await tester.pumpWidget(_wrap(loadFriends: () async => [_friendship()]));
      await tester.pumpAndSettle();
      await tester.tap(find.text('FRIENDS'));
      await tester.pumpAndSettle();
      for (final text in tester.widgetList<Text>(find.byType(Text))) {
        expect(text.style?.color, isNot(AppColors.gold));
      }
    });
  });
}
