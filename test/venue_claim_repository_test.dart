// Covers claimConflictMessage() — the branching VenueClaimRepository.
// submitClaim() uses to turn a 23505 (unique_violation) into the right
// UI-safe StateError message. Tested directly against hand-built
// PostgrestExceptions rather than through submitClaim() itself: that
// method needs a real signed-in SupabaseClient to reach this code, and
// this repo has no existing pattern for faking a signed-in Supabase
// session in a test — mirrors venue_claim_model_test.dart's own approach
// of testing pure logic directly instead of routing through the network
// layer. Message text below is copied verbatim from a real rollback-
// transaction probe against the live database, not guessed.

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:michelin_passport/data/repositories/venue_claim_repository.dart';

void main() {
  group('claimConflictMessage', () {
    test(
      'a different user claiming a venue that already has a pending claim '
      '(claims_restaurants_one_pending_per_venue_uidx) gets told the venue '
      'is already under review, not that THEY already have a claim',
      () {
        const e = PostgrestException(
          message: 'duplicate key value violates unique constraint '
              '"claims_restaurants_one_pending_per_venue_uidx"',
          code: '23505',
          details: 'Key (restaurant_id)=(1dd94e66-ac31-44c0-904a-4b03b3e1be16) already exists.',
        );
        expect(
          claimConflictMessage(e),
          "This venue already has a claim under review. If you believe "
          "it's yours, get in touch and we'll take a look.",
        );
      },
    );

    test(
      'the same user claiming the same venue twice '
      '(claims_restaurants_active_uidx) gets told THEY already have a '
      'claim in progress — a different message from the case above',
      () {
        const e = PostgrestException(
          message: 'duplicate key value violates unique constraint '
              '"claims_restaurants_active_uidx"',
          code: '23505',
          details:
              'Key (user_id, restaurant_id)=(cd5e627f-ad26-4b5f-91a3-0fe5e94c8dc1, '
              '1dd94e66-ac31-44c0-904a-4b03b3e1be16) already exists.',
        );
        expect(
          claimConflictMessage(e),
          'You already have a claim in progress for this venue.',
        );
      },
    );

    test(
      'the same-user-active-claim message also covers claims_hotels/'
      'claims_private_chefs, which only ever have their own active_uidx '
      '(the new per-venue index is restaurant-only)',
      () {
        const hotel = PostgrestException(
          message: 'duplicate key value violates unique constraint "claims_hotels_active_uidx"',
          code: '23505',
        );
        const chef = PostgrestException(
          message:
              'duplicate key value violates unique constraint "claims_private_chefs_active_uidx"',
          code: '23505',
        );
        expect(claimConflictMessage(hotel), 'You already have a claim in progress for this venue.');
        expect(claimConflictMessage(chef), 'You already have a claim in progress for this venue.');
      },
    );

    test('a non-23505 PostgrestException is not handled here — the caller '
        'must rethrow it, never swallow it as a claim-conflict message', () {
      const e = PostgrestException(
        message: 'permission denied for table claims_restaurants',
        code: '42501',
      );
      expect(claimConflictMessage(e), isNull);
    });

    test('a 23505 from an unrelated constraint is not mapped to either '
        'claim-conflict message — stays null so the caller rethrows it '
        'unchanged rather than showing a misleading claim-specific message', () {
      const e = PostgrestException(
        message: 'duplicate key value violates unique constraint "some_other_table_uidx"',
        code: '23505',
      );
      expect(claimConflictMessage(e), isNull);
    });
  });
}
