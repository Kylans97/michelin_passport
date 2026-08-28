// Covers AnalyticsEvent's wire names and analyticsSchemaVersion — Events V2
// Step 2. Protects the one canonical string every provider/debug
// implementation actually sends, so a Dart-side rename of an enum member
// can never silently change what ships on the wire without this test
// catching it.

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/analytics/analytics_event.dart';

void main() {
  group('AnalyticsEvent.wireName', () {
    test('every event maps to its documented snake_case wire name', () {
      const expected = {
        AnalyticsEvent.eventOpened: 'event_opened',
        AnalyticsEvent.eventSearchPerformed: 'event_search_performed',
        AnalyticsEvent.eventFilterApplied: 'event_filter_applied',
        AnalyticsEvent.hostProfileOpened: 'host_profile_opened',
        AnalyticsEvent.followAdded: 'follow_added',
        AnalyticsEvent.followRemoved: 'follow_removed',
        AnalyticsEvent.eventInterestedAdded: 'event_interested_added',
        AnalyticsEvent.eventInterestedRemoved: 'event_interested_removed',
        AnalyticsEvent.eventGoingAdded: 'event_going_added',
        AnalyticsEvent.eventGoingRemoved: 'event_going_removed',
        AnalyticsEvent.ticketLinkOpened: 'ticket_link_opened',
        AnalyticsEvent.venueBookingLinkOpened: 'venue_booking_link_opened',
        AnalyticsEvent.eventAttendancePrompted: 'event_attendance_prompted',
        AnalyticsEvent.eventAttendanceConfirmed: 'event_attendance_confirmed',
        AnalyticsEvent.eventAttendanceDenied: 'event_attendance_denied',
        AnalyticsEvent.eventRatingAdded: 'event_rating_added',
        AnalyticsEvent.eventPhotoAdded: 'event_photo_added',
        AnalyticsEvent.eventCommentAdded: 'event_comment_added',
        AnalyticsEvent.eventRecommendationAdded: 'event_recommendation_added',
        AnalyticsEvent.eventRecommendationRemoved:
            'event_recommendation_removed',
        AnalyticsEvent.tripEventAdded: 'trip_event_added',
        AnalyticsEvent.tripRestaurantAdded: 'trip_restaurant_added',
        AnalyticsEvent.tripHotelAdded: 'trip_hotel_added',
        AnalyticsEvent.tripReviewOpened: 'trip_review_opened',
        AnalyticsEvent.tripItemConfirmed: 'trip_item_confirmed',
        AnalyticsEvent.tripItemRejected: 'trip_item_rejected',
        AnalyticsEvent.passportItemCreated: 'passport_item_created',
        AnalyticsEvent.passportItemRemoved: 'passport_item_removed',
        AnalyticsEvent.friendsSignalOpened: 'friends_signal_opened',
      };

      for (final event in AnalyticsEvent.values) {
        expect(
          event.wireName,
          expected[event],
          reason:
              '${event.name} is missing from the expected map above — '
              'every AnalyticsEvent value must be covered here',
        );
      }
    });

    test('every wire name is unique', () {
      final names = AnalyticsEvent.values.map((e) => e.wireName).toSet();
      expect(names.length, AnalyticsEvent.values.length);
    });

    test('every wire name is snake_case (lowercase, digits, underscores '
        'only)', () {
      for (final event in AnalyticsEvent.values) {
        expect(
          RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(event.wireName),
          isTrue,
          reason: '${event.wireName} is not snake_case',
        );
      }
    });
  });

  test('analyticsSchemaVersion is 1', () {
    expect(analyticsSchemaVersion, 1);
  });
}
