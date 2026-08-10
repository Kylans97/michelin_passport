import 'award_history_entry.dart';

/// The kind of change a year's award value represents relative to the
/// previous *known* value — never relative to the previous *year*, since
/// guide years can be missing from the data entirely (see
/// [detectAwardTransitions]).
enum AwardChangeKind {
  /// The first known value in the history, and it is non-zero. No earlier
  /// state — recorded or not — is implied.
  firstAwarded,

  /// Strictly greater than the previous known non-zero value.
  promoted,

  /// Strictly less than the previous known value, but still above zero.
  decreased,

  /// Dropped to zero (no award) from a previous known non-zero value. Only
  /// ever produced when a row explicitly records the value 0 — a missing
  /// year is never interpreted as a loss.
  lost,

  /// Rose above zero after a previous known value of exactly zero (an
  /// explicit recorded "no award" row) — distinct from [firstAwarded],
  /// which has no such prior record at all.
  regained,
}

/// One detected change in an entity's award value, already collapsed from
/// raw annual rows — consecutive years with an unchanged value never
/// produce more than one [AwardTransition]. Award-type-agnostic (works
/// identically for Michelin stars today and Michelin Keys later); turning
/// this into display copy ("Promoted to 2 stars" vs "Promoted to 2 Keys")
/// is a separate, presentation-layer concern — see
/// michelin_history_view_model.dart.
class AwardTransition {
  final int guideYear;
  final int value;
  final int? previousValue;
  final AwardChangeKind kind;

  const AwardTransition({
    required this.guideYear,
    required this.value,
    required this.previousValue,
    required this.kind,
  });
}

/// Converts raw annual [history] rows (any order) into the list of moments
/// where the award value actually changed, oldest first.
///
/// Rules (see the Award History task spec for the exact product rationale):
/// - Rows with a null [MichelinAwardHistoryEntry.awardValue] are skipped —
///   an unknown year is never treated as unchanged, lost, or anything else.
/// - Consecutive known years with the same value produce no entry at all —
///   this is what collapses a decade of "3 stars" into a single moment, and
///   what makes a same-value `is_current` row (e.g. a 2026 row duplicating
///   an unchanged 2007 value) disappear rather than showing as a fake new
///   transition. `isCurrent` itself is never consulted here — every row is
///   compared purely on its value.
/// - A missing year is never treated as a loss or as continuity: the
///   comparison is always against the previous *known* value, whatever
///   year that was recorded in.
List<AwardTransition> detectAwardTransitions(
  List<MichelinAwardHistoryEntry> history,
) {
  final known = [
    for (final entry in history)
      if (entry.awardValue != null) entry,
  ]..sort((a, b) => a.guideYear.compareTo(b.guideYear));

  final transitions = <AwardTransition>[];
  int? previousValue; // null = no known prior record at all (not even 0).

  for (final entry in known) {
    final value = entry.awardValue!;
    if (previousValue == null) {
      // First known record. A recorded 0 establishes a known "no award"
      // baseline for future regain-detection, but isn't itself a moment
      // worth displaying.
      if (value > 0) {
        transitions.add(
          AwardTransition(
            guideYear: entry.guideYear,
            value: value,
            previousValue: null,
            kind: AwardChangeKind.firstAwarded,
          ),
        );
      }
    } else if (value != previousValue) {
      final AwardChangeKind kind;
      if (value == 0) {
        kind = AwardChangeKind.lost;
      } else if (previousValue == 0) {
        kind = AwardChangeKind.regained;
      } else if (value > previousValue) {
        kind = AwardChangeKind.promoted;
      } else {
        kind = AwardChangeKind.decreased;
      }
      transitions.add(
        AwardTransition(
          guideYear: entry.guideYear,
          value: value,
          previousValue: previousValue,
          kind: kind,
        ),
      );
    }
    previousValue = value;
  }

  return transitions;
}
