// Covers the VISITED/WISHLIST section behavior FriendProfileScreen adds
// for an accepted friend (Community/Friends UX Step 1): flatten-and-sort-
// by-date-desc across venues, loading/empty states (empty now omits the
// section entirely rather than showing a "nothing here" line — Step 1
// §18), the shared preview limit, and the "View all" trigger.
//
// _FriendVisitedSection/_FriendWishlistSection themselves are private to
// friend_profile_screen.dart (Dart privacy is per-file, so a test can't
// import them directly), so this reconstructs the exact FutureBuilder +
// preview/empty-omission shape here, using the REAL FriendVisitTile/
// FriendWishlistTile leaf widgets and the now-public
// flattenFriendVisits/FriendVenueVisit helpers friend_profile_screen.dart
// exports specifically so this logic has one source of truth.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/core/theme/cs_typography.dart';
import 'package:michelin_passport/features/friends/friend_profile_screen.dart';
import 'package:michelin_passport/features/friends/widgets/friend_visit_tile.dart';
import 'package:michelin_passport/features/friends/widgets/friend_wishlist_tile.dart';
import 'package:michelin_passport/models/passport_venue.dart';
import 'package:michelin_passport/models/restaurant.dart';
import 'package:michelin_passport/models/venue_entry.dart';
import 'package:michelin_passport/models/visit.dart';

const _previewLimit = 4;

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

// Mirrors _FriendVisitedSection exactly.
Widget _visitedSection(Future<List<VenueEntry>>? future) {
  return FutureBuilder<List<VenueEntry>>(
    future: future,
    builder: (context, snap) {
      final loading = snap.connectionState == ConnectionState.waiting;
      if (!loading && !snap.hasError) {
        final rows = flattenFriendVisits(snap.data ?? const []);
        if (rows.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'VISITED',
                  style: CsTypography.eyebrow.copyWith(color: AppColors.taupe),
                ),
                if (rows.length > _previewLimit)
                  Text(
                    'View all',
                    style: CsTypography.metadata.copyWith(
                      color: AppColors.forestGreen,
                    ),
                  ),
              ],
            ),
            for (var i = 0; i < rows.length && i < _previewLimit; i++)
              FriendVisitTile(
                venue: rows[i].venue,
                visit: rows[i].visit,
                onTap: () {},
              ),
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

// Mirrors _FriendWishlistSection exactly.
Widget _wishlistSection(Future<List<PassportVenue>>? future) {
  return FutureBuilder<List<PassportVenue>>(
    future: future,
    builder: (context, snap) {
      final loading = snap.connectionState == ConnectionState.waiting;
      if (!loading && !snap.hasError) {
        final items = snap.data ?? const [];
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'WISHLIST',
                  style: CsTypography.eyebrow.copyWith(color: AppColors.taupe),
                ),
                if (items.length > _previewLimit)
                  Text(
                    'View all',
                    style: CsTypography.metadata.copyWith(
                      color: AppColors.forestGreen,
                    ),
                  ),
              ],
            ),
            for (var i = 0; i < items.length && i < _previewLimit; i++)
              FriendWishlistTile(venue: items[i], onTap: () {}),
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
  group('Friend Profile VISITED section', () {
    testWidgets('shows a loading spinner while pending', (tester) async {
      // A never-completing Completer, not Future.delayed — it schedules
      // no Timer, so nothing is left pending for the test binding to
      // trip on when the widget tree is disposed at the end of the test.
      final completer = Completer<List<VenueEntry>>();
      await tester.pumpWidget(_wrap(_visitedSection(completer.future)));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets(
      'omits the whole section entirely when empty — never a "nothing '
      'here" line (Step 1 §18)',
      (tester) async {
        await tester.pumpWidget(_wrap(_visitedSection(Future.value(const []))));
        await tester.pumpAndSettle();
        expect(find.text('VISITED'), findsNothing);
        expect(find.textContaining('No shared visits'), findsNothing);
        expect(find.byType(FriendVisitTile), findsNothing);
      },
    );

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

    testWidgets(
      'caps the preview at $_previewLimit rows and shows "View all" only '
      'when more exist',
      (tester) async {
        final entries = [
          for (var i = 0; i < 6; i++)
            VenueEntry(
              venue: RestaurantVenue(_restaurant('r$i', 'Place $i')),
              visits: [_visit('v$i', DateTime(2026, 1, i + 1))],
            ),
        ];
        await tester.pumpWidget(_wrap(_visitedSection(Future.value(entries))));
        await tester.pumpAndSettle();
        expect(find.byType(FriendVisitTile), findsNWidgets(_previewLimit));
        expect(find.text('View all'), findsOneWidget);
      },
    );

    testWidgets('shows no "View all" trigger when everything already fits', (
      tester,
    ) async {
      final entries = [
        VenueEntry(
          venue: RestaurantVenue(_restaurant('r1', 'Place 1')),
          visits: [_visit('v1', DateTime(2026, 1, 1))],
        ),
      ];
      await tester.pumpWidget(_wrap(_visitedSection(Future.value(entries))));
      await tester.pumpAndSettle();
      expect(find.text('View all'), findsNothing);
    });
  });

  group('Friend Profile WISHLIST section', () {
    testWidgets(
      'omits the whole section entirely when empty — never a "nothing '
      'here" line (Step 1 §18)',
      (tester) async {
        await tester.pumpWidget(
          _wrap(_wishlistSection(Future.value(const []))),
        );
        await tester.pumpAndSettle();
        expect(find.text('WISHLIST'), findsNothing);
        expect(find.textContaining('Nothing saved'), findsNothing);
      },
    );

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
