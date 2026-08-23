// Events V2 Discovery Taxonomy Phase C Correction Pass — the pure
// EventLocationContext value type (lib/models/event_location_context.
// dart). No Supabase dependency anywhere in this file.

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/models/event_location_context.dart';
import 'package:michelin_passport/models/venue_country.dart';

const _netherlands = VenueCountry(
  name: 'Netherlands',
  code: 'NL',
  flag: '🇳🇱',
);

void main() {
  group('EventLocationContext — any (no restriction)', () {
    test('isAny is true, countryCodes is empty, label is "Location"', () {
      const location = EventLocationContext.any;
      expect(location.isAny, isTrue);
      expect(location.countryCodes, isEmpty);
      expect(location.label, 'Location');
    });

    test('the default constructor with no country is equivalent to .any', () {
      const location = EventLocationContext();
      expect(location, EventLocationContext.any);
    });
  });

  group('EventLocationContext — a selected country', () {
    test('isAny is false, countryCodes resolves to exactly that code, '
        'label is the display name (never the raw code)', () {
      const location = EventLocationContext(country: _netherlands);
      expect(location.isAny, isFalse);
      expect(location.countryCodes, {'NL'});
      expect(location.label, 'Netherlands');
    });
  });

  group('EventLocationContext — equality', () {
    test('two contexts for the same country compare equal', () {
      const a = EventLocationContext(country: _netherlands);
      const b = EventLocationContext(country: _netherlands);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('.any and a country selection are never equal', () {
      const a = EventLocationContext.any;
      const b = EventLocationContext(country: _netherlands);
      expect(a, isNot(equals(b)));
    });
  });
}
