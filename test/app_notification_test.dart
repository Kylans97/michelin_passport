// Covers AppNotification.fromRow's mapping — a pure function, the only
// coverage available for this model (NotificationsRepository itself has
// no DI seam, same established limitation as every other Supabase-eager
// repository in this app).

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/models/app_notification.dart';

Map<String, dynamic> _friendshipRow({
  required String type,
  bool isRead = false,
}) => {
  'id': 'notif-1',
  'type': type,
  'subject_type': 'friendship',
  'subject_id': 'friendship-1',
  'is_read': isRead,
  'created_at': '2026-01-01T00:00:00Z',
  'other_user_id': 'user-2',
  'other_username': 'kylan',
  'other_display_name': 'Kylan',
  'other_avatar_url': null,
  'listing_subject_type': null,
  'listing_name': null,
  'listing_city': null,
};

Map<String, dynamic> _submissionRow({
  required String type,
  required String subjectType,
  String? reviewNote,
}) => {
  'id': 'notif-3',
  'type': type,
  'subject_type': subjectType,
  'subject_id': 'submission-1',
  'is_read': false,
  'created_at': '2026-01-03T00:00:00Z',
  'other_user_id': null,
  'other_username': null,
  'other_display_name': null,
  'other_avatar_url': null,
  'listing_subject_type': null,
  'listing_name': null,
  'listing_city': null,
  'submission_venue_type': 'restaurant',
  'submission_venue_id': 'r1',
  'submission_venue_name': 'Flore',
  'submission_venue_city': 'Amsterdam',
  'submission_review_note': reviewNote,
};

Map<String, dynamic> _claimRow({required String type, String? reviewNote}) => {
  'id': 'notif-4',
  'type': type,
  'subject_type': 'venue_claim',
  'subject_id': 'claim-1',
  'is_read': false,
  'created_at': '2026-01-04T00:00:00Z',
  'other_user_id': null,
  'other_username': null,
  'other_display_name': null,
  'other_avatar_url': null,
  'listing_subject_type': null,
  'listing_name': null,
  'listing_city': null,
  'claim_venue_type': 'restaurant',
  'claim_venue_id': 'r1',
  'claim_venue_name': 'Flore',
  'claim_venue_city': 'Amsterdam',
  'claim_review_note': reviewNote,
};

Map<String, dynamic> _listingRow() => {
  'id': 'notif-2',
  'type': 'missing_listing_added',
  'subject_type': 'missing_listing_report',
  'subject_id': 'report-1',
  'is_read': false,
  'created_at': '2026-01-02T00:00:00Z',
  'other_user_id': null,
  'other_username': null,
  'other_display_name': null,
  'other_avatar_url': null,
  'listing_subject_type': 'restaurant',
  'listing_name': 'Flore',
  'listing_city': 'Amsterdam',
};

