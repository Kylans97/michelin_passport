import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/venue_claim.dart';

String _tableFor(VenueClaimVenueType type) => switch (type) {
  VenueClaimVenueType.restaurant => 'claims_restaurants',
  VenueClaimVenueType.hotel => 'claims_hotels',
  VenueClaimVenueType.privateChef => 'claims_private_chefs',
};

String _venueColumnFor(VenueClaimVenueType type) => switch (type) {
  VenueClaimVenueType.restaurant => 'restaurant_id',
  VenueClaimVenueType.hotel => 'hotel_id',
  VenueClaimVenueType.privateChef => 'private_chef_id',
};

/// Maps a 23505 (unique_violation) from a claim insert to the UI-safe
/// message the two live cases actually need — `null` for anything else
/// (any other constraint, or not a 23505 at all), so the caller knows to
/// rethrow rather than substitute a message. A top-level function, not a
/// private method, and `@visibleForTesting`, purely so
/// `test/venue_claim_repository_test.dart` can exercise the branching
/// directly against hand-built [PostgrestException]s — this repository's
/// own [submitClaim] needs a real signed-in [SupabaseClient] to reach
/// this code any other way, and this codebase has no existing pattern for
/// faking a signed-in Supabase session in a test (confirmed before
/// writing this: no test in this repo mocks GoTrue). Matches
/// venue_claim_model_test.dart's own established approach of testing the
/// pure logic directly instead.
///
/// Postgres/PostgREST put the constraint name only in
/// [PostgrestException.message] (e.g. `duplicate key value violates
/// unique constraint "claims_restaurants_active_uidx"`) — there is no
/// separate structured "constraint" field — so matching against it is the
/// only way to tell these two apart. Confirmed against the real error
/// text via a rollback-transaction probe against the live database before
/// writing this, not assumed.
@visibleForTesting
String? claimConflictMessage(PostgrestException e) {
  if (e.code != '23505') return null;
  if (e.message.contains('claims_restaurants_one_pending_per_venue_uidx')) {
    // A DIFFERENT user's claim on this same restaurant is already
    // pending — added by
    // 20260928120000_harden_claims_restaurants_insert_rls.sql,
    // restaurants only (see that migration's own header for why
    // claims_hotels/claims_private_chefs weren't widened at the same
    // time), so this branch can only ever fire for restaurant claims.
    return "This venue already has a claim under review. If you believe "
        "it's yours, get in touch and we'll take a look.";
  }
  // claims_restaurants_active_uidx / claims_hotels_active_uidx /
  // claims_private_chefs_active_uidx (matched by their shared naming
  // convention, not each spelled out) — THIS user already has an active
  // (pending/approved/blocked) claim on this venue.
  if (e.message.contains('_active_uidx')) {
    return 'You already have a claim in progress for this venue.';
  }
  // Any other 23505 — an unrelated constraint — is deliberately left
  // unmapped so submitClaim() rethrows it unchanged rather than showing
  // a claim-conflict message for a conflict that isn't one.
  return null;
}

/// Plain table writes/reads against whichever of `claims_restaurants`/
/// `claims_hotels`/`claims_private_chefs` matches the venue type — no RPC
/// needed, since `..._insert` RLS (`user_id = auth.uid()`) already is the
/// only check an insert needs, and there is no client-facing way to
/// change `status` at all (see the tables' own migration: approval is a
/// manual Supabase-dashboard action, by explicit product decision — "geen
/// beheerscherm in de app").
class VenueClaimRepository {
  VenueClaimRepository(this._client);

  final SupabaseClient _client;

  /// Throws a plain [StateError] with a UI-safe message on the expected
  /// 23505 (unique_violation) failures — see [claimConflictMessage] for
  /// which ones and why they need different wording. Any other
  /// [PostgrestException] is rethrown unchanged.
  Future<void> submitClaim({
    required VenueClaimVenueType venueType,
    required String venueId,
    required VenueClaimRole role,
    required String businessEmail,
    required String phone,
    String? notes,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Not authenticated');

    try {
      await _client.from(_tableFor(venueType)).insert({
        'user_id': userId,
        _venueColumnFor(venueType): venueId,
        'role': role.wireValue,
        'business_email': businessEmail.trim(),
        'phone': phone.trim(),
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      });
    } on PostgrestException catch (e) {
      final message = claimConflictMessage(e);
      if (message != null) throw StateError(message);
      rethrow;
    }
  }

  /// Every claim the current user has ever filed, across all three venue
  /// types, newest first — used to gate "my venue" management entry
  /// points on `status == approved` and to stop someone re-submitting a
  /// claim that's already pending. Three small selects, not a union view
  /// — no such view exists (the claims tables are deliberately typed, not
  /// polymorphic; see their own migration header), and a user's own claim
  /// count is always small enough that three round trips is not a real
  /// concern.
  Future<List<VenueClaim>> loadMyClaims() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final results = await Future.wait([
      _client
          .from('claims_restaurants')
          .select('id, restaurant_id, status, requested_at')
          .eq('user_id', userId),
      _client
          .from('claims_hotels')
          .select('id, hotel_id, status, requested_at')
          .eq('user_id', userId),
      _client
          .from('claims_private_chefs')
          .select('id, private_chef_id, status, requested_at')
          .eq('user_id', userId),
    ]);

    final claims = [
      for (final row in results[0])
        VenueClaim.fromJson(
          row,
          venueType: VenueClaimVenueType.restaurant,
          venueIdColumn: 'restaurant_id',
        ),
      for (final row in results[1])
        VenueClaim.fromJson(
          row,
          venueType: VenueClaimVenueType.hotel,
          venueIdColumn: 'hotel_id',
        ),
      for (final row in results[2])
        VenueClaim.fromJson(
          row,
          venueType: VenueClaimVenueType.privateChef,
          venueIdColumn: 'private_chef_id',
        ),
    ]..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
    return claims;
  }
}
