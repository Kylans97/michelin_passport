// Pure-logic tests for passport_stamp_source.dart's pagination rule — the
// "Done when" acceptance case explicitly named in the ink-stamp redesign
// spec: 1, 4, 5, and 13 visits must each page correctly, including the
// edge case where the real stamps alone already fill a whole page (4, 8,
// 12, ...), which needs a wholly new trailing page just for the "next
// stamp" slot (see paginateStamps' own doc comment).

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/features/passport/passport_stamp_source.dart';
import 'package:michelin_passport/features/passport/models/passport_stamp_item.dart';
import 'package:michelin_passport/models/passport_venue.dart';
import 'package:michelin_passport/models/restaurant.dart';
import 'package:michelin_passport/models/venue_entry.dart';
import 'package:michelin_passport/models/visit.dart';

PassportStampItem _item(String id, {DateTime? date}) => RestaurantStampItem(
  restaurant: Restaurant(
    id: 'r-$id',
    restaurantCode: 'r-$id',
    name: 'Restaurant $id',
    michelinStars: null,
    inclusionReason: 'michelin_star',
    cityName: 'Paris',
    countryCode: 'FR',
    countryName: 'France',
    flagEmoji: '🇫🇷',
    address: '1 Rue de Test',
  ),
  visit: Visit(
    id: id,
    userId: 'u1',
    entityType: 'restaurant',
    entityId: 'r-$id',
    visitedOn: date ?? DateTime(2026, 1, 1),
  ),
);

List<PassportStampItem> _items(int count) => [
  for (var i = 0; i < count; i++) _item('v$i', date: DateTime(2026, 1, i + 1)),
];

void main() {
  group('paginateStamps', () {
    test('1 visit: a single page with 1 filled slot, 1 next slot, 2 blanks', () {
      final pages = paginateStamps(_items(1));
      expect(pages, hasLength(1));
      expect(pages[0], hasLength(4));
      expect(pages[0][0], isA<FilledStampSlot>());
      expect(pages[0][1], isA<NextStampSlot>());
      expect(pages[0][2], isA<BlankStampSlot>());
      expect(pages[0][3], isA<BlankStampSlot>());
    });

    test(
      '4 visits: a full first page, PLUS a second page holding only the '
      'next-stamp slot — a full page never carries the empty slot itself',
      () {
        final pages = paginateStamps(_items(4));
        expect(pages, hasLength(2));
        expect(pages[0], hasLength(4));
        expect(pages[0].every((s) => s is FilledStampSlot), isTrue);
        expect(pages[1], hasLength(4));
        expect(pages[1][0], isA<NextStampSlot>());
        expect(pages[1][1], isA<BlankStampSlot>());
        expect(pages[1][2], isA<BlankStampSlot>());
        expect(pages[1][3], isA<BlankStampSlot>());
      },
    );

    test('5 visits: a full first page, then 1 filled + next slot + 2 blanks', () {
      final pages = paginateStamps(_items(5));
      expect(pages, hasLength(2));
      expect(pages[0].every((s) => s is FilledStampSlot), isTrue);
      expect(pages[1][0], isA<FilledStampSlot>());
      expect(pages[1][1], isA<NextStampSlot>());
      expect(pages[1][2], isA<BlankStampSlot>());
      expect(pages[1][3], isA<BlankStampSlot>());
    });

    test('13 visits: 3 full pages, then 1 filled + next slot + 2 blanks', () {
      final pages = paginateStamps(_items(13));
      expect(pages, hasLength(4));
      for (final page in pages.take(3)) {
        expect(page.every((s) => s is FilledStampSlot), isTrue);
      }
      expect(pages[3][0], isA<FilledStampSlot>());
      expect(pages[3][1], isA<NextStampSlot>());
      expect(pages[3][2], isA<BlankStampSlot>());
      expect(pages[3][3], isA<BlankStampSlot>());
    });

    test('every real item appears exactly once, in order, across all pages', () {
      final items = _items(13);
      final pages = paginateStamps(items);
      final flattened = [
        for (final page in pages)
          for (final slot in page)
            if (slot is FilledStampSlot) slot.item,
      ];
      expect(flattened.map((i) => i.id), items.map((i) => i.id));
    });

    test('exactly one NextStampSlot exists across the whole collection', () {
      for (final count in [1, 4, 5, 8, 12, 13]) {
        final pages = paginateStamps(_items(count));
        final nextSlots = [
          for (final page in pages)
            for (final slot in page)
              if (slot is NextStampSlot) slot,
        ];
        expect(nextSlots, hasLength(1), reason: 'count=$count');
      }
    });
  });

  group('buildRestaurantStampItems ordering', () {
    test(
      'sorts oldest visit first, not newest — the last page must be where '
      'the *next* stamp naturally continues from — and produces one item '
      'per VISIT, not one per venue, even for a single repeatedly-visited '
      'restaurant',
      () {
        const restaurant = Restaurant(
          id: 'r1',
          restaurantCode: 'r1',
          name: 'Flore',
          michelinStars: 2,
          inclusionReason: 'michelin_star',
          cityName: 'Amsterdam',
          countryCode: 'NL',
          countryName: 'Netherlands',
          flagEmoji: '🇳🇱',
          address: '1 Prinsengracht',
        );
        final entry = VenueEntry(
          venue: const RestaurantVenue(restaurant),
          visits: [
            Visit(
              id: 'newest',
              userId: 'u1',
              entityType: 'restaurant',
              entityId: 'r1',
              visitedOn: DateTime(2026, 6, 1),
            ),
            Visit(
              id: 'oldest',
              userId: 'u1',
              entityType: 'restaurant',
              entityId: 'r1',
              visitedOn: DateTime(2026, 1, 1),
            ),
            Visit(
              id: 'middle',
              userId: 'u1',
              entityType: 'restaurant',
              entityId: 'r1',
              visitedOn: DateTime(2026, 3, 1),
            ),
          ],
        );

        final items = buildRestaurantStampItems([entry]);

        expect(items, hasLength(3));
        expect(items.map((i) => i.id), ['oldest', 'middle', 'newest']);
      },
    );
  });
}
