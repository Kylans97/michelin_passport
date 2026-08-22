import '../core/utils/event_time.dart';
import 'event.dart';

/// Events V2 Time Precision Phase B — the one canonical chronological
/// ordering for Events, replacing every previous
/// `a.startAt.compareTo(b.startAt)` call site (Trip matching's
/// [eventsMatchingTrip], Explore's [selectFeaturedEvent], Step 8A's
/// [rankEventsForDiscovery] tie-break). Primary: local calendar start date
/// ([compareCalendarDates] — zone-tag-agnostic, so it's correct regardless
/// of how either [Event.startDate] was constructed). Secondary, only
/// within the same start date: a KNOWN start time sorts before an UNKNOWN
/// one — deliberately, so a date-only Event never lands at an implied
/// arbitrary midnight position ahead of an Event that genuinely starts
/// earlier that same day (see the architecture audit's own Sorting
/// section: "do not sort date-only Events by invented midnight"). Two
/// known times compare directly. Final, purely mechanical tie-break:
/// [Event.id] — never a meaningful ranking signal, only a deterministic
/// answer when nothing else distinguishes two Events.
int compareEventChronology(Event a, Event b) {
  final dateCompare = compareCalendarDates(a.startDate, b.startDate);
  if (dateCompare != 0) return dateCompare;

  final aTime = a.startTime;
  final bTime = b.startTime;
  if (aTime != null && bTime != null) {
    final timeCompare = aTime.compareTo(bTime);
    if (timeCompare != 0) return timeCompare;
  } else if (aTime != null) {
    return -1;
  } else if (bTime != null) {
    return 1;
  }

  return a.id.compareTo(b.id);
}
