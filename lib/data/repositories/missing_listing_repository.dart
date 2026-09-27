import 'package:supabase_flutter/supabase_flutter.dart';

/// A restaurant, hotel, event or private chef a reporter couldn't find in
/// the app. `privateChef` was added for the venue-claim flow's own "type
/// + search, not found -> report it" step, which needs to cover every
/// venue type the claims tables do — the original three (restaurant/
/// hotel/event) predate that flow. `wireValue` can't just be `name` for
/// every case any more (`'privateChef'` is not a valid identifier match
/// for the `'private_chef'` the CHECK constraint/column actually store),
/// hence the explicit switch instead of the old one-line `=> name`.
enum MissingListingSubjectType {
  restaurant,
  hotel,
  event,
  privateChef;

  String get wireValue => switch (this) {
    MissingListingSubjectType.privateChef => 'private_chef',
    _ => name,
  };
}

/// A plain table insert — same shape as [ReportRepository.submitReport]
/// (content_reports): no state machine, just row ownership, resolving the
/// current user itself rather than asking every call site to pass it.
/// `missing_listing_reports_insert` RLS requires `reporter_id =
/// auth.uid()`. Nothing this class does ever reads a row back — there is
/// no select policy/grant on this table for any client role, by design
/// (the operator reads reports via the Supabase dashboard only).
class MissingListingRepository {
  MissingListingRepository(this._client);

  final SupabaseClient _client;

  Future<void> submitReport({
    required MissingListingSubjectType subjectType,
    required String name,
    required String city,
    required String message,
    String? reporterRole,
    String? reporterContact,
  }) async {
    final reporterId = _client.auth.currentUser?.id;
    if (reporterId == null) throw StateError('Not authenticated');
    final worksHere = reporterRole != null || reporterContact != null;
    await _client.from('missing_listing_reports').insert({
      'reporter_id': reporterId,
      'subject_type': subjectType.wireValue,
      'name': name.trim(),
      'city': city.trim(),
      'message': message.trim(),
      'works_here': worksHere,
      if (reporterRole != null) 'reporter_role': reporterRole.trim(),
      if (reporterContact != null) 'reporter_contact': reporterContact.trim(),
    });
  }
}
