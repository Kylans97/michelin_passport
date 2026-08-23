// Events V2 Discovery Taxonomy Phase C Correction Pass — the pure
// EventLocationContext value type (lib/models/event_location_context.
// dart). Extended by Near Me Phase N1 with the mutually-exclusive
// nearMe mode. No Supabase dependency anywhere in this file.

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/models/event_location_context.dart';
import 'package:michelin_passport/models/event_near_me_location.dart';
import 'package:michelin_passport/models/geo_coordinate.dart';
import 'package:michelin_passport/models/venue_country.dart';

const _netherlands = VenueCountry(
  name: 'Netherlands',
  code: 'NL',
  flag: '🇳🇱',
);

EventNearMeLocation _amsterdamNearMe() => EventNearMeLocation(
  coordinate: GeoCoordinate(latitude: 52.3676, longitude: 4.9041),
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

  group('EventLocationContext — a resolved Near-me location (Phase N1)', () {
    test('isAny is false, isNearMe is true, isCountry is false, label is '
        '"Near me"', () {
      final location = EventLocationContext.nearMe(_amsterdamNearMe());
      expect(location.isAny, isFalse);
      expect(location.isNearMe, isTrue);
      expect(location.isCountry, isFalse);
      expect(location.country, isNull);
      expect(location.label, 'Near me');
    });

    test('countryCodes is empty under Near me — it is never expressed as '
        'a country-code set', () {
      final location = EventLocationContext.nearMe(_amsterdamNearMe());
      expect(location.countryCodes, isEmpty);
    });

    test('two contexts for the same Near-me location compare equal', () {
      final a = EventLocationContext.nearMe(_amsterdamNearMe());
      final b = EventLocationContext.nearMe(_amsterdamNearMe());
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('EventLocationContext — mutual exclusivity (Phase N1)', () {
    test('constructing both country and nearMe at once throws', () {
      expect(
        () => EventLocationContext(
          country: _netherlands,
          nearMe: _amsterdamNearMe(),
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('.country() never sets nearMe', () {
      final location = EventLocationContext.country(_netherlands);
      expect(location.isCountry, isTrue);
      expect(location.nearMe, isNull);
    });

    test('.nearMe() never sets country', () {
      final location = EventLocationContext.nearMe(_amsterdamNearMe());
      expect(location.isNearMe, isTrue);
      expect(location.country, isNull);
    });

    test('selecting Near me after a Country selection replaces it — no '
        'hidden previous Location predicate remains active', () {
      var location = EventLocationContext.country(_netherlands);
      location = EventLocationContext.nearMe(_amsterdamNearMe());
      expect(location.isCountry, isFalse);
      expect(location.country, isNull);
      expect(location.isNearMe, isTrue);
      expect(location.countryCodes, isEmpty);
    });

    test('selecting a Country after Near me replaces it — no hidden '
        'previous Near-me predicate remains active', () {
      var location = EventLocationContext.nearMe(_amsterdamNearMe());
      location = EventLocationContext.country(_netherlands);
      expect(location.isNearMe, isFalse);
      expect(location.nearMe, isNull);
      expect(location.isCountry, isTrue);
      expect(location.countryCodes, {'NL'});
    });

    test('selecting .any after either mode clears the active Location '
        'context entirely', () {
      var location = EventLocationContext.nearMe(_amsterdamNearMe());
      location = EventLocationContext.any;
      expect(location.isAny, isTrue);
      expect(location.country, isNull);
      expect(location.nearMe, isNull);
    });
  });
}
