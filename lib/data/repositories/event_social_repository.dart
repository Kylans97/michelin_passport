import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/going_member_count.dart';

/// Events V2 Step 7 — reads the anonymous, platform-wide Going count for
/// one Event via `get_event_going_member_count`, a `SECURITY DEFINER` SQL
/// function that caps its own return value at 100 server-side (see that
/// function's own migration for the full contract). Deliberately its own
/// small repository, not folded into [EventAttendanceRepository] — that
/// repository's own doc comment already draws this exact line for its
/// sibling function (`get_event_attendance_count`): an identity-free,
/// k-anonymized aggregate is a structurally different concern from
/// reading/writing the caller's own or a friend's individual intent rows,
/// and deserves its own small, obviously-scoped class rather than growing
/// an existing one with a concern it was never about.
class EventSocialRepository {
  EventSocialRepository(this._client);

  final SupabaseClient _client;

  /// The capped Going count for [eventId] — never the exact platform-wide
  /// total once it reaches 100 or more; see [GoingMemberCount]'s own doc
  /// comment. A non-existent [eventId] resolves to a count of 0, the same
  /// as a real event nobody has marked Going for yet — the RPC itself
  /// makes no distinction, so neither does this method.
  Future<GoingMemberCount> getGoingMemberCount(String eventId) async {
    final result = await _client.rpc(
      'get_event_going_member_count',
      params: {'target_event_id': eventId},
    );
    return GoingMemberCount(result as int);
  }
}
