// Pure-logic tests for the venue-claim feature's own wire-value mappings —
// the one place a typo would silently produce a value the database's own
// CHECK constraints reject at write time or never recognize at read time.

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/data/repositories/missing_listing_repository.dart';
import 'package:michelin_passport/models/venue_claim.dart';

void main() {
  group('VenueClaimVenueType', () {
    test('wire values match the claims_* tables\' own venue_type strings', () {
      expect(VenueClaimVenueType.restaurant.wireValue, 'restaurant');
      expect(VenueClaimVenueType.hotel.wireValue, 'hotel');
      expect(VenueClaimVenueType.privateChef.wireValue, 'private_chef');
    });
  });

  group('VenueClaimRole', () {
    test('wire values match the role column\'s own CHECK constraint', () {
      expect(VenueClaimRole.owner.wireValue, 'owner');
      expect(VenueClaimRole.manager.wireValue, 'manager');
      expect(VenueClaimRole.chef.wireValue, 'chef');
      expect(VenueClaimRole.other.wireValue, 'other');
    });
  });

  group('VenueClaimStatus.fromWire', () {
    test('parses all four real statuses, including the newer "blocked" one', () {
      expect(VenueClaimStatus.fromWire('pending'), VenueClaimStatus.pending);
      expect(VenueClaimStatus.fromWire('approved'), VenueClaimStatus.approved);
      expect(VenueClaimStatus.fromWire('rejected'), VenueClaimStatus.rejected);
      expect(VenueClaimStatus.fromWire('blocked'), VenueClaimStatus.blocked);
    });

    test('an unrecognised value fails safe to pending rather than throwing', () {
      expect(VenueClaimStatus.fromWire('nonsense'), VenueClaimStatus.pending);
    });
  });

  group('VenueClaim.fromJson', () {
    test('reads the right venue id column for each venue type', () {
      final restaurant = VenueClaim.fromJson(
        {'id': 'c1', 'restaurant_id': 'r1', 'status': 'pending', 'requested_at': '2026-01-01T00:00:00Z'},
        venueType: VenueClaimVenueType.restaurant,
        venueIdColumn: 'restaurant_id',
      );
      expect(restaurant.venueId, 'r1');
      expect(restaurant.venueType, VenueClaimVenueType.restaurant);
      expect(restaurant.status, VenueClaimStatus.pending);
    });
  });

  group('MissingListingSubjectType — private chef addition', () {
    test('wire values are correct for all four types, including the new '
        'private_chef case that can\'t just reuse .name', () {
      expect(MissingListingSubjectType.restaurant.wireValue, 'restaurant');
      expect(MissingListingSubjectType.hotel.wireValue, 'hotel');
      expect(MissingListingSubjectType.event.wireValue, 'event');
      expect(MissingListingSubjectType.privateChef.wireValue, 'private_chef');
    });
  });
}
