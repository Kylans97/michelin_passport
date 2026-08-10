import '../../../models/award_transition.dart';

/// Turns a Michelin-stars [AwardTransition] into its exact display copy.
/// This is the only star-specific piece of the Michelin timeline — the
/// transition detection itself ([detectAwardTransitions]) is award-type
/// agnostic. A future Michelin Keys (hotel) history would reuse
/// [detectAwardTransitions] unchanged and write its own key-specific
/// formatter alongside this one.
String michelinTransitionLabel(AwardTransition t) {
  String plural(int n) => n == 1 ? 'star' : 'stars';

  return switch (t.kind) {
    AwardChangeKind.firstAwarded =>
      t.value == 1
          ? 'First star'
          : 'First recorded at ${t.value} ${plural(t.value)}',
    AwardChangeKind.promoted => 'Promoted to ${t.value} ${plural(t.value)}',
    AwardChangeKind.decreased => 'Changed to ${t.value} ${plural(t.value)}',
    AwardChangeKind.lost => 'No longer Michelin-starred',
    AwardChangeKind.regained =>
      t.value == 1
          ? 'Regained 1 star'
          : 'Regained at ${t.value} ${plural(t.value)}',
  };
}
