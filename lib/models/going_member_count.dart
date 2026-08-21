// Events V2 Step 7 — the client-side counterpart to
// get_event_going_member_count(uuid), the SECURITY DEFINER SQL function
// that caps its own return value at 100 server-side (see that function's
// own migration header comment for the full privacy rationale). This
// file never computes or receives an exact count above 99 — it only ever
// wraps whatever the server already decided to disclose.

/// The capped, anonymous platform-wide Going count for one Event. [count]
/// is never the true value once the real count reaches 100 or more — the
/// server itself already capped it before this object was ever
/// constructed, so there is no way for this class (or anything upstream
/// of it in Dart) to recover the real number.
///
/// Deliberately not named with "exact" anywhere — [count] is only "exact"
/// below 100; [isCapped] exists specifically so no call site has to
/// re-derive the `>= 100` check by hand or accidentally treat a `count`
/// of exactly 100 as a real, displayable number.
class GoingMemberCount {
  /// 0-100. A value of 100 means "100 or more" — see [isCapped].
  final int count;

  const GoingMemberCount(this.count);

  /// True exactly when [count] is the capped sentinel (100), meaning the
  /// true platform-wide Going count is 100 or greater. The UI must render
  /// "100+" in this case, never the literal number 100.
  bool get isCapped => count >= 100;
}
