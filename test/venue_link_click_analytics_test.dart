// Covers the venue-link-click-tracking narrow path:
// - the new AnalyticsEvent/AnalyticsProperties additions
//   (lib/core/analytics/analytics_event.dart,
//   lib/core/analytics/analytics_properties.dart)
// - SupabaseAnalyticsService's own scoping/guard logic
//   (lib/core/analytics/supabase_analytics_service.dart) — only the
//   synchronous, client-untouched paths; the actual insert requires a
//   live Supabase connection this test sandbox doesn't have, matching
//   this codebase's established limitation for Supabase-eager code
//   (see event_discovery_filter_service_test.dart's own header comment
//   for the identical "SupabaseClient(url, key) is safe to construct,
//   never safe to actually query" pattern reused here).

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/analytics/analytics_event.dart';
import 'package:michelin_passport/core/analytics/analytics_properties.dart';
import 'package:michelin_passport/core/analytics/supabase_analytics_service.dart';
import 'package:michelin_passport/models/hotel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _dummyClient = SupabaseClient(
  'https://example.supabase.co',
  'dummy-anon-key',
);

void main() {
  group('AnalyticsEvent.venueBookingLinkOpened', () {
    test('wire name is venue_booking_link_opened, distinct from '
        'ticket_link_opened', () {
      expect(
        AnalyticsEvent.venueBookingLinkOpened.wireName,
        'venue_booking_link_opened',
      );
      expect(
        AnalyticsEvent.ticketLinkOpened.wireName,
        isNot(AnalyticsEvent.venueBookingLinkOpened.wireName),
      );
    });
  });

  group('AnalyticsLinkDestination / AnalyticsVenueDetailScreen wire names', () {
    test('matches venue_link_clicks\' own CHECK constraint values', () {
      expect(AnalyticsLinkDestination.website.wireName, 'website');
      expect(AnalyticsLinkDestination.booking.wireName, 'booking');
      expect(
        AnalyticsVenueDetailScreen.restaurantDetail.wireName,
        'restaurant_detail',
      );
      expect(AnalyticsVenueDetailScreen.hotelDetail.wireName, 'hotel_detail');
    });
  });

  group('AnalyticsProperties.toMap — new fields', () {
    test('serializes linkDestination, sourceScreen and eventId when set', () {
      const properties = AnalyticsProperties(
        entityType: AnalyticsEntityType.restaurant,
        entityId: 'restaurant-123',
        linkDestination: AnalyticsLinkDestination.booking,
        sourceScreen: AnalyticsVenueDetailScreen.restaurantDetail,
        eventId: 'event-456',
      );
      final map = properties.toMap();
      expect(map['entity_type'], 'restaurant');
      expect(map['entity_id'], 'restaurant-123');
      expect(map['link_destination'], 'booking');
      expect(map['source_screen'], 'restaurant_detail');
      expect(map['event_id'], 'event-456');
    });

    test('omits eventId entirely when null, never sends an explicit null', () {
      const properties = AnalyticsProperties(
        entityType: AnalyticsEntityType.hotel,
        entityId: 'hotel-1',
        linkDestination: AnalyticsLinkDestination.website,
        sourceScreen: AnalyticsVenueDetailScreen.hotelDetail,
      );
      final map = properties.toMap();
      expect(map.containsKey('event_id'), isFalse);
    });
  });

  group('Hotel.bookingUrl mapping', () {
    test('Hotel.fromJson maps booking_url — field only, no UI consumer yet', () {
      final hotel = Hotel.fromJson({
        'id': 'x',
        'hotel_code': 'hotel_003',
        'name': 'Test Hotel',
        'city_name': 'Paris',
        'country_code': 'FR',
        'country_name': 'France',
        'flag_emoji': '🇫🇷',
        'address': '1 Test Street',
        'has_michelin_restaurant': false,
        'restaurant_count': 0,
        'booking_url': 'https://booking.example.com/test-hotel',
      });
      expect(hotel.bookingUrl, 'https://booking.example.com/test-hotel');
    });

    test('missing booking_url parses to null, same shape as websiteUrl', () {
      final hotel = Hotel.fromJson({
        'id': 'x',
        'hotel_code': 'hotel_004',
        'name': 'Test Hotel',
        'city_name': 'Paris',
        'country_code': 'FR',
        'country_name': 'France',
        'flag_emoji': '🇫🇷',
        'address': '1 Test Street',
        'has_michelin_restaurant': false,
        'restaurant_count': 0,
      });
      expect(hotel.bookingUrl, isNull);
    });
  });

  group('SupabaseAnalyticsService.track — synchronous guard behaviour', () {
    test('ignores every event other than venueBookingLinkOpened, never '
        'touches the client', () {
      final service = SupabaseAnalyticsService(_dummyClient);
      expect(
        () => service.track(
          AnalyticsEvent.followAdded,
          const AnalyticsProperties(
            entityType: AnalyticsEntityType.restaurant,
            entityId: 'x',
          ),
        ),
        returnsNormally,
      );
      expect(() => service.track(AnalyticsEvent.eventOpened), returnsNormally);
    });

    test('identify/resetIdentity are no-ops that never throw', () {
      final service = SupabaseAnalyticsService(_dummyClient);
      expect(() => service.identify('user-1'), returnsNormally);
      expect(() => service.resetIdentity(), returnsNormally);
    });

    test('venueBookingLinkOpened with null properties fails the debug-only '
        'assertion rather than silently guessing values', () {
      final service = SupabaseAnalyticsService(_dummyClient);
      expect(
        () => service.track(AnalyticsEvent.venueBookingLinkOpened),
        throwsA(isA<AssertionError>()),
      );
    });

    test('venueBookingLinkOpened missing linkDestination fails the same '
        'assertion', () {
      final service = SupabaseAnalyticsService(_dummyClient);
      expect(
        () => service.track(
          AnalyticsEvent.venueBookingLinkOpened,
          const AnalyticsProperties(
            entityType: AnalyticsEntityType.restaurant,
            entityId: 'x',
            sourceScreen: AnalyticsVenueDetailScreen.restaurantDetail,
            // linkDestination deliberately omitted
          ),
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('venueBookingLinkOpened with every required property present '
        'returns synchronously without throwing — the actual insert is '
        'fire-and-forget and never awaited by track() itself', () {
      final service = SupabaseAnalyticsService(_dummyClient);
      expect(
        () => service.track(
          AnalyticsEvent.venueBookingLinkOpened,
          const AnalyticsProperties(
            entityType: AnalyticsEntityType.hotel,
            entityId: 'hotel-1',
            linkDestination: AnalyticsLinkDestination.website,
            sourceScreen: AnalyticsVenueDetailScreen.hotelDetail,
          ),
        ),
        returnsNormally,
      );
    });
  });
}
