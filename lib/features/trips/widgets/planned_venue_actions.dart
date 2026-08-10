import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/repositories/planned_trips_repository.dart';
import '../../../models/planned_venue.dart';
import '../../../models/resolved_planned_venue.dart';
import '../../planning/widgets/plan_venue_sheet.dart';

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
  final action = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(
              Icons.edit_outlined,
              color: AppColors.textPrimary,
            ),
            title: Text('Edit plan', style: GoogleFonts.inter()),
            onTap: () => Navigator.pop(context, 'edit'),
          ),
          if (item.plan.status == PlannedVenueStatus.planned)
            ListTile(
              leading: const Icon(
                Icons.cancel_outlined,
                color: AppColors.textSecondary,
              ),
              title: Text('Cancel plan', style: GoogleFonts.inter()),
              onTap: () => Navigator.pop(context, 'cancel'),
            ),
          ListTile(
            leading: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.error,
            ),
            title: Text(
              'Delete',
              style: GoogleFonts.inter(color: AppColors.error),
            ),
            onTap: () => Navigator.pop(context, 'delete'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
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
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.card,
          title: Text(
            'Delete this plan?',
            style: GoogleFonts.playfairDisplay(
              color: AppColors.textPrimary,
              fontSize: 18,
            ),
          ),
          content: Text(
            'This removes the planned visit/stay only — the venue itself '
            'is never affected.',
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(color: AppColors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                'Delete',
                style: GoogleFonts.inter(
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
      if (confirmed == true) {
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
