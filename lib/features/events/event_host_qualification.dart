/// Events V2 Step 8A §6 — the exact, non-negotiable "from a host you
/// follow" qualification rule: a followed entity's link to an event
/// qualifies for [FollowedHostRelevanceReason] ONLY when that link is
/// explicitly marked as the event's host. Venue-only (the entity merely
/// hosted the event physically) and participant-only (the entity took part
/// without organizing) both leave [isHost] false and must NOT qualify,
/// regardless of [isVenue]'s value.
///
/// A one-line rule, deliberately pulled out into its own pure, named,
/// independently-unit-tested function rather than an inline `.eq('is_host',
/// true)` filter buried in a query — the task's own emphasis ("this
/// semantic rule is non-negotiable") is exactly the kind of thing that
/// should be provable by a test, not merely trusted from reading SQL.
bool eventHostFollowQualifies({required bool isHost, required bool isVenue}) =>
    isHost;
