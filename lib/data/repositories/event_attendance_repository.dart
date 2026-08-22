import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/event_time.dart';
import '../../models/event.dart';
import '../../models/event_attendance.dart';
import '../../models/event_chronology.dart';
import '../../models/event_intent.dart';

// Every column on public.event_attendance. Listed explicitly, rather than
// select('*'), so a schema change is a visible diff here — matching this
// project's established convention (see VisitedRepository/PhotoRepository).
const _attendanceColumns =
    'id, event_id, user_id, status, visibility, created_at';

/// Reads/writes `public.event_attendance` — the Interested/Going INTENT
/// table (Social Foundation Step 2B, widened by Events V2 Step 1). Plain
/// client-side ownership writes, not RPC-mediated — setting/removing
/// intent is a simple row create/update/delete against the caller's own
/// row, the same shape WishlistRepository already uses, not a multi-party
/// state machine like friendships (no role-asymmetric transition rule
/// exists here the way friend-request accept/decline needs one). RLS
/// (event_attendance_select/_insert/_update/_delete) is the actual
/// security boundary throughout; every read here returns only what the
/// database already decided the caller may see.
///
/// Deliberately does NOT model confirmed Attendance — that's
/// `event_confirmed_attendance`, a structurally separate table/concept,
/// out of scope for this repository entirely (Events V2 Step 3's own hard
/// scope boundary).
class EventAttendanceRepository {
  EventAttendanceRepository(this._client);

  final SupabaseClient _client;

