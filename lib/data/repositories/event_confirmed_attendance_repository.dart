import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/event.dart';
import '../../models/event_chronology.dart';
import '../../models/event_confirmed_attendance.dart';
import 'photo_repository.dart';

// Every column on public.event_confirmed_attendance. Listed explicitly,
// rather than select('*'), matching EventAttendanceRepository/
// VisitedRepository/PhotoRepository's own established convention — a
// schema change is a visible diff here.
const _attendanceColumns =
    'id, event_id, user_id, confirmed_at, rating, would_recommend, comment, '
    'visibility, source, created_at';

/// One (event, user) pair a Passport Event card needs: the confirmed
/// attendance row itself plus the Event it's about. Kept as a plain pair,
/// not folded into a shared union with RestaurantVenue/HotelVenue's own
/// PassportVenue/VenueEntry shape — Events V2 Step 4 deliberately keeps
/// Passport's Event integration additive (its own section, its own load
/// call) rather than extending the sealed PassportVenue type, so as not to
/// force every one of that type's ~10 exhaustive switch sites (Rankings,
/// Wishlist, Trips, My Map, Friend tiles) to grow an Events case as a side
/// effect of this step — see the Step 4 pre-final report's own PASSPORT
/// section for the full reasoning.
class EventAttendanceEntry {
  final EventConfirmedAttendance attendance;
  final Event event;

  /// A signed URL for this attendance's own most-recently-taken photo, if
  /// one exists — null otherwise. [PassportEventCard]'s image-priority
  /// rule (the user's own attendance photo, then the official Event
  /// image, then the branded placeholder) reads this field first; see
  /// [EventConfirmedAttendanceRepository.loadPassportEventAttendance] for
  /// how it's resolved.
  final String? coverPhotoUrl;

  const EventAttendanceEntry({
    required this.attendance,
    required this.event,
    this.coverPhotoUrl,
  });
}

/// Events V2 Step 8C — Passport's own "when did this actually happen"
/// order: most recent Event date first, using each entry's [Event.
/// startDate] — never [EventConfirmedAttendance.confirmedAt]/
/// `createdAt`, which describe when the row was logged, not when the
/// experience occurred (a post-event-prompt confirmation logged weeks
/// later, or a manually back-logged one, must still sort by the Event's
/// own date). Matches Restaurant/Hotel Passport's own "sort by when it
/// happened" convention exactly. Reuses the canonical
/// [compareEventChronology] rather than inventing a second comparator —
/// simply swaps the two operands to get descending (most-recent-first)
/// order from that same ascending (soonest-first) rule, including its
/// existing tie-break (a known start time before an unknown one, then
/// [Event.id]). Extracted as a standalone pure function, matching this
/// codebase's established "extract the pure part for direct testing"
/// convention (see [buildAttendanceDetailsUpdate] in this same file).
List<EventAttendanceEntry> sortEventAttendanceByEventDate(
  List<EventAttendanceEntry> entries,
) {
  final sorted = List<EventAttendanceEntry>.from(entries);
  sorted.sort((a, b) => compareEventChronology(b.event, a.event));
  return sorted;
}

/// Events V2 Step 8C — the [entries] whose Event happened in [year]
/// (all of them when [year] is null), using [Event.startDate].year —
/// never `confirmedAt.year`, so an Event that happened 31 Dec 2026 but
/// was confirmed 1 Jan 2027 still files under 2026, matching how
/// Restaurant/Hotel Passport already scopes by when a visit/stay itself
/// occurred.
List<EventAttendanceEntry> eventAttendanceInYear(
  List<EventAttendanceEntry> entries,
  int? year,
) {
  if (year == null) return entries;
  return [
    for (final entry in entries)
      if (entry.event.startDate.year == year) entry,
  ];
}

