// Covers the GOING section FriendProfileScreen adds for an accepted
// friend (Community/Friends UX Step 1): loading/error/empty states (empty
// AND error now omit the section entirely — Step 1 §18's "omit rather
// than clutter" rule applied consistently across VISITED/WISHLIST/GOING),
// the shared preview limit, the "View all" trigger, and that it renders
// exactly what the repository call returns (RLS-filtered already) via the
// real FriendGoingTile leaf widget.
//
// _FriendGoingSection is private to friend_profile_screen.dart, and
// FriendProfileScreen constructs EventAttendanceRepository against
// Supabase.instance.client eagerly in initState — same established
// limitation as every other screen in this app that touches Supabase
// there — so this reconstructs the exact FutureBuilder + preview/
// empty-omission shape here, using the real FriendGoingTile.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/core/theme/cs_typography.dart';
import 'package:michelin_passport/features/friends/widgets/friend_going_tile.dart';
import 'package:michelin_passport/models/event.dart';

const _previewLimit = 4;

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
      final loading = snap.connectionState == ConnectionState.waiting;
      if (!loading && !snap.hasError) {
        final events = snap.data ?? const [];
        if (events.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'GOING',
                  style: CsTypography.eyebrow.copyWith(color: AppColors.taupe),
                ),
                if (events.length > _previewLimit)
                  Text(
                    'View all',
                    style: CsTypography.metadata.copyWith(
                      color: AppColors.forestGreen,
                    ),
                  ),
              ],
            ),
            for (var i = 0; i < events.length && i < _previewLimit; i++)
              FriendGoingTile(event: events[i], onTap: () {}),
          ],
        );
      }
      if (snap.hasError) return const SizedBox.shrink();
      return const Center(
        child: CircularProgressIndicator(color: AppColors.forestGreen),
      );
    },
  );
}

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(backgroundColor: AppColors.ivory, body: child),
);

void main() {
  group('Friend Profile GOING section', () {
    testWidgets('shows a loading spinner while pending', (tester) async {
      final completer = Completer<List<Event>>();
      await tester.pumpWidget(_wrap(_goingSection(completer.future)));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets(
      'omits the whole section entirely when empty — never a "nothing '
      'here" line (Step 1 §18)',
      (tester) async {
        await tester.pumpWidget(_wrap(_goingSection(Future.value(const []))));
        await tester.pumpAndSettle();
        expect(find.text('GOING'), findsNothing);
        expect(find.textContaining('No upcoming events'), findsNothing);
      },
    );

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

    testWidgets(
      'caps the preview at $_previewLimit rows and shows "View all" only '
      'when more exist',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            _goingSection(
              Future.value([
                for (var i = 0; i < 6; i++) _event('e$i', 'Festival $i'),
              ]),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(FriendGoingTile), findsNWidgets(_previewLimit));
        expect(find.text('View all'), findsOneWidget);
      },
    );

    testWidgets(
      'omits the section on error, rather than showing a raw error line',
      (tester) async {
        // .ignore() marks this future's error as intentionally handled
        // elsewhere (by FutureBuilder's own snapshot.error, not a
        // top-level catch) — without it, the test zone reports it as an
        // unhandled exception even though FutureBuilder handles it
        // correctly.
        final errorFuture = Future<List<Event>>.error('boom')..ignore();
        await tester.pumpWidget(_wrap(_goingSection(errorFuture)));
        await tester.pumpAndSettle();
        expect(find.text('GOING'), findsNothing);
        expect(find.textContaining('Could not load'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
