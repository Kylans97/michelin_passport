// Covers the GOING section FriendProfileScreen adds for an accepted
// friend (Social Foundation Step 2B §13): loading/error/empty states, and
// that it renders exactly what the repository call returns (RLS-filtered
// already) via the real FriendGoingTile leaf widget.
//
// _FriendGoingSection is private to friend_profile_screen.dart, and
// FriendProfileScreen constructs EventAttendanceRepository against
// Supabase.instance.client eagerly in initState — same established
// limitation as every other screen in this app that touches Supabase
// there (see friend_profile_visited_wishlist_sections_test.dart's own
// note) — so this reconstructs the exact FutureBuilder + empty-state
// shape, using the real FriendGoingTile.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/core/theme/cs_spacing.dart';
import 'package:michelin_passport/core/theme/cs_typography.dart';
import 'package:michelin_passport/features/friends/widgets/friend_going_tile.dart';
import 'package:michelin_passport/models/event.dart';

Event _event(String id, String name, {DateTime? startAt}) => Event(
  id: id,
  name: name,
  city: 'Maastricht',
  startAt: startAt ?? DateTime(2026, 8, 28),
  endAt: startAt ?? DateTime(2026, 8, 30),
  countryCode: 'NL',
  eventType: EventType.festival,
  status: EventStatus.upcoming,
  createdAt: DateTime(2026, 1, 1),
);

// Mirrors _FriendGoingSection exactly.
Widget _goingSection(Future<List<Event>>? future) {
  return FutureBuilder<List<Event>>(
    future: future,
    builder: (context, snap) {
      final events = snap.data ?? const <Event>[];
      final loading = snap.connectionState == ConnectionState.waiting;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'GOING',
            style: CsTypography.eyebrow.copyWith(
              color: AppColors.secondaryOnDark,
            ),
          ),
          const SizedBox(height: CsSpacing.md),
          if (loading)
            const Center(
              child: CircularProgressIndicator(color: AppColors.gold),
            )
          else if (snap.hasError)
            Text(
              'Could not load events.',
              style: CsTypography.body.copyWith(
                color: AppColors.secondaryOnDark,
              ),
            )
          else if (events.isEmpty)
            Text(
              'No upcoming events yet.',
              style: CsTypography.body.copyWith(
                color: AppColors.secondaryOnDark,
              ),
            )
          else
            Column(
              children: [
                for (final event in events)
                  FriendGoingTile(event: event, onTap: () {}),
              ],
            ),
        ],
      );
    },
  );
}

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(backgroundColor: AppColors.deepGreen, body: child),
);

void main() {
  group('Friend Profile GOING section', () {
    testWidgets('shows a loading spinner while pending', (tester) async {
      final completer = Completer<List<Event>>();
      await tester.pumpWidget(_wrap(_goingSection(completer.future)));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('empty state says "No upcoming events yet."', (tester) async {
      await tester.pumpWidget(_wrap(_goingSection(Future.value(const []))));
      await tester.pumpAndSettle();
      expect(find.text('No upcoming events yet.'), findsOneWidget);
    });

    testWidgets('renders one tile per upcoming event the repository '
        'returns', (tester) async {
      await tester.pumpWidget(
        _wrap(
          _goingSection(
            Future.value([
              _event('e1', 'Festival A'),
              _event('e2', 'Festival B'),
            ]),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(FriendGoingTile), findsNWidgets(2));
      expect(find.text('Festival A'), findsOneWidget);
      expect(find.text('Festival B'), findsOneWidget);
    });

    testWidgets('error state renders restrained copy, not a crash', (
      tester,
    ) async {
      // .ignore() marks this future's error as intentionally handled
      // elsewhere (by FutureBuilder's own snapshot.error, not a top-level
      // catch) — without it, the test zone reports it as an unhandled
      // exception even though FutureBuilder handles it correctly.
      final errorFuture = Future<List<Event>>.error('boom')..ignore();
      await tester.pumpWidget(_wrap(_goingSection(errorFuture)));
      await tester.pumpAndSettle();
      expect(find.text('Could not load events.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