/// Every year with at least one confirmed Event attendance among
/// [entries], newest first — the Event-attendance equivalent of
/// [availableVisitYears] (`core/utils/visit_years.dart`), kept as its
/// own function here rather than folded into that shared helper: a year
/// with only Event attendance, and no Restaurant/Hotel visit at all,
/// must still be selectable — the two year lists are independent, not a
/// single merged set (see the Step 8C pre-final doc's Year Filter
/// section for the full reasoning).
List<int> availableEventAttendanceYears(List<EventAttendanceEntry> entries) {
  final years = entries.map((e) => e.event.startDate.year).toSet().toList();
  years.sort((a, b) => b.compareTo(a));
  return years;
}

/// Events V2 Step 4.1. Distinguishes "leave `would_recommend` unchanged"
/// (omit the `wouldRecommend` argument to [EventConfirmedAttendanceRepository
/// .updateAttendanceDetails] entirely — the parameter itself is null) from
/// "explicitly set it, including to null" (wrap the intended value in this
/// class). `rating`/`comment` reuse a simpler "null = don't touch"
/// convention on that same method (documented on its own doc comment,
/// unchanged by this step) because nothing yet needs to explicitly clear
/// them back to null; `would_recommend` cannot reuse that convention
/// because clearing an existing Yes/No answer back to "not answered" is a
/// real, required UI action (§10/§12 of the task this class was added
/// for), so its own nullability (`value`) and whether it was provided at
/// all (this wrapper being non-null) are two independent axes.
class WouldRecommendUpdate {
  final bool? value;
  const WouldRecommendUpdate(this.value);
}

/// Builds the `update` map [EventConfirmedAttendanceRepository
/// .updateAttendanceDetails] sends to Supabase — kept as a pure,
/// standalone function (no network call, no `this`) specifically so its
/// "omit vs explicit null" semantics are unit-testable without a live
/// Supabase client, matching this codebase's existing constraint that
/// Supabase-eager repositories/screens can't be exercised directly in the
/// test sandbox (see attendance_details_sheet_shell_test.dart's own header
/// comment for the identical limitation elsewhere in this feature).
Map<String, dynamic> buildAttendanceDetailsUpdate({
  int? rating,
  String? comment,
  ConfirmedAttendanceVisibility? visibility,
  WouldRecommendUpdate? wouldRecommend,
}) => {
  'rating': ?rating,
  'comment': ?comment,
  if (visibility != null) 'visibility': visibility.dbValue,
  if (wouldRecommend != null) 'would_recommend': wouldRecommend.value,
};

/// Reads/writes `public.event_confirmed_attendance` — the confirmed
/// HISTORY table (Events V2 Step 1 database foundation; unused by any
/// Dart code before Step 4). Structurally separate from
/// EventAttendanceRepository, which owns `event_attendance` (pre-event
/// INTENT) and deliberately does not touch this table — see that
/// repository's own doc comment. RLS
/// (event_confirmed_attendance_select/_insert/_update/_delete) is the
/// actual security boundary throughout; every read here returns only what
/// the database already decided the caller may see.
class EventConfirmedAttendanceRepository {
  EventConfirmedAttendanceRepository(this._client);

  final SupabaseClient _client;
  late final PhotoRepository _photoRepo = PhotoRepository(_client);

  /// The caller's own confirmed-attendance row for [eventId], or null if
  /// attendance has not been confirmed.
  Future<EventConfirmedAttendance?> getConfirmedAttendance({
    required String userId,
    required String eventId,
  }) async {
    final rows = await _client
        .from('event_confirmed_attendance')
        .select(_attendanceColumns)
        .eq('event_id', eventId)
        .eq('user_id', userId)
        .limit(1);
    final list = rows as List;
    if (list.isEmpty) return null;
    return EventConfirmedAttendance.fromJson(
      list.first as Map<String, dynamic>,
    );
  }

  /// Every event id in [eventIds] the caller already has a confirmed
  /// attendance row for — one batched query, never one lookup per event.
  /// Used by the Events-screen prompt surface to exclude already-resolved
  /// events from its own eligibility scan.
  Future<Set<String>> getConfirmedEventIds({
    required String userId,
    required Iterable<String> eventIds,
  }) async {
    final ids = eventIds.toList();
    if (ids.isEmpty) return {};
    final rows = await _client
        .from('event_confirmed_attendance')
        .select('event_id')
        .eq('user_id', userId)
        .inFilter('event_id', ids);
    return {for (final row in rows as List) row['event_id'] as String};
  }

