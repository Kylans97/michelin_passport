import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../theme/cs_spacing.dart';
import '../theme/cs_typography.dart';

/// The compact "icon above label" utility row shared by Restaurant and
/// Hotel Detail, per the Clove Club reference's "DIRECTIONS · WEBSITE ·
/// CALL · [X]" pattern (UI Consistency Step 1D — final action alignment):
/// Mantelier uses Michelin Guide as its fourth action instead of
/// Share, since Michelin is more valuable to this product and there is no
/// existing share infrastructure (`share_plus` is not a dependency — Share
/// is deliberately not offered anywhere in this app today).
///
/// Only real, currently-available actions are ever shown — never a dead/
/// disabled button pretending to be real. [onOpenMaps] is the only
/// required callback (every venue can always be located); [onOpenWebsite],
/// [onCall], and [onOpenMichelin] are each omitted individually when that
/// action isn't available. [onCall] was a prepared seam until Restaurant
/// Enrichment Step 1D added `phone` to [Restaurant] — RestaurantDetailScreen
/// now wires a real callback whenever `buildTelUri` resolves one; Hotel
/// Detail still passes `null` (no `phone` field on [Hotel] yet, a natural
/// future follow-up, not implemented in Step 1D). The row already renders
/// correctly with 2, 3, or 4 actions and rebalances automatically, so
/// Hotel's own day-phone-data-lands change would only touch its call site.
/// Existing URL-generation logic is untouched — this widget only ever
/// receives already-resolved callbacks.
///
/// [onOpenGaultMillau] is the guide-page counterpart of [onOpenMichelin]:
/// the restaurant's own Gault&Millau page, wired only when its stored
/// `gault_millau_url` is a real URL (see GaultMillauAward.profileUrl).
/// There is no World's 50 Best equivalent yet — no per-venue 50 Best URL
/// is stored anywhere.
class VenueUtilityActions extends StatelessWidget {
  final VoidCallback onOpenMaps;
  final VoidCallback? onOpenWebsite;
  final VoidCallback? onCall;
  final VoidCallback? onOpenMichelin;
  final VoidCallback? onOpenGaultMillau;

  const VenueUtilityActions({
    super.key,
    required this.onOpenMaps,
    this.onOpenWebsite,
    this.onCall,
    this.onOpenMichelin,
    this.onOpenGaultMillau,
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
        if (onOpenMichelin != null)
          Expanded(
            child: _UtilityAction(
              icon: Icons.menu_book_rounded,
              label: 'Michelin',
              onTap: onOpenMichelin!,
            ),
          ),
        if (onOpenGaultMillau != null)
          Expanded(
            child: _UtilityAction(
              icon: Icons.auto_stories_rounded,
              label: 'Gault&Millau',
              onTap: onOpenGaultMillau!,
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
            // Scales down rather than truncating: with all five actions on
            // a 402pt phone, "Gault&Millau" otherwise reads "Gault&Mill…".
            // Every shorter label keeps its full size.
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
