// Covers the venue action + app usage tracking path
// (20261023200000_add_venue_action_and_app_usage_tracking.sql):
// - the new AnalyticsEvent/AnalyticsProperties additions
// - that every wire name the app can send is one the migration's CHECK
//   constraints accept, read from the migration file itself so the two
//   cannot drift apart silently
// - SupabaseAnalyticsService's synchronous guard logic only; the inserts
//   need a live Supabase connection this sandbox doesn't have (same
//   limitation as venue_link_click_analytics_test.dart).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/analytics/analytics_event.dart';
import 'package:michelin_passport/core/analytics/analytics_properties.dart';
import 'package:michelin_passport/core/analytics/supabase_analytics_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _dummyClient = SupabaseClient(
  'https://example.supabase.co',
  'dummy-anon-key',
);

const _migration =
    'supabase/migrations/20261023200000_add_venue_action_and_app_usage_tracking.sql';

/// The quoted values inside the `check (<column> in (...))` that follows
/// [anchor] in the migration.
Set<String> _checkValues(String sql, String anchor) {
  final start = sql.indexOf(anchor);
  expect(start, isNot(-1), reason: 'anchor "$anchor" not in migration');
  final open = sql.indexOf('(', sql.indexOf(' in ', start));
  final close = sql.indexOf(')', open);
  return RegExp(
    r"'([a-z_]+)'",
  ).allMatches(sql.substring(open, close)).map((m) => m.group(1)!).toSet();
}

void main() {
  final sql = File(_migration).readAsStringSync();

  group('wire names match the migration CHECK constraints', () {
    test('AnalyticsScreen ↔ app_usage_events.screen', () {
      expect(
        AnalyticsScreen.values.map((s) => s.wireName).toSet(),
        _checkValues(sql, 'screen      text check'),
      );
    });

    test('persisted usage events ↔ app_usage_events.event_name', () {
      expect({
        AnalyticsEvent.screenOpened.wireName,
        AnalyticsEvent.exploreSearchPerformed.wireName,
        AnalyticsEvent.exploreFilterApplied.wireName,
        AnalyticsEvent.eventOpened.wireName,
      }, _checkValues(sql, 'event_name  text not null check'));
    });

    test('AnalyticsVenueDetailScreen ↔ venue_link_clicks.source_screen', () {
      expect(
        AnalyticsVenueDetailScreen.values.map((s) => s.wireName).toSet(),
        _checkValues(
          sql,
          'add constraint venue_link_clicks_source_screen_check',
        ),
      );
    });

    test('website/booking plus phone/directions ↔ '
        'venue_link_clicks.destination', () {
      expect(
        {
          ...AnalyticsLinkDestination.values.map((d) => d.wireName),
          'phone',
          'directions',
        },
        _checkValues(sql, 'add constraint venue_link_clicks_destination_check'),
      );
    });
  });

  group('AnalyticsProperties.screen', () {
    test('serializes as its wire name, omitted when null', () {
      expect(
        const AnalyticsProperties(
          screen: AnalyticsScreen.friendProfile,
        ).toMap()['screen'],
        'friend_profile',
      );
      expect(
        const AnalyticsProperties().toMap().containsKey('screen'),
        isFalse,
      );
    });
  });

  group('SupabaseAnalyticsService.track — required properties', () {
    final service = SupabaseAnalyticsService(_dummyClient);

    test('screenOpened without a screen fails the debug assertion', () {
      expect(
        () => service.track(AnalyticsEvent.screenOpened),
        throwsA(isA<AssertionError>()),
      );
    });

    test('venuePhoneTapped / venueDirectionsOpened need sourceScreen', () {
      for (final event in [
        AnalyticsEvent.venuePhoneTapped,
        AnalyticsEvent.venueDirectionsOpened,
      ]) {
        expect(
          () => service.track(
            event,
            const AnalyticsProperties(
              entityType: AnalyticsEntityType.restaurant,
              entityId: 'x',
            ),
          ),
          throwsA(isA<AssertionError>()),
          reason: event.wireName,
        );
      }
    });

    test('venueDetailOpened and eventOpened need an entityId', () {
      expect(
        () => service.track(
          AnalyticsEvent.venueDetailOpened,
          const AnalyticsProperties(entityType: AnalyticsEntityType.hotel),
        ),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => service.track(AnalyticsEvent.eventOpened),
        throwsA(isA<AssertionError>()),
      );
    });

    test('complete calls return synchronously — inserts are '
        'fire-and-forget', () {
      expect(
        () => service.track(
          AnalyticsEvent.venuePhoneTapped,
          const AnalyticsProperties(
            entityType: AnalyticsEntityType.hotel,
            entityId: 'hotel-1',
            sourceScreen: AnalyticsVenueDetailScreen.hotelDetail,
          ),
        ),
        returnsNormally,
      );
      expect(
        () => service.track(
          AnalyticsEvent.screenOpened,
          const AnalyticsProperties(screen: AnalyticsScreen.explore),
        ),
        returnsNormally,
      );
      expect(
        () => service.track(AnalyticsEvent.exploreSearchPerformed),
        returnsNormally,
      );
    });
  });
}