  /// Creates a confirmed-attendance row. [rating]/[comment] are optional —
  /// a user can confirm attendance with neither (§10/§12's explicit "never
  /// required" rule).
  ///
  /// Idempotent against double-tap/retry/reopened-flow: the database's own
  /// `unique(event_id, user_id)` is the actual guarantee (§9); a 23505
  /// violation here means a confirmed row already exists for this pair, so
  /// the existing row is fetched and returned rather than surfacing a raw
  /// constraint error to the UI — the caller always gets back "the"
  /// confirmed-attendance row for this pair, whether this call created it
  /// or a prior one did.
  Future<EventConfirmedAttendance> confirmAttendance({
    required String userId,
    required String eventId,
    required EventAttendanceSource source,
    int? rating,
    String? comment,
    ConfirmedAttendanceVisibility visibility =
        ConfirmedAttendanceVisibility.private,
  }) async {
    try {
      final row = await _client
          .from('event_confirmed_attendance')
          .insert({
            'event_id': eventId,
            'user_id': userId,
            'source': source.dbValue,
            'visibility': visibility.dbValue,
            'rating': ?rating,
            if (comment != null && comment.isNotEmpty) 'comment': comment,
          })
          .select(_attendanceColumns)
          .single();
      return EventConfirmedAttendance.fromJson(row);
    } on PostgrestException catch (e) {
      if (e.code != '23505') rethrow;
      final existing = await getConfirmedAttendance(
        userId: userId,
        eventId: eventId,
      );
      if (existing != null) return existing;
      rethrow;
    }
  }

  /// Edits rating/would-recommend/comment/visibility on an already-
  /// confirmed attendance — distinct from [confirmAttendance], which only
  /// ever creates. [rating]/[comment] keep their pre-existing "left null =
  /// left unchanged" convention; there is deliberately no way to
  /// explicitly clear either back to null in this MVP pass (an edge case
  /// narrower than what §10/§12 asked this step to cover — noted, not
  /// silently worked around).
  ///
  /// [wouldRecommend] cannot reuse that convention (Events V2 Step 4.1):
  /// omit the argument entirely to leave `would_recommend` unchanged, or
  /// pass `WouldRecommendUpdate(true)`/`WouldRecommendUpdate(false)`/
  /// `WouldRecommendUpdate(null)` to explicitly set Yes/No/cleared — see
  /// [WouldRecommendUpdate]'s own doc comment for why this field needed
  /// its own mechanism rather than sharing rating/comment's.
  Future<EventConfirmedAttendance> updateAttendanceDetails({
    required String userId,
    required String attendanceId,
    int? rating,
    String? comment,
    ConfirmedAttendanceVisibility? visibility,
    WouldRecommendUpdate? wouldRecommend,
  }) async {
    final update = buildAttendanceDetailsUpdate(
      rating: rating,
      comment: comment,
      visibility: visibility,
      wouldRecommend: wouldRecommend,
    );
    final row = await _client
        .from('event_confirmed_attendance')
        .update(update)
        .eq('id', attendanceId)
        .eq('user_id', userId)
        .select(_attendanceColumns)
        .single();
    return EventConfirmedAttendance.fromJson(row);
  }

