import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../theme/cs_spacing.dart';
import '../theme/cs_typography.dart';

/// The compact "icon above label" utility row shared by Restaurant and
/// Hotel Detail, per the Clove Club reference's "DIRECTIONS · WEBSITE ·
/// CALL" pattern (UI Consistency Step 1D — final action alignment). Share
/// is deliberately not offered (`share_plus` is not a dependency).
///
/// Only real, currently-available actions are ever shown — never a dead/
/// disabled button pretending to be real. [onOpenMaps] is the only
/// required callback (every venue can always be located); [onOpenWebsite]
/// and [onCall] are each omitted individually when that
/// action isn't available. [onCall] was a prepared seam until Restaurant
/// Enrichment Step 1D added `phone` to [Restaurant] — RestaurantDetailScreen
/// now wires a real callback whenever `buildTelUri` resolves one; Hotel
/// Detail still passes `null` (no `phone` field on [Hotel] yet, a natural
/// future follow-up, not implemented in Step 1D). The row already renders
/// correctly with 1, 2 or 3 actions and rebalances automatically, so
/// Hotel's own day-phone-data-lands change would only touch its call site.
/// Existing URL-generation logic is untouched — this widget only ever
/// receives already-resolved callbacks.
///
/// The guide pages (MICHELIN, World's 50 Best, Gault&Millau) used to be
/// actions here too, and on a venue with every award the row grew to six.
/// They moved to VenueGuideLinks beside Award history (2026-10-30), so
/// this row is only ever the practical Directions · Website · Call.
class VenueUtilityActions extends StatelessWidget {
  final VoidCallback onOpenMaps;
  final VoidCallback? onOpenWebsite;
  final VoidCallback? onCall;

  const VenueUtilityActions({
    super.key,
    required this.onOpenMaps,
    this.onOpenWebsite,
    this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _UtilityAction(
            icon: Icons.directions_rounded,
            label: 'Directions',
            onTap: onOpenMaps,
          ),
        ),
        if (onOpenWebsite != null)
          Expanded(
            child: _UtilityAction(
              icon: Icons.language_rounded,
              label: 'Website',
              onTap: onOpenWebsite!,
            ),
          ),
        if (onCall != null)
          Expanded(
            child: _UtilityAction(
              icon: Icons.call_rounded,
              label: 'Call',
              onTap: onCall!,
            ),
          ),
      ],
    );
  }
}

class _UtilityAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _UtilityAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(CsRadius.medium),
      splashColor: AppColors.forestGreen.withValues(alpha: 0.08),
      highlightColor: AppColors.forestGreen.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: CsSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.forestGreen, size: 20),
            const SizedBox(height: CsSpacing.xs),
            // Scales down rather than truncating, should a label ever be
            // too wide for its share of a narrow phone.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: CsTypography.smallLabel.copyWith(
                  color: AppColors.forestGreen,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
