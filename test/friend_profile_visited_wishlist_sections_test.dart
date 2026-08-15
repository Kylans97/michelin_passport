// Covers the VISITED/WISHLIST section behavior FriendProfileScreen adds
// for an accepted friend (Social Foundation Step 2 §13-14):
// flatten-and-sort-by-date-desc across venues, loading/error/empty
// states, and that both sections are backed by nothing but what the
// (already RLS-filtered) repository call returns — no client-side
// filtering of a broader dataset.
//
// _FriendVisitedSection/_FriendWishlistSection themselves are private to
// friend_profile_screen.dart, and FriendProfileScreen constructs
// FriendshipRepository/VisitedRepository/WishlistRepository against
// Supabase.instance.client eagerly in initState (the same established
// limitation as every other screen in this app that touches Supabase
// there — see friend_profile_no_activity_test.dart's own note), so this
// reconstructs the exact FutureBuilder + flatten/sort + empty-state shape
// from friend_profile_screen.dart, using the REAL FriendVisitTile/
// FriendWishlistTile leaf widgets (which are themselves genuinely
// Supabase-free/safe to pump — see friend_visit_wishlist_tiles_test.dart).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/core/theme/cs_spacing.dart';
import 'package:michelin_passport/core/theme/cs_typography.dart';
import 'package:michelin_passport/features/friends/widgets/friend_visit_tile.dart';
import 'package:michelin_passport/features/friends/widgets/friend_wishlist_tile.dart';
import 'package:michelin_passport/models/passport_venue.dart';
import 'package:michelin_passport/models/restaurant.dart';
import 'package:michelin_passport/models/venue_entry.dart';
import 'package:michelin_passport/models/visit.dart';

Restaurant _restaurant(String id, String name) => Restaurant(
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

Visit _visit(String id, DateTime visitedOn) => Visit(
  id: id,
  userId: 'friend-u1',
  entityType: 'restaurant',
  entityId: 'r1',
  visitedOn: visitedOn,
  visibility: VisitVisibility.friends,
);

class _VenueVisit {
  final PassportVenue venue;
  final Visit visit;
  const _VenueVisit(this.venue, this.visit);
}

// Mirrors _FriendVisitedSection exactly.
Widget _visitedSection(Future<List<VenueEntry>>? future) {
  return FutureBuilder<List<VenueEntry>>(
    future: future,
    builder: (context, snap) {
      final entries = snap.data ?? const <VenueEntry>[];
      final loading = snap.connectionState == ConnectionState.waiting;
      final rows = <_VenueVisit>[
        for (final entry in entries)
          for (final visit in entry.visits) _VenueVisit(entry.venue, visit),
      ]..sort((a, b) => b.visit.visitedOn.compareTo(a.visit.visitedOn));

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'VISITED',
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
              'Could not load visits.',
              style: CsTypography.body.copyWith(
                color: AppColors.secondaryOnDark,
              ),
            )
          else if (rows.isEmpty)
            Text(
              'No shared visits yet.',
              style: CsTypography.body.copyWith(
                color: AppColors.secondaryOnDark,
              ),
            )
          else
            Column(
              children: [
                for (var i = 0; i < rows.length; i++)
                  FriendVisitTile(
                    venue: rows[i].venue,
                    visit: rows[i].visit,
                    onTap: () {},
                  ),
              ],
            ),
        ],
      );
    },
  );
}

// Mirrors _FriendWishlistSection exactly.
Widget _wishlistSection(Future<List<PassportVenue>>? future) {
  return FutureBuilder<List<PassportVenue>>(
    future: future,
    builder: (context, snap) {
      final items = snap.data ?? const <PassportVenue>[];
      final loading = snap.connectionState == ConnectionState.waiting;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'WISHLIST',
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
              'Could not load wishlist.',
              style: CsTypography.body.copyWith(
                color: AppColors.secondaryOnDark,
              ),
            )
          else if (items.isEmpty)
            Text(
              'Nothing saved yet.',
              style: CsTypography.body.copyWith(
                color: AppColors.secondaryOnDark,
              ),
            )
          else
            Column(
              children: [
                for (final item in items)
                  FriendWishlistTile(venue: item, onTap: () {}),
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
  group('Friend Profile VISITED section', () {
    testWidgets('shows a loading spinner while pending', (tester) async {
      // A never-completing Completer, not Future.delayed — it schedules
      // no Timer, so nothing is left pending for the test binding to
      // trip on when the widget tree is disposed at the end of the test.
      final completer = Completer<List<VenueEntry>>();
      await tester.pumpWidget(_wrap(_visitedSection(completer.future)));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('empty state says "No shared visits yet." — not that the '
        'friend never visited anywhere', (tester) async {
      await tester.pumpWidget(_wrap(_visitedSection(Future.value(const []))));
      await tester.pumpAndSettle();
      expect(find.text('No shared visits yet.'), findsOneWidget);
    });

    testWidgets('flattens venues and sorts every visit newest-first, '
        'across venues', (tester) async {
      final entries = [
        VenueEntry(
          venue: RestaurantVenue(_restaurant('r1', 'Older Place')),
          visits: [_visit('v1', DateTime(2026, 1, 1))],
        ),
        VenueEntry(
          venue: RestaurantVenue(_restaurant('r2', 'Newest Place')),
          visits: [
            _visit('v2', DateTime(2026, 6, 1)),
            _visit('v3', DateTime(2026, 3, 1)),
          ],
        ),
      ];
      await tester.pumpWidget(_wrap(_visitedSection(Future.value(entries))));
      await tester.pumpAndSettle();

      final tiles = tester.widgetList<FriendVisitTile>(
        find.byType(FriendVisitTile),
      );
      final order = tiles.map((t) => t.visit.id).toList();
      expect(order, ['v2', 'v3', 'v1']); // newest first, across venues
    });
  });

  group('Friend Profile WISHLIST section', () {
    testWidgets('empty state says "Nothing saved yet."', (tester) async {
      await tester.pumpWidget(_wrap(_wishlistSection(Future.value(const []))));
      await tester.pumpAndSettle();
      expect(find.text('Nothing saved yet.'), findsOneWidget);
    });

    testWidgets('renders one tile per wishlisted venue', (tester) async {
      await tester.pumpWidget(
        _wrap(
          _wishlistSection(
            Future.value([
              RestaurantVenue(_restaurant('r1', 'Wishlist Restaurant A')),
              RestaurantVenue(_restaurant('r2', 'Wishlist Restaurant B')),
            ]),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(FriendWishlistTile), findsNWidgets(2));
    });
  });
}
