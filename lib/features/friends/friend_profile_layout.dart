/// The three friend-profile layouts being compared — dev-only, per the
/// task brief ("kies de layout met een dev-only instelling... Standaard
/// is A"). Switched live via a small debug-only A/B/C row on the screen
/// itself (see FriendProfileScreen) rather than a build-time constant, so
/// they can actually be compared side by side in a running app without a
/// rebuild.
enum FriendProfileLayout {
  /// "Hun paspoort" — read-only stamped passport page + wishlist ledger.
  passport,

  /// "Samen dineren" — shared-wishlist invitation card + verdict rows.
  dineTogether,

  /// "De column" — full ivory magazine page, mini-reviews + wishlist rail.
  column;

  static const FriendProfileLayout defaultLayout = FriendProfileLayout.passport;
}
