// Events V2 Step 7 — centralized display copy for the anonymous
// platform-wide Going count, so pluralization/capping wording is never
// scattered across widgets. A pure, top-level function (no Supabase, no
// BuildContext) — mirrors formatEventDateRange/canAttendEvent's own
// established "pure, directly unit-testable" pattern in this feature.

import '../../models/going_member_count.dart';

/// The exact Event Detail copy for [memberCount], or null when nothing
/// should render at all (0 Going — the task's own explicit "show
/// nothing" rule, not an empty string or a "0 members going" line).
/// [memberCount.isCapped] always renders as `"100+ ..."`, never the
/// literal count of 100 — see [GoingMemberCount]'s own doc comment for
/// why the underlying value can never be anything other than exactly 100
/// once capped, so there is nothing more precise this function could show
/// even if it wanted to.
///
/// Copy is deliberately "Mantelier member(s) going" — never "users,"
/// "attendees," or "people registered" (this is intent, not a ticket
/// count or confirmed registration), matching Going's own existing
/// product meaning throughout this app.
String? formatGoingMemberCount(GoingMemberCount memberCount) {
  if (memberCount.count == 0) return null;
  if (memberCount.isCapped) return '100+ Mantelier members going';
  return memberCount.count == 1
      ? '1 Mantelier member going'
      : '${memberCount.count} Mantelier members going';
}
