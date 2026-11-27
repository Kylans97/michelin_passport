// Visit companions (20261101850000): the feed's "dined together" rows, the
// companions line, and the tag notification's fields.

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/data/repositories/visit_companion_repository.dart';
import 'package:michelin_passport/features/community/friends_activity.dart';
import 'package:michelin_passport/features/community/widgets/friend_activity_row.dart';
import 'package:michelin_passport/models/app_notification.dart';
import 'package:michelin_passport/models/friendship.dart';
import 'package:michelin_passport/models/passport_venue.dart';
import 'package:michelin_passport/models/restaurant.dart';
import 'package:michelin_passport/models/venue_entry.dart';
import 'package:michelin_passport/models/visit.dart';

const _kylan = Friendship(friendshipId: 'f1', friendId: 'kylan', displayName: 'Kylan');
const _pieter = Friendship(friendshipId: 'f2', friendId: 'pieter', displayName: 'Pieter');

const _tacite = Restaurant(
  id: 'r1',
  restaurantCode: 'r1',
  name: 'Tacite',
  michelinStars: null,
  inclusionReason: 'editorial_selection',
  cityName: 'Amsterdam',
  countryCode: 'NL',
  countryName: 'Netherlands',
  flagEmoji: '',
  address: '1 Test Street',
);

Visit _visit(String id, String userId) => Visit(
  id: id,
  userId: userId,
  entityType: 'restaurant',
  entityId: 'r1',
  visitedOn: DateTime(2026, 11, 20),
);

VisitCompanion _tag(String userId, String label, {String status = 'accepted', String? copy}) =>
    VisitCompanion(
      tagId: 't-$userId',
      visitId: 'v-kylan',
      userId: userId,
      displayName: label,
      status: status,
      copyVisitId: copy,
    );

void main() {
  final kylansVisit = _visit('v-kylan', 'kylan');
  final pietersCopy = _visit('v-pieter', 'pieter');
  final visits = {
    'kylan': [VenueEntry(venue: const RestaurantVenue(_tacite), visits: [kylansVisit])],
    'pieter': [VenueEntry(venue: const RestaurantVenue(_tacite), visits: [pietersCopy])],
  };

  test('companionsLine reads naturally for one to many names', () {
    expect(companionsLine(const ['Pieter']), 'Pieter');
    expect(companionsLine(const ['Pieter', 'Anouk']), 'Pieter and Anouk');
    expect(companionsLine(const ['Pieter', 'Anouk', 'Joris']), 'Pieter, Anouk and Joris');
    expect(companionsLine(const ['Pieter', 'Anouk', 'Joris', 'Eva']), 'Pieter and 3 others');
  });

  test('two friends who dined together are one row, not two', () {
    final items = buildFriendActivity(
      friends: const [_kylan, _pieter],
      visitsByFriend: visits,
      intents: const [],
      stamps: const [],
      companionsByVisit: {
        'v-kylan': [_tag('pieter', 'Pieter', copy: 'v-pieter')],
      },
    );
    expect(items, hasLength(1));
    final row = items.single as VisitActivity;
    expect(row.friend.friendId, 'kylan');
    expect(activitySentence(row), ('Kylan', 'and Pieter dined together at', 'Tacite'));
  });

  test("a companion the viewer doesn't know is still named", () {
    final items = buildFriendActivity(
      friends: const [_kylan],
      visitsByFriend: {'kylan': visits['kylan']!},
      intents: const [],
      stamps: const [],
      companionsByVisit: {
        'v-kylan': [_tag('pieter', 'Pieter van Dam', copy: 'v-pieter')],
      },
    );
    expect(activitySentence(items.single), ('Kylan', 'dined with Pieter van Dam at', 'Tacite'));
  });

  test('a pending or declined tag is never shown', () {
    final items = buildFriendActivity(
      friends: const [_kylan, _pieter],
      visitsByFriend: visits,
      intents: const [],
      stamps: const [],
      companionsByVisit: {
        'v-kylan': [_tag('pieter', 'Pieter', status: 'pending')],
      },
    );
    expect(items, hasLength(2));
    expect(activitySentence(items.first).$2, 'visited');
  });

  test('the viewer on a friend’s visit reads as "you"', () {
    final items = buildFriendActivity(
      friends: const [_kylan],
      visitsByFriend: {'kylan': visits['kylan']!},
      intents: const [],
      stamps: const [],
      companionsByVisit: {
        'v-kylan': [_tag('me', 'Me')],
      },
      viewerId: 'me',
    );
    expect(activitySentence(items.single), ('Kylan', 'dined with you at', 'Tacite'));
  });

  test('a tag notification carries the visit it is about', () {
    final n = AppNotification.tryFromRow({
      'id': 'n1',
      'type': 'visit_tag_received',
      'subject_type': 'visit_companion',
      'subject_id': 't1',
      'is_read': false,
      'created_at': '2026-11-27T10:00:00Z',
      'other_user_id': 'kylan',
      'other_display_name': 'Kylan',
      'tag_status': 'pending',
      'tag_visit_id': 'v-kylan',
      'tag_entity_type': 'restaurant',
      'tag_entity_id': 'r1',
      'tag_venue_name': 'Tacite',
      'tag_visited_on': '2026-11-20',
      'tag_copy_visit_id': null,
    })!;
    expect(n.type, AppNotificationType.visitTagReceived);
    expect(n.tagStatus, 'pending');
    expect(n.tagVenueName, 'Tacite');
    expect(n.tagVisitedOn, DateTime(2026, 11, 20));
  });
}
