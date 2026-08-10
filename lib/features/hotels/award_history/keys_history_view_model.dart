import '../../../models/award_transition.dart';

/// Turns a MICHELIN Keys [AwardTransition] into its exact display copy —
/// the Keys-specific counterpart to michelinTransitionLabel (restaurant
/// Stars). detectAwardTransitions itself is award-type agnostic and reused
/// unchanged; only the wording differs.
String keysTransitionLabel(AwardTransition t) {
  String plural(int n) => n == 1 ? 'Key' : 'Keys';

  return switch (t.kind) {
    AwardChangeKind.firstAwarded =>
      t.value == 1
          ? 'First Key'
          : 'First recorded at ${t.value} ${plural(t.value)}',
    AwardChangeKind.promoted => 'Promoted to ${t.value} ${plural(t.value)}',
    AwardChangeKind.decreased => 'Changed to ${t.value} ${plural(t.value)}',
    AwardChangeKind.lost => 'No longer holds a MICHELIN Key',
    AwardChangeKind.regained =>
      t.value == 1
          ? 'Regained 1 Key'
          : 'Regained at ${t.value} ${plural(t.value)}',
  };
}
