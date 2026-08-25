import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/cs_image_placeholder.dart';

/// EVENT WISHLIST V1 — the Events tab's own empty state, visually in the
/// same family as [PassportEmptyState] (`passport_empty_state.dart`: same
/// small, quiet monogram, same restrained intent) but not a reuse of it —
/// that widget renders a single message line only, while this one needs a
/// two-tier headline + supporting copy and an optional "Explore events"
/// link, per this feature's own spec. Modifying [PassportEmptyState]
/// itself to support those extra slots would risk changing the
/// Restaurant/Hotel Wishlist empty states too, which this task doesn't
/// touch.
class EventWishlistEmptyState extends StatelessWidget {
  final VoidCallback? onExplore;

  const EventWishlistEmptyState({super.key, this.onExplore});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CsImagePlaceholder(
            width: 64,
            height: 64,
            borderRadius: BorderRadius.all(Radius.circular(CsRadius.medium)),
            logoScale: 0.5,
          ),
          const SizedBox(height: CsSpacing.lg),
          Text(
            'No saved events yet.',
            textAlign: TextAlign.center,
            style: CsTypography.placeTitle.copyWith(color: AppColors.textOnDark),
          ),
          const SizedBox(height: CsSpacing.xs),
          Text(
            'Events you want to experience will appear here.',
            textAlign: TextAlign.center,
            style: CsTypography.body.copyWith(color: AppColors.secondaryOnDark),
          ),
          if (onExplore != null) ...[
            const SizedBox(height: CsSpacing.md),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onExplore,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: CsSpacing.sm,
                    vertical: CsSpacing.xs,
                  ),
                  child: Text(
                    'Explore events →',
                    style: CsTypography.bodyMedium.copyWith(
                      color: AppColors.textOnDark,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
