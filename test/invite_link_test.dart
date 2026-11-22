import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/models/app_notification.dart';
import 'package:michelin_passport/models/invite_link.dart';

void main() {
  group('inviteTokenFrom', () {
    test('finds the token in a link or in pasted text around it', () {
      expect(
        inviteTokenFrom('https://mantelier.app/i/poqxGYMrR8qmJd9_gAKe6Y'),
        'poqxGYMrR8qmJd9_gAKe6Y',
      );
      expect(
        inviteTokenFrom(
          'Elise Laurent invited you to Mantelier.\n'
          'https://mantelier.app/i/poqxGYMrR8qmJd9_gAKe6Y',
        ),
        'poqxGYMrR8qmJd9_gAKe6Y',
      );
    });

    test('ignores other links and short paths', () {
      expect(inviteTokenFrom('https://mantelier.app/auth/confirm'), isNull);
      expect(inviteTokenFrom('https://mantelier.app/i/abc'), isNull);
      expect(inviteTokenFrom('https://example.com/i/poqxGYMrR8qmJd9_gAKe6Y'), isNull);
      expect(inviteTokenFrom(null), isNull);
    });
  });

  group('inviteMonths', () {
    test('one month, two months in a year, across years', () {
      expect(inviteMonths(DateTime(2027, 5, 8), DateTime(2027, 5, 12)), 'May 2027');
      expect(
        inviteMonths(DateTime(2027, 5, 28), DateTime(2027, 6, 2)),
        'May to June 2027',
      );
      expect(
        inviteMonths(DateTime(2026, 12, 29), DateTime(2027, 1, 3)),
        'December 2026 to January 2027',
      );
    });
  });

  group('InviteLinkPreview', () {
    final visit = InviteLinkPreview.fromRow({
      'state': 'open',
      'kind': 'visit',
      'is_group': true,
      'needs_approval': false,
      'sender_name': 'Elise Laurent',
      'venue_type': 'restaurant',
      'venue_name': 'Hof van Cleve',
      'venue_city': 'Kruishoutem',
      'michelin_stars': 3,
      'visited_on': '2026-11-14',
      'code': 'K7Q2M9XD',
    }, token: 'tok');

    test('reads the row', () {
      expect(visit.isOpen, isTrue);
      expect(visit.kind, InviteLinkKind.visit);
      expect(visit.isGroup, isTrue);
      expect(visit.senderFirstName, 'Elise');
      expect(visit.targetLine, 'Hof van Cleve, 14 November 2026');
      expect(visit.code, 'K7Q2M9XD');
    });

    test('share message names the place and date, with no dashes', () {
      final message = visit.shareMessage('https://mantelier.app/i/tok');
      expect(
        message,
        'Elise Laurent invited you to Mantelier. We had dinner at Hof van '
        'Cleve on 14 November 2026. Accept and it goes straight into your '
        'Passport.\nhttps://mantelier.app/i/tok',
      );
      expect(message.contains('—'), isFalse);
      expect(message.contains(' - '), isFalse);
    });

    test('a trip message carries its months', () {
      final trip = InviteLinkPreview.fromRow({
        'state': 'own',
        'kind': 'trip',
        'sender_name': 'Elise Laurent',
        'trip_title': 'Piemonte in May',
        'trip_start_date': '2027-05-08',
        'trip_end_date': '2027-05-12',
      }, token: 'tok');
      expect(
        trip.shareMessage('u'),
        'Elise Laurent invited you on a trip: Piemonte in May, May 2027. '
        'Join on Mantelier.\nu',
      );
    });

    test('a friend link message', () {
      final friend = InviteLinkPreview.fromRow({
        'state': 'own',
        'kind': 'friend',
        'sender_name': 'Elise Laurent',
      }, token: 'tok');
      expect(
        friend.shareMessage('u'),
        'Elise Laurent invited you to Mantelier. Find unique events, '
        'experience impeccable hospitality, share memories with friends.\nu',
      );
    });

    test('an unknown sender reads as a member', () {
      final p = InviteLinkPreview.fromRow({'state': 'unavailable'}, token: 't');
      expect(p.sender, 'A member');
      expect(p.kind, isNull);
    });
  });

  test('MyInviteLink knows when it is still open', () {
    final now = DateTime.utc(2026, 11, 22, 12);
    final link = MyInviteLink.fromRow({
      'id': 'l1',
      'token': 'tok',
      'code': 'K7Q2M9XD',
      'kind': 'visit',
      'max_uses': 6,
      'use_count': 3,
      'expires_at': '2026-12-06T12:00:00Z',
      'revoked_at': null,
      'created_at': '2026-11-22T12:00:00Z',
      'venue_name': 'Hof van Cleve',
      'visited_on': '2026-11-14',
    });
    expect(link.isGroup, isTrue);
    expect(link.isOpen(now), isTrue);
    expect(link.title, 'Hof van Cleve, 14 November');
    expect(link.isOpen(DateTime.utc(2026, 12, 7)), isFalse);
  });

  group('AppNotification invite link rows', () {
    Map<String, dynamic> row(String type) => {
      'id': 'n1',
      'type': type,
      'subject_type': 'invite_link_redemption',
      'subject_id': 'r1',
      'is_read': false,
      'created_at': '2026-11-22T12:00:00Z',
      'other_user_id': 'u2',
      'other_display_name': 'Julien Martens',
      'link_kind': 'visit',
      'link_venue_name': 'Hof van Cleve',
      'link_visited_on': '2026-11-14',
      'link_redemption_status': 'approved',
      'link_became_friends': true,
      'link_visit_id': 'v2',
    };

    test('every new type is known and its fields parse', () {
      for (final type in [
        'invite_link_accepted',
        'invite_link_join_request',
        'invite_link_join_approved',
        'invite_link_join_declined',
      ]) {
        expect(AppNotification.tryFromRow(row(type)), isNotNull, reason: type);
      }
      final n = AppNotification.fromRow(row('invite_link_accepted'));
      expect(n.type, AppNotificationType.inviteLinkAccepted);
      expect(n.linkVenueName, 'Hof van Cleve');
      expect(n.linkVisitedOn, DateTime(2026, 11, 14));
      expect(n.linkBecameFriends, isTrue);
      expect(n.linkVisitId, 'v2');
    });
  });
}
