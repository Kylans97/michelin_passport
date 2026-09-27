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

  /// Throws a plain [StateError] with a UI-safe message on the one
  /// expected failure — the venue already has an active (pending/
  /// approved/blocked) claim from this same user, per the partial unique
  /// index the migration widened to cover all three of those statuses.
  /// Any other [PostgrestException] is rethrown unchanged.
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
      if (e.code == '23505') {
        throw StateError('You already have a claim in progress for this venue.');
      }
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