  /// The caller's own intent row for [eventId], or null if none recorded
  /// (NONE — see event_intent.dart's own header comment for why NONE is a
  /// null EventAttendance, not a status value).
  Future<EventAttendance?> getMyEventIntent({
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

  /// Sets the caller's intent for [eventId] to [status] — covers every
  /// legal transition into INTERESTED or GOING (NONE→X or a switch away
  /// from whatever the current status was) with one method, never a
  /// separate markInterested()/markGoing() pair. Visibility is always
  /// derived from [status] via [visibilityForIntent] — never a caller-
  /// supplied value — so a switch can never accidentally carry a
  /// friends-visible value onto Interested (see that function's own doc
  /// comment for the approved rule).
  ///
  /// Idempotent and switch-safe: tries INSERT first (the common NONE→X
  /// case); a unique(event_id, user_id) violation means a row already
  /// exists (a switch, or the exact same status re-tapped), so that row
  /// is UPDATEd in place instead of leaving two conflicting writes to
  /// reconcile — the same "already-in-that-state is fine" idempotency
  /// pattern WishlistRepository/markGoing's own predecessor already used
  /// for the identical unique-violation case, extended to also cover an
  /// actual status change rather than only a no-op retry.
  Future<EventAttendance> setEventIntent({
    required String userId,
    required String eventId,
    required EventIntentStatus status,
  }) async {
    final visibility = visibilityForIntent(status);
    try {
      final row = await _client
          .from('event_attendance')
          .insert({
            'event_id': eventId,
            'user_id': userId,
            'status': status.dbValue,
            'visibility': visibility.dbValue,
          })
          .select(_attendanceColumns)
          .single();
      return EventAttendance.fromJson(row);
    } on PostgrestException catch (e) {
      if (e.code != '23505') rethrow;
      final row = await _client
          .from('event_attendance')
          .update({'status': status.dbValue, 'visibility': visibility.dbValue})
          .eq('event_id', eventId)
          .eq('user_id', userId)
          .select(_attendanceColumns)
          .single();
      return EventAttendance.fromJson(row);
    }
  }

  /// Removes the caller's own intent entirely (→ NONE). Scoped by both
  /// event_id and user_id — belt-and-suspenders alongside RLS
  /// (event_attendance_delete is already owner-only), matching every
  /// other owner-write method in this codebase.
  Future<void> removeEventIntent({
    required String userId,
    required String eventId,
  }) async {
    await _client
        .from('event_attendance')
        .delete()
        .eq('event_id', eventId)
        .eq('user_id', userId);
  }

  /// Every user_id RLS (event_attendance_select) allows the caller to see
  /// for [eventId] with the given [status] — the caller's own row (if it
  /// matches [status]) plus any accepted friend's friends-visible row (if
  /// it matches [status]), and nothing else. The [status] filter is
  /// mandatory, not cosmetic: before Events V2 Step 1, `status` had only
  /// one legal value ('going'), so this query never needed to filter by
  /// it; now that 'interested' is also legal, an unfiltered query would
  /// return BOTH intents indiscriminately, which would silently leak
  /// Interested rows into what every caller today still assumes is a
  /// Going-only list (Friends Going, Friend Profile's GOING section).
  /// Callers pass `status: EventIntentStatus.going` today; a future
  /// Friends Interested feature (not built — Events V2 Step 3's explicit
  /// scope boundary) can reuse this exact method with `status:
  /// EventIntentStatus.interested` once its own privacy model is
  /// approved — Interested is private-by-default in MVP (see
  /// visibilityForIntent), so it is never friends-visible today
  /// regardless, but this filter is the query-level guarantee, not merely
  /// a side effect of the visibility default.
  ///
  /// Community/Friends Step 1A: this is the "event → its visible
  /// attendees" direction, the inverse of [getFriendUpcomingEvents] ("one
  /// friend → their events") — the two are not interchangeable. Distinct
  /// from get_event_attendance_count, which returns a k-anonymized global
  /// number with no identities at all — not reused or repurposed here.
  Future<List<String>> getVisibleUserIds({
    required String eventId,
    required EventIntentStatus status,
  }) async {
    final rows = await _client
        .from('event_attendance')
        .select('user_id')
        .eq('event_id', eventId)
        .eq('status', status.dbValue);
    return [for (final row in rows as List) row['user_id'] as String];
  }

  /// Events V2 Step 8A — the discovery-list counterpart to
  /// [getVisibleUserIds]'s single-event shape: every visible (own or
  /// accepted-friend, per RLS) attendance row with the given [status]
  /// across ALL of [eventIds] in ONE query, grouped by event id.
  /// `event_attendance_select` RLS
  /// (`user_id = auth.uid() OR (visibility = 'friends' AND
  /// is_friend(user_id))`) has no per-event dependency in its own logic —
  /// it only ever reasons about the ROW's own user_id/visibility — so
  /// filtering by `event_id IN (...)` instead of `.eq()` still applies that
  /// exact same per-row guarantee across many events at once. This is why
  /// one call here replaces what would otherwise be one [getVisibleUserIds]
  /// call per event on a discovery list of any size — the N+1 shape Step 8A
  /// §14 explicitly prohibits. An [eventId] with no visible rows for
  /// [status] is simply absent from the result map, never an empty-list
  /// entry.
  Future<Map<String, List<String>>> getVisibleUserIdsForEvents({
    required List<String> eventIds,
    required EventIntentStatus status,
  }) async {
    if (eventIds.isEmpty) return {};
    final rows = await _client
        .from('event_attendance')
        .select('event_id, user_id')
        .inFilter('event_id', eventIds)
        .eq('status', status.dbValue);
    final result = <String, List<String>>{};
    for (final row in rows as List) {
      final eventId = row['event_id'] as String;
      final userId = row['user_id'] as String;
      (result[eventId] ??= <String>[]).add(userId);
    }
    return result;
  }

  /// Every future/current event [userId] has the given [status] for that
  /// the caller is authorized to see — RLS alone decides that; this never
  /// fetches a broader set and filters client-side BEYOND the precision-
  /// aware upcoming/past split below. The [status] filter exists for the
  /// identical reason [getVisibleUserIds]'s own does — see that method's
  /// doc comment; Friend Profile's GOING section passes `status:
  /// EventIntentStatus.going` and must never show a friend's Interested
  /// events under a "GOING" heading. Past events are excluded here (Friend
  /// Profile GOING intentionally shows only upcoming/current intent),
  /// soonest first. Two queries total regardless of how many events: one
  /// for the intent rows, one batched `events` lookup — never one query
  /// per event.
  ///
  /// Events V2 Time Precision Phase B: the upcoming/past split is now
  /// [eventHasEnded] (exact `end_at` instant when known — identical
  /// behavior to before Phase B for every one of today's full-precision
  /// Events — else the local-day-end of `end_date`), applied Dart-side
  /// after a single batched fetch, rather than a `.gte('end_at', now)` SQL
  /// filter. Production still has `end_at NOT NULL` on every row today
  /// (Phase A only), so this produces byte-identical results to the old
  /// SQL filter right now — but a SQL `NULL` comparison is neither true
  /// nor false, so once Phase C ever lets `end_at` be null, the old filter
  /// would have silently excluded every date-only Event from this query
  /// forever. Preparing this now means Phase C needs zero further changes
  /// here.
  Future<List<Event>> getFriendUpcomingEvents({
    required String userId,
    required EventIntentStatus status,
  }) async {
    final attendanceRows = await _client
        .from('event_attendance')
        .select('event_id')
        .eq('user_id', userId)
        .eq('status', status.dbValue);
    final eventIds = [
      for (final row in attendanceRows as List) row['event_id'] as String,
    ];
    if (eventIds.isEmpty) return [];

    final rows = await _client.from('events').select().inFilter('id', eventIds);
    final now = DateTime.now().toUtc();
    final events =
        [
              for (final row in rows as List)
                Event.fromJson(row as Map<String, dynamic>),
            ]
            .where(
              (event) => !eventHasEnded(
                endAt: event.endAt,
                endDate: event.endDate,
                timezone: event.timezone,
                now: now,
              ),
            )
            .toList()
          ..sort(compareEventChronology);
    return events;
  }

  /// Every event [userId] currently has an active GOING intent for that
  /// has already ended — the raw candidate pool for Events V2 Step 4's
  /// "Did you make it?" prompt surfaces. Deliberately unfiltered by
  /// cancellation, lookback window, or existing confirmed attendance —
  /// [mostRecentEligibleAttendancePromptEvent] (event_attendance_
  /// eligibility.dart) applies every one of those rules itself, so this
  /// method stays a plain, reusable "past Going events" query, the mirror
  /// image of [getFriendUpcomingEvents]'s own "future/current" query.
  /// [maxCount] bounds how many past-Going rows are ever fetched — no
  /// signed-in user is expected to have more than a handful of unresolved
  /// past-Going events at once, and this is a client-side candidate list,
  /// not a paginated feed.
  ///
  /// Events V2 Time Precision Phase B: same rationale as
  /// [getFriendUpcomingEvents] — the past-events filter is now
  /// [eventHasEnded], applied Dart-side, not a `.lt('end_at', now)` SQL
  /// filter that would silently exclude a future date-only Event once
  /// `end_at` can be null.
  Future<List<Event>> getPastGoingEvents({
    required String userId,
    int maxCount = 20,
  }) async {
    final attendanceRows = await _client
        .from('event_attendance')
        .select('event_id')
        .eq('user_id', userId)
        .eq('status', EventIntentStatus.going.dbValue)
        .limit(maxCount);
    final eventIds = [
      for (final row in attendanceRows as List) row['event_id'] as String,
    ];
    if (eventIds.isEmpty) return [];

    final rows = await _client.from('events').select().inFilter('id', eventIds);
    final now = DateTime.now().toUtc();
    return [
          for (final row in rows as List)
            Event.fromJson(row as Map<String, dynamic>),
        ]
        .where(
          (event) => eventHasEnded(
            endAt: event.endAt,
            endDate: event.endDate,
            timezone: event.timezone,
            now: now,
          ),
        )
        .toList();
  }
}
