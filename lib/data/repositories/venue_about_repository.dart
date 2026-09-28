import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/venue_about_submission.dart';

/// The real DB constraint (venue_about_submissions.about_text's own
/// `check (char_length(about_text) <= 900)`, 20260828120000) — mirrored
/// here, not picked independently, so the UI's live character count
/// stays truthful. If that constraint is ever changed, this must change
/// with it; there is no way to read a CHECK constraint's literal value
/// from the client at runtime, so this is the traceable, documented
/// alternative.
const venueAboutTextMaxLength = 900;

/// Reads/writes venue_about_submissions — the review-queue table an
/// approved venue_managers_* grant is authorized to insert into (RLS:
/// `is_active_venue_manager(venue_type, venue_id)`, migrated onto that
/// function today — see 20261001120000_venue_managers_cutover.sql).
/// There is no update/delete path for any client role: a manager submits
/// a NEW row every time, never edits an existing one — review (approve/
/// reject) is a service_role/dashboard-only action, unchanged from the
/// claims review pattern.
class VenueAboutRepository {
  VenueAboutRepository(this._client);

  final SupabaseClient _client;

  /// The venue's current, LIVE about text — the latest APPROVED
  /// submission, via the venue_about_current view (DISTINCT ON venue_
  /// type/venue_id, newest reviewed_at wins). `null` when nothing has
  /// ever been approved for this venue yet, which is the normal,
  /// expected state for every venue today (confirmed live: 0 rows in
  /// venue_about_current project-wide before this feature existed).
  Future<String?> loadCurrentText({required String venueType, required String venueId}) async {
    final row = await _client
        .from('venue_about_current')
        .select('about_text')
        .eq('venue_type', venueType)
        .eq('venue_id', venueId)
        .maybeSingle();
    return row?['about_text'] as String?;
  }

  /// The signed-in user's own most recent submission for this venue,
  /// whatever its status — pending, approved, or rejected — so the
  /// screen can say "your last submission is awaiting review" or "wasn't
  /// approved" rather than staying silent. `null` when they've never
  /// submitted anything for this venue.
  Future<VenueAboutSubmission?> loadMyLatestSubmission({
    required String venueType,
    required String venueId,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    final row = await _client
        .from('venue_about_submissions')
        .select('id, about_text, status, submitted_at')
        .eq('user_id', userId)
        .eq('venue_type', venueType)
        .eq('venue_id', venueId)
        .order('submitted_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (row == null) return null;
    return VenueAboutSubmission.fromJson(row);
  }

  /// Files a new about-text submission. Always lands as `pending` (the
  /// column default; nothing here can set any other status) — it does
  /// NOT become the venue's current text until a human approves it via
  /// the dashboard. Resubmitting while a previous submission is still
  /// pending is allowed (no uniqueness constraint on this table blocks
  /// it) — a manager revising their own wording before review is a
  /// normal, expected case, not a conflict to guard against.
  Future<void> submit({
    required String venueType,
    required String venueId,
    required String aboutText,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Not authenticated');
    await _client.from('venue_about_submissions').insert({
      'user_id': userId,
      'venue_type': venueType,
      'venue_id': venueId,
      'about_text': aboutText,
    });
  }
}