void main() {
  group('AppNotificationType.fromWire', () {
    test('maps every wire value the CHECK constraint allows', () {
      expect(
        AppNotificationType.fromWire('friend_request_received'),
        AppNotificationType.friendRequestReceived,
      );
      expect(
        AppNotificationType.fromWire('friend_request_accepted'),
        AppNotificationType.friendRequestAccepted,
      );
      expect(
        AppNotificationType.fromWire('missing_listing_added'),
        AppNotificationType.missingListingAdded,
      );
      expect(
        AppNotificationType.fromWire('venue_about_approved'),
        AppNotificationType.venueAboutApproved,
      );
      expect(
        AppNotificationType.fromWire('venue_about_rejected'),
        AppNotificationType.venueAboutRejected,
      );
      expect(
        AppNotificationType.fromWire('venue_photo_approved'),
        AppNotificationType.venuePhotoApproved,
      );
      expect(
        AppNotificationType.fromWire('venue_photo_rejected'),
        AppNotificationType.venuePhotoRejected,
      );
    });

    test('throws on an unrecognized value rather than silently defaulting',
        () {
      expect(
        () => AppNotificationType.fromWire('something_else'),
        throwsArgumentError,
      );
    });
  });

  group('AppNotification.fromRow', () {
    test('maps a friend-request-received row, including the other '
        "person's identity", () {
      final n = AppNotification.fromRow(
        _friendshipRow(type: 'friend_request_received'),
      );
      expect(n.type, AppNotificationType.friendRequestReceived);
      expect(n.subjectType, 'friendship');
      expect(n.subjectId, 'friendship-1');
      expect(n.isRead, isFalse);
      expect(n.otherUserId, 'user-2');
      expect(n.otherLabel, 'Kylan');
      expect(n.listingName, isNull);
    });

    test('maps a missing-listing-added row, including listing context', () {
      final n = AppNotification.fromRow(_listingRow());
      expect(n.type, AppNotificationType.missingListingAdded);
      expect(n.subjectType, 'missing_listing_report');
      expect(n.listingName, 'Flore');
      expect(n.listingCity, 'Amsterdam');
      expect(n.otherUserId, isNull);
    });

    test('is_read is read faithfully, not assumed false', () {
      final n = AppNotification.fromRow(
        _friendshipRow(type: 'friend_request_accepted', isRead: true),
      );
      expect(n.isRead, isTrue);
    });

    test('maps a venue-about-rejected row, including the venue and the '
        "reviewer's own note", () {
      final n = AppNotification.fromRow(
        _submissionRow(
          type: 'venue_about_rejected',
          subjectType: 'venue_about_submission',
          reviewNote: 'Please rewrite without contact details.',
        ),
      );
      expect(n.type, AppNotificationType.venueAboutRejected);
      expect(n.subjectType, 'venue_about_submission');
      expect(n.submissionVenueName, 'Flore');
      expect(n.submissionVenueCity, 'Amsterdam');
      expect(
        n.submissionReviewNote,
        'Please rewrite without contact details.',
      );
    });

    test('maps a venue-photo-approved row — no review note on an approval',
        () {
      final n = AppNotification.fromRow(
        _submissionRow(
          type: 'venue_photo_approved',
          subjectType: 'venue_photo_submission',
        ),
      );
      expect(n.type, AppNotificationType.venuePhotoApproved);
      expect(n.subjectType, 'venue_photo_submission');
      expect(n.submissionVenueName, 'Flore');
      expect(n.submissionReviewNote, isNull);
    });

    test('maps a venue-claim-rejected row, including the reviewer\'s own '
        'note', () {
      final n = AppNotification.fromRow(
        _claimRow(
          type: 'venue_claim_rejected',
          reviewNote: 'Could not verify ownership of this listing.',
        ),
      );
      expect(n.type, AppNotificationType.venueClaimRejected);
      expect(n.claimVenueName, 'Flore');
      expect(n.claimVenueCity, 'Amsterdam');
      expect(
        n.claimReviewNote,
        'Could not verify ownership of this listing.',
      );
    });

    test('maps a venue-claim-approved row — no review note on an approval',
        () {
      final n = AppNotification.fromRow(
        _claimRow(type: 'venue_claim_approved'),
      );
      expect(n.type, AppNotificationType.venueClaimApproved);
      expect(n.claimVenueName, 'Flore');
      expect(n.claimReviewNote, isNull);
    });
  });

  group('AppNotification.otherLabel fallback order', () {
    test('falls back to @username when display_name is blank', () {
      final row = _friendshipRow(type: 'friend_request_received')
        ..['other_display_name'] = '';
      final n = AppNotification.fromRow(row);
      expect(n.otherLabel, '@kylan');
    });

    test('falls back to a neutral default when neither is available', () {
      final row = _friendshipRow(type: 'friend_request_received')
        ..['other_display_name'] = null
        ..['other_username'] = null;
      final n = AppNotification.fromRow(row);
      expect(n.otherLabel, 'Mantelier member');
    });
  });
}
