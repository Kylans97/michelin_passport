// Every list of events asks for moderation_status = published itself
// (publishedEventsOnly). RLS alone isn't enough since 20261018130000:
// admins and an event's own submitter can also read unpublished rows,
// which leaked a rejected test event into an admin's Explore on
// 2026-10-28. Asserted on the real REST requests, via a recording client.

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:michelin_passport/data/repositories/event_attendance_repository.dart';
import 'package:michelin_passport/data/repositories/events_repository.dart';
import 'package:michelin_passport/models/event_attendance.dart';

void main() {
  late List<Uri> requests;
  late SupabaseClient client;

  setUp(() {
    requests = [];
    client = SupabaseClient(
      'https://test.supabase.co',
      'test-anon-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        requests.add(request.url);
        // Link and attendance lookups return one id, so the events query
        // that follows them actually runs.
        final body = request.url.path.endsWith('/events') ||
                request.url.path.endsWith('/countries')
            ? '[]'
            : '[{"event_id":"e1"}]';
        return http.Response(body, 200, request: request);
      }),
    );
  });

  List<Uri> eventsQueries() =>
      [for (final u in requests) if (u.path.endsWith('/rest/v1/events')) u];

  void expectPublishedOnly() {
    final queries = eventsQueries();
    expect(queries, isNotEmpty);
    for (final u in queries) {
      expect(u.queryParameters['moderation_status'], 'eq.published', reason: '$u');
    }
  }

  test('discovery: loadEvents', () async {
    await EventsRepository(client).loadEvents();
    expectPublishedOnly();
  });

  test('a country\'s events, and the countries that have any', () async {
    await EventsRepository(client).loadEventsForCountry('NL');
    await EventsRepository(client).getCountries();
    expectPublishedOnly();
  });

  test('a venue\'s hosted events', () async {
    await EventsRepository(client).loadHostedEventsForRestaurant('r1');
    expectPublishedOnly();
  });

  test('a wishlist\'s events by id', () async {
    await EventsRepository(client).loadEventsByIds(['e1']);
    expectPublishedOnly();
  });

  test('a friend\'s upcoming events, and past events a member went to', () async {
    final repo = EventAttendanceRepository(client);
    await repo.getFriendUpcomingEvents(userId: 'u1', status: EventIntentStatus.going);
    await repo.getPastGoingEvents(userId: 'u1');
    expectPublishedOnly();
  });

  test('a single event by id stays unfiltered, for the admin review preview', () async {
    await EventsRepository(client).loadEventById('e1');
    expect(eventsQueries().single.queryParameters.containsKey('moderation_status'), isFalse);
  });
}
