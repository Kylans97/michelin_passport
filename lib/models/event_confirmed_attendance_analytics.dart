// Kept as its own tiny file, mirroring event_intent.dart's own precedent
// (split from event_attendance.dart specifically so the model file itself
// never needs to import analytics_properties.dart).

import '../core/analytics/analytics_event.dart';
import '../core/analytics/analytics_properties.dart';
import 'event_confirmed_attendance.dart';

/// Translates the DB-layer [EventAttendanceSource] into the analytics-layer
/// [AttendanceSource] — two distinct enum types by this codebase's own
/// established convention (see [EventAttendanceSource]'s own doc comment):
/// the DB vocabulary and the analytics vocabulary happen to share the same
/// three values today, but are translated explicitly here rather than
/// merged into one type spanning both layers, the same way
/// ConfirmedAttendanceVisibility is kept distinct from AttendanceVisibility
/// despite an identical private/friends shape.
AttendanceSource attendanceSourceForAnalytics(EventAttendanceSource source) =>
    switch (source) {
      EventAttendanceSource.manual => AttendanceSource.manual,
      EventAttendanceSource.postEventPrompt => AttendanceSource.postEventPrompt,
      EventAttendanceSource.tripCompletion => AttendanceSource.tripCompletion,
    };

/// Events V2 Step 4.1. Which [AnalyticsEvent] (if any) an attendance-details
/// save of `wouldRecommend` should fire, given the value already on the row
/// before this save ([previous]) and the value being saved now ([next]).
/// Pure and call-site-independent specifically so this decision is
/// unit-testable without the Supabase-eager screens that actually call it
/// (EventDetailScreen._saveAttendanceDetails, EventsScreen's own prompt
/// save path) — both call this same function rather than duplicating the
/// three-way branch inline.
///
/// - [next] non-null (Yes or No, whether this is the first answer or a
///   changed one) → [AnalyticsEvent.eventRecommendationAdded]. Mirrors
///   `event_rating_added`'s own "fired on every save, no separate updated
///   event" convention — see that event's own doc comment.
/// - [next] null and [previous] non-null → an existing answer was just
///   cleared → [AnalyticsEvent.eventRecommendationRemoved].
/// - [next] null and [previous] null → nothing meaningful changed → `null`
///   (fire no event at all; the DB write itself is harmless as a no-op,
///   but analytics must never report a "removal" of something that was
///   never set — see EVENTS_V2_ANALYTICS_CONTRACT.md's Content section).
AnalyticsEvent? recommendationAnalyticsEvent({
  required bool? previous,
  required bool? next,
}) {
  if (next != null) return AnalyticsEvent.eventRecommendationAdded;
  if (previous != null) return AnalyticsEvent.eventRecommendationRemoved;
  return null;
}
