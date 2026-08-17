// Covers EventFriendsGoingSection and EventFriendsGoingListScreen
// (Community/Friends Step 1A). Both are plain presentational widgets that
// take an already-resolved `List<Friendship>` and touch Supabase nowhere —
// unlike EventDetailScreen itself (Supabase-in-initState, same established
// limitation as every other screen in this app — see
// event_detail_redesign_test.dart's own header comment), so these can be
// pumped directly rather than mirrored.
//
// The gating logic that decides *whether* this section is shown at all —
// omit while loading, omit on error, omit when the resolved list is empty,
// omit for a past/cancelled event via canAttendEvent (already covered by
// can_attend_event_test.dart) — lives inside
// _EventDetailScreenState._load()/build(), which is exactly the part of
// EventDetailScreen this project has no way to pump; that gating is
// reviewed by direct code inspection instead (see the implementation
// report), matching the same constraint the rest of this feature already
// documents.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/features/events/event_friends_going_list_screen.dart';
import 'package:michelin_passport/features/events/widgets/event_friends_going_section.dart';
import 'package:michelin_passport/features/friends/friend_profile_screen.dart';
import 'package:michelin_passport/models/friendship.dart';

Friendship _friend({
  required String id,
  required String name,
  String? username,
  String? avatarUrl,
}) => Friendship(
  friendshipId: 'fs-$id',
  friendId: id,
  displayName: name,
  username: username,
  avatarUrl: avatarUrl,
);

final _one = [_friend(id: 'f1', name: 'Amy Adams', username: 'amy')];
final _three = [
  _friend(id: 'f1', name: 'Amy Adams'),
  _friend(id: 'f2', name: 'Bo Baker'),
  _friend(id: 'f3', name: 'Cy Cole'),
];
final _four = [..._three, _friend(id: 'f4', name: 'Di Diaz')];

Widget _wrap(
  Widget child, {
  double width = 390,
  double textScale = 1.0,
  NavigatorObserver? observer,
}) => MaterialApp(
  navigatorObservers: [?observer],
  home: MediaQuery(
    data: MediaQueryData(
      size: Size(width, 800),
      textScaler: TextScaler.linear(textScale),
    ),
    child: Scaffold(backgroundColor: AppColors.ivory, body: child),
  ),
);

// FriendProfileScreen constructs FriendshipRepository against
// Supabase.instance.client eagerly in initState (same established
// limitation as everywhere else in this app — see
// friend_profile_hero_test.dart's own note), so a real push that lets
// Flutter build/mount the destination would crash under test. This
// observer captures the pushed MaterialPageRoute the moment
// Navigator.push registers it (synchronous, before any frame is drawn),
// so the route's builder can be called directly to inspect the widget it
// produces without ever mounting it.
class _CapturingObserver extends NavigatorObserver {
  Route<dynamic>? pushed;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed = route;
  }
}

