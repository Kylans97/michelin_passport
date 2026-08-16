import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../theme/cs_spacing.dart';
import '../theme/cs_typography.dart';

/// A restaurant/hotel row inside another venue's own detail screen — a
/// hotel's linked restaurants (DINING), or a restaurant's own related
/// hotel (AT THIS HOTEL). The shared, Cs-token-based twin of the
/// near-identical `_LinkedRestaurantRow` (HotelRestaurantsCard) and the
/// hotel-link row previously buried inside `RestaurantInfoCard`. Tapping
/// opens the existing canonical RestaurantDetailScreen/HotelDetailScreen —
/// unchanged, never a new detail screen.
///
/// [onTap] is nullable to preserve an existing distinction: a restaurant's
/// related-hotel name can come from a plain `property_name` string with no
/// real `hotel_id` behind it — not a genuine Michelin Key hotel row — in
/// which case it was never tappable and showed no chevron. That
/// non-interactive state survives here as `onTap == null`.
class LinkedVenueRow extends StatelessWidget {
  final String name;
  final Widget? recognition;
  final VoidCallback? onTap;
  final bool loading;

  const LinkedVenueRow({
    super.key,
    required this.name,
    this.recognition,
    this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final interactive = onTap != null;
    final content = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(CsSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.warmWhite,
        borderRadius: BorderRadius.circular(CsRadius.medium),
        border: Border.all(color: AppColors.subtleBorderLight),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: CsTypography.bodyMedium.copyWith(
                    color: AppColors.forestGreen,
                  ),
                ),
                if (recognition != null) ...[
                  const SizedBox(height: 4),
                  recognition!,
                ],
              ],
            ),
          ),
          if (interactive) ...[
            const SizedBox(width: CsSpacing.sm),
            loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: AppColors.taupe,
                      strokeWidth: 1.5,
                    ),
                  )
                : const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.taupe,
                    size: 20,
                  ),
          ],
        ],
      ),
    );

    if (!interactive) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(CsRadius.medium),
        child: content,
      ),
    );
  }
}
