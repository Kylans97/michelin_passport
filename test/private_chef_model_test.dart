// Covers PrivateChef.fromJson — nullable fields, pricing, languages,
// publication status, and the two derived getters (hasGuestRange,
// hasShowablePricingFrom) that the UI layer relies on to decide what to
// render, matching Restaurant/Hotel's own established model-test pattern
// (pure Dart, no widget/Supabase dependency).

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/models/private_chef.dart';

Map<String, dynamic> _row({
  String id = 'chef-1',
  String slug = 'test-chef',
  String displayName = 'Test Chef',
  Object? businessName,
  Object? biography,
  Object? homeCity,
  Object? homeCountryCode,
  Object? minimumGuests,
  Object? maximumGuests,
  bool priceOnRequest = true,
  Object? pricingFrom,
  Object? pricingCurrency,
  Object? pricingUnit,
  Object? languages,
  String publicationStatus = 'published',
}) => {
  'id': id,
  'slug': slug,
  'display_name': displayName,
  'business_name': businessName,
  'biography': biography,
  'personalization_note': null,
  'home_city': homeCity,
  'home_country_code': homeCountryCode,
  'service_area_text': null,
  'travel_available': true,
  'minimum_guests': minimumGuests,
  'maximum_guests': maximumGuests,
  'wine_pairing_available': false,
  'wine_note': null,
  'price_on_request': priceOnRequest,
  'pricing_from': pricingFrom,
  'pricing_currency': pricingCurrency,
  'pricing_unit': pricingUnit,
  'instagram_url': null,
  'website_url': null,
  'profile_image_url': null,
  'languages': languages,
  'publication_status': publicationStatus,
};

void main() {
  group('PrivateChef.fromJson', () {
    test('maps every required field', () {
      final chef = PrivateChef.fromJson(_row());
      expect(chef.id, 'chef-1');
      expect(chef.slug, 'test-chef');
      expect(chef.displayName, 'Test Chef');
      expect(chef.publicationStatus, 'published');
    });

    test('nullable business_name/biography/city/country stay null, never '
        'coerced to empty-string-as-present', () {
      final chef = PrivateChef.fromJson(_row());
      expect(chef.businessName, isNull);
      expect(chef.biography, isNull);
      expect(chef.homeCity, isNull);
      expect(chef.homeCountryCode, isNull);
    });

    test('optional fields populate when present', () {
      final chef = PrivateChef.fromJson(
        _row(
          businessName: 'Test Catering',
          biography: 'A short biography.',
          homeCity: 'Breda',
          homeCountryCode: 'NL',
        ),
      );
      expect(chef.businessName, 'Test Catering');
      expect(chef.biography, 'A short biography.');
      expect(chef.homeCity, 'Breda');
      expect(chef.homeCountryCode, 'NL');
    });

    group('guest range', () {
      test('neither set -> hasGuestRange false', () {
        final chef = PrivateChef.fromJson(_row());
        expect(chef.minimumGuests, isNull);
        expect(chef.maximumGuests, isNull);
        expect(chef.hasGuestRange, isFalse);
      });

      test('minimum only -> hasGuestRange true', () {
        final chef = PrivateChef.fromJson(_row(minimumGuests: 6));
        expect(chef.minimumGuests, 6);
        expect(chef.maximumGuests, isNull);
        expect(chef.hasGuestRange, isTrue);
      });

      test('both set -> hasGuestRange true', () {
        final chef = PrivateChef.fromJson(
          _row(minimumGuests: 6, maximumGuests: 14),
        );
        expect(chef.minimumGuests, 6);
        expect(chef.maximumGuests, 14);
        expect(chef.hasGuestRange, isTrue);
      });
    });

    group('pricing', () {
      test('price_on_request true -> hasShowablePricingFrom false even '
          'when pricing_from is also set', () {
        final chef = PrivateChef.fromJson(
          _row(priceOnRequest: true, pricingFrom: 450),
        );
        expect(chef.priceOnRequest, isTrue);
        expect(chef.hasShowablePricingFrom, isFalse);
      });

      test('price_on_request false with a pricing_from -> showable', () {
        final chef = PrivateChef.fromJson(
          _row(
            priceOnRequest: false,
            pricingFrom: 450,
            pricingCurrency: 'EUR',
            pricingUnit: 'per_person',
          ),
        );
        expect(chef.priceOnRequest, isFalse);
        expect(chef.pricingFrom, 450.0);
        expect(chef.pricingCurrency, 'EUR');
        expect(chef.pricingUnit, 'per_person');
        expect(chef.hasShowablePricingFrom, isTrue);
      });

      test('price_on_request false with no pricing_from -> not showable', () {
        final chef = PrivateChef.fromJson(_row(priceOnRequest: false));
        expect(chef.hasShowablePricingFrom, isFalse);
      });

      test('numeric pricing_from decodes as double regardless of JSON '
          'int/double shape', () {
        final chef = PrivateChef.fromJson(
          _row(priceOnRequest: false, pricingFrom: 450),
        );
        expect(chef.pricingFrom, isA<double>());
        expect(chef.pricingFrom, 450.0);
      });
    });

    group('languages', () {
      test('null languages -> empty list, never null', () {
        final chef = PrivateChef.fromJson(_row());
        expect(chef.languages, isEmpty);
      });

      test('populated languages list maps to strings', () {
        final chef = PrivateChef.fromJson(
          _row(languages: ['English', 'Dutch', 'French']),
        );
        expect(chef.languages, ['English', 'Dutch', 'French']);
      });
    });

    test(
      'publication_status maps through as-is (draft/published/archived)',
      () {
        expect(
          PrivateChef.fromJson(
            _row(publicationStatus: 'draft'),
          ).publicationStatus,
          'draft',
        );
        expect(
          PrivateChef.fromJson(
            _row(publicationStatus: 'archived'),
          ).publicationStatus,
          'archived',
        );
      },
    );
  });
}
