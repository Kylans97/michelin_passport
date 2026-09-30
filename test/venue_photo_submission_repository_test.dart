// Covers photoSubmissionConflictMessage() — the branching
// VenuePhotoSubmissionRepository.submit() uses to turn a 23505
// (unique_violation) into the right UI-safe StateError message. Tested
// directly against a hand-built PostgrestException rather than through
// submit() itself: that method needs a real signed-in SupabaseClient with
// Storage access to reach this code, and this repo has no existing
// pattern for faking that in a test — mirrors venue_claim_repository_
// test.dart's own approach exactly. Message text below is copied verbatim
// from a real rollback-transaction probe against the live database, not
// guessed.

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:michelin_passport/data/repositories/venue_photo_submission_repository.dart';

void main() {
  group('photoSubmissionConflictMessage', () {
    test(
      'a second pending submission naming the same replaces_photo_id '
      '(venue_photo_submissions_one_pending_replacement_uidx) is told a '
      'replacement is already awaiting review, not shown the raw '
      'constraint name',
      () {
        const e = PostgrestException(
          message: 'duplicate key value violates unique constraint '
              '"venue_photo_submissions_one_pending_replacement_uidx"',
          code: '23505',
          details:
              'Key (replaces_photo_id)=(11111111-1111-1111-1111-111111111111) '
              'already exists.',
        );
        expect(
          photoSubmissionConflictMessage(e),
          "A replacement for this photo is already awaiting review. "
          "You can submit another once that one's been decided.",
        );
      },
    );

    test('a non-23505 PostgrestException is not handled here — the caller '
        'must rethrow it, never swallow it as a submission-conflict '
        'message', () {
      const e = PostgrestException(
        message: 'permission denied for table venue_photo_submissions',
        code: '42501',
      );
      expect(photoSubmissionConflictMessage(e), isNull);
    });

    test('a 23505 from an unrelated constraint (e.g. the near-duplicate-'
        'photo check) is not mapped to the replacement-conflict message — '
        'stays null so the caller rethrows it unchanged rather than '
        'showing a misleading message', () {
      const e = PostgrestException(
        message: 'duplicate key value violates unique constraint '
            '"some_other_table_uidx"',
        code: '23505',
      );
      expect(photoSubmissionConflictMessage(e), isNull);
    });
  });
}
