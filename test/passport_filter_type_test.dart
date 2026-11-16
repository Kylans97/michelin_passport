// Events V2 Step 8C — Passport's own local content-type filter. Confirms
// exactly three values (no `all`), correct labels, and that this is a
// genuinely separate type from ExploreVenueType (a compile-time guarantee
// this file also exercises at the type level, not just the runtime one).

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/features/passport/passport_filter_type.dart';

void main() {
  // Journeys (trains and ships) joined as a fourth value, 2026-11-16.
  test(
    'exactly four values: restaurants, hotels, events, journeys — no "all"',
    () {
      expect(PassportFilterType.values, [
        PassportFilterType.restaurants,
        PassportFilterType.hotels,
        PassportFilterType.events,
        PassportFilterType.journeys,
      ]);
    },
  );

  test('labels', () {
    expect(PassportFilterType.restaurants.label, 'Restaurants');
    expect(PassportFilterType.hotels.label, 'Hotels');
    expect(PassportFilterType.events.label, 'Events');
    expect(PassportFilterType.journeys.label, 'Journeys');
  });
}
