import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/event.dart';
import '../../models/event_attendance.dart';

// Every column on public.event_attendance. Listed explicitly, rather than
// select('*'), so a schema change is a visible diff here — matching this
// project's established convention (see VisitedRepository/PhotoRepository).
const _attendanceColumns =
    'id, event_id, user_id, status, visibility, created_at';

/// Reads/writes `public.event_attendance` (Social Foundation Step 2B).
/// Plain client-side ownership writes, not RPC-mediated — "mark going"/
/// "remove attendance" are simple row create/delete against the caller's
/// own row, the same shape WishlistRepository already uses, not a
/// multi-party state machine like friendships. RLS
/// (event_attendance_select/_insert/_update/_delete) is the actual
/// security boundary throughout; every read here returns only what the
/// database already decided the caller may see.
class EventAttendanceRepository {
  EventAttendanceRepository(this._client);

  final SupabaseClient _client;

  /// The caller's own attendance row for [eventId], or null if not going.
  Future<EventAttendance?> getMyAttendance({
    required String userId,
    required String eventId,
  }) async {
    final rows = await _client
        .from('event_attendance')
        .select(_attendanceColumns)
        .eq('event_id', eventId)
        .eq('user_id', userId)
        .limit(1);
    final list = rows as List;
    if (list.isEmpty) return null;
    return EventAttendance.fromJson(list.first as Map<String, dynamic>);
  }

  /// Marks the caller as going to [eventId]. Defaults to friends-visible —
  /// see the migration's own comment for why that default (not private)
  /// was chosen. Idempotent: if a row already exists (e.g. the user
  /// reopened Event Detail after already marking going), the table's own
  /// unique(event_id, user_id) raises 23505, which is treated as success
  /// and the existing row is returned — same "already-in-that-state is
  /// fine" pattern WishlistRepository._add already uses for the identical
  /// unique-violation case, not a new one-off.
  Future<EventAttendance> markGoing({
    required String userId,
    required String eventId,
    AttendanceVisibility visibility = AttendanceVisibility.friends,
  }) async {
    try {
      final row = await _client
          .from('event_attendance')
          .insert({
            'event_id': eventId,
            'user_id': userId,
            'status': 'going',
            'visibility': visibility.dbValue,
          })
          .select(_attendanceColumns)
          .single();
      return EventAttendance.fromJson(row);
    } on PostgrestException catch (e) {
      if (e.code != '23505') rethrow;
      final existing = await getMyAttendance(userId: userId, eventId: eventId);
      if (existing == null) rethrow;
      return existing;
    }
  }

  /// Removes the caller's own attendance. Scoped by both event_id and
  /// user_id — belt-and-suspenders alongside RLS (event_attendance_delete
  /// is already owner-only), matching every other owner-write method in
  /// this codebase.
  Future<void> removeAttendance({
    required String userId,
    required String eventId,
  }) async {
    await _client
        .from('event_attendance')
        .delete()
        .eq('event_id', eventId)
        .eq('user_id', userId);
  }

  /// Every future/current event [userId] is going to that the caller is
  /// authorized to see — RLS alone decides that; this never fetches a
  /// broader set and filters client-side. Past events are excluded here
  /// (Friend Profile GOING intentionally shows only upcoming/current
  /// attendance — task's own explicit instruction), soonest first. Two
  /// queries total regardless of how many events: one for the attendance
  /// rows, one batched `events` lookup — never one query per event.
  Future<List<Event>> getFriendUpcomingAttendance(String userId) async {
    final attendanceRows = await _client
        .from('event_attendance')
        .select('event_id')
        .eq('user_id', userId);
    final eventIds = [
      for (final row in attendanceRows as List) row['event_id'] as String,
    ];
    if (eventIds.isEmpty) return [];

    final rows = await _client
        .from('events')
        .select()
        .inFilter('id', eventIds)
        .gte('end_at', DateTime.now().toUtc().toIso8601String())
        .order('start_at', ascending: true);
    return [
      for (final row in rows as List)
        Event.fromJson(row as Map<String, dynamic>),
    ];
  }
}
