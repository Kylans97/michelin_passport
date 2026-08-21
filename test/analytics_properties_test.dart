// Covers AnalyticsProperties and its controlled vocabularies — Events V2
// Step 2. Protects the canonical wire names for every enum, and
// AnalyticsProperties.toMap()'s null-omission behavior (a null field must
// never appear as an explicit null on the wire — it must simply be absent).

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/analytics/analytics_properties.dart';

void main() {
  group('AnalyticsSourceSurface.wireName', () {
    test('every value maps to its documented wire name', () {
      const expected = {
        AnalyticsSourceSurface.eventsFeed: 'events_feed',
        AnalyticsSourceSurface.eventSearch: 'event_search',
        AnalyticsSourceSurface.discover: 'discover',
        AnalyticsSourceSurface.hostProfile: 'host_profile',
        AnalyticsSourceSurface.friendActivity: 'friend_activity',
        AnalyticsSourceSurface.tripRecommendation: 'trip_recommendation',
        AnalyticsSourceSurface.passport: 'passport',
        AnalyticsSourceSurface.map: 'map',
        AnalyticsSourceSurface.pushNotification: 'push_notification',
        AnalyticsSourceSurface.deepLink: 'deep_link',
        AnalyticsSourceSurface.externalShare: 'external_share',
      };
      for (final value in AnalyticsSourceSurface.values) {
        expect(value.wireName, expected[value]);
      }
    });
  });

  group('AnalyticsSourceContext.wireName', () {
    test('every value maps to its documented wire name', () {
      const expected = {
        AnalyticsSourceContext.featured: 'featured',
        AnalyticsSourceContext.followedHost: 'followed_host',
        AnalyticsSourceContext.nearby: 'nearby',
        AnalyticsSourceContext.tripDestination: 'trip_destination',
        AnalyticsSourceContext.friendSignal: 'friend_signal',
        AnalyticsSourceContext.searchResult: 'search_result',
      };
      for (final value in AnalyticsSourceContext.values) {
        expect(value.wireName, expected[value]);
      }
    });
  });

  test('AttendanceSource.wireName mirrors event_confirmed_attendance.source '
      "'s CHECK constraint exactly", () {
    const expected = {
      AttendanceSource.manual: 'manual',
      AttendanceSource.postEventPrompt: 'post_event_prompt',
      AttendanceSource.tripCompletion: 'trip_completion',
    };
    for (final value in AttendanceSource.values) {
      expect(value.wireName, expected[value]);
    }
  });

  test('AnalyticsEntityType.wireName covers only MVP entity types', () {
    const expected = {
      AnalyticsEntityType.restaurant: 'restaurant',
      AnalyticsEntityType.hotel: 'hotel',
      AnalyticsEntityType.privateChef: 'private_chef',
      AnalyticsEntityType.event: 'event',
    };
    expect(AnalyticsEntityType.values.length, 4);
    for (final value in AnalyticsEntityType.values) {
      expect(value.wireName, expected[value]);
    }
  });

  test('PriceBucket.wireName never exposes an exact amount', () {
    const expected = {
      PriceBucket.free: 'free',
      PriceBucket.under100: 'under_100',
      PriceBucket.between100And250: '100_250',
      PriceBucket.over250: 'over_250',
    };
    for (final value in PriceBucket.values) {
      expect(value.wireName, expected[value]);
    }
  });

  group('AnalyticsProperties.toMap', () {
    test('an empty properties object serializes to an empty map', () {
      expect(const AnalyticsProperties().toMap(), isEmpty);
    });

    test('every populated field appears, using its wireName where the '
        'field is an enum', () {
      const properties = AnalyticsProperties(
        entityType: AnalyticsEntityType.event,
        entityId: 'evt-1',
        sourceSurface: AnalyticsSourceSurface.friendActivity,
        sourceContext: AnalyticsSourceContext.friendSignal,
        hostType: AnalyticsEntityType.restaurant,
        hostId: 'rest-1',
        hostCount: 1,
        city: 'Rotterdam',
        countryCode: 'NL',
        eventCategory: 'dinner',
        admissionType: 'paid',
        priceBucket: PriceBucket.between100And250,
        tripId: 'trip-1',
        followedHost: true,
        positionInFeed: 2,
        friendSignalType: FriendSignalType.going,
        attendanceSource: AttendanceSource.tripCompletion,
        resultsCount: 5,
        wouldRecommend: true,
      );

      expect(properties.toMap(), {
        'entity_type': 'event',
        'entity_id': 'evt-1',
        'source_surface': 'friend_activity',
        'source_context': 'friend_signal',
        'host_type': 'restaurant',
        'host_id': 'rest-1',
        'host_count': 1,
        'city': 'Rotterdam',
        'country_code': 'NL',
        'event_category': 'dinner',
        'admission_type': 'paid',
        'price_bucket': '100_250',
        'trip_id': 'trip-1',
        'followed_host': true,
        'position_in_feed': 2,
        'friend_signal_type': 'going',
        'attendance_source': 'trip_completion',
        'results_count': 5,
        'would_recommend': true,
      });
    });

    test('would_recommend serializes false as an explicit false, never '
        'omitted — false is a genuine answer, not "unset"', () {
      const properties = AnalyticsProperties(wouldRecommend: false);
      expect(properties.toMap(), {'would_recommend': false});
    });

    test('would_recommend is omitted entirely when null — Step 4.1\'s '
        '"never send a value for event_recommendation_removed" rule', () {
      const properties = AnalyticsProperties(wouldRecommend: null);
      expect(properties.toMap(), isEmpty);
    });

    test('a null field is omitted entirely, never sent as an explicit '
        'null', () {
      const properties = AnalyticsProperties(
        entityType: AnalyticsEntityType.restaurant,
        entityId: 'rest-1',
      );
      final map = properties.toMap();
      expect(map, {'entity_type': 'restaurant', 'entity_id': 'rest-1'});
      expect(map.containsKey('host_id'), isFalse);
      expect(map.containsKey('trip_id'), isFalse);
    });

    test('host_count can be populated without host_type/host_id, for '
        'multi-host events that never attribute to one host', () {
      const properties = AnalyticsProperties(hostCount: 3);
      expect(properties.toMap(), {'host_count': 3});
    });

    test('friend_signal_type never carries a friend identifier — the '
        'property is a closed enum, not a free-text/id field', () {
      // Structural guarantee: FriendSignalType has exactly 3 members, none
      // of which can hold an id/name/email — this is enforced by the type
      // system itself (an enum cannot be handed arbitrary string data).
      expect(FriendSignalType.values, hasLength(3));
    });
  });
}
