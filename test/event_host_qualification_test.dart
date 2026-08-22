// Events V2 Step 8A §6/§30 — proves the non-negotiable "from a host you
// follow" semantic rule as a pure, independently-tested decision:
// venue-only and participant-only links must NOT qualify, only an explicit
// is_host = true link does, regardless of entity type (Restaurant/Hotel/
// Private Chef all share the exact same event_*.is_host/is_venue shape —
// see EventHostFollowRepository).

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/features/events/event_host_qualification.dart';

void main() {
  group('eventHostFollowQualifies', () {
    test('is_host = true qualifies, regardless of is_venue', () {
      expect(eventHostFollowQualifies(isHost: true, isVenue: false), isTrue);
      expect(eventHostFollowQualifies(isHost: true, isVenue: true), isTrue);
    });

    test('venue-only (is_venue = true, is_host = false) does NOT qualify', () {
      expect(eventHostFollowQualifies(isHost: false, isVenue: true), isFalse);
    });

    test('bare participant (is_host = false, is_venue = false) does NOT '
        'qualify', () {
      expect(eventHostFollowQualifies(isHost: false, isVenue: false), isFalse);
    });
  });
}