void main() {
  group('EventFriendsGoingSection — preview + View all threshold', () {
    testWidgets('renders the exact "FRIENDS GOING" section title', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(EventFriendsGoingSection(eventTitle: 'Event', friends: _one)),
      );
      expect(find.text('FRIENDS GOING'), findsOneWidget);
    });

    testWidgets('1 friend: shows that one row, no View all', (tester) async {
      await tester.pumpWidget(
        _wrap(EventFriendsGoingSection(eventTitle: 'Event', friends: _one)),
      );
      expect(find.text('Amy Adams'), findsOneWidget);
      expect(find.text('View all'), findsNothing);
    });

    testWidgets('exactly 3 friends: all three preview, no View all', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(EventFriendsGoingSection(eventTitle: 'Event', friends: _three)),
      );
      expect(find.text('Amy Adams'), findsOneWidget);
      expect(find.text('Bo Baker'), findsOneWidget);
      expect(find.text('Cy Cole'), findsOneWidget);
      expect(find.text('View all'), findsNothing);
    });

    testWidgets('4 friends: only the first 3 preview, View all appears', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(EventFriendsGoingSection(eventTitle: 'Event', friends: _four)),
      );
      expect(find.text('Amy Adams'), findsOneWidget);
      expect(find.text('Bo Baker'), findsOneWidget);
      expect(find.text('Cy Cole'), findsOneWidget);
      expect(find.text('Di Diaz'), findsNothing);
      expect(find.text('View all'), findsOneWidget);
    });

    testWidgets('tapping a friend row opens FriendProfileScreen for that '
        'exact friend', (tester) async {
      final observer = _CapturingObserver();
      await tester.pumpWidget(
        _wrap(
          EventFriendsGoingSection(eventTitle: 'Event', friends: _one),
          observer: observer,
        ),
      );
      await tester.tap(find.text('Amy Adams'));
      final route = observer.pushed! as MaterialPageRoute<dynamic>;
      final widget = route.builder(tester.element(find.byType(MaterialApp)));
      expect(widget, isA<FriendProfileScreen>());
      expect((widget as FriendProfileScreen).userId, 'f1');
    });

    testWidgets('tapping View all opens EventFriendsGoingListScreen with '
        'the full friend list', (tester) async {
      await tester.pumpWidget(
        _wrap(
          EventFriendsGoingSection(
            eventTitle: "'t Preuvenemint",
            friends: _four,
          ),
        ),
      );
      await tester.tap(find.text('View all'));
      await tester.pumpAndSettle();
      final screen = tester.widget<EventFriendsGoingListScreen>(
        find.byType(EventFriendsGoingListScreen),
      );
      expect(screen.friends.length, 4);
      expect(screen.eventTitle, "'t Preuvenemint");
      expect(find.text('Di Diaz'), findsOneWidget);
    });

    testWidgets('never renders gold', (tester) async {
      await tester.pumpWidget(
        _wrap(EventFriendsGoingSection(eventTitle: 'Event', friends: _four)),
      );
      for (final text in tester.widgetList<Text>(find.byType(Text))) {
        expect(text.style?.color, isNot(AppColors.gold));
      }
    });

    testWidgets('320px width, 4 friends — no overflow', (tester) async {
      await tester.pumpWidget(
        _wrap(
          EventFriendsGoingSection(eventTitle: 'Event', friends: _four),
          width: 320,
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('1.6x text scale — no overflow', (tester) async {
      await tester.pumpWidget(
        _wrap(
          EventFriendsGoingSection(eventTitle: 'Event', friends: _four),
          width: 320,
          textScale: 1.6,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('EventFriendsGoingListScreen', () {
    testWidgets('renders every friend, not just a preview slice', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: EventFriendsGoingListScreen(
            eventTitle: 'Event',
            friends: _four,
          ),
        ),
      );
      expect(find.text('Amy Adams'), findsOneWidget);
      expect(find.text('Bo Baker'), findsOneWidget);
      expect(find.text('Cy Cole'), findsOneWidget);
      expect(find.text('Di Diaz'), findsOneWidget);
    });

    testWidgets('shows the event title as the header context', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: EventFriendsGoingListScreen(
            eventTitle: "'t Preuvenemint",
            friends: _one,
          ),
        ),
      );
      expect(find.text("'t Preuvenemint"), findsOneWidget);
    });

    testWidgets('deep-green Scaffold background with an explicit ivory '
        'ColoredBox body and a light status-bar AnnotatedRegion', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: EventFriendsGoingListScreen(eventTitle: 'Event', friends: _one),
        ),
      );
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, AppColors.deepGreen);
      expect(
        find.byWidgetPredicate(
          (w) => w is ColoredBox && w.color == AppColors.ivory,
        ),
        findsOneWidget,
      );
      final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
      );
      expect(region.value, SystemUiOverlayStyle.light);
    });

    testWidgets('tapping a row opens FriendProfileScreen for that exact '
        'friend', (tester) async {
      final observer = _CapturingObserver();
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [observer],
          home: EventFriendsGoingListScreen(
            eventTitle: 'Event',
            friends: _three,
          ),
        ),
      );
      await tester.tap(find.text('Bo Baker'));
      final route = observer.pushed! as MaterialPageRoute<dynamic>;
      final widget = route.builder(tester.element(find.byType(MaterialApp)));
      expect(widget, isA<FriendProfileScreen>());
      expect((widget as FriendProfileScreen).userId, 'f2');
    });

    testWidgets('long display name at 320px does not overflow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(320, 800)),
            child: EventFriendsGoingListScreen(
              eventTitle:
                  'An Exceptionally Long Curated Gastronomic Festival Name',
              friends: [
                _friend(
                  id: 'f1',
                  name:
                      'A Deliberately Long Display Name Used To Confirm '
                      'This Row Never Overflows',
                  username: 'a_very_long_username_indeed',
                ),
              ],
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('1.6x text scale — no overflow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 800),
              textScaler: TextScaler.linear(1.6),
            ),
            child: EventFriendsGoingListScreen(
              eventTitle: 'Event',
              friends: _four,
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
