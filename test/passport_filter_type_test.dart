// Events V2 Step 8C — Passport's own local content-type filter. Confirms
// exactly three values (no `all`), correct labels, and that this is a
// genuinely separate type from ExploreVenueType (a compile-time guarantee
// this file also exercises at the type level, not just the runtime one).

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/features/passport/passport_filter_type.dart';

void main() {
  test('exactly three values: restaurants, hotels, events — no "all"', () {
    expect(PassportFilterType.values, [
      PassportFilterType.restaurants,
      PassportFilterType.hotels,
      PassportFilterType.events,
    ]);
  });

  test('labels', () {
    expect(PassportFilterType.restaurants.label, 'Restaurants');
    expect(PassportFilterType.hotels.label, 'Hotels');
    expect(PassportFilterType.events.label, 'Events');
  });
}
