import 'package:supabase_flutter/supabase_flutter.dart';

/// A restaurant, hotel or event a reporter couldn't find in the app —
/// deliberately not `venue_corrections`' `restaurant`/`hotel`/`private_
/// chef` shape (see the migration's own header for why). No enum needed
/// beyond this constant set of three wire values, matching how
/// `subject_type`'s own CHECK constraint is written.
enum MissingListingSubjectType {
  restaurant,
  hotel,
  event;

  String get wireValue => name;
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
