/// Shared "is this venue there the way the user expects it to be"
/// resolution for Restaurant and Hotel — the two lifecycle signals
/// (`status` and pop-up `is_expired`) are different data, but the same
/// product problem, so they resolve through one function rather than
/// four copies of the same branching in each tile/detail screen.
enum VenueLifecycleState {
  /// Ordinary venue, nothing to show.
  normal,

  /// A pop-up/temporary venue whose `ends_on` has passed. Informational,
  /// not a problem — the venue simply isn't running anymore.
  popupEnded,

  /// `status = 'temporarily_closed'`. Booking (see [venue_lifecycle.dart]
  /// callers) stays partially available — Website, not Call — per
  /// DATA_UPDATE_PROCESS.md §7.
  temporarilyClosed,

  /// `status = 'permanently_closed'`. Booking removed entirely; visit
  /// history stays visible (that's a different repository's concern,
  /// not this function's).
  permanentlyClosed,
}

/// Resolves the two lifecycle signals into one state, in priority order:
/// an explicit closure is a stronger, more deliberate signal than a
/// pop-up's own end date, so `status` wins whenever both could apply
/// (rare — a closed status on an ordinary permanent venue has no pop-up
/// fields at all, so this mostly matters for a pop-up that was also
/// manually marked closed).
VenueLifecycleState resolveLifecycleState({
  required String status,
  required bool isExpired,
}) {
  if (status == 'permanently_closed') return VenueLifecycleState.permanentlyClosed;
  if (status == 'temporarily_closed') return VenueLifecycleState.temporarilyClosed;
  if (isExpired) return VenueLifecycleState.popupEnded;
  return VenueLifecycleState.normal;
}
