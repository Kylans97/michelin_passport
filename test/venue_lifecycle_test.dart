import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/utils/venue_lifecycle.dart';

void main() {
  group('resolveLifecycleState', () {
    test('open, not expired -> normal', () {
      expect(
        resolveLifecycleState(status: 'open', isExpired: false),
        VenueLifecycleState.normal,
      );
    });

    test('open, expired pop-up -> popupEnded', () {
      expect(
        resolveLifecycleState(status: 'open', isExpired: true),
        VenueLifecycleState.popupEnded,
      );
    });

    test('temporarily_closed -> temporarilyClosed regardless of isExpired', () {
      expect(
        resolveLifecycleState(status: 'temporarily_closed', isExpired: false),
        VenueLifecycleState.temporarilyClosed,
      );
      expect(
        resolveLifecycleState(status: 'temporarily_closed', isExpired: true),
        VenueLifecycleState.temporarilyClosed,
      );
    });

    test('permanently_closed wins over everything, including isExpired', () {
      expect(
        resolveLifecycleState(status: 'permanently_closed', isExpired: true),
        VenueLifecycleState.permanentlyClosed,
      );
    });

    test('permanently_closed outranks temporarily_closed', () {
      // Not a real production state, but the priority order must still
      // be deterministic if it ever happens.
      expect(
        resolveLifecycleState(status: 'permanently_closed', isExpired: false),
        VenueLifecycleState.permanentlyClosed,
      );
    });
  });
}
