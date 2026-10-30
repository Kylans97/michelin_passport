// Lists that downloaded a member's whole history on every visit: the
// notifications feed (and, past PostgREST's 1,000-row cap, silently lost
// the oldest), Friend Profile's covers (every public photo of every visit,
// to show one each), and Profile's second copy of the Passport. Asserted
// here against fake PostgREST responses.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:michelin_passport/data/repositories/notifications_repository.dart';
import 'package:michelin_passport/data/repositories/photo_repository.dart';
import 'package:michelin_passport/data/repositories/visited_repository.dart';
import 'package:michelin_passport/features/friends/friend_profile_all_visits_screen.dart';
import 'package:michelin_passport/features/friends/friend_profile_screen.dart'
    show FriendVenueVisit;
import 'package:michelin_passport/models/hotel.dart';
import 'package:michelin_passport/models/passport_venue.dart';
import 'package:michelin_passport/models/restaurant.dart';
import 'package:michelin_passport/models/venue_entry.dart';
import 'package:michelin_passport/models/visit.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late List<http.Request> requests;

  SupabaseClient clientWith(
    Future<http.Response> Function(http.Request request) handler,
  ) {
    requests = [];
    return SupabaseClient(
      'https://test.supabase.co',
      'test-anon-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) {
        requests.add(request);
        return handler(request);
      }),
    );
  }

  http.Response json(Object body, http.Request request, [int status = 200]) =>
      http.Response(jsonEncode(body), status, request: request);

  http.Response notFound(http.Request request) => json(
    {'code': 'PGRST202', 'message': 'Could not find the function'},
    request,
    404,
  );

  Map<String, dynamic> notificationRow(int i) => {
    'id': 'n$i',
    'type': 'friend_request_received',
    'subject_type': 'friendship',
    'subject_id': 's$i',
    'is_read': false,
    'created_at': '2026-10-01T00:00:00Z',
    'other_user_id': 'u$i',
  };

  group('notifications', () {
    test('ask for one newest-first page, ordered stably', () async {
      final repo = NotificationsRepository(
        clientWith(
          (r) async => json([
            for (var i = 0; i < notificationsPageSize; i++) notificationRow(i),
          ], r),
        ),
      );
      final page = await repo.getNotifications(offset: 50);

      final q = requests.single.url.queryParameters;
      expect(requests.single.url.path, endsWith('/rpc/get_notifications_v3'));
      expect(q['order'], 'created_at.desc.nullslast,id.desc.nullslast');
      expect(q['offset'], '50');
      expect(q['limit'], '$notificationsPageSize');
      expect(page.hasMore, isTrue);
    });

    test('a short page is the last one', () async {
      final repo = NotificationsRepository(
        clientWith((r) async => json([notificationRow(1)], r)),
      );
      final page = await repo.getNotifications();
      expect(page.notifications, hasLength(1));
      expect(page.hasMore, isFalse);
    });

    test('an older server version is paged the same way', () async {
      final repo = NotificationsRepository(
        clientWith(
          (r) async => r.url.path.endsWith('_v3')
              ? notFound(r)
              : json([notificationRow(1)], r),
        ),
      );
      await repo.getNotifications(offset: 100);
      expect(requests.last.url.path, endsWith('/rpc/get_notifications_v2'));
      expect(requests.last.url.queryParameters['offset'], '100');
      expect(requests.last.url.queryParameters['limit'], '50');
    });
  });

  group('visit covers', () {
    // Signing answers with a URL naming the path, so a cover's URL shows
    // which photo was picked. Member-photo transforms are off by default,
    // so covers are signed in one batch.
    http.Response sign(http.Request r) {
      final paths = (jsonDecode(r.body) as Map)['paths'] as List;
      return json([
        for (final path in paths)
          {
            'path': path,
            'signedURL': '/object/sign/visit-photos/$path?token=t',
            'error': null,
          },
      ], r);
    }

    test('read one cover per visit from get_visit_cover_photos', () async {
      final repo = PhotoRepository(
        clientWith((r) async {
          if (r.url.path.contains('/object/sign/')) return sign(r);
          return json([
            {'visit_id': 'v1', 'storage_path': 'u/v1/new.jpg'},
          ], r);
        }),
      );
      final covers = await repo.loadCoverPhotoUrlsForVisits(['v1', 'v2']);

      expect(requests.first.url.path, endsWith('/rpc/get_visit_cover_photos'));
      expect(jsonDecode(requests.first.body), {
        'p_visit_ids': ['v1', 'v2'],
      });
      expect(covers.keys, ['v1']);
      expect(covers['v1'], contains('u/v1/new.jpg'));
    });

    test('before the migration, fall back to the every-photo query and '
        'keep the newest per visit', () async {
      final repo = PhotoRepository(
        clientWith((r) async {
          if (r.url.path.contains('/rpc/')) return notFound(r);
          if (r.url.path.contains('/object/sign/')) return sign(r);
          return json([
            {'visit_id': 'v1', 'storage_path': 'u/v1/new.jpg'},
            {'visit_id': 'v1', 'storage_path': 'u/v1/old.jpg'},
          ], r);
        }),
      );
      final covers = await repo.loadCoverPhotoUrlsForVisits(['v1']);

      expect(
        requests.any((r) => r.url.path.endsWith('/rest/v1/photos')),
        isTrue,
      );
      expect(covers['v1'], contains('u/v1/new.jpg'));
    });
  });

  testWidgets('All visits loads covers only for the rows it builds', (
    tester,
  ) async {
    final restaurant = Restaurant.fromJson(const {'id': 'r', 'name': 'R'});
    final visits = [
      for (var i = 0; i < 200; i++)
        FriendVenueVisit(
          RestaurantVenue(restaurant),
          Visit.fromJson({
            'id': 'v$i',
            'user_id': 'u',
            'entity_type': 'restaurant',
            'entity_id': 'r',
            'visited_on': '2026-01-01',
          }),
        ),
    ];
    final asked = <List<String>>[];
    await tester.pumpWidget(
      MaterialApp(
        home: FriendProfileAllVisitsScreen(
          friendName: 'Ann',
          visits: visits,
          coverPhotoByVisitId: const {'v0': 'https://x/v0.jpg'},
          onTapVisit: (_, _) {},
          loadCoverPhotos: (ids) async {
            asked.add(ids);
            return const {};
          },
        ),
      ),
    );
    await tester.pump();

    final requested = asked.expand((ids) => ids).toSet();
    expect(requested, isNot(contains('v0'))); // the preview already had it
    expect(requested, contains('v1'));
    expect(requested.length, lessThan(visits.length ~/ 2));
    for (final ids in asked) {
      expect(
        ids.length,
        lessThanOrEqualTo(FriendProfileAllVisitsScreen.coverChunkSize),
      );
    }
  });

  test('Profile counts restaurants from the Passport it already loads', () {
    Visit visit(String id) => Visit.fromJson({
      'id': id,
      'user_id': 'u',
      'entity_type': 'restaurant',
      'entity_id': 'x',
      'visited_on': '2026-01-01',
    });
    final a = Restaurant.fromJson(const {'id': 'a', 'name': 'A'});
    final b = Restaurant.fromJson(const {'id': 'b', 'name': 'B'});
    final h = Hotel.fromJson(const {'id': 'h', 'name': 'H'});
    final entries = [
      VenueEntry(venue: RestaurantVenue(a), visits: [visit('1'), visit('2')]),
      VenueEntry(venue: HotelVenue(h), visits: [visit('3')]),
      VenueEntry(venue: RestaurantVenue(b), visits: [visit('4')]),
    ];
    expect(visitedRestaurantsOf(entries).map((r) => r.id), ['a', 'b']);
  });
}