  /// Removes a confirmed attendance — §16's "remove from Passport" action.
  /// Ordering matches the photos security pre-apply report's §14 exactly:
  /// (1) delete the Storage photo objects first — while the photos rows
  /// (and therefore their storage_paths) are still queryable via
  /// [attendanceId] — then (2) delete the attendance row itself, which (3)
  /// cascades the `photos` ROWS automatically (`photos.attendance_id ...
  /// on delete cascade`, unlike visits' own manual two-step row delete).
  /// DB cascade only ever removes rows, never the actual Storage objects —
  /// step (1) is what closes that gap; skipping it would silently leak
  /// storage objects with nothing left referencing them. Storage cleanup
  /// is best-effort (see PhotoRepository.deleteAllPhotosForAttendance) so
  /// a storage hiccup never blocks the attendance removal the user asked
  /// for. Scoped by both id and user_id — belt-and-suspenders alongside
  /// RLS (event_confirmed_attendance_delete is already owner-only),
  /// matching every other owner-write method in this codebase.
  /// Deliberately does NOT recreate the Going intent row that may have
  /// been removed when this attendance was originally confirmed (§16:
  /// "removing history means 'I don't want this in my confirmed
  /// Passport,' not 'restore my old intent'").
  Future<void> deleteConfirmedAttendance({
    required String userId,
    required String attendanceId,
  }) async {
    await _photoRepo.deleteAllPhotosForAttendance(attendanceId: attendanceId);
    await _client
        .from('event_confirmed_attendance')
        .delete()
        .eq('id', attendanceId)
        .eq('user_id', userId);
  }

  /// Every confirmed attendance the caller has, each paired with its own
  /// Event and (if one exists) a signed URL for its cover photo — what
  /// Passport's Events filter renders. Three queries total regardless of
  /// row count (the confirmed-attendance rows, one batched `events`
  /// lookup, one batched `photos` lookup for cover images), matching
  /// EventAttendanceRepository.getFriendUpcomingEvents' own "never one
  /// query per row" convention.
  ///
  /// Events V2 Step 8C: sorted by the Event's own occurrence date, most
  /// recent first ([sortEventAttendanceByEventDate]) — not by
  /// `confirmed_at`, which only reflects when the row was logged. That
  /// sort needs the joined Event's own `startDate`, which isn't known
  /// until after the second query below resolves, so no SQL `.order(...)`
  /// is applied to the first query at all — it would only describe an
  /// intermediate, not-final order.
  Future<List<EventAttendanceEntry>> loadPassportEventAttendance(
    String userId,
  ) async {
    final rows = await _client
        .from('event_confirmed_attendance')
        .select(_attendanceColumns)
        .eq('user_id', userId);
    final attendanceRows = (rows as List).cast<Map<String, dynamic>>();
    if (attendanceRows.isEmpty) return [];

    final eventIds = [
      for (final row in attendanceRows) row['event_id'] as String,
    ];
    final eventRows = await _client
        .from('events')
        .select()
        .inFilter('id', eventIds);
    final eventsById = {
      for (final row in eventRows as List)
        (row as Map<String, dynamic>)['id'].toString(): Event.fromJson(row),
    };

    final attendanceIds = [
      for (final row in attendanceRows) row['id'] as String,
    ];
    final coverPathByAttendanceId = await _coverPhotoPaths(attendanceIds);
    final coverUrls = await _photoRepo.resolveDisplayUrls(
      coverPathByAttendanceId.values.toList(),
    );

    final entries = [
      for (final row in attendanceRows)
        if (eventsById[row['event_id'] as String] != null)
          EventAttendanceEntry(
            attendance: EventConfirmedAttendance.fromJson(row),
            event: eventsById[row['event_id'] as String]!,
            coverPhotoUrl:
                coverUrls[coverPathByAttendanceId[row['id'] as String]],
          ),
    ];
    return sortEventAttendanceByEventDate(entries);
  }

  /// One storage_path per attendance id — its most-recently-taken photo,
  /// if any. A single batched query (`attendance_id IN (...)`, ordered so
  /// the first row seen per attendance is the newest), never one query per
  /// attendance.
  Future<Map<String, String>> _coverPhotoPaths(
    List<String> attendanceIds,
  ) async {
    if (attendanceIds.isEmpty) return {};
    final rows = await _client
        .from('photos')
        .select('attendance_id, storage_path')
        .inFilter('attendance_id', attendanceIds)
        .order('taken_at', ascending: false);
    final byAttendanceId = <String, String>{};
    for (final row in rows as List) {
      final map = row as Map<String, dynamic>;
      final attendanceId = map['attendance_id'] as String;
      byAttendanceId.putIfAbsent(
        attendanceId,
        () => map['storage_path'] as String,
      );
    }
    return byAttendanceId;
  }
}
