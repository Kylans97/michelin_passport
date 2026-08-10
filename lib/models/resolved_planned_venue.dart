import 'passport_venue.dart';
import 'planned_venue.dart';

/// A [PlannedVenue] paired with the actual [PassportVenue] it addresses —
/// what My Planned Trips renders, since a plan row alone only carries
/// entity_type/entity_id, never a name/city to display.
class ResolvedPlannedVenue {
  final PlannedVenue plan;
  final PassportVenue venue;

  const ResolvedPlannedVenue({required this.plan, required this.venue});
}
