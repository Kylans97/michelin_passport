import 'package:flutter/material.dart';
import '../../../data/repositories/planned_trips_repository.dart';
import '../../../models/planned_venue.dart';
import '../../../models/resolved_planned_venue.dart';
import '../../planning/widgets/plan_venue_sheet.dart';
import 'trip_chrome.dart';

/// Edit / cancel / delete for one planned venue — shared by
/// PlannedTripsScreen's standalone "PLANNED VISITS" list and
/// TripDetailScreen's trip-attached lists, so both offer the same actions
/// rather than only trip-attached plans being editable. Deleting only ever
/// removes the plan row itself — the underlying restaurant/hotel catalogue
/// data is never touched. Returns true if anything changed (caller should
/// reload), false/null otherwise.
Future<bool> showPlannedVenueActions(
  BuildContext context, {
  required ResolvedPlannedVenue item,
  required String userId,
  required PlannedTripsRepository repo,
}) async {
  final action = await showTripActionSheet<String>(
    context,
    title: item.venue.name,
    actions: [
      const TripSheetAction(
        value: 'edit',
        label: 'Edit plan',
        icon: Icons.edit_outlined,
      ),
      if (item.plan.status == PlannedVenueStatus.planned)
        const TripSheetAction(
          value: 'cancel',
          label: 'Cancel plan',
          icon: Icons.cancel_outlined,
        ),
      const TripSheetAction(
        value: 'delete',
        label: 'Delete',
        icon: Icons.delete_outline_rounded,
        destructive: true,
      ),
    ],
  );

  if (!context.mounted || action == null) return false;

  switch (action) {
    case 'edit':
      final saved = await showPlanVenueSheet(
        context,
        venue: item.venue,
        userId: userId,
        plannedTripsRepository: repo,
        existingPlan: item.plan,
      );
      return saved == true;
    case 'cancel':
      await repo.updatePlannedVenue(
        userId: userId,
        plannedVenueId: item.plan.id,
        tripId: item.plan.tripId,
        startDate: item.plan.startDate,
        endDate: item.plan.endDate,
        notes: item.plan.notes,
        status: PlannedVenueStatus.cancelled,
      );
      return true;
    case 'delete':
      if (!context.mounted) return false;
      final confirmed = await showTripConfirmDialog(
        context,
        title: 'Delete this plan?',
        message:
            'This removes the planned visit/stay only — the venue itself '
            'is never affected.',
        confirmLabel: 'Delete',
      );
      if (confirmed) {
        await repo.deletePlannedVenue(
          userId: userId,
          plannedVenueId: item.plan.id,
        );
        return true;
      }
      return false;
    default:
      return false;
  }
}
