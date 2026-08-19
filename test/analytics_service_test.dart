// Covers NoopAnalyticsService and DebugPrintAnalyticsService — Events V2
// Step 2. NoopAnalyticsService is the actual production-safe default this
// app ships with while no vendor is selected; DebugPrintAnalyticsService is
// a local-only development aid. Neither is wired into the app by this
// step — these tests protect the two implementations directly.

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/analytics/analytics_event.dart';
import 'package:michelin_passport/core/analytics/analytics_properties.dart';
import 'package:michelin_passport/core/analytics/analytics_service.dart';

void main() {
  group('NoopAnalyticsService', () {
    const service = NoopAnalyticsService();

    test('track never throws, with or without properties', () {
      expect(() => service.track(AnalyticsEvent.eventOpened), returnsNormally);
      expect(
        () => service.track(
          AnalyticsEvent.eventGoingAdded,
          const AnalyticsProperties(entityId: 'evt-1'),
        ),
        returnsNormally,
      );
    });

    test('identify and resetIdentity never throw', () {
      expect(() => service.identify('user-1'), returnsNormally);
      expect(() => service.resetIdentity(), returnsNormally);
    });
  });

  group('DebugPrintAnalyticsService', () {
    late List<String> printed;
    late DebugPrintAnalyticsService service;
    late DebugPrintCallback originalDebugPrint;

    setUp(() {
      printed = [];
      originalDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) printed.add(message);
      };
      service = DebugPrintAnalyticsService();
    });

    tearDown(() {
      debugPrint = originalDebugPrint;
    });

    test('track prints exactly one line containing the event wire name '
        'and schema version', () {
      service.track(AnalyticsEvent.eventOpened);
      expect(printed, hasLength(1));
      expect(printed.single, contains('event_opened'));
      expect(printed.single, contains('schema_version: 1'));
      expect(printed.single, contains('session_id'));
      expect(printed.single, contains('timestamp'));
    });

    test('track without identify never includes user_internal_id', () {
      service.track(AnalyticsEvent.eventOpened);
      expect(printed.single, isNot(contains('user_internal_id')));
    });

    test('identify causes subsequent track calls to include the id', () {
      service.identify('user-abc');
      service.track(AnalyticsEvent.eventOpened);
      expect(printed.single, contains('user_internal_id: user-abc'));
    });

    test('resetIdentity removes the id from subsequent track calls', () {
      service.identify('user-abc');
      service.resetIdentity();
      service.track(AnalyticsEvent.eventOpened);
      expect(printed.single, isNot(contains('user_internal_id')));
    });

    test('properties are flattened into the same printed envelope', () {
      service.track(
        AnalyticsEvent.eventGoingAdded,
        const AnalyticsProperties(
          entityType: AnalyticsEntityType.event,
          entityId: 'evt-1',
          sourceSurface: AnalyticsSourceSurface.eventsFeed,
        ),
      );
      expect(printed.single, contains('entity_type: event'));
      expect(printed.single, contains('entity_id: evt-1'));
      expect(printed.single, contains('source_surface: events_feed'));
    });

    test('a null property field never appears in the printed envelope', () {
      service.track(
        AnalyticsEvent.eventGoingAdded,
        const AnalyticsProperties(entityId: 'evt-1'),
      );
      expect(printed.single, isNot(contains('host_id')));
      expect(printed.single, isNot(contains('trip_id')));
    });

    test('the session id stays identical across multiple track calls on '
        'the same instance', () {
      service.track(AnalyticsEvent.eventOpened);
      service.track(AnalyticsEvent.hostProfileOpened);
      final sessionIdPattern = RegExp(r'session_id: (\S+?)[,}]');
      final firstMatch = sessionIdPattern.firstMatch(printed[0])!.group(1);
      final secondMatch = sessionIdPattern.firstMatch(printed[1])!.group(1);
      expect(firstMatch, secondMatch);
    });

    test('two separate instances get different session ids', () {
      final other = DebugPrintAnalyticsService();
      service.track(AnalyticsEvent.eventOpened);
      other.track(AnalyticsEvent.eventOpened);
      final sessionIdPattern = RegExp(r'session_id: (\S+?)[,}]');
      final firstMatch = sessionIdPattern.firstMatch(printed[0])!.group(1);
      final secondMatch = sessionIdPattern.firstMatch(printed[1])!.group(1);
      expect(firstMatch, isNot(secondMatch));
    });
  });
}
